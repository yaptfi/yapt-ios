//
//  DiscoveryModels.swift
//  Yapt
//
//  Models for wallet discovery progress via SSE streaming
//

import Foundation

// MARK: - Discovery Event
/// Server-Sent Event from the discovery stream
struct DiscoveryEvent: Codable, Equatable {
    let type: DiscoveryEventType
    let data: DiscoveryEventData
}

enum DiscoveryEventType: String, Codable {
    case progress = "progress"
    case complete = "complete"
    case error = "error"
}

struct DiscoveryEventData: Codable, Equatable {
    // Progress fields
    let status: String?
    let currentChain: String?
    let chainsCompleted: Int?
    let chainsTotal: Int?
    let positionsFound: Int?

    // Completion fields
    let walletsCreated: Int?
    let positionsCreated: Int?
    let totalValueUsd: Double?

    // Error fields
    let message: String?
    let code: String?

    // ENS resolution
    let ensName: String?
    let ensResolved: Bool?
}

// MARK: - Discovery Progress
/// UI-friendly representation of discovery progress
struct DiscoveryProgress: Equatable {
    let status: String
    let currentChain: String?
    let chainsCompleted: Int
    let chainsTotal: Int
    let positionsFound: Int
    let ensName: String?

    var progressPercentage: Double {
        guard chainsTotal > 0 else { return 0 }
        return Double(chainsCompleted) / Double(chainsTotal)
    }

    var isComplete: Bool {
        chainsCompleted >= chainsTotal && chainsTotal > 0
    }

    /// Create from SSE event data
    static func from(eventData: DiscoveryEventData) -> DiscoveryProgress {
        return DiscoveryProgress(
            status: eventData.status ?? "Processing...",
            currentChain: eventData.currentChain,
            chainsCompleted: eventData.chainsCompleted ?? 0,
            chainsTotal: eventData.chainsTotal ?? 0,
            positionsFound: eventData.positionsFound ?? 0,
            ensName: eventData.ensName
        )
    }
}

// MARK: - Discovery Result
/// Final result after discovery completes
struct DiscoveryResult: Equatable {
    let walletsCreated: Int
    let positionsCreated: Int
    let totalValueUsd: Double

    /// Create from SSE completion event
    static func from(eventData: DiscoveryEventData) -> DiscoveryResult? {
        guard let walletsCreated = eventData.walletsCreated,
              let positionsCreated = eventData.positionsCreated,
              let totalValueUsd = eventData.totalValueUsd else {
            return nil
        }

        return DiscoveryResult(
            walletsCreated: walletsCreated,
            positionsCreated: positionsCreated,
            totalValueUsd: totalValueUsd
        )
    }
}

// MARK: - Add Wallet Request
/// Request body for POST /wallets
struct AddWalletRequest: Codable {
    let address: String
    let label: String?

    enum CodingKeys: String, CodingKey {
        case address
        case label
    }
}
