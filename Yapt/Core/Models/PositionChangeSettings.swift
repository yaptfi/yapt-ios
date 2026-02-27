//
//  PositionChangeSettings.swift
//  Yapt
//
//  UserDefaults-backed settings for position change alerts
//

import Foundation
import Combine

class PositionChangeSettings: ObservableObject {
    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: "posChange.enabled") }
    }

    /// Fractional threshold, e.g. 0.20 = 20%
    @Published var threshold: Double {
        didSet { UserDefaults.standard.set(threshold, forKey: "posChange.threshold") }
    }

    init() {
        enabled = UserDefaults.standard.object(forKey: "posChange.enabled") as? Bool ?? true
        threshold = UserDefaults.standard.object(forKey: "posChange.threshold") as? Double ?? 0.20
    }
}
