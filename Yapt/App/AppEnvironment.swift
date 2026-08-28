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
    let pushNotificationService: PushNotificationService
    let portfolioValueCache: PortfolioValueCache
    let positionChangeSettings: PositionChangeSettings
    private var cancellables = Set<AnyCancellable>()

    init() {
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

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
        self.sseClient.errorHandler = errorHandler

        // Initialize feature services (work with both real and mock APIClient)
        self.authService = AuthService(apiClient: apiClient, sessionManager: sessionManager)
        self.portfolioService = PortfolioService(apiClient: apiClient)
        self.positionChangeSettings = PositionChangeSettings()
        self.positionService = PositionService(apiClient: apiClient, changeSettings: positionChangeSettings)
        self.walletService = WalletService(apiClient: apiClient, sseClient: sseClient)
        self.notificationService = NotificationService(apiClient: apiClient)
        self.pushNotificationService = PushNotificationService(
            notificationService: notificationService,
            registerAsNotificationDelegate: !isRunningTests
        )
        self.portfolioValueCache = PortfolioValueCache()

        portfolioValueCache.setActiveUserID(sessionManager.currentUser?.id)
        observeSessionState()
    }

    private func observeSessionState() {
        sessionManager.$currentUser
            .sink { [weak self] user in
                self?.portfolioValueCache.setActiveUserID(user?.id)
            }
            .store(in: &cancellables)

        sessionManager.$isAuthenticated
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] isAuthenticated in
                guard let self, !isAuthenticated else { return }
                clearSessionScopedState()
            }
            .store(in: &cancellables)
    }

    private func clearSessionScopedState() {
        sseClient.stopStreaming()
        portfolioService.clearCache()
        positionService.clearCache()
        walletService.clearCache()
        notificationService.clearCache()
        portfolioValueCache.clearAllValues()
    }
}
