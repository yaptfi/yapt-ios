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
    private let settingsCache = TimedMemoryCache<NotificationSettings>()

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Settings

    /// Fetch notification settings
    func fetchSettings(forceRefresh: Bool = false) -> AnyPublisher<NotificationSettings, APIError> {
        // Check cache
        if !forceRefresh, let cached = settingsCache.valueIfValid(ttl: 300) {
            Logger.network.debug("Returning cached notification settings")
            return Just(cached)
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }

        let endpoint = APIEndpoint(path: "/api/notifications/settings", method: .get)

        return apiClient.request(endpoint)
            .map { (response: NotificationSettingsResponse) -> NotificationSettings in
                let settings = response.settings
                // Cache with 5 minute TTL
                self.settingsCache.store(settings)
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
                    self.settingsCache.store(updatedSettings)
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

    // MARK: - Device Registration (APNs)

    /// Register device for push notifications
    func registerDevice(token: Data) -> AnyPublisher<DeviceRegistrationResponse, APIError> {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        let environment = DeviceRegistration.detectEnvironment()

        do {
            let registration = DeviceRegistration(
                token: tokenString,
                environment: environment
            )
            let endpoint = try APIEndpoint(
                path: "/api/notifications/devices",
                method: .post,
                bodyObject: registration
            )

            Logger.network.info("Registering device with environment: \(environment)")

            return apiClient.request(endpoint)
                .handleEvents(receiveOutput: { response in
                    Logger.network.info("Registered device for push notifications: \(response.deviceId)")
                })
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: .networkError(error)).eraseToAnyPublisher()
        }
    }

    /// Unregister device from push notifications
    func unregisterDevice(deviceId: String) -> AnyPublisher<Void, APIError> {
        let endpoint = APIEndpoint(
            path: "/api/notifications/devices/\(deviceId)",
            method: .delete
        )

        return apiClient.request(endpoint)
            .handleEvents(receiveOutput: {
                Logger.network.info("Unregistered device from push notifications")
            })
            .eraseToAnyPublisher()
    }

    func clearCache() {
        settingsCache.clear()
    }
}
