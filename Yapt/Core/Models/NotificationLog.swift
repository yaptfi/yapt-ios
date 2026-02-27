//
//  NotificationLog.swift
//  Yapt
//
//  Notification history log model
//

import Foundation


// MARK: - Notification Log

struct NotificationLog: Codable, Identifiable, Equatable {
    let id: String
    let type: NotificationType
    let severity: NotificationSeverity
    let title: String
    let message: String
    let metadata: NotificationMetadata?
    let createdAt: Date

    var formattedTimestamp: String {
        createdAt.asRelativeString()
    }

    // Handle backend returning id as Int or String
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode id flexibly (Int or String)
        if let intId = try? container.decode(Int.self, forKey: .id) {
            self.id = String(intId)
        } else {
            self.id = try container.decode(String.self, forKey: .id)
        }

        self.type = try container.decode(NotificationType.self, forKey: .type)
        self.severity = try container.decode(NotificationSeverity.self, forKey: .severity)
        self.title = try container.decode(String.self, forKey: .title)
        self.message = try container.decode(String.self, forKey: .message)
        self.metadata = try container.decodeIfPresent(NotificationMetadata.self, forKey: .metadata)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, severity, title, message, metadata, createdAt
    }
}

// MARK: - Notification Type

enum NotificationType: String, Codable, CaseIterable {
    case depeg
    case apy

    var displayName: String {
        switch self {
        case .depeg: return "Depeg Alert"
        case .apy: return "APY Change"
        }
    }

    var icon: String {
        switch self {
        case .depeg: return "exclamationmark.triangle.fill"
        case .apy: return "chart.line.uptrend.xyaxis"
        }
    }

    var color: String {
        switch self {
        case .depeg: return "orange"
        case .apy: return "blue"
        }
    }
}

// MARK: - Notification Metadata

struct NotificationMetadata: Codable, Equatable {
    // Common fields
    let positionId: UUID?
    let walletId: UUID?

    // Depeg-specific
    let symbol: String?
    let price: Double?
    let deviation: Double?

    // APY-specific
    let oldApy: Double?
    let newApy: Double?
    let change: Double?
}

// MARK: - API Responses

struct NotificationHistoryResponse: Codable {
    let notifications: [NotificationLog]
    let total: Int
    let hasMore: Bool
}
