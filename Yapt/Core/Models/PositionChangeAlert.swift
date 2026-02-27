//
//  PositionChangeAlert.swift
//  Yapt
//
//  Model for client-side position change detection
//

import Foundation

enum PositionChangeType {
    case appeared       // New position detected (added to wallet)
    case increased      // Existing position grew significantly
    case partialExit    // Existing position shrank significantly
    case fullExit       // Position disappeared
}

struct PositionChangeAlert: Identifiable {
    let id: UUID
    let positionId: UUID?       // nil if fully exited
    let positionName: String
    let walletId: UUID
    let changeType: PositionChangeType
    let previousValueUsd: Double
    let newValueUsd: Double
    let changePercent: Double   // e.g. -0.85 for -85%
    let detectedAt: Date
}
