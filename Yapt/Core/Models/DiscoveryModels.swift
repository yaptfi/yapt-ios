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
    case start = "start"
    case ensResolved = "ens_resolved"
    case protocolStart = "protocol_start"
    case protocolComplete = "protocol_complete"
    case positionsFound = "positions_found"
    case complete = "complete"
    case error = "error"
}

struct DiscoveryEventData: Codable, Equatable {
    // Start event
    let totalProtocols: Int?

    // ENS resolution
    let ensName: String?
    let address: String?

    // Protocol progress
    let `protocol`: String?
    let index: Int?
    let total: Int?

    // Positions found
    let count: Int?
    let positions: [DiscoveredPosition]?

    // Completion
    let walletsCreated: Int?
    let positionsCreated: Int?
    let totalValueUsd: Double?

    // Error
    let message: String?
    let code: String?
}

// Lightweight position info in SSE discovery events
struct DiscoveredPosition: Codable, Equatable {
    let `protocol`: String
    let displayName: String
    let valueUsd: Double
}

// MARK: - Discovery Progress
/// UI-friendly representation of discovery progress
struct DiscoveryProgress: Equatable {
    let status: String
    let currentProtocol: String?
    let protocolsCompleted: Int
    let protocolsTotal: Int
    let positionsFound: Int
    let ensName: String?

    var progressPercentage: Double {
        guard protocolsTotal > 0 else { return 0 }
        return Double(protocolsCompleted) / Double(protocolsTotal)
    }

    var isComplete: Bool {
        protocolsCompleted >= protocolsTotal && protocolsTotal > 0
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
