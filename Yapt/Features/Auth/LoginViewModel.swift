//
//  LoginViewModel.swift
//  Yapt
//
//  Login screen view model
//

import Foundation
import OSLog
import Combine

@MainActor
class LoginViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    func login() async {
        guard !username.isEmpty else {
            errorMessage = "Please enter a username"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.login(username: username.trimmingCharacters(in: .whitespacesAndNewlines))
            Logger.auth.info("Login successful for: \(user.username)")
            // Session manager will update and trigger navigation
        } catch {
            Logger.auth.error("Login failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func clearError() {
        errorMessage = nil
    }
}
