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

    // MARK: - Initialization

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
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

        // Clear session
        sessionManager.logout()

        // Show banner
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
        bannerMessage = message
        showBanner = true

        // Auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.dismissBanner()
        }
    }

    /// Dismiss the current banner
    func dismissBanner() {
        showBanner = false

        // Clear message after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.bannerMessage = nil
        }
    }
}
