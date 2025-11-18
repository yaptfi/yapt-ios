//
//  PortfolioSummary.swift
//  Yapt
//
//  Portfolio summary model
//

import Foundation

struct PortfolioSummary: Codable, Equatable {
    let asOf: Date
    let totalValueUsd: Double
    let estDailyUsd: Double
    let estMonthlyUsd: Double
    let estYearlyUsd: Double
    let positions: [PortfolioPosition]

    var lastUpdated: String {
        asOf.asRelativeString()
    }
}

// MARK: - Portfolio Position (lighter than full Position model)
/// Position data in portfolio summary - subset of full Position model
struct PortfolioPosition: Codable, Equatable, Identifiable {
    let id: UUID
    let displayName: String
    let measureMethod: MeasureMethod
    let valueUsd: Double
    let countingMode: CountingMode
    let estDailyUsd: Double
    let estMonthlyUsd: Double
    let estYearlyUsd: Double

    // APY fields - optional for reward-based positions
    let apy: Double?
    let apy7d: Double?
    let apy30d: Double?

    // Absolute yield - only for reward-based positions
    let absoluteYield: AbsoluteYield?

    var isRewardBased: Bool {
        measureMethod.isRewardBased
    }

    var hasAPY: Bool {
        apy != nil && !isRewardBased
    }
}
