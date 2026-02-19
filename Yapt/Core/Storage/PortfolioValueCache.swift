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
    func setActiveUserID(_ userID: UUID?)
    func loadLastValue() -> CachedPortfolioValue?
    func store(totalValue: Double, timestamp: Date)
    func clearCurrentUserValue()
    func clearAllValues()
}

final class PortfolioValueCache: PortfolioValueCaching {
    private enum Keys {
        static let scopedPrefix = "dashboard.lastTotalValue.byUser"
        static let legacyTotalValue = "dashboard.lastTotalValue"
        static let legacyTimestamp = "dashboard.lastTotalTimestamp"
    }

    private let userDefaults: UserDefaults
    private var activeUserID: UUID?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func setActiveUserID(_ userID: UUID?) {
        activeUserID = userID
    }

    func loadLastValue() -> CachedPortfolioValue? {
        guard let totalKey = scopedTotalValueKey,
              let timestampKey = scopedTimestampKey,
              userDefaults.object(forKey: totalKey) != nil else {
            return nil
        }

        let total = userDefaults.double(forKey: totalKey)
        let timestamp = userDefaults.object(forKey: timestampKey) as? Date
        return CachedPortfolioValue(totalValue: total, timestamp: timestamp)
    }

    func store(totalValue: Double, timestamp: Date) {
        guard let totalKey = scopedTotalValueKey,
              let timestampKey = scopedTimestampKey else {
            return
        }

        userDefaults.set(totalValue, forKey: totalKey)
        userDefaults.set(timestamp, forKey: timestampKey)
    }

    func clearCurrentUserValue() {
        guard let totalKey = scopedTotalValueKey,
              let timestampKey = scopedTimestampKey else {
            return
        }

        userDefaults.removeObject(forKey: totalKey)
        userDefaults.removeObject(forKey: timestampKey)
    }

    func clearAllValues() {
        let keysToRemove = userDefaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix(Keys.scopedPrefix) ||
            $0 == Keys.legacyTotalValue ||
            $0 == Keys.legacyTimestamp
        }

        for key in keysToRemove {
            userDefaults.removeObject(forKey: key)
        }
    }

    private var scopedTotalValueKey: String? {
        guard let activeUserID else { return nil }
        return "\(Keys.scopedPrefix).\(activeUserID.uuidString.lowercased()).total"
    }

    private var scopedTimestampKey: String? {
        guard let activeUserID else { return nil }
        return "\(Keys.scopedPrefix).\(activeUserID.uuidString.lowercased()).timestamp"
    }
}
