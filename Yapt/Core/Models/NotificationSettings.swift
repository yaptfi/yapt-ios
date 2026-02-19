//
//  NotificationSettings.swift
//  Yapt
//
//  Notification settings model
//

import Foundation

// MARK: - Notification Settings

struct NotificationSettings: Codable, Equatable {
    // Depeg Alert Settings
    let depegEnabled: Bool
    let depegSeverity: NotificationSeverity
    let depegLowerThreshold: Double
    let depegUpperThreshold: Double
    let depegSymbols: [String]?

    // APY Alert Settings
    let apyEnabled: Bool
    let apySeverity: NotificationSeverity
    let apyThreshold: Double
    let apyWindow: APYWindow

    init(
        depegEnabled: Bool,
        depegSeverity: NotificationSeverity,
        depegLowerThreshold: Double,
        depegUpperThreshold: Double,
        depegSymbols: [String]?,
        apyEnabled: Bool,
        apySeverity: NotificationSeverity,
        apyThreshold: Double,
        apyWindow: APYWindow = .sevenDay
    ) {
        self.depegEnabled = depegEnabled
        self.depegSeverity = depegSeverity
        self.depegLowerThreshold = depegLowerThreshold
        self.depegUpperThreshold = depegUpperThreshold
        self.depegSymbols = depegSymbols
        self.apyEnabled = apyEnabled
        self.apySeverity = apySeverity
        self.apyThreshold = apyThreshold
        self.apyWindow = apyWindow
    }

    private enum CodingKeys: String, CodingKey {
        case depegEnabled
        case depegSeverity
        case depegLowerThreshold
        case depegUpperThreshold
        case depegSymbols
        case apyEnabled
        case apySeverity
        case apyThreshold
        case apyWindow
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        depegEnabled = try container.decode(Bool.self, forKey: .depegEnabled)
        depegSeverity = try container.decode(NotificationSeverity.self, forKey: .depegSeverity)
        depegLowerThreshold = try container.decode(Double.self, forKey: .depegLowerThreshold)
        depegUpperThreshold = try container.decode(Double.self, forKey: .depegUpperThreshold)
        depegSymbols = try container.decodeIfPresent([String].self, forKey: .depegSymbols)
        apyEnabled = try container.decode(Bool.self, forKey: .apyEnabled)
        apySeverity = try container.decode(NotificationSeverity.self, forKey: .apySeverity)
        apyThreshold = try container.decode(Double.self, forKey: .apyThreshold)
        apyWindow = try container.decodeIfPresent(APYWindow.self, forKey: .apyWindow) ?? .sevenDay
    }
}

// MARK: - APY Window

enum APYWindow: String, Codable, CaseIterable, Identifiable {
    case sevenDay = "7d"
    case fourHour = "4h"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sevenDay: return "7-day"
        case .fourHour: return "4-hour"
        }
    }
}

// MARK: - Notification Severity

enum NotificationSeverity: String, Codable, CaseIterable, Identifiable {
    case min
    case low
    case `default`
    case high
    case urgent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .min: return "Minimal"
        case .low: return "Low"
        case .default: return "Default"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }

    var icon: String {
        switch self {
        case .min: return "bell.slash"
        case .low: return "bell"
        case .default: return "bell.fill"
        case .high: return "bell.badge"
        case .urgent: return "bell.badge.fill"
        }
    }
}

// MARK: - API Responses

struct NotificationSettingsResponse: Codable {
    let settings: NotificationSettings
}
