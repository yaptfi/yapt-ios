//
//  PortfolioService.swift
//  Yapt
//
//  Portfolio data service
//

import Foundation
import Combine
import OSLog

class PortfolioService {
    private let apiClient: APIClient
    private let summaryCache = TimedMemoryCache<PortfolioSummary>()

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Fetch portfolio summary with caching
    func fetchSummary(forceRefresh: Bool = false) -> AnyPublisher<PortfolioSummary, APIError> {
        // Check cache
        if !forceRefresh,
           let cached = summaryCache.valueIfValid(ttl: Constants.Cache.portfolioTTL) {
            Logger.cache.debug("Returning cached portfolio summary")
            return Just(cached)
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }

        // Fetch from API
        let endpoint = APIEndpoint(path: "/api/portfolio/summary", method: .get)

        return apiClient.request(endpoint)
            .handleEvents(
                receiveOutput: { [weak self] (summary: PortfolioSummary) in
                    self?.summaryCache.store(summary)
                    Logger.cache.debug("Cached portfolio summary")
                }
            )
            .eraseToAnyPublisher()
    }

    func clearCache() {
        summaryCache.clear()
    }
}
