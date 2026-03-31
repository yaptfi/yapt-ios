//
//  PortfolioSummary.swift
//  Yapt
//
//  Portfolio summary model
//

import Foundation

// MARK: - Portfolio Summary

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

// MARK: - Position Display Protocol
/// Shared interface for position-like objects that can be displayed in UI
protocol PositionDisplayable {
    var id: UUID { get }
    var displayName: String { get }
    var valueUsd: Double { get }
    var estDailyUsd: Double { get }
    var estMonthlyUsd: Double { get }
    var estYearlyUsd: Double { get }
    var apy: Double? { get }
    var apy7d: Double? { get }
    var apy30d: Double? { get }
    var absoluteYield: AbsoluteYield? { get }
}

extension PositionDisplayable {
    var hasAPY: Bool {
        apy != nil
    }
}

// MARK: - Portfolio Position
/// Lightweight position data from portfolio summary endpoint
/// Subset of full Position model - doesn't include walletId, baseAsset, lastUpdated
struct PortfolioPosition: Codable, Equatable, Identifiable, PositionDisplayable {
    let id: UUID
    let displayName: String
    let valueUsd: Double
    let estDailyUsd: Double
    let estMonthlyUsd: Double
    let estYearlyUsd: Double
    let apy: Double?
    let apy7d: Double?
    let apy30d: Double?
    let absoluteYield: AbsoluteYield?
}
