//
//  SessionManager.swift
//  Yapt
//
//  Manages authentication state and session
//

import Foundation
import Combine
import OSLog

@MainActor
class SessionManager: ObservableObject {
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var currentUser: User?
    @Published private(set) var isRestoringSession: Bool = false

    private let userDefaultsKey = "yapt.currentUser"

    func login(user: User) {
        Logger.auth.info("User logged in: \(user.username)")
        self.currentUser = user
        self.isAuthenticated = true
        persistUser(user)
    }

    func logout() {
        Logger.auth.info("User logged out")
        self.currentUser = nil
        self.isAuthenticated = false
        clearPersistedUser()
    }

    func updateUser(_ user: User) {
        self.currentUser = user
        if !isAuthenticated {
            self.isAuthenticated = true
        }
        persistUser(user)
    }

    /// Attempt to restore session from persisted user data
    /// Should be called on app startup
    func restoreSession() {
        isRestoringSession = true

        // Load persisted user if available
        if let user = loadPersistedUser() {
            Logger.auth.info("Found persisted user: \(user.username)")
            self.currentUser = user
            self.isAuthenticated = true
        }

        isRestoringSession = false
    }

    // MARK: - Persistence

    private func persistUser(_ user: User) {
        do {
            let data = try JSONEncoder().encode(user)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            Logger.auth.debug("User persisted to UserDefaults")
        } catch {
            Logger.auth.error("Failed to persist user: \(error.localizedDescription)")
        }
    }

    private func loadPersistedUser() -> User? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return nil
        }

        do {
            let user = try JSONDecoder().decode(User.self, from: data)
            return user
        } catch {
            Logger.auth.error("Failed to load persisted user: \(error.localizedDescription)")
            return nil
        }
    }

    private func clearPersistedUser() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        Logger.auth.debug("Cleared persisted user")
    }
}
