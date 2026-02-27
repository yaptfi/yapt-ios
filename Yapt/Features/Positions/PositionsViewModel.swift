//
//  PositionsViewModel.swift
//  Yapt
//
//  Positions list view model
//

import Foundation
import Combine
import OSLog

@MainActor
class PositionsViewModel: ObservableObject {
    @Published var positions: [Position] = []
    @Published var summary: PositionSummary?
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var errorMessage: String?
    @Published var pendingChanges: [PositionChangeAlert] = []

    private let positionService: PositionService
    private let positionChangeSettings: PositionChangeSettings
    private var loadCancellable: AnyCancellable?
    private var changesCancellable: AnyCancellable?

    init(positionService: PositionService, positionChangeSettings: PositionChangeSettings) {
        self.positionService = positionService
        self.positionChangeSettings = positionChangeSettings

        changesCancellable = positionService.positionChanges
            .receive(on: DispatchQueue.main)
            .sink { [weak self] changes in
                guard self?.positionChangeSettings.enabled == true else { return }
                self?.pendingChanges = changes
            }
    }

    func loadPositions() {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        loadCancellable?.cancel()
        loadCancellable = positionService.fetchPositions()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    self?.loadCancellable = nil
                    if case .failure(let error) = completion {
                        Logger.ui.error("Failed to load positions: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.positions = response.positions
                    self?.summary = response.summary
                    Logger.ui.debug("Loaded \(response.positions.count) positions")
                }
            )
    }

    func refresh() {
        guard !isRefreshing else { return }

        isRefreshing = true
        errorMessage = nil

        loadCancellable?.cancel()
        loadCancellable = positionService.fetchPositions(forceRefresh: true)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isRefreshing = false
                    self?.loadCancellable = nil
                    if case .failure(let error) = completion {
                        Logger.ui.error("Failed to refresh positions: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.positions = response.positions
                    self?.summary = response.summary
                    Logger.ui.debug("Refreshed positions")
                }
            )
    }

    func clearError() {
        errorMessage = nil
    }

    func dismissChanges() {
        pendingChanges = []
    }
}
