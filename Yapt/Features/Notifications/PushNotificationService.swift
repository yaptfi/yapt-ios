//
//  PushNotificationService.swift
//  Yapt
//
//  Service for managing APNs push notifications
//

import Foundation
import Combine
import UserNotifications
import UIKit
import OSLog

class PushNotificationService: NSObject, ObservableObject {
    private let notificationService: NotificationService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published State

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var isRegistering: Bool = false
    @Published private(set) var registeredDeviceId: String?
    @Published var error: String?

    // MARK: - Private State

    private let deviceIdKey = "yapt.push.deviceId"

    // MARK: - Initialization

    init(notificationService: NotificationService, registerAsNotificationDelegate: Bool = true) {
        self.notificationService = notificationService
        super.init()

        // Load saved device ID
        registeredDeviceId = UserDefaults.standard.string(forKey: deviceIdKey)

        // Check current authorization status
        refreshAuthorizationStatus()

        if registerAsNotificationDelegate {
            // App runtime only: tests don't need global notification delegate wiring.
            UNUserNotificationCenter.current().delegate = self
        }
    }

    // MARK: - Public Methods

    /// Check and update authorization status
    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    /// Request notification permissions
    func requestAuthorization() -> AnyPublisher<Bool, Never> {
        Future { promise in
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            ) { [weak self] granted, error in
                DispatchQueue.main.async {
                    if let error = error {
                        Logger.network.error("Push authorization error: \(error.localizedDescription)")
                        self?.error = error.localizedDescription
                    }

                    self?.refreshAuthorizationStatus()
                    promise(.success(granted))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// Register for remote notifications (triggers APNs token request)
    func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
            self.isRegistering = true
            Logger.network.info("Requested remote notification registration")
        }
    }

    /// Handle successful device token registration
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        Logger.network.info("Received device token, registering with backend")

        notificationService.registerDevice(token: deviceToken)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isRegistering = false
                    if case .failure(let error) = completion {
                        Logger.network.error("Failed to register device: \(error.localizedDescription)")
                        self?.error = "Failed to enable push notifications"
                    }
                },
                receiveValue: { [weak self] response in
                    self?.registeredDeviceId = response.deviceId
                    UserDefaults.standard.set(response.deviceId, forKey: self?.deviceIdKey ?? "")
                    Logger.network.info("Device registered successfully")
                }
            )
            .store(in: &cancellables)
    }

    /// Handle failed device token registration
    func didFailToRegisterForRemoteNotifications(error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isRegistering = false
            self?.error = "Failed to register: \(error.localizedDescription)"
            Logger.network.error("Failed to register for remote notifications: \(error.localizedDescription)")
        }
    }

    /// Unregister device from push notifications
    func unregisterDevice() -> AnyPublisher<Void, Never> {
        guard let deviceId = registeredDeviceId else {
            return Just(()).eraseToAnyPublisher()
        }

        return notificationService.unregisterDevice(deviceId: deviceId)
            .receive(on: DispatchQueue.main)
            .handleEvents(
                receiveOutput: { [weak self] in
                    self?.registeredDeviceId = nil
                    UserDefaults.standard.removeObject(forKey: self?.deviceIdKey ?? "")
                },
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        Logger.network.error("Failed to unregister device: \(error.localizedDescription)")
                    }
                    // Clear local state regardless of API result
                    self?.registeredDeviceId = nil
                    UserDefaults.standard.removeObject(forKey: self?.deviceIdKey ?? "")
                }
            )
            .replaceError(with: ())
            .eraseToAnyPublisher()
    }

    /// Check if push notifications are enabled and registered
    var isPushEnabled: Bool {
        authorizationStatus == .authorized && registeredDeviceId != nil
    }

    /// Enable push notifications (request permission + register)
    func enablePushNotifications() {
        requestAuthorization()
            .sink { [weak self] granted in
                if granted {
                    self?.registerForRemoteNotifications()
                }
            }
            .store(in: &cancellables)
    }

    /// Disable push notifications (unregister device)
    func disablePushNotifications() {
        unregisterDevice()
            .sink { _ in }
            .store(in: &cancellables)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner and play sound even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        Logger.network.debug("Notification tapped with payload: \(userInfo)")

        // TODO: Handle deep linking based on notification payload
        // Example: Navigate to specific notification, position, or wallet

        completionHandler()
    }
}
