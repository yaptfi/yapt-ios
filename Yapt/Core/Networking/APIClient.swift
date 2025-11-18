//
//  APIClient.swift
//  Yapt
//
//  Core API client with cookie-based session support
//

import Foundation
import Combine
import OSLog

class APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        // Configure URLSession with shared cookie storage for session cookies
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = .shared
        configuration.httpCookieAcceptPolicy = .always
        configuration.timeoutIntervalForRequest = Constants.API.timeout
        configuration.waitsForConnectivity = true

        self.session = URLSession(configuration: configuration)

        // Configure JSON decoder
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds first
            if let date = Formatters.iso8601.date(from: dateString) {
                return date
            }

            // Fallback to standard ISO8601
            let fallbackFormatter = ISO8601DateFormatter()
            if let date = fallbackFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string \(dateString)"
            )
        }
    }

    // MARK: - Request Methods

    /// Build a URLRequest from an APIEndpoint
    /// Used for SSE streaming and custom request handling
    func buildRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        guard let url = endpoint.url() else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body

        // Set headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return request
    }

    /// Perform a request and decode the response
    func request<T: Decodable>(_ endpoint: APIEndpoint) -> AnyPublisher<T, APIError> {
        guard let url = endpoint.url() else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body

        // Set headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        Logger.network.debug("[\(endpoint.method.rawValue)] \(url.absoluteString)")

        return session.dataTaskPublisher(for: request)
            .tryMap { [weak self] data, response -> Data in
                try self?.handleResponse(data: data, response: response, url: url) ?? data
            }
            .decode(type: T.self, decoder: decoder)
            .mapError { error -> APIError in
                if let apiError = error as? APIError {
                    return apiError
                } else if error is DecodingError {
                    Logger.network.error("Decoding error: \(error.localizedDescription)")
                    return .decodingError(error)
                } else {
                    Logger.network.error("Network error: \(error.localizedDescription)")
                    return .networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }

    /// Perform a request without decoding (for empty responses like DELETE)
    func request(_ endpoint: APIEndpoint) -> AnyPublisher<Void, APIError> {
        guard let url = endpoint.url() else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        Logger.network.debug("[\(endpoint.method.rawValue)] \(url.absoluteString)")

        return session.dataTaskPublisher(for: request)
            .tryMap { [weak self] data, response -> Void in
                _ = try self?.handleResponse(data: data, response: response, url: url)
                return ()
            }
            .mapError { error -> APIError in
                if let apiError = error as? APIError {
                    return apiError
                } else {
                    Logger.network.error("Network error: \(error.localizedDescription)")
                    return .networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Response Handling

    private func handleResponse(data: Data, response: URLResponse, url: URL) throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.network.error("Invalid response type")
            throw APIError.invalidResponse
        }

        Logger.network.debug("[\(httpResponse.statusCode)] \(url.absoluteString)")

        switch httpResponse.statusCode {
        case 200...299:
            return data

        case 401:
            Logger.network.warning("Unauthorized request to \(url.absoluteString)")
            throw APIError.unauthorized

        case 403:
            Logger.network.warning("Forbidden request to \(url.absoluteString)")
            throw APIError.forbidden

        case 404:
            Logger.network.warning("Not found: \(url.absoluteString)")
            throw APIError.notFound

        case 409:
            // Try to extract error message from response
            let errorMessage = try? extractErrorMessage(from: data)
            Logger.network.warning("Conflict: \(errorMessage ?? "Unknown conflict")")
            throw APIError.conflict(errorMessage ?? "Resource conflict")

        case 400...499:
            let errorMessage = try? extractErrorMessage(from: data)
            Logger.network.error("Client error (\(httpResponse.statusCode)): \(errorMessage ?? "Unknown")")
            throw APIError.serverError(httpResponse.statusCode, errorMessage)

        case 500...599:
            let errorMessage = try? extractErrorMessage(from: data)
            Logger.network.error("Server error (\(httpResponse.statusCode)): \(errorMessage ?? "Unknown")")
            throw APIError.serverError(httpResponse.statusCode, errorMessage)

        default:
            Logger.network.error("Unknown status code: \(httpResponse.statusCode)")
            throw APIError.unknown
        }
    }

    private func extractErrorMessage(from data: Data) throws -> String? {
        struct ErrorResponse: Decodable {
            let error: String
        }

        let response = try decoder.decode(ErrorResponse.self, from: data)
        return response.error
    }

    // MARK: - Cookie Management

    func clearCookies() {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return }

        for cookie in cookies where cookie.domain.contains("yapt.fi") {
            HTTPCookieStorage.shared.deleteCookie(cookie)
            Logger.network.debug("Deleted cookie: \(cookie.name)")
        }
    }

    func printCookies() {
        guard let cookies = HTTPCookieStorage.shared.cookies else {
            Logger.network.debug("No cookies found")
            return
        }

        let yaptCookies = cookies.filter { $0.domain.contains("yapt.fi") }
        Logger.network.debug("Yapt cookies: \(yaptCookies.map { $0.name }.joined(separator: ", "))")
    }
}
