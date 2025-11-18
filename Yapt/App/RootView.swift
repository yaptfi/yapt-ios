//
//  RootView.swift
//  Yapt
//
//  Root view with authentication gate
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        Group {
            if sessionManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: sessionManager.isAuthenticated)
    }
}
