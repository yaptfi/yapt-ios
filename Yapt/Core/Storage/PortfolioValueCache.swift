//
//  PortfolioValueCache.swift
//  Yapt
//
//  Lightweight persistence for the dashboard hero metric so we can
//  show the last known total immediately when the app relaunches.
//

import Foundation

struct CachedPortfolioValue {
    let totalValue: Double
    let timestamp: Date?
}

protocol PortfolioValueCaching {
    func loadLastValue() -> CachedPortfolioValue?
    func store(totalValue: Double, timestamp: Date)
}

final class PortfolioValueCache: PortfolioValueCaching {
    private enum Keys {
        static let totalValue = "dashboard.lastTotalValue"
        static let timestamp = "dashboard.lastTotalTimestamp"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadLastValue() -> CachedPortfolioValue? {
        guard userDefaults.object(forKey: Keys.totalValue) != nil else {
            return nil
        }

        let total = userDefaults.double(forKey: Keys.totalValue)
        let timestamp = userDefaults.object(forKey: Keys.timestamp) as? Date
        return CachedPortfolioValue(totalValue: total, timestamp: timestamp)
    }

    func store(totalValue: Double, timestamp: Date) {
        userDefaults.set(totalValue, forKey: Keys.totalValue)
        userDefaults.set(timestamp, forKey: Keys.timestamp)
    }
}
