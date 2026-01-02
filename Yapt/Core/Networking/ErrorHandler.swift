//
//  ErrorHandler.swift
//  Yapt
//
//  Global error handler for API errors and session management
//

import Foundation
import Combine
import OSLog

@MainActor
class ErrorHandler: ObservableObject {
    // MARK: - Published State

    /// Banner message to display to user (e.g., "Session expired")
    @Published var bannerMessage: String?

    /// Whether to show the banner
    @Published var showBanner: Bool = false

    // MARK: - Dependencies

    private let sessionManager: SessionManager
    private var cancellables = Set<AnyCancellable>()
    private var autoDismissTask: DispatchWorkItem?
    private var hasShownLogoutBanner = false

    // MARK: - Initialization

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager

        // Reset banner flag when user logs back in
        sessionManager.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    // User logged in - reset flag
                    self?.hasShownLogoutBanner = false
                } else {
                    // User logged out - immediately hide any banners
                    if self?.showBanner == true {
                        self?.dismissBanner()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Error Handling

    /// Handle API errors globally
    /// - Parameter error: The API error to handle
    /// - Returns: True if error was handled globally, false if it should be handled locally
    func handle(_ error: APIError) -> Bool {
        switch error {
        case .unauthorized, .forbidden:
            handleAuthError(error)
            return true

        default:
            // Let ViewModels handle other errors locally
            return false
        }
    }

    // MARK: - Private Methods

    private func handleAuthError(_ error: APIError) {
        Logger.auth.warning("Auth error detected: \(error.localizedDescription)")

        // Check if user was authenticated before logout
        let wasAuthenticated = sessionManager.isAuthenticated

        // Don't show banner if we already showed one for this logout session
        guard wasAuthenticated && !hasShownLogoutBanner else {
            if !wasAuthenticated {
                Logger.auth.debug("Skipping error banner - user already logged out")
            } else {
                Logger.auth.debug("Skipping error banner - already shown for this session")
            }

            // Still need to logout if authenticated
            if wasAuthenticated {
                sessionManager.logout()
            }
            return
        }

        // Mark that we've shown the banner for this logout session
        hasShownLogoutBanner = true

        // Clear session
        sessionManager.logout()

        // Show banner to inform user why they were logged out
        let message: String
        if case .unauthorized = error {
            message = "Session expired. Please sign in again."
        } else {
            message = "Access denied. Please sign in again."
        }

        showBanner(message: message)
    }

    /// Display a banner message to the user
    private func showBanner(message: String) {
        // Cancel any existing auto-dismiss task
        autoDismissTask?.cancel()

        bannerMessage = message
        showBanner = true

        // Auto-dismiss after 5 seconds
        let task = DispatchWorkItem { [weak self] in
            self?.dismissBanner()
        }
        autoDismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: task)
    }

    /// Dismiss the current banner
    func dismissBanner() {
        // Cancel auto-dismiss timer
        autoDismissTask?.cancel()
        autoDismissTask = nil

        showBanner = false

        // Clear message after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.bannerMessage = nil
        }
    }
}
