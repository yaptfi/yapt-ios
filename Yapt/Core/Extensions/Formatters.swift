//
//  Formatters.swift
//  Yapt
//
//  Number and date formatters
//

import Foundation

enum Formatters {
    // MARK: - Currency
    /// Standard currency formatter: $X (no decimals, $ prefix, no locale suffix)
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "$"
        formatter.internationalCurrencySymbol = "$"
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 0  // Integer rounding
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static let currencyCompact: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "$"
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    // MARK: - Percentage
    static let percentage: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.multiplier = 100 // Since backend sends 0.1176 for 11.76%
        return formatter
    }()

    // MARK: - Date
    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    // MARK: - ISO8601
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

// MARK: - Helper Extensions
extension Double {
    func asCurrency() -> String {
        Formatters.currency.string(from: NSNumber(value: self)) ?? "$\(self)"
    }

    func asCurrencyWithSign() -> String {
        let absoluteValue = abs(self)
        let formatted = Formatters.currency.string(from: NSNumber(value: absoluteValue)) ?? "$\(absoluteValue)"
        return self >= 0 ? "+\(formatted)" : "-\(formatted)"
    }

    func asCurrencyCompact() -> String {
        if self >= 1_000_000 {
            return "$\(String(format: "%.1fM", self / 1_000_000))"
        } else if self >= 1_000 {
            return "$\(String(format: "%.1fK", self / 1_000))"
        } else {
            return Formatters.currencyCompact.string(from: NSNumber(value: self)) ?? "$\(self)"
        }
    }

    func asPercentage() -> String {
        Formatters.percentage.string(from: NSNumber(value: self)) ?? "\(self * 100)%"
    }
}

extension Date {
    func asRelativeString() -> String {
        Formatters.relative.localizedString(for: self, relativeTo: Date())
    }

    func asDateTimeString() -> String {
        Formatters.dateTime.string(from: self)
    }
}
