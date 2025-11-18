//
//  DashboardViewModel.swift
//  Yapt
//
//  Dashboard view model
//

import Foundation
import Combine
import OSLog

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var summary: PortfolioSummary?
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var errorMessage: String?

    private let portfolioService: PortfolioService
    private var cancellables = Set<AnyCancellable>()

    init(portfolioService: PortfolioService) {
        self.portfolioService = portfolioService
    }

    func loadSummary() {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        portfolioService.fetchSummary()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        Logger.ui.error("Failed to load portfolio: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] summary in
                    self?.summary = summary
                    Logger.ui.debug("Loaded portfolio: \(summary.positions.count) positions")
                }
            )
            .store(in: &cancellables)
    }

    func refresh() {
        guard !isRefreshing else { return }

        isRefreshing = true
        errorMessage = nil

        portfolioService.fetchSummary(forceRefresh: true)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isRefreshing = false
                    if case .failure(let error) = completion {
                        Logger.ui.error("Failed to refresh portfolio: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] summary in
                    self?.summary = summary
                    Logger.ui.debug("Refreshed portfolio")
                }
            )
            .store(in: &cancellables)
    }

    func clearError() {
        errorMessage = nil
    }
}
