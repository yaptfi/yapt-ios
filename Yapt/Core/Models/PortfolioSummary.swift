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
    let positions: [Position]

    var lastUpdated: String {
        asOf.asRelativeString()
    }
}
