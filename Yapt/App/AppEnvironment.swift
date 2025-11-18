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
    let sessionManager: SessionManager

    // MARK: - Feature Services
    let authService: AuthService
    let portfolioService: PortfolioService
    let positionService: PositionService
    let walletService: WalletService

    init() {
        // Initialize core services
        self.apiClient = APIClient()
        self.sessionManager = SessionManager()

        // Initialize feature services
        self.authService = AuthService(apiClient: apiClient, sessionManager: sessionManager)
        self.portfolioService = PortfolioService(apiClient: apiClient)
        self.positionService = PositionService(apiClient: apiClient)
        self.walletService = WalletService(apiClient: apiClient)
    }
}
