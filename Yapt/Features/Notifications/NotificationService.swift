//
//  NotificationService.swift
//  Yapt
//
//  Service for notification settings and history
//

import Foundation
import Combine
import OSLog

class NotificationService {
    private let apiClient: APIClient
    private var settingsCache: CachedValue<NotificationSettings>?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Settings

    /// Fetch notification settings
    func fetchSettings(forceRefresh: Bool = false) -> AnyPublisher<NotificationSettings, APIError> {
        // Check cache
        if !forceRefresh, let cached = settingsCache, cached.isValid {
            Logger.network.debug("Returning cached notification settings")
            return Just(cached.data)
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }

        let endpoint = APIEndpoint(path: "/api/notifications/settings", method: .get)

        return apiClient.request(endpoint)
            .map { (response: NotificationSettingsResponse) -> NotificationSettings in
                let settings = response.settings
                // Cache with 5 minute TTL
                self.settingsCache = CachedValue(data: settings, ttl: 300)
                Logger.network.debug("Fetched notification settings from API")
                return settings
            }
            .eraseToAnyPublisher()
    }

    /// Update notification settings
    func updateSettings(_ settings: NotificationSettings) -> AnyPublisher<NotificationSettings, APIError> {
        do {
            let endpoint = try APIEndpoint(
                path: "/api/notifications/settings",
                method: .put,
                bodyObject: settings
            )

            return apiClient.request(endpoint)
                .map { (response: NotificationSettingsResponse) -> NotificationSettings in
                    let updatedSettings = response.settings
                    // Update cache
                    self.settingsCache = CachedValue(data: updatedSettings, ttl: 300)
                    Logger.network.info("Updated notification settings")
                    return updatedSettings
                }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: .networkError(error)).eraseToAnyPublisher()
        }
    }

    // MARK: - History

    /// Fetch notification history with pagination
    func fetchHistory(
        limit: Int = 50,
        offset: Int = 0,
        type: NotificationType? = nil
    ) -> AnyPublisher<NotificationHistoryResponse, APIError> {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        if let type = type {
            queryItems.append(URLQueryItem(name: "type", value: type.rawValue))
        }

        let endpoint = APIEndpoint(
            path: "/api/notifications/history",
            method: .get,
            queryItems: queryItems
        )

        return apiClient.request(endpoint)
            .handleEvents(receiveOutput: { (response: NotificationHistoryResponse) in
                Logger.network.debug("Fetched \(response.notifications.count) notifications (offset: \(offset))")
            })
            .eraseToAnyPublisher()
    }
}

// MARK: - Cached Value

private struct CachedValue<T> {
    let data: T
    let timestamp: Date
    let ttl: TimeInterval

    init(data: T, ttl: TimeInterval) {
        self.data = data
        self.timestamp = Date()
        self.ttl = ttl
    }

    var isValid: Bool {
        Date().timeIntervalSince(timestamp) < ttl
    }
}
