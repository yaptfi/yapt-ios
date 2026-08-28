//
//  APIError.swift
//  Yapt
//
//  API error types
//

import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case conflict(String)
    case serverError(Int, String?)
    case eventStreamError(String)
    case decodingError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Authentication required. Please log in again."
        case .forbidden:
            return "You don't have permission to perform this action"
        case .notFound:
            return "Resource not found"
        case .conflict(let message):
            return message
        case .serverError(let code, let message):
            return message ?? "Server error (\(code))"
        case .eventStreamError(let message):
            return message
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .unknown:
            return "An unknown error occurred"
        }
    }

    var isAuthError: Bool {
        if case .unauthorized = self {
            return true
        }
        return false
    }
}
