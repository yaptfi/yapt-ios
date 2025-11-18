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

    init() {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(
            authService: AuthService(apiClient: APIClient(), sessionManager: SessionManager())
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

                // Notifications Section (Phase 3 - placeholder)
                Section {
                    NavigationLink(destination: EmptyView()) {
                        Label("Notifications", systemImage: "bell")
                    }
                    .disabled(true)
                    .foregroundColor(.secondary)
                } header: {
                    Text("Preferences")
                } footer: {
                    Text("Notification settings will be available in Phase 3")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                let vm = SettingsViewModel(authService: appEnvironment.authService)
                _viewModel.wrappedValue = vm
                await vm.loadUser()
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
    SettingsView()
        .environmentObject(AppEnvironment())
        .environmentObject(SessionManager())
}
