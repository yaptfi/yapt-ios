//
//  MockConfiguration.swift
//  Yapt
//
//  Configuration for mock API scenarios and behavior
//

import Foundation

#if MOCK_API

/// Mock API scenario types
enum MockScenario {
    case success        // Normal happy path with data
    case empty          // Empty states (no positions, no wallets)
    case unauthorized   // 401 error - triggers session expiration
    case serverError    // 500 error - server failure
    case networkTimeout // Simulates network timeout
}

/// Global mock configuration
struct MockConfiguration {
    /// Current mock scenario
    static var scenario: MockScenario = .success

    /// Network delay in seconds (simulates slow network)
    static var networkDelay: TimeInterval = 0.0

    /// Whether to log mock API calls
    static var enableLogging: Bool = true

    /// Get the filename for portfolio summary based on scenario
    static var portfolioSummaryFile: String {
        switch scenario {
        case .success:
            return "portfolio-summary"
        case .empty:
            return "portfolio-summary-empty"
        case .unauthorized, .serverError, .networkTimeout:
            return "portfolio-summary"
        }
    }

    /// Get the filename for positions based on scenario
    static var positionsFile: String {
        switch scenario {
        case .success:
            return "positions"
        case .empty:
            return "positions-empty"
        case .unauthorized, .serverError, .networkTimeout:
            return "positions"
        }
    }

    /// Get the filename for wallets based on scenario
    static var walletsFile: String {
        switch scenario {
        case .success:
            return "wallets"
        case .empty:
            return "wallets-empty"
        case .unauthorized, .serverError, .networkTimeout:
            return "wallets"
        }
    }

    /// Check if the current scenario should return an error
    static func shouldReturnError(for path: String) -> MockError? {
        switch scenario {
        case .unauthorized:
            return .unauthorized
        case .serverError:
            return .serverError
        case .networkTimeout:
            return .timeout
        case .success, .empty:
            return nil
        }
    }
}

/// Mock error types
enum MockError: Error {
    case unauthorized
    case serverError
    case timeout
}

#endif
