//
//  AuthService.swift
//  Yapt
//
//  Authentication service
//

import Foundation
import Combine
import OSLog

@MainActor
class AuthService: ObservableObject {
    private let apiClient: APIClient
    private let sessionManager: SessionManager
    private let webAuthnCoordinator = WebAuthnCoordinator()

    init(apiClient: APIClient, sessionManager: SessionManager) {
        self.apiClient = apiClient
        self.sessionManager = sessionManager
    }

    // MARK: - Login Flow

    /// Complete login flow: generate options -> passkey auth -> verify
    func login(username: String) async throws -> User {
        Logger.auth.info("Starting login for user: \(username)")

        // Step 1: Generate WebAuthn options
        let options = try await generateLoginOptions(username: username)

        // Step 2: Perform passkey authentication
        let authResponse = try await webAuthnCoordinator.authenticate(options: options)

        // Step 3: Verify with backend
        let user = try await verifyLogin(authResponse: authResponse)

        // Step 4: Update session
        sessionManager.login(user: user)

        return user
    }

    /// Fetch current user (check if session is valid)
    func fetchCurrentUser() async throws -> User {
        let endpoint = APIEndpoint(path: "/api/auth/me", method: .get)

        let response: AuthMeResponse = try await apiClient.request(endpoint)
            .async()

        sessionManager.updateUser(response.user)
        return response.user
    }

    /// Logout
    func logout() async throws {
        let endpoint = APIEndpoint(path: "/api/auth/logout", method: .post)

        let _: LogoutResponse = try await apiClient.request(endpoint)
            .async()

        // Clear cookies and session
        apiClient.clearCookies()
        sessionManager.logout()
    }

    // MARK: - Private Methods

    private func generateLoginOptions(username: String) async throws -> PublicKeyCredentialRequestOptions {
        let request = LoginGenerateOptionsRequest(username: username)
        let endpoint = try APIEndpoint(
            path: "/api/auth/login/generate-options",
            method: .post,
            bodyObject: request
        )

        Logger.auth.debug("Generating login options for: \(username)")

        return try await apiClient.request(endpoint)
            .async()
    }

    private func verifyLogin(authResponse: AuthenticationResponseJSON) async throws -> User {
        let endpoint = try APIEndpoint(
            path: "/api/auth/login/verify",
            method: .post,
            bodyObject: authResponse
        )

        Logger.auth.debug("Verifying login")

        let response: AuthVerifyResponse = try await apiClient.request(endpoint)
            .async()

        guard response.verified else {
            throw AuthError.verificationFailed
        }

        return response.user
    }
}

// MARK: - Combine Publisher Extension
extension Publisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?

            cancellable = self.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                },
                receiveValue: { value in
                    continuation.resume(returning: value)
                }
            )
        }
    }
}

// MARK: - Errors
enum AuthError: LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Login verification failed"
        }
    }
}
