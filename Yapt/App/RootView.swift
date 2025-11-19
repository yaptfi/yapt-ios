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
    @StateObject private var errorHandler: ErrorHandler

    init() {
        // ErrorHandler will be properly initialized in onAppear
        _errorHandler = StateObject(wrappedValue: ErrorHandler(sessionManager: SessionManager()))
    }

    var body: some View {
        ZStack {
            // Main content
            Group {
                if sessionManager.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView(authService: appEnvironment.authService)
                }
            }
            .animation(.easeInOut, value: sessionManager.isAuthenticated)

            // Global error banner (appears at top)
            VStack {
                if appEnvironment.errorHandler.showBanner,
                   let message = appEnvironment.errorHandler.bannerMessage {
                    ErrorBannerView(
                        message: message,
                        onDismiss: {
                            appEnvironment.errorHandler.dismissBanner()
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
                }

                Spacer()
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appEnvironment.errorHandler.showBanner)
        }
    }
}
