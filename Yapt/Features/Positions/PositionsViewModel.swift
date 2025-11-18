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

    private let positionService: PositionService
    private var cancellables = Set<AnyCancellable>()

    init(positionService: PositionService) {
        self.positionService = positionService
    }

    func loadPositions() {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        positionService.fetchPositions()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
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
            .store(in: &cancellables)
    }

    func refresh() {
        guard !isRefreshing else { return }

        isRefreshing = true
        errorMessage = nil

        positionService.fetchPositions(forceRefresh: true)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isRefreshing = false
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
            .store(in: &cancellables)
    }

    func clearError() {
        errorMessage = nil
    }
}
