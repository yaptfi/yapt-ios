//
//  DashboardViewModel.swift
//  Yapt
//
//  Dashboard view model
//

import Foundation
import Combine
import OSLog

struct PortfolioValueAnimationTrigger: Identifiable, Equatable {
    let id = UUID()
    let previousValue: Double
    let newValue: Double

    var delta: Double { newValue - previousValue }

    static func == (lhs: PortfolioValueAnimationTrigger, rhs: PortfolioValueAnimationTrigger) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var summary: PortfolioSummary?
    @Published var actualYields: PositionSummary?
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var cachedTotalValue: Double?
    @Published private(set) var cachedTotalValueTimestamp: Date?
    @Published var valueAnimationTrigger: PortfolioValueAnimationTrigger?

    private let portfolioService: PortfolioService
    private let positionService: PositionService
    private let portfolioValueCache: PortfolioValueCache
    private var loadCancellable: AnyCancellable?
    private let animationThreshold: Double = 1

    init(
        portfolioService: PortfolioService,
        positionService: PositionService,
        portfolioValueCache: PortfolioValueCache
    ) {
        self.portfolioService = portfolioService
        self.positionService = positionService
        self.portfolioValueCache = portfolioValueCache

        if let cached = portfolioValueCache.loadLastValue() {
            self.cachedTotalValue = cached.totalValue
            self.cachedTotalValueTimestamp = cached.timestamp
        }
    }

    func loadSummary() {
        guard !isLoading else { return }

        // Always fetch - the service layer will use cache if still valid
        performLoad(forceRefresh: false)
    }

    func refresh() {
        guard !isRefreshing else { return }

        performLoad(forceRefresh: true)
    }

    func clearError() {
        errorMessage = nil
    }

    private func performLoad(forceRefresh: Bool) {
        if forceRefresh {
            isRefreshing = true
        } else {
            isLoading = true
        }

        errorMessage = nil

        loadCancellable?.cancel()
        loadCancellable = Publishers.CombineLatest(
            portfolioService.fetchSummary(forceRefresh: forceRefresh),
            positionService.fetchPositions(forceRefresh: forceRefresh)
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                guard let self else { return }
                if forceRefresh {
                    self.isRefreshing = false
                } else {
                    self.isLoading = false
                }

                if case .failure(let error) = completion {
                    Logger.ui.error("Failed to load portfolio: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                }

                self.loadCancellable = nil
            },
            receiveValue: { [weak self] summary, positionsResponse in
                self?.applyLoadedData(summary: summary, positionsResponse: positionsResponse)
            }
        )
    }

    // MARK: - Performance Calculations

    var performance1D: Double? {
        guard let summary = summary, let yields = actualYields,
              summary.estDailyUsd > 0 else { return nil }
        return (yields.actual24hYield / summary.estDailyUsd) - 1
    }

    var performance7D: Double? {
        guard let summary = summary, let yields = actualYields else { return nil }
        let expected7d = summary.estDailyUsd * 7
        guard expected7d > 0 else { return nil }
        return (yields.actual7dYield / expected7d) - 1
    }

    var performance30D: Double? {
        guard let summary = summary, let yields = actualYields,
              summary.estMonthlyUsd > 0 else { return nil }
        return (yields.actual30dYield / summary.estMonthlyUsd) - 1
    }

    private func applyLoadedData(summary: PortfolioSummary, positionsResponse: PositionsResponse) {
        let previousValue = cachedTotalValue

        self.summary = summary
        self.actualYields = positionsResponse.summary

        if let previousValue = previousValue,
           abs(summary.totalValueUsd - previousValue) >= animationThreshold {
            valueAnimationTrigger = PortfolioValueAnimationTrigger(
                previousValue: previousValue,
                newValue: summary.totalValueUsd
            )
        } else {
            valueAnimationTrigger = nil
        }

        cachedTotalValue = summary.totalValueUsd
        cachedTotalValueTimestamp = summary.asOf
        portfolioValueCache.store(totalValue: summary.totalValueUsd, timestamp: summary.asOf)

        Logger.ui.debug("Loaded portfolio: \(summary.positions.count) positions")
    }
}
