//
//  Position.swift
//  Yapt
//
//  Position model with measurement semantics
//

import Foundation

// MARK: - Enums
enum CountingMode: String, Codable {
    case count
    case partial
    case ignore
}

enum MeasureMethod: String, Codable {
    case exchangeRate
    case balance
    case rebaseIndex
    case subgraph
    case rewards
    case lpPosition = "lp-position"

    var isRewardBased: Bool {
        self == .rewards
    }
}

// MARK: - Position Model
struct Position: Codable, Identifiable, Equatable {
    let id: UUID
    let walletId: UUID
    let displayName: String
    let baseAsset: String
    let countingMode: CountingMode
    let measureMethod: MeasureMethod
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

    var isRewardBased: Bool {
        measureMethod.isRewardBased
    }

    var hasAPY: Bool {
        apy != nil && !isRewardBased
    }
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
