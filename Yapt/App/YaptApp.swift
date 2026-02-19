//
//  YaptApp.swift
//  Yapt
//
//  Main app entry point
//

import SwiftUI
import UserNotifications

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    /// Reference to push notification service (set by YaptApp)
    weak var pushNotificationService: PushNotificationService?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        pushNotificationService?.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        pushNotificationService?.didFailToRegisterForRemoteNotifications(error: error)
    }
}

// MARK: - Main App

@main
struct YaptApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appEnvironment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appEnvironment.sessionManager)
                .environmentObject(appEnvironment)
                .onAppear {
                    let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
                    guard !isRunningTests else { return }

                    // Restore session on app startup
                    appEnvironment.sessionManager.restoreSession()

                    // Wire up push notification service to app delegate
                    appDelegate.pushNotificationService = appEnvironment.pushNotificationService
                }
        }
    }
}
