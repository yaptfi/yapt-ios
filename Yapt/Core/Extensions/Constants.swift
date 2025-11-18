//
//  Constants.swift
//  Yapt
//
//  App-wide constants
//

import Foundation

enum Constants {
    enum API {
        static let baseURL = "https://yapt.fi"
        static let timeout: TimeInterval = 30
        static let cacheTTL: TimeInterval = 60 // seconds
    }

    enum WebAuthn {
        static let rpID = "yapt.fi"
    }

    enum Cache {
        static let portfolioTTL: TimeInterval = 60
        static let positionsTTL: TimeInterval = 60
        static let walletsTTL: TimeInterval = 300
    }
}
