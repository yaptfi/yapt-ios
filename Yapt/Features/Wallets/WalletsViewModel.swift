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
    private var cancellables = Set<AnyCancellable>()

    init(walletService: WalletService) {
        self.walletService = walletService
    }

    func loadWallets() {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        walletService.fetchWallets()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
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
            .store(in: &cancellables)
    }

    func refresh() {
        guard !isRefreshing else { return }

        isRefreshing = true
        errorMessage = nil

        walletService.fetchWallets(forceRefresh: true)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isRefreshing = false
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
            .store(in: &cancellables)
    }

    func clearError() {
        errorMessage = nil
    }
}
