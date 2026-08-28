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
    @Published var rescanTotalPositions: Int?
    @Published var failedProtocols: [String] = []
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let walletService: WalletService
    private let positionService: PositionService
    private var positionsCancellable: AnyCancellable?
    private var rescanCancellable: AnyCancellable?

    init(wallet: Wallet, walletService: WalletService, positionService: PositionService) {
        self.wallet = wallet
        self.walletService = walletService
        self.positionService = positionService
    }

    // MARK: - Load Positions

    func loadPositions() {
        isLoading = true
        errorMessage = nil

        positionsCancellable?.cancel()
        positionsCancellable = positionService.fetchPositions()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    self.isLoading = false
                    self.positionsCancellable = nil

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
    }

    // MARK: - Rescan Wallet

    func rescan() {
        guard !isRescanning else { return }

        Logger.ui.info("Rescanning wallet: \(self.wallet.address)")

        // Reset state
        errorMessage = nil
        progress = nil
        rescanTotalPositions = nil
        failedProtocols = []
        isRescanning = true

        // Start rescan stream
        rescanCancellable?.cancel()
        rescanCancellable = walletService.rescanWallet(walletId: wallet.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    self.rescanCancellable = nil

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
    }

    private func handleDiscoveryEvent(_ event: DiscoveryEvent) {
        switch event.type {
        case .status:
            guard let message = event.data.message else { return }
            let currentProgress = progress ?? emptyProgress(status: message)
            progress = DiscoveryProgress(
                status: message,
                currentProtocol: currentProgress.currentProtocol,
                protocolsCompleted: currentProgress.protocolsCompleted,
                protocolsTotal: currentProgress.protocolsTotal,
                positionsFound: currentProgress.positionsFound,
                ensName: currentProgress.ensName
            )

        case .start:
            if let total = event.data.totalProtocols {
                let currentProgress = progress
                self.progress = DiscoveryProgress(
                    status: currentProgress?.status ?? "Starting rescan...",
                    currentProtocol: currentProgress?.currentProtocol,
                    protocolsCompleted: currentProgress?.protocolsCompleted ?? 0,
                    protocolsTotal: total,
                    positionsFound: currentProgress?.positionsFound ?? 0,
                    ensName: currentProgress?.ensName
                )
            }

        case .protocolStart:
            if let protocolName = event.data.`protocol` {
                let currentProgress = progress ?? emptyProgress(status: "Scanning \(protocolName)...")
                let completedBeforeProtocol = event.data.index.map { max(0, $0 - 1) }
                self.progress = DiscoveryProgress(
                    status: "Scanning \(protocolName)...",
                    currentProtocol: protocolName,
                    protocolsCompleted: max(
                        currentProgress.protocolsCompleted,
                        completedBeforeProtocol ?? currentProgress.protocolsCompleted
                    ),
                    protocolsTotal: event.data.total ?? currentProgress.protocolsTotal,
                    positionsFound: currentProgress.positionsFound,
                    ensName: currentProgress.ensName
                )
            }

        case .protocolComplete:
            if let protocolName = event.data.`protocol` ?? progress?.currentProtocol {
                let currentProgress = progress ?? emptyProgress(status: "\(protocolName) complete")
                let incrementedCount = currentProgress.protocolsCompleted + 1
                let completedCount = max(currentProgress.protocolsCompleted, event.data.index ?? incrementedCount)
                let boundedCompletedCount = currentProgress.protocolsTotal > 0
                    ? min(completedCount, currentProgress.protocolsTotal)
                    : completedCount
                self.progress = DiscoveryProgress(
                    status: "\(protocolName) complete",
                    currentProtocol: protocolName,
                    protocolsCompleted: boundedCompletedCount,
                    protocolsTotal: currentProgress.protocolsTotal,
                    positionsFound: currentProgress.positionsFound,
                    ensName: currentProgress.ensName
                )
            }

        case .positionFound:
            let currentProgress = progress ?? emptyProgress(status: "Scanning...")
            let newCount = currentProgress.positionsFound + 1
            self.progress = DiscoveryProgress(
                status: currentProgress.currentProtocol.map { "Scanning \($0)..." } ?? "Scanning...",
                currentProtocol: currentProgress.currentProtocol,
                protocolsCompleted: currentProgress.protocolsCompleted,
                protocolsTotal: currentProgress.protocolsTotal,
                positionsFound: newCount,
                ensName: currentProgress.ensName
            )

        case .protocolError:
            let protocolName = event.data.`protocol` ?? "Protocol"
            let message = event.data.message ?? "Scan failed"
            let currentProgress = progress ?? emptyProgress(status: message)
            self.progress = DiscoveryProgress(
                status: "\(protocolName): \(message)",
                currentProtocol: protocolName,
                protocolsCompleted: currentProgress.protocolsCompleted,
                protocolsTotal: currentProgress.protocolsTotal,
                positionsFound: currentProgress.positionsFound,
                ensName: currentProgress.ensName
            )
            Logger.ui.warning("Protocol scan failed nonfatally: \(protocolName)")

        case .complete:
            rescanTotalPositions = event.data.totalPositions
            failedProtocols = event.data.failedProtocols
            Logger.ui.info("Rescan complete with \(event.data.failedProtocols.count) failed protocols")
            self.progress = nil

        case .error:
            let errorMsg = event.data.message ?? "Unknown rescan error"
            self.errorMessage = errorMsg
            self.isRescanning = false
            Logger.ui.error("Rescan error: \(errorMsg)")

        case .ensResolved, .unknown:
            // ENS already resolved, ignore
            break
        }
    }

    private func emptyProgress(status: String) -> DiscoveryProgress {
        DiscoveryProgress(
            status: status,
            currentProtocol: nil,
            protocolsCompleted: 0,
            protocolsTotal: 0,
            positionsFound: 0,
            ensName: nil
        )
    }
}
