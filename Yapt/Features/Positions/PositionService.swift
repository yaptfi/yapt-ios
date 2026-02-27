//
//  PositionService.swift
//  Yapt
//
//  Position data service
//

import Foundation
import Combine
import OSLog

class PositionService {
    private let apiClient: APIClient
    private let positionsCache = TimedMemoryCache<PositionsResponse>()
    private var previousPositions: [Position]?
    private let changeSettings: PositionChangeSettings

    /// Emits arrays of detected position changes after each fresh network fetch.
    let positionChanges = PassthroughSubject<[PositionChangeAlert], Never>()

    init(apiClient: APIClient, changeSettings: PositionChangeSettings = PositionChangeSettings()) {
        self.apiClient = apiClient
        self.changeSettings = changeSettings
    }

    /// Fetch all positions with caching
    func fetchPositions(forceRefresh: Bool = false) -> AnyPublisher<PositionsResponse, APIError> {
        // Check cache
        if !forceRefresh,
           let cached = positionsCache.valueIfValid(ttl: Constants.Cache.positionsTTL) {
            Logger.cache.debug("Returning cached positions")
            return Just(cached)
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }

        // Fetch from API
        let endpoint = APIEndpoint(path: "/api/positions", method: .get)

        return apiClient.request(endpoint)
            .handleEvents(
                receiveOutput: { [weak self] (response: PositionsResponse) in
                    self?.positionsCache.store(response)
                    Logger.cache.debug("Cached positions: \(response.positions.count) positions")
                    self?.detectChanges(newPositions: response.positions)
                }
            )
            .eraseToAnyPublisher()
    }

    // MARK: - Change Detection

    private func detectChanges(newPositions: [Position]) {
        guard let previous = previousPositions else {
            // First-ever load — just record baseline, no alerts
            previousPositions = newPositions
            return
        }

        let threshold = changeSettings.threshold
        let now = Date()
        var alerts: [PositionChangeAlert] = []

        let previousById = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        let newById = Dictionary(uniqueKeysWithValues: newPositions.map { ($0.id, $0) })

        // Fully exited: was in previous, not in new
        for old in previous where newById[old.id] == nil {
            alerts.append(PositionChangeAlert(
                id: UUID(),
                positionId: nil,
                positionName: old.displayName,
                walletId: old.walletId,
                changeType: .fullExit,
                previousValueUsd: old.valueUsd,
                newValueUsd: 0,
                changePercent: -1.0,
                detectedAt: now
            ))
        }

        // Appeared: in new, not in previous
        for new in newPositions where previousById[new.id] == nil {
            alerts.append(PositionChangeAlert(
                id: UUID(),
                positionId: new.id,
                positionName: new.displayName,
                walletId: new.walletId,
                changeType: .appeared,
                previousValueUsd: 0,
                newValueUsd: new.valueUsd,
                changePercent: 1.0,
                detectedAt: now
            ))
        }

        // Changed: exists in both
        for new in newPositions {
            guard let old = previousById[new.id], old.valueUsd > 0 else { continue }
            let change = (new.valueUsd - old.valueUsd) / old.valueUsd
            guard abs(change) >= threshold else { continue }

            alerts.append(PositionChangeAlert(
                id: UUID(),
                positionId: new.id,
                positionName: new.displayName,
                walletId: new.walletId,
                changeType: change > 0 ? .increased : .partialExit,
                previousValueUsd: old.valueUsd,
                newValueUsd: new.valueUsd,
                changePercent: change,
                detectedAt: now
            ))
        }

        previousPositions = newPositions

        if !alerts.isEmpty {
            Logger.cache.debug("Detected \(alerts.count) position change(s)")
            positionChanges.send(alerts)
        }
    }

    /// Fetch snapshots for a position
    func fetchSnapshots(positionId: UUID, from: Date? = nil, to: Date? = nil) -> AnyPublisher<PositionSnapshotsResponse, APIError> {
        var queryItems: [URLQueryItem] = []

        if let from = from {
            queryItems.append(URLQueryItem(name: "from", value: Formatters.iso8601.string(from: from)))
        }
        if let to = to {
            queryItems.append(URLQueryItem(name: "to", value: Formatters.iso8601.string(from: to)))
        }

        let endpoint = APIEndpoint(
            path: "/api/positions/\(positionId.uuidString)/snapshots",
            method: .get,
            queryItems: queryItems.isEmpty ? nil : queryItems
        )

        return apiClient.request(endpoint)
    }

    func clearCache() {
        positionsCache.clear()
        previousPositions = nil
    }
}
