//
//  SettingsViewModel.swift
//  Yapt
//
//  Settings view model
//

import Foundation
import Combine
import OSLog

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoggingOut: Bool = false
    @Published var errorMessage: String?

    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()

    init(authService: AuthService) {
        self.authService = authService
    }

    func loadUser() async {
        do {
            let user = try await authService.fetchCurrentUser()
            self.user = user
        } catch {
            Logger.ui.error("Failed to load user: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func logout() async {
        isLoggingOut = true
        errorMessage = nil

        do {
            try await authService.logout()
            Logger.auth.info("Logged out successfully")
        } catch {
            Logger.auth.error("Logout failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoggingOut = false
    }

    func clearError() {
        errorMessage = nil
    }
}
