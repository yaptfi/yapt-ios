//
//  WalletService.swift
//  Yapt
//
//  Wallet data service
//

import Foundation
import Combine
import OSLog

class WalletService {
    private let apiClient: APIClient
    private var cachedWallets: [Wallet]?
    private var lastFetchTime: Date?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Fetch all wallets with caching
    func fetchWallets(forceRefresh: Bool = false) -> AnyPublisher<[Wallet], APIError> {
        // Check cache
        if !forceRefresh,
           let cached = cachedWallets,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < Constants.Cache.walletsTTL {
            Logger.cache.debug("Returning cached wallets")
            return Just(cached)
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }

        // Fetch from API
        let endpoint = APIEndpoint(path: "/api/wallets", method: .get)

        return apiClient.request(endpoint)
            .map { (response: WalletsResponse) in response.wallets }
            .handleEvents(
                receiveOutput: { [weak self] wallets in
                    self?.cachedWallets = wallets
                    self?.lastFetchTime = Date()
                    Logger.cache.debug("Cached wallets: \(wallets.count) wallets")
                }
            )
            .eraseToAnyPublisher()
    }

    func clearCache() {
        cachedWallets = nil
        lastFetchTime = nil
    }
}
