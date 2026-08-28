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
    private final class RescanCompletionState {
        var didReceiveComplete = false
    }

    private let apiClient: APIClient
    private let sseClient: SSEClient
    private let walletsCache = TimedMemoryCache<[Wallet]>()

    init(apiClient: APIClient, sseClient: SSEClient) {
        self.apiClient = apiClient
        self.sseClient = sseClient
    }

    /// Fetch all wallets with caching
    func fetchWallets(forceRefresh: Bool = false) -> AnyPublisher<[Wallet], APIError> {
        // Check cache
        if !forceRefresh,
           let cached = walletsCache.valueIfValid(ttl: Constants.Cache.walletsTTL) {
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
                    self?.walletsCache.store(wallets)
                    Logger.cache.debug("Cached wallets: \(wallets.count) wallets")
                }
            )
            .eraseToAnyPublisher()
    }

    func clearCache() {
        walletsCache.clear()
    }

    // MARK: - Add Wallet with Discovery

    /// Add a new wallet and stream discovery progress via SSE
    /// - Parameters:
    ///   - address: Ethereum address or ENS name
    ///   - label: Optional label for the wallet
    /// - Returns: Publisher that emits DiscoveryEvent objects as they arrive
    func addWallet(address: String, label: String?) -> AnyPublisher<DiscoveryEvent, APIError> {
        let request = AddWalletRequest(address: address, label: label)

        // Encode request body
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let bodyData = try? encoder.encode(request) else {
            return Fail(error: APIError.decodingError(NSError(domain: "WalletService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request"])))
                .eraseToAnyPublisher()
        }

        // Use /discover endpoint for SSE streaming
        let endpoint = APIEndpoint(path: "/api/wallets/discover", method: .post, body: bodyData)

        // Build URLRequest for SSE streaming
        guard var urlRequest = try? apiClient.buildRequest(for: endpoint) else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        // Convert SSE string events to DiscoveryEvent objects
        return sseClient.stream(request: urlRequest)
            .tryCompactMap { [weak self] jsonString -> DiscoveryEvent? in
                guard let self else { throw APIError.unknown }
                let event = try self.decodeDiscoveryEvent(jsonString)
                return event.type == .unknown ? nil : event
            }
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                }
                return APIError.decodingError(error)
            }
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    // Clear cache when wallet is added
                    if case .finished = completion {
                        self?.clearCache()
                    }
                    // Stop SSE stream
                    self?.sseClient.stopStreaming()
                },
                receiveCancel: { [weak self] in
                    self?.sseClient.stopStreaming()
                }
            )
            .eraseToAnyPublisher()
    }

    // MARK: - Rescan Wallet

    /// Rescan an existing wallet for new positions
    /// - Parameter walletId: ID of wallet to rescan
    /// - Returns: Publisher that emits DiscoveryEvent objects as they arrive
    func rescanWallet(walletId: UUID) -> AnyPublisher<DiscoveryEvent, APIError> {
        // Use /scan endpoint for SSE streaming
        let endpoint = APIEndpoint(path: "/api/wallets/\(walletId)/scan", method: .post)

        // Build URLRequest for SSE streaming
        guard var urlRequest = try? apiClient.buildRequest(for: endpoint) else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        urlRequest.setValue(nil, forHTTPHeaderField: "Content-Type")

        let completionState = RescanCompletionState()

        // Convert SSE string events to DiscoveryEvent objects
        return sseClient.stream(request: urlRequest)
            .tryCompactMap { [weak self] jsonString -> DiscoveryEvent? in
                guard let self else { throw APIError.unknown }
                guard !completionState.didReceiveComplete else { return nil }
                let event = try self.decodeDiscoveryEvent(jsonString)

                switch event.type {
                case .unknown:
                    return nil
                case .error:
                    throw APIError.eventStreamError(event.data.message ?? "The wallet rescan failed")
                default:
                    return event
                }
            }
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                }
                return APIError.decodingError(error)
            }
            .handleEvents(receiveOutput: { [weak self] event in
                guard event.type == .complete else { return }
                completionState.didReceiveComplete = true
                self?.sseClient.stopStreaming()
            })
            .append(Deferred {
                if completionState.didReceiveComplete {
                    return Empty<DiscoveryEvent, APIError>().eraseToAnyPublisher()
                }

                return Fail(
                    error: APIError.eventStreamError("The wallet rescan ended before completion")
                )
                .eraseToAnyPublisher()
            })
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    // Clear cache when rescan completes
                    if case .finished = completion {
                        self?.clearCache()
                    }
                    // Stop SSE stream
                    self?.sseClient.stopStreaming()
                },
                receiveCancel: { [weak self] in
                    self?.sseClient.stopStreaming()
                }
            )
            .eraseToAnyPublisher()
    }

    private func decodeDiscoveryEvent(_ jsonString: String) throws -> DiscoveryEvent {
        guard let data = jsonString.data(using: .utf8) else {
            throw APIError.decodingError(
                NSError(
                    domain: "SSE",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to convert SSE data to UTF-8"]
                )
            )
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(DiscoveryEvent.self, from: data)
        } catch {
            Logger.network.error("Failed to decode discovery event: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Delete Wallet

    /// Delete a wallet and all associated positions
    /// - Parameter walletId: ID of wallet to delete
    /// - Returns: Publisher that completes when deletion succeeds
    func deleteWallet(walletId: UUID) -> AnyPublisher<Void, APIError> {
        let endpoint = APIEndpoint(path: "/api/wallets/\(walletId)", method: .delete)

        return apiClient.request(endpoint)
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    // Clear cache when wallet is deleted
                    if case .finished = completion {
                        self?.clearCache()
                    }
                }
            )
            .eraseToAnyPublisher()
    }
}
