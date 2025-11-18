//
//  User.swift
//  Yapt
//
//  User model
//

import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: UUID
    let username: String
    let displayName: String?
    let isAdmin: Bool

    var effectiveDisplayName: String {
        displayName ?? username
    }
}

// MARK: - API Responses
struct AuthMeResponse: Codable {
    let user: User
}

struct AuthVerifyResponse: Codable {
    let verified: Bool
    let user: User
}

struct LogoutResponse: Codable {
    let message: String
}
