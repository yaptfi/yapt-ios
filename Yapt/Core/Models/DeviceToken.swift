//
//  DeviceToken.swift
//  Yapt
//
//  Device token model for APNs push notifications
//

import Foundation
import UIKit

// MARK: - Device Registration Request

struct DeviceRegistration: Codable {
    let token: String
    let platform: String
    let environment: String

    init(token: String, platform: String = "ios", environment: String) {
        self.token = token
        self.platform = platform
        self.environment = environment
    }
}

// MARK: - Device Registration Response

struct DeviceRegistrationResponse: Codable {
    let deviceId: String

    // Handle backend returning deviceId as Int or String
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let intId = try? container.decode(Int.self, forKey: .deviceId) {
            self.deviceId = String(intId)
        } else {
            self.deviceId = try container.decode(String.self, forKey: .deviceId)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case deviceId
    }
}

// MARK: - APNs Environment Detection

extension DeviceRegistration {
    /// Detect the current APNs environment (sandbox or production)
    static func detectEnvironment() -> String {
        #if DEBUG
        // Debug builds always use sandbox
        return "sandbox"
        #else
        // Release builds: check if this is a TestFlight build
        // TestFlight builds use sandbox environment despite being release builds
        if let receiptURL = Bundle.main.appStoreReceiptURL,
           receiptURL.lastPathComponent == "sandboxReceipt" {
            return "sandbox"
        }
        // Production build from App Store
        return "production"
        #endif
    }
}
