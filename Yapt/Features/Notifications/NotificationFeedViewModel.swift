//
//  NotificationFeedViewModel.swift
//  Yapt
//
//  ViewModel for notification history feed
//

import Foundation
import Combine
import OSLog

@MainActor
class NotificationFeedViewModel: ObservableObject {
    // MARK: - Published State

    @Published var notifications: [NotificationLog] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var errorMessage: String?
    @Published var selectedType: NotificationType? = nil
    @Published var hasMore: Bool = false

    // MARK: - Private State

    private var currentOffset: Int = 0
    private let pageSize: Int = 50

    // MARK: - Dependencies

    private let notificationService: NotificationService
    private var cancellables = Set<AnyCancellable>()

    init(notificationService: NotificationService) {
        self.notificationService = notificationService
    }

    // MARK: - Actions

    func loadNotifications() {
        guard !isLoading else { return }

        isLoading = true
        currentOffset = 0
        errorMessage = nil

        notificationService.fetchHistory(limit: pageSize, offset: 0, type: selectedType)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        Logger.ui.error("Failed to load notifications: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.notifications = response.notifications
                    self?.hasMore = response.hasMore
                    self?.currentOffset = response.notifications.count
                    Logger.ui.debug("Loaded \(response.notifications.count) notifications")
                }
            )
            .store(in: &cancellables)
    }

    func refresh() {
        guard !isRefreshing else { return }

        isRefreshing = true
        currentOffset = 0
        errorMessage = nil

        notificationService.fetchHistory(limit: pageSize, offset: 0, type: selectedType)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isRefreshing = false
                    if case .failure(let error) = completion {
                        Logger.ui.error("Failed to refresh notifications: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.notifications = response.notifications
                    self?.hasMore = response.hasMore
                    self?.currentOffset = response.notifications.count
                    Logger.ui.debug("Refreshed notifications")
                }
            )
            .store(in: &cancellables)
    }

    func loadMore() {
        guard !isLoadingMore, hasMore else { return }

        isLoadingMore = true

        notificationService.fetchHistory(limit: pageSize, offset: currentOffset, type: selectedType)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingMore = false
                    if case .failure(let error) = completion {
                        Logger.ui.error("Failed to load more notifications: \(error.localizedDescription)")
                        // Don't overwrite existing error message for "load more" failures
                    }
                },
                receiveValue: { [weak self] response in
                    self?.notifications.append(contentsOf: response.notifications)
                    self?.hasMore = response.hasMore
                    self?.currentOffset += response.notifications.count
                    Logger.ui.debug("Loaded \(response.notifications.count) more notifications")
                }
            )
            .store(in: &cancellables)
    }

    func filterByType(_ type: NotificationType?) {
        guard selectedType != type else { return }
        selectedType = type
        loadNotifications()
    }

    func clearError() {
        errorMessage = nil
    }
}
