//
//  YaptApp.swift
//  Yapt
//
//  Main app entry point
//

import SwiftUI

@main
struct YaptApp: App {
    @StateObject private var appEnvironment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appEnvironment.sessionManager)
                .environmentObject(appEnvironment)
                .onAppear {
                    // Restore session on app startup
                    appEnvironment.sessionManager.restoreSession()
                }
        }
    }
}
