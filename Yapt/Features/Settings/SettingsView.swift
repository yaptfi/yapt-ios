//
//  SettingsView.swift
//  Yapt
//
//  Settings screen
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel: SettingsViewModel

    init(authService: AuthService) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(
            authService: authService
        ))
    }

    var body: some View {
        NavigationView {
            List {
                // User Profile Section
                Section {
                    if let user = sessionManager.currentUser {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.blue)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.effectiveDisplayName)
                                        .font(.headline)

                                    Text("@\(user.username)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    if user.isAdmin {
                                        Text("Admin")
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.2))
                                            .foregroundColor(.orange)
                                            .cornerRadius(4)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    } else {
                        HStack {
                            ProgressView()
                            Text("Loading user info...")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Profile")
                }

                // App Information Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(buildNumber)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("App Information")
                }

                // Notifications Section (Phase 3)
                Section {
                    NavigationLink(destination: NotificationSettingsView(notificationService: appEnvironment.notificationService, pushService: appEnvironment.pushNotificationService)) {
                        Label("Notification Settings", systemImage: "bell.badge")
                    }

                    NavigationLink(destination: NotificationFeedView(notificationService: appEnvironment.notificationService)) {
                        Label("Notification History", systemImage: "bell.fill")
                    }
                } header: {
                    Text("Notifications")
                }

                // Logout Section
                Section {
                    Button(action: {
                        Task {
                            await viewModel.logout()
                        }
                    }) {
                        HStack {
                            if viewModel.isLoggingOut {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "arrow.right.square")
                                Text("Log Out")
                            }
                        }
                        .foregroundColor(.red)
                    }
                    .disabled(viewModel.isLoggingOut)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadUser()
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    let env = AppEnvironment()
    return SettingsView(authService: env.authService)
        .environmentObject(env)
        .environmentObject(env.sessionManager)
}
