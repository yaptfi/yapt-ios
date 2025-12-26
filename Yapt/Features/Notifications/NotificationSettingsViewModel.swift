//
//  NotificationSettingsViewModel.swift
//  Yapt
//
//  ViewModel for notification settings
//

import Foundation
import Combine
import OSLog

@MainActor
class NotificationSettingsViewModel: ObservableObject {
    // MARK: - Published State

    @Published var settings: NotificationSettings?
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Editable fields (bound to UI)
    @Published var depegEnabled: Bool = false
    @Published var depegSeverity: NotificationSeverity = .default
    @Published var depegLowerThreshold: String = "0.95"
    @Published var depegUpperThreshold: String = "1.05"
    @Published var depegSymbols: String = ""  // Comma-separated

    @Published var apyEnabled: Bool = false
    @Published var apySeverity: NotificationSeverity = .default
    @Published var apyThresholdPercent: String = "5"  // Display as percentage (e.g., "5" for 5%)

    // MARK: - Dependencies

    private let notificationService: NotificationService
    private var cancellables = Set<AnyCancellable>()

    init(notificationService: NotificationService) {
        self.notificationService = notificationService
    }

    // MARK: - Actions

    func loadSettings() {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        notificationService.fetchSettings()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        Logger.ui.error("Failed to load notification settings: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] settings in
                    self?.settings = settings
                    self?.populateFields(from: settings)
                    Logger.ui.debug("Loaded notification settings")
                }
            )
            .store(in: &cancellables)
    }

    func saveSettings() {
        guard !isSaving else { return }
        guard let updatedSettings = buildSettings() else {
            errorMessage = "Invalid input values"
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        notificationService.updateSettings(updatedSettings)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSaving = false
                    if case .failure(let error) = completion {
                        Logger.ui.error("Failed to save notification settings: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] settings in
                    self?.settings = settings
                    self?.successMessage = "Settings saved successfully"
                    Logger.ui.info("Saved notification settings")

                    // Clear success message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.successMessage = nil
                    }
                }
            )
            .store(in: &cancellables)
    }

    func clearError() {
        errorMessage = nil
    }

    func clearSuccess() {
        successMessage = nil
    }

    // MARK: - Private Helpers

    private func populateFields(from settings: NotificationSettings) {
        depegEnabled = settings.depegEnabled
        depegSeverity = settings.depegSeverity
        depegLowerThreshold = String(format: "%.2f", settings.depegLowerThreshold)
        depegUpperThreshold = String(format: "%.2f", settings.depegUpperThreshold)
        depegSymbols = settings.depegSymbols?.joined(separator: ", ") ?? ""

        apyEnabled = settings.apyEnabled
        apySeverity = settings.apySeverity
        // Convert from decimal (0.05) to percentage display (5)
        let percentValue = settings.apyThreshold * 100
        if percentValue.truncatingRemainder(dividingBy: 1) == 0 {
            apyThresholdPercent = String(format: "%.0f", percentValue)
        } else {
            apyThresholdPercent = String(format: "%.1f", percentValue)
        }
    }

    /// Parse a localized decimal string (handles both comma and period as decimal separator)
    private func parseLocalizedDouble(_ string: String) -> Double? {
        // Try parsing with period first
        if let value = Double(string) {
            return value
        }
        // Try replacing comma with period (for localized keyboards)
        let normalized = string.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func buildSettings() -> NotificationSettings? {
        // Parse and validate thresholds (using localized decimal parsing)
        guard let depegLower = parseLocalizedDouble(depegLowerThreshold),
              let depegUpper = parseLocalizedDouble(depegUpperThreshold),
              let apyPercent = parseLocalizedDouble(apyThresholdPercent) else {
            return nil
        }

        // Convert percentage to decimal (e.g., 5 -> 0.05)
        let apyThresh = apyPercent / 100

        // Validate ranges
        guard depegLower > 0, depegLower < 1,
              depegUpper > 1, depegUpper < 2,
              apyThresh > 0, apyThresh < 1 else {
            return nil
        }

        // Parse symbols (split by comma, trim whitespace, filter empty)
        let symbolsArray = depegSymbols
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }

        return NotificationSettings(
            depegEnabled: depegEnabled,
            depegSeverity: depegSeverity,
            depegLowerThreshold: depegLower,
            depegUpperThreshold: depegUpper,
            depegSymbols: symbolsArray.isEmpty ? nil : symbolsArray,
            apyEnabled: apyEnabled,
            apySeverity: apySeverity,
            apyThreshold: apyThresh
        )
    }
}
