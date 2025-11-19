//
//  MockAPIClient.swift
//  Yapt
//
//  Mock API client that returns data from JSON files
//

import Foundation
import Combine
import OSLog

#if MOCK_API

class MockAPIClient: APIClient {

    // MARK: - Request Methods Override

    override func request<T: Decodable>(_ endpoint: APIEndpoint) -> AnyPublisher<T, APIError> {
        if MockConfiguration.enableLogging {
            Logger.network.info("[MOCK] Request: \(endpoint.path)")
        }

        // Check if scenario should return an error
        if let mockError = MockConfiguration.shouldReturnError(for: endpoint.path) {
            return createErrorPublisher(mockError)
        }

        // Get mock data based on endpoint
        return createMockPublisher(for: endpoint)
    }

    override func request(_ endpoint: APIEndpoint) -> AnyPublisher<Void, APIError> {
        if MockConfiguration.enableLogging {
            Logger.network.info("[MOCK] Request (void): \(endpoint.path)")
        }

        // Check if scenario should return an error
        if let mockError = MockConfiguration.shouldReturnError(for: endpoint.path) {
            return Fail(error: mapMockError(mockError))
                .delay(for: .seconds(MockConfiguration.networkDelay), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }

        // For void requests (like DELETE), just return success
        return Just(())
            .setFailureType(to: APIError.self)
            .delay(for: .seconds(MockConfiguration.networkDelay), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: - Mock Data Loading

    private func createMockPublisher<T: Decodable>(for endpoint: APIEndpoint) -> AnyPublisher<T, APIError> {
        let filename = getMockFilename(for: endpoint.path)

        // Load mock data
        guard let mockData: T = MockDataLoader.loadOptional(filename) else {
            Logger.network.error("[MOCK] Failed to load mock data for: \(endpoint.path)")
            return Fail(error: APIError.decodingError(NSError(domain: "MockAPI", code: -1, userInfo: [:])))
                .eraseToAnyPublisher()
        }

        if MockConfiguration.enableLogging {
            Logger.network.info("[MOCK] Loaded: \(filename).json")
        }

        // Return with optional delay
        return Just(mockData)
            .setFailureType(to: APIError.self)
            .delay(for: .seconds(MockConfiguration.networkDelay), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    private func createErrorPublisher<T>(_ error: MockError) -> AnyPublisher<T, APIError> {
        return Fail(error: mapMockError(error))
            .delay(for: .seconds(MockConfiguration.networkDelay), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: - Path to Filename Mapping

    private func getMockFilename(for path: String) -> String {
        switch path {
        case "/api/auth/me":
            return "user"

        case "/api/portfolio/summary":
            return MockConfiguration.portfolioSummaryFile

        case "/api/positions":
            return MockConfiguration.positionsFile

        case "/api/wallets":
            return MockConfiguration.walletsFile

        default:
            Logger.network.warning("[MOCK] No mock file mapped for path: \(path), using default")
            return "user"
        }
    }

    // MARK: - Error Mapping

    private func mapMockError(_ error: MockError) -> APIError {
        switch error {
        case .unauthorized:
            return .unauthorized
        case .serverError:
            return .serverError(500, "Internal server error")
        case .timeout:
            return .networkError(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil))
        }
    }
}

#endif
