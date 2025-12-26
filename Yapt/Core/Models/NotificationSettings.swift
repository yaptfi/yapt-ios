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
