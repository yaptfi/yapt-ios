//
//  SSEClient.swift
//  Yapt
//
//  Server-Sent Events (SSE) client for real-time streaming
//

import Foundation
import Combine
import OSLog

/// Client for handling Server-Sent Events (SSE) streams
/// Uses URLSessionDataDelegate for line-by-line parsing of text/event-stream format
@MainActor
class SSEClient: NSObject, ObservableObject {
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var eventSubject = PassthroughSubject<String, APIError>()
    private var buffer = Data()
    private var errorResponseBody = Data()
    private var hasCompletedStream = false

    /// Global error handler for authentication failures received before an SSE stream starts.
    weak var errorHandler: ErrorHandler?

    /// Publisher that emits SSE event data as JSON strings
    var events: AnyPublisher<String, APIError> {
        eventSubject.eraseToAnyPublisher()
    }

    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = .shared
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.timeoutIntervalForRequest = .infinity
        configuration.timeoutIntervalForResource = .infinity
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    /// Start streaming from an SSE endpoint
    /// - Parameter request: URLRequest configured for SSE endpoint
    func startStreaming(request: URLRequest) {
        guard prepareStreaming(request: request) else { return }
        task?.resume()
    }

    /// Create a stream that connects only after a subscriber is attached.
    func stream(request: URLRequest) -> AnyPublisher<String, APIError> {
        Deferred { [weak self] () -> AnyPublisher<String, APIError> in
            guard let self else {
                return Fail(error: APIError.unknown).eraseToAnyPublisher()
            }

            guard self.prepareStreaming(request: request) else {
                return Fail(
                    error: APIError.eventStreamError("Another event stream is already active")
                )
                .eraseToAnyPublisher()
            }

            return self.eventSubject
                .handleEvents(
                    receiveSubscription: { [weak self] _ in
                        self?.task?.resume()
                    },
                    receiveCancel: { [weak self] in
                        self?.stopStreaming()
                    }
                )
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    private func prepareStreaming(request: URLRequest) -> Bool {
        guard task == nil else {
            Logger.network.warning("SSE stream already active, ignoring startStreaming call")
            return false
        }

        var sseRequest = request
        sseRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        sseRequest.timeoutInterval = .infinity

        // A completed subject cannot be reused across streams.
        // Recreate it for each new stream so new subscribers receive events.
        eventSubject = PassthroughSubject<String, APIError>()
        buffer = Data()
        errorResponseBody = Data()
        hasCompletedStream = false
        task = session?.dataTask(with: sseRequest)

        Logger.network.info("Starting SSE stream to: \(sseRequest.url?.absoluteString ?? "unknown")")
        return task != nil
    }

    /// Stop the active SSE stream
    func stopStreaming() {
        guard task != nil else { return }

        Logger.network.info("Stopping SSE stream")
        task?.cancel()
    }

    /// Parse buffered data for complete SSE messages
    private func parseBuffer() {
        guard let string = String(data: buffer, encoding: .utf8) else {
            return
        }

        let lines = string.components(separatedBy: .newlines)

        // Keep last incomplete line in buffer
        if let lastLine = lines.last, !lastLine.isEmpty {
            if let lastLineData = lastLine.data(using: .utf8) {
                buffer = lastLineData
            }
        } else {
            buffer = Data()
        }

        // Process complete lines
        for line in lines.dropLast() {
            processLine(line)
        }
    }

    /// Process a single SSE line
    func processLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Skip empty lines and comments
        guard !trimmed.isEmpty, !trimmed.hasPrefix(":") else {
            return
        }

        // Parse "data: {...}" format
        if trimmed.hasPrefix("data:") {
            let jsonString = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)

            // Validate it's valid JSON
            guard let jsonData = jsonString.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: jsonData)) != nil else {
                Logger.network.warning("Invalid JSON in SSE data line: \(jsonString.prefix(100))")
                return
            }

            Logger.network.debug("SSE event received: \(jsonString.prefix(100))...")
            eventSubject.send(jsonString)
        }
        // Ignore other SSE fields (event:, id:, retry:) for now
    }

    private func finishStream(with completion: Subscribers.Completion<APIError>) {
        guard !hasCompletedStream else { return }
        hasCompletedStream = true

        if case .failure(let error) = completion {
            _ = errorHandler?.handle(error)
        }

        eventSubject.send(completion: completion)
    }

    func errorForHTTPResponse(statusCode: Int, body: Data) -> APIError {
        struct ErrorResponse: Decodable {
            let error: String
        }

        let message = try? JSONDecoder().decode(ErrorResponse.self, from: body).error

        switch statusCode {
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404 where message == nil:
            return .notFound
        case 409:
            return .conflict(message ?? "Resource conflict")
        default:
            return .serverError(statusCode, message)
        }
    }

    nonisolated deinit {
        task?.cancel()
        session?.invalidateAndCancel()
    }
}

// MARK: - URLSessionDataDelegate
extension SSEClient: URLSessionDataDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let httpResponse = response as? HTTPURLResponse else {
            Task { @MainActor in
                self.finishStream(with: .failure(.invalidResponse))
            }
            completionHandler(.cancel)
            return
        }

        // Log synchronously
        let statusCode = httpResponse.statusCode
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")

        // Error responses have ordinary JSON bodies, so allow the body to arrive before failing.
        if statusCode != 200 {
            completionHandler(.allow)
            return
        }

        guard let contentType,
              contentType.localizedCaseInsensitiveContains("text/event-stream") else {
            Task { @MainActor in
                Logger.network.error("SSE response did not use text/event-stream")
                self.finishStream(with: .failure(.invalidResponse))
            }
            completionHandler(.cancel)
            return
        }

        Task { @MainActor in
            Logger.network.info("SSE stream connected: status \(statusCode)")
        }

        completionHandler(.allow)
    }

    nonisolated func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        let statusCode = (dataTask.response as? HTTPURLResponse)?.statusCode

        Task { @MainActor in
            guard dataTask === self.task else { return }

            if statusCode == 200 {
                self.buffer.append(data)
                self.parseBuffer()
            } else {
                self.errorResponseBody.append(data)
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let response = task.response
        let httpResponse = response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode
        let contentType = httpResponse?.value(forHTTPHeaderField: "Content-Type")
        let hasValidSSEContentType = contentType?.localizedCaseInsensitiveContains("text/event-stream") == true

        Task { @MainActor in
            guard task === self.task else { return }

            if response != nil, httpResponse == nil {
                self.finishStream(with: .failure(.invalidResponse))
            } else if let statusCode, statusCode != 200 {
                let apiError = self.errorForHTTPResponse(
                    statusCode: statusCode,
                    body: self.errorResponseBody
                )
                Logger.network.error("SSE request failed with status \(statusCode)")
                self.finishStream(with: .failure(apiError))
            } else if statusCode == 200, !hasValidSSEContentType {
                self.finishStream(with: .failure(.invalidResponse))
            } else if let error = error {
                // Ignore cancellation errors (user-initiated)
                if (error as NSError).code == NSURLErrorCancelled {
                    Logger.network.info("SSE stream cancelled by user")
                    self.finishStream(with: .finished)
                } else {
                    Logger.network.error("SSE stream error: \(error.localizedDescription)")
                    self.finishStream(with: .failure(.networkError(error)))
                }
            } else {
                if !self.buffer.isEmpty,
                   let finalLine = String(data: self.buffer, encoding: .utf8) {
                    self.processLine(finalLine)
                }
                Logger.network.info("SSE stream completed successfully")
                self.finishStream(with: .finished)
            }

            self.task = nil
            self.buffer = Data()
            self.errorResponseBody = Data()
        }
    }
}
