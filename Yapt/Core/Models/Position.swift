//
//  Position.swift
//  Yapt
//
//  Position model with measurement semantics
//

import Foundation

// MARK: - Enums
enum PositionType: String, Codable {
    case rewards
    case savings
    case fixedIncome = "fixed-income"

    var title: String {
        switch self {
        case .rewards:
            return "Rewards"
        case .savings:
            return "Savings"
        case .fixedIncome:
            return "Fixed Income"
        }
    }

    var isRewardsBased: Bool {
        self == .rewards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if let value = PositionType(rawValue: rawValue) {
            self = value
        } else {
            self = .savings
        }
    }
}

// MARK: - Position Model
/// Full position model from /api/positions endpoint
/// Includes additional fields: walletId, baseAsset, lastUpdated
struct Position: Codable, Identifiable, Equatable, PositionDisplayable {
    let id: UUID
    let walletId: UUID
    let displayName: String
    let baseAsset: String
    let countingMode: String
    let positionType: PositionType
    let valueUsd: Double
    let lastUpdated: Date?

    // APY fields - only present for non-reward based positions
    let apy: Double?
    let apy7d: Double?
    let apy30d: Double?

    // Income estimates (always present)
    let estDailyUsd: Double
    let estMonthlyUsd: Double
    let estYearlyUsd: Double

    // Absolute yield - only present for reward-based positions
    let absoluteYield: AbsoluteYield?
}

// MARK: - Nested Types
struct AbsoluteYield: Codable, Equatable {
    let totalYield7d: Double?
    let avgDailyYield: Double
    let projectedMonthlyYield: Double
    let projectedYearlyYield: Double
}

struct PositionSnapshot: Codable, Identifiable {
    let id: Int
    let positionId: UUID
    let ts: Date
    let valueUsd: Double
    let netFlowsUsd: Double
    let yieldDeltaUsd: Double
    let apy: Double?
}

// MARK: - API Responses
struct PositionsResponse: Codable {
    let positions: [Position]
    let summary: PositionSummary
}

struct PositionSummary: Codable {
    let actual24hYield: Double
    let actual7dYield: Double
    let actual30dYield: Double
}

struct PositionSnapshotsResponse: Codable {
    let position: PositionInfo
    let snapshots: [PositionSnapshot]
}

struct PositionInfo: Codable {
    let id: UUID
    let displayName: String
}
