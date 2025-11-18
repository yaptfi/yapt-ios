//
//  WalletDetailViewModel.swift
//  Yapt
//
//  ViewModel for wallet detail screen with rescan functionality
//

import Foundation
import Combine
import OSLog

@MainActor
class WalletDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var wallet: Wallet
    @Published var positions: [Position] = []
    @Published var isLoading: Bool = false
    @Published var isRescanning: Bool = false
    @Published var progress: DiscoveryProgress?
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let walletService: WalletService
    private let positionService: PositionService
    private var cancellables = Set<AnyCancellable>()

    init(wallet: Wallet, walletService: WalletService, positionService: PositionService) {
        self.wallet = wallet
        self.walletService = walletService
        self.positionService = positionService
    }

    // MARK: - Load Positions

    func loadPositions() {
        isLoading = true
        errorMessage = nil

        positionService.fetchPositions()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    self.isLoading = false

                    if case .failure(let error) = completion {
                        Logger.ui.error("Failed to load positions: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    guard let self = self else { return }
                    // Filter positions for this wallet
                    self.positions = response.positions.filter { $0.walletId == self.wallet.id }
                    Logger.ui.info("Loaded \(self.positions.count) positions for wallet \(self.wallet.address)")
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Rescan Wallet

    func rescan() {
        guard !isRescanning else { return }

        Logger.ui.info("Rescanning wallet: \(self.wallet.address)")

        // Reset state
        errorMessage = nil
        progress = nil
        isRescanning = true

        // Start rescan stream
        walletService.rescanWallet(walletId: wallet.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }

                    switch completion {
                    case .finished:
                        Logger.ui.info("Wallet rescan completed successfully")
                        self.isRescanning = false
                        // Reload positions after rescan
                        self.loadPositions()

                    case .failure(let error):
                        Logger.ui.error("Wallet rescan failed: \(error.localizedDescription)")
                        self.isRescanning = false
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
        case .start:
            if let total = event.data.totalProtocols {
                self.progress = DiscoveryProgress(
                    status: "Starting rescan...",
                    currentProtocol: nil,
                    protocolsCompleted: 0,
                    protocolsTotal: total,
                    positionsFound: 0,
                    ensName: nil
                )
            }

        case .protocolStart:
            if let protocolName = event.data.`protocol`,
               let index = event.data.index,
               let currentProgress = self.progress {
                self.progress = DiscoveryProgress(
                    status: "Scanning \(protocolName)...",
                    currentProtocol: protocolName,
                    protocolsCompleted: index - 1,
                    protocolsTotal: currentProgress.protocolsTotal,
                    positionsFound: currentProgress.positionsFound,
                    ensName: currentProgress.ensName
                )
            }

        case .protocolComplete:
            if let index = event.data.index, let currentProgress = self.progress {
                self.progress = DiscoveryProgress(
                    status: currentProgress.currentProtocol.map { "\($0) complete" } ?? "Protocol complete",
                    currentProtocol: currentProgress.currentProtocol,
                    protocolsCompleted: index,
                    protocolsTotal: currentProgress.protocolsTotal,
                    positionsFound: currentProgress.positionsFound,
                    ensName: currentProgress.ensName
                )
            }

        case .positionFound:
            if let currentProgress = self.progress {
                let newCount = currentProgress.positionsFound + 1
                self.progress = DiscoveryProgress(
                    status: currentProgress.currentProtocol.map { "Scanning \($0)..." } ?? "Scanning...",
                    currentProtocol: currentProgress.currentProtocol,
                    protocolsCompleted: currentProgress.protocolsCompleted,
                    protocolsTotal: currentProgress.protocolsTotal,
                    positionsFound: newCount,
                    ensName: currentProgress.ensName
                )
            }

        case .complete:
            Logger.ui.info("Rescan complete")
            self.progress = nil

        case .error:
            let errorMsg = event.data.message ?? "Unknown rescan error"
            self.errorMessage = errorMsg
            self.isRescanning = false
            Logger.ui.error("Rescan error: \(errorMsg)")

        case .ensResolved:
            // ENS already resolved, ignore
            break
        }
    }
}
