//
//  AppEnvironment.swift
//  Yapt
//
//  Dependency injection container
//

import Foundation
import Combine
import OSLog

@MainActor
class AppEnvironment: ObservableObject {
    // MARK: - Core Services
    let apiClient: APIClient
    let sseClient: SSEClient
    let sessionManager: SessionManager
    let errorHandler: ErrorHandler

    // MARK: - Feature Services
    let authService: AuthService
    let portfolioService: PortfolioService
    let positionService: PositionService
    let walletService: WalletService
    let notificationService: NotificationService
    let portfolioValueCache: PortfolioValueCache

    init() {
        // Initialize core services
        #if MOCK_API
        // Mock mode: Use MockAPIClient instead of real APIClient
        self.apiClient = MockAPIClient()
        Logger.network.info("[MOCK] Using MockAPIClient - all API calls will use mock data")
        #else
        // Production mode: Use real APIClient
        self.apiClient = APIClient()
        #endif

        self.sseClient = SSEClient()
        self.sessionManager = SessionManager()
        self.errorHandler = ErrorHandler(sessionManager: sessionManager)

        // Set error handler in APIClient for global error handling
        self.apiClient.errorHandler = errorHandler

        // Initialize feature services (work with both real and mock APIClient)
        self.authService = AuthService(apiClient: apiClient, sessionManager: sessionManager)
        self.portfolioService = PortfolioService(apiClient: apiClient)
        self.positionService = PositionService(apiClient: apiClient)
        self.walletService = WalletService(apiClient: apiClient, sseClient: sseClient)
        self.notificationService = NotificationService(apiClient: apiClient)
        self.portfolioValueCache = PortfolioValueCache()
    }
}
