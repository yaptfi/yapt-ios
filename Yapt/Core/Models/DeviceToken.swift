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
        return checkReceiptEnvironment()
        #endif
    }

    private static func checkReceiptEnvironment() -> String {
        // Note: appStoreReceiptURL is deprecated in iOS 18+, but remains the most
        // reliable way to detect TestFlight vs App Store builds. The StoreKit 2
        // alternative requires async/await and is more complex for this use case.
        // The property still functions correctly and is the recommended approach
        // for environment detection in push notification registration.
        if let receiptURL = Bundle.main.appStoreReceiptURL,
           receiptURL.lastPathComponent == "sandboxReceipt" {
            return "sandbox"
        }
        return "production"
    }
}
