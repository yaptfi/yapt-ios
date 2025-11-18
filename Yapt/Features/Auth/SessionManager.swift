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

    func login(user: User) {
        Logger.auth.info("User logged in: \(user.username)")
        self.currentUser = user
        self.isAuthenticated = true
    }

    func logout() {
        Logger.auth.info("User logged out")
        self.currentUser = nil
        self.isAuthenticated = false
    }

    func updateUser(_ user: User) {
        self.currentUser = user
        if !isAuthenticated {
            self.isAuthenticated = true
        }
    }
}
