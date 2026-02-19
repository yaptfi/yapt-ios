//
//  WalletsViewModel.swift
//  Yapt
//
//  Wallets list view model
//

import Foundation
import Combine
import OSLog

@MainActor
class WalletsViewModel: ObservableObject {
    @Published var wallets: [Wallet] = []
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var errorMessage: String?

    private let walletService: WalletService
    private var loadCancellable: AnyCancellable?
    private var deleteCancellables: [UUID: AnyCancellable] = [:]

    init(walletService: WalletService) {
        self.walletService = walletService
    }

    func loadWallets() {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        loadCancellable?.cancel()
        loadCancellable = walletService.fetchWallets()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    self?.loadCancellable = nil
                    if case .failure(let error) = completion {
                        Logger.ui.error("Failed to load wallets: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] wallets in
                    self?.wallets = wallets
                    Logger.ui.debug("Loaded \(wallets.count) wallets")
                }
            )
    }

    func refresh() {
        guard !isRefreshing else { return }

        isRefreshing = true
        errorMessage = nil

        loadCancellable?.cancel()
        loadCancellable = walletService.fetchWallets(forceRefresh: true)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isRefreshing = false
                    self?.loadCancellable = nil
                    if case .failure(let error) = completion {
                        Logger.ui.error("Failed to refresh wallets: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] wallets in
                    self?.wallets = wallets
                    Logger.ui.debug("Refreshed wallets")
                }
            )
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Delete Wallet

    func deleteWallet(_ wallet: Wallet) {
        Logger.ui.info("Deleting wallet: \(wallet.address)")

        // Optimistically remove from UI
        wallets.removeAll { $0.id == wallet.id }

        let requestID = UUID()
        let cancellable = walletService.deleteWallet(walletId: wallet.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.deleteCancellables[requestID] = nil
                    if case .failure(let error) = completion {
                        Logger.ui.error("Failed to delete wallet: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                        // Reload wallets on error to restore state
                        self?.refresh()
                    } else {
                        Logger.ui.info("Wallet deleted successfully")
                    }
                },
                receiveValue: { _ in
                    // Success - wallet already removed optimistically
                }
            )
        deleteCancellables[requestID] = cancellable
    }
}
