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
    @ObservedObject private var pushService: PushNotificationService
    @FocusState private var focusedField: FocusedField?

    private enum FocusedField {
        case depegLower, depegUpper, depegSymbols, apyThreshold
    }

    init(notificationService: NotificationService, pushService: PushNotificationService) {
        _viewModel = StateObject(wrappedValue: NotificationSettingsViewModel(
            notificationService: notificationService
        ))
        self.pushService = pushService
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
                pushService.refreshAuthorizationStatus()
            }
        }
    }

    @ViewBuilder
    private var settingsForm: some View {
        Form {
            // Push Notifications Section
            pushNotificationsSection

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
                            .focused($focusedField, equals: .depegLower)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField = .depegLower
                    }

                    HStack {
                        Text("Upper Threshold")
                        Spacer()
                        TextField("1.05", text: $viewModel.depegUpperThreshold)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .depegUpper)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField = .depegUpper
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Symbols (optional)")
                            .font(.subheadline)
                        TextField("USDC, USDT, DAI", text: $viewModel.depegSymbols)
                            .textInputAutocapitalization(.characters)
                            .focused($focusedField, equals: .depegSymbols)
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
                Toggle("Enable Low APY Alerts", isOn: $viewModel.apyEnabled)

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
                        Text("Minimum APY")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("5", text: $viewModel.apyThresholdPercent)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .apyThreshold)
                            Text("%")
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField = .apyThreshold
                    }
                    Text("Alert when APY drops below this value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                HStack {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                    Text("Low APY Alerts")
                }
            } footer: {
                Text("Get notified when position APY drops below your threshold")
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
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
    }

    // MARK: - Push Notifications Section

    @ViewBuilder
    private var pushNotificationsSection: some View {
        Section {
            Toggle(
                "Push Notifications",
                isOn: Binding(
                    get: { pushService.isPushEnabled },
                    set: { enabled in
                        if enabled {
                            pushService.enablePushNotifications()
                        } else {
                            pushService.disablePushNotifications()
                        }
                    }
                )
            )
            .disabled(pushService.isRegistering)

            // Show status based on authorization
            switch pushService.authorizationStatus {
            case .denied:
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Notifications are disabled in Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption)
                }

            case .authorized where pushService.registeredDeviceId != nil:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Push notifications enabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

            case .notDetermined:
                Text("Tap the toggle to enable push notifications")
                    .font(.caption)
                    .foregroundColor(.secondary)

            default:
                EmptyView()
            }

            if pushService.isRegistering {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Registering device...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let error = pushService.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        } header: {
            HStack {
                Image(systemName: "bell.badge.fill")
                Text("Push Notifications")
            }
        } footer: {
            Text("Receive alerts even when the app is closed")
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
    return NotificationSettingsView(
        notificationService: env.notificationService,
        pushService: env.pushNotificationService
    )
    .environmentObject(env)
}
