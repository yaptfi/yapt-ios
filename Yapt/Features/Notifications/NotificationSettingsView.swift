//
//  NotificationSettingsView.swift
//  Yapt
//
//  Notification settings screen
//

import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject private var viewModel: NotificationSettingsViewModel

    init(notificationService: NotificationService) {
        _viewModel = StateObject(wrappedValue: NotificationSettingsViewModel(
            notificationService: notificationService
        ))
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading && viewModel.settings == nil {
                    ProgressView("Loading settings...")
                } else if let errorMessage = viewModel.errorMessage, viewModel.settings == nil {
                    errorView(errorMessage)
                } else {
                    settingsForm
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.loadSettings()
            }
        }
    }

    @ViewBuilder
    private var settingsForm: some View {
        Form {
            // Depeg Alerts Section
            Section {
                Toggle("Enable Depeg Alerts", isOn: $viewModel.depegEnabled)

                if viewModel.depegEnabled {
                    Picker("Severity", selection: $viewModel.depegSeverity) {
                        ForEach(NotificationSeverity.allCases) { severity in
                            HStack {
                                Image(systemName: severity.icon)
                                Text(severity.displayName)
                            }
                            .tag(severity)
                        }
                    }

                    HStack {
                        Text("Lower Threshold")
                        Spacer()
                        TextField("0.95", text: $viewModel.depegLowerThreshold)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    HStack {
                        Text("Upper Threshold")
                        Spacer()
                        TextField("1.05", text: $viewModel.depegUpperThreshold)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Symbols (optional)")
                            .font(.subheadline)
                        TextField("USDC, USDT, DAI", text: $viewModel.depegSymbols)
                            .textInputAutocapitalization(.characters)
                        Text("Comma-separated. Leave empty for all stablecoins.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Depeg Alerts")
                }
            } footer: {
                Text("Get notified when stablecoins deviate from $1.00")
            }

            // APY Alerts Section
            Section {
                Toggle("Enable APY Alerts", isOn: $viewModel.apyEnabled)

                if viewModel.apyEnabled {
                    Picker("Severity", selection: $viewModel.apySeverity) {
                        ForEach(NotificationSeverity.allCases) { severity in
                            HStack {
                                Image(systemName: severity.icon)
                                Text(severity.displayName)
                            }
                            .tag(severity)
                        }
                    }

                    HStack {
                        Text("Change Threshold")
                        Spacer()
                        TextField("0.05", text: $viewModel.apyThreshold)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    Text("Minimum APY change to trigger alert (e.g., 0.05 = 5%)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("APY Change Alerts")
                }
            } footer: {
                Text("Get notified when position APY changes significantly")
            }

            // ntfy Topic Section
            if let ntfyTopic = viewModel.settings?.ntfyTopic {
                Section {
                    HStack {
                        Text("Your Topic")
                        Spacer()
                        Text(ntfyTopic)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("ntfy Configuration")
                } footer: {
                    Text("This is your unique notification topic. You can subscribe to it directly using the ntfy app.")
                }
            }

            // Save Button
            Section {
                Button(action: {
                    viewModel.saveSettings()
                }) {
                    HStack {
                        Spacer()
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Save Settings")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(viewModel.isSaving)
            }

            // Error/Success Messages
            if let errorMessage = viewModel.errorMessage {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }

            if let successMessage = viewModel.successMessage {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(successMessage)
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            Text("Failed to load settings")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                viewModel.loadSettings()
            }
        }
    }
}

#Preview {
    let env = AppEnvironment()
    return NotificationSettingsView(notificationService: env.notificationService)
        .environmentObject(env)
}
