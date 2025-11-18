//
//  AddWalletViewModel.swift
//  Yapt
//
//  ViewModel for adding a new wallet with discovery progress
//

import Foundation
import Combine
import OSLog

@MainActor
class AddWalletViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var address: String = ""
    @Published var label: String = ""

    // Progress tracking
    @Published var isDiscovering: Bool = false
    @Published var progress: DiscoveryProgress?
    @Published var discoveryResult: DiscoveryResult?
    @Published var errorMessage: String?

    // Validation
    @Published var addressError: String?

    // MARK: - Dependencies
    private let walletService: WalletService
    private var cancellables = Set<AnyCancellable>()

    init(walletService: WalletService) {
        self.walletService = walletService
    }

    // MARK: - Validation

    var canSubmit: Bool {
        !address.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isDiscovering &&
        addressError == nil
    }

    /// Validate Ethereum address or ENS name format
    func validateAddress() {
        let trimmed = address.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else {
            addressError = nil
            return
        }

        // Check if it's an ENS name (ends with .eth)
        if trimmed.hasSuffix(".eth") {
            // Basic ENS validation: at least 3 chars before .eth
            let name = String(trimmed.dropLast(4))
            if name.count >= 3 {
                addressError = nil
            } else {
                addressError = "ENS name too short"
            }
            return
        }

        // Check if it's an Ethereum address (0x + 40 hex chars)
        if trimmed.hasPrefix("0x") {
            let addressPart = String(trimmed.dropFirst(2))
            if addressPart.count == 40 && addressPart.allSatisfy({ $0.isHexDigit }) {
                addressError = nil
            } else {
                addressError = "Invalid Ethereum address format"
            }
        } else {
            addressError = "Address must start with 0x or be an ENS name"
        }
    }

    // MARK: - Add Wallet

    func addWallet() {
        guard canSubmit else { return }

        let trimmedAddress = address.trimmingCharacters(in: .whitespaces)
        let trimmedLabel = label.trimmingCharacters(in: .whitespaces)
        let finalLabel = trimmedLabel.isEmpty ? nil : trimmedLabel

        Logger.ui.info("Adding wallet: \(trimmedAddress)")

        // Reset state
        errorMessage = nil
        progress = nil
        discoveryResult = nil
        isDiscovering = true

        // Start discovery stream
        walletService.addWallet(address: trimmedAddress, label: finalLabel)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }

                    switch completion {
                    case .finished:
                        Logger.ui.info("Wallet discovery completed successfully")
                        self.isDiscovering = false

                    case .failure(let error):
                        Logger.ui.error("Wallet discovery failed: \(error.localizedDescription)")
                        self.isDiscovering = false
                        self.errorMessage = error.localizedDescription
                        self.progress = nil
                    }
                },
                receiveValue: { [weak self] event in
                    guard let self = self else { return }
                    self.handleDiscoveryEvent(event)
                }
            )
            .store(in: &cancellables)
    }

    private func handleDiscoveryEvent(_ event: DiscoveryEvent) {
        switch event.type {
        case .progress:
            // Update progress
            let newProgress = DiscoveryProgress.from(eventData: event.data)
            self.progress = newProgress

            Logger.ui.debug("Discovery progress: \(newProgress.chainsCompleted)/\(newProgress.chainsTotal) chains, \(newProgress.positionsFound) positions")

        case .complete:
            // Extract final result
            if let result = DiscoveryResult.from(eventData: event.data) {
                self.discoveryResult = result
                Logger.ui.info("Discovery complete: \(result.walletsCreated) wallets, \(result.positionsCreated) positions, $\(result.totalValueUsd)")
            }

        case .error:
            // Handle error event
            let errorMsg = event.data.message ?? "Unknown discovery error"
            self.errorMessage = errorMsg
            self.isDiscovering = false
            Logger.ui.error("Discovery error: \(errorMsg)")
        }
    }

    // MARK: - Reset

    func reset() {
        address = ""
        label = ""
        addressError = nil
        errorMessage = nil
        progress = nil
        discoveryResult = nil
        isDiscovering = false
        cancellables.removeAll()
    }
}
