//
//  AppEnvironment.swift
//  Yapt
//
//  Dependency injection container
//

import Foundation
import Combine

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

    init() {
        // Initialize core services
        self.apiClient = APIClient()
        self.sseClient = SSEClient()
        self.sessionManager = SessionManager()
        self.errorHandler = ErrorHandler(sessionManager: sessionManager)

        // Set error handler in APIClient for global error handling
        self.apiClient.errorHandler = errorHandler

        // Initialize feature services
        self.authService = AuthService(apiClient: apiClient, sessionManager: sessionManager)
        self.portfolioService = PortfolioService(apiClient: apiClient)
        self.positionService = PositionService(apiClient: apiClient)
        self.walletService = WalletService(apiClient: apiClient, sseClient: sseClient)
    }
}
