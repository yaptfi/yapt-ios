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
    private var cachedResponse: PositionsResponse?
    private var lastFetchTime: Date?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Fetch all positions with caching
    func fetchPositions(forceRefresh: Bool = false) -> AnyPublisher<PositionsResponse, APIError> {
        // Check cache
        if !forceRefresh,
           let cached = cachedResponse,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < Constants.Cache.positionsTTL {
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
                    self?.cachedResponse = response
                    self?.lastFetchTime = Date()
                    Logger.cache.debug("Cached positions: \(response.positions.count) positions")
                }
            )
            .eraseToAnyPublisher()
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
        cachedResponse = nil
        lastFetchTime = nil
    }
}
