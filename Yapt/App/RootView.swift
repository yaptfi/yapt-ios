//
//  RootView.swift
//  Yapt
//
//  Root view with authentication gate
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var appEnvironment: AppEnvironment

    var body: some View {
        Group {
            if sessionManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView(authService: appEnvironment.authService)
            }
        }
        .animation(.easeInOut, value: sessionManager.isAuthenticated)
    }
}
