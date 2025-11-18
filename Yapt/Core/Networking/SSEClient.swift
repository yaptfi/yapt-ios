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

    /// Publisher that emits SSE event data as JSON strings
    var events: AnyPublisher<String, APIError> {
        eventSubject.eraseToAnyPublisher()
    }

    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = .infinity
        configuration.timeoutIntervalForResource = .infinity
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    /// Start streaming from an SSE endpoint
    /// - Parameter request: URLRequest configured for SSE endpoint
    func startStreaming(request: URLRequest) {
        guard task == nil else {
            Logger.network.warning("SSE stream already active, ignoring startStreaming call")
            return
        }

        var sseRequest = request
        sseRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        sseRequest.timeoutInterval = .infinity

        buffer = Data()
        task = session?.dataTask(with: sseRequest)

        Logger.network.info("Starting SSE stream to: \(sseRequest.url?.absoluteString ?? "unknown")")
        task?.resume()
    }

    /// Stop the active SSE stream
    func stopStreaming() {
        guard task != nil else { return }

        Logger.network.info("Stopping SSE stream")
        task?.cancel()
        task = nil
        buffer = Data()
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
    private func processLine(_ line: String) {
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
            completionHandler(.cancel)
            return
        }

        // Log synchronously
        let statusCode = httpResponse.statusCode
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")

        // Check status code and content type
        if statusCode != 200 {
            Task { @MainActor in
                Logger.network.error("SSE stream failed with status \(statusCode)")
                eventSubject.send(completion: .failure(.serverError(statusCode, "SSE connection failed")))
            }
            completionHandler(.cancel)
            return
        }

        Task { @MainActor in
            Logger.network.info("SSE stream connected: status \(statusCode)")

            // Verify content type
            if let contentType = contentType, !contentType.contains("text/event-stream") {
                Logger.network.warning("Unexpected content type for SSE: \(contentType)")
            }
        }

        completionHandler(.allow)
    }

    nonisolated func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        Task { @MainActor in
            buffer.append(data)
            parseBuffer()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                // Ignore cancellation errors (user-initiated)
                if (error as NSError).code == NSURLErrorCancelled {
                    Logger.network.info("SSE stream cancelled by user")
                    eventSubject.send(completion: .finished)
                } else {
                    Logger.network.error("SSE stream error: \(error.localizedDescription)")
                    eventSubject.send(completion: .failure(.networkError(error)))
                }
            } else {
                Logger.network.info("SSE stream completed successfully")
                eventSubject.send(completion: .finished)
            }

            self.task = nil
            self.buffer = Data()
        }
    }
}
