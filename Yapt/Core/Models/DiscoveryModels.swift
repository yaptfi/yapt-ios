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

    enum CodingKeys: String, CodingKey {
        case type
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(DiscoveryEventType.self, forKey: .type)
        data = type == .unknown
            ? .empty
            : try container.decode(DiscoveryEventData.self, forKey: .data)
    }
}

enum DiscoveryEventType: String, Codable {
    case status = "status"
    case start = "start"
    case ensResolved = "ens_resolved"
    case protocolStart = "protocol_start"
    case protocolComplete = "protocol_complete"
    case positionFound = "position_found"  // Singular - one position at a time
    case protocolError = "protocol_error"
    case complete = "complete"
    case error = "error"
    case unknown = "__unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = DiscoveryEventType(rawValue: rawValue) ?? .unknown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct DiscoveryEventData: Codable, Equatable {
    static let empty = DiscoveryEventData()

    // Start event
    let totalProtocols: Int?

    // ENS resolution
    let ensName: String?
    let address: String?

    // Protocol progress
    let `protocol`: String?
    let index: Int?
    let total: Int?

    // Position found (individual position data)
    let displayName: String?
    let baseAsset: String?
    let valueUsd: Double?

    // Protocol completion
    let positionsFound: Int?

    // Completion
    let walletsCreated: Int?
    let positionsCreated: Int?
    let totalValueUsd: Double?
    let totalPositions: Int?
    let failedProtocols: [String]

    // Error
    let message: String?
    let code: String?

    private init() {
        totalProtocols = nil
        ensName = nil
        address = nil
        `protocol` = nil
        index = nil
        total = nil
        displayName = nil
        baseAsset = nil
        valueUsd = nil
        positionsFound = nil
        walletsCreated = nil
        positionsCreated = nil
        totalValueUsd = nil
        totalPositions = nil
        failedProtocols = []
        message = nil
        code = nil
    }

    enum CodingKeys: String, CodingKey {
        case totalProtocols
        case ensName
        case address
        case `protocol`
        case index
        case total
        case displayName
        case baseAsset
        case valueUsd
        case positionsFound
        case walletsCreated
        case positionsCreated
        case totalValueUsd
        case totalPositions
        case failedProtocols
        case message
        case code
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalProtocols = try container.decodeIfPresent(Int.self, forKey: .totalProtocols)
        ensName = try container.decodeIfPresent(String.self, forKey: .ensName)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        `protocol` = try container.decodeIfPresent(String.self, forKey: .protocol)
        index = try container.decodeIfPresent(Int.self, forKey: .index)
        total = try container.decodeIfPresent(Int.self, forKey: .total)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        baseAsset = try container.decodeIfPresent(String.self, forKey: .baseAsset)
        valueUsd = try container.decodeIfPresent(Double.self, forKey: .valueUsd)
        positionsFound = try container.decodeIfPresent(Int.self, forKey: .positionsFound)
        walletsCreated = try container.decodeIfPresent(Int.self, forKey: .walletsCreated)
        positionsCreated = try container.decodeIfPresent(Int.self, forKey: .positionsCreated)
        totalValueUsd = try container.decodeIfPresent(Double.self, forKey: .totalValueUsd)
        totalPositions = try container.decodeIfPresent(Int.self, forKey: .totalPositions)
        failedProtocols = try container.decodeIfPresent([String].self, forKey: .failedProtocols) ?? []
        message = try container.decodeIfPresent(String.self, forKey: .message)
        code = try container.decodeIfPresent(String.self, forKey: .code)
    }
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
