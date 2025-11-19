//
//  NotificationFeedView.swift
//  Yapt
//
//  Notification history feed screen
//

import SwiftUI

struct NotificationFeedView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject private var viewModel: NotificationFeedViewModel
    @State private var selectedNotification: NotificationLog?

    init(notificationService: NotificationService) {
        _viewModel = StateObject(wrappedValue: NotificationFeedViewModel(
            notificationService: notificationService
        ))
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading && viewModel.notifications.isEmpty {
                    ProgressView("Loading notifications...")
                } else if let errorMessage = viewModel.errorMessage, viewModel.notifications.isEmpty {
                    errorView(errorMessage)
                } else if !viewModel.notifications.isEmpty {
                    contentView
                } else {
                    emptyView
                }
            }
            .navigationTitle("Notification History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    filterMenu
                }
            }
            .sheet(item: $selectedNotification) { notification in
                NotificationDetailView(notification: notification)
            }
            .onAppear {
                viewModel.loadNotifications()
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        List {
            ForEach(viewModel.notifications) { notification in
                NotificationRow(notification: notification)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedNotification = notification
                    }
                    .onAppear {
                        // Load more when reaching last item
                        if notification.id == viewModel.notifications.last?.id {
                            viewModel.loadMore()
                        }
                    }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    private var filterMenu: some View {
        Menu {
            Button(action: { viewModel.filterByType(nil) }) {
                Label("All Notifications", systemImage: viewModel.selectedType == nil ? "checkmark" : "")
            }

            ForEach(NotificationType.allCases, id: \.self) { type in
                Button(action: { viewModel.filterByType(type) }) {
                    Label(type.displayName, systemImage: viewModel.selectedType == type ? "checkmark" : type.icon)
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            Text("No notifications")
                .font(.headline)
            Text("You'll see notification history here")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            Text("Failed to load notifications")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                viewModel.loadNotifications()
            }
        }
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notification: NotificationLog

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon with severity color
            severityIcon

            VStack(alignment: .leading, spacing: 6) {
                // Type and timestamp
                HStack {
                    Text(notification.type.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(typeColor)

                    Spacer()

                    Text(notification.formattedTimestamp)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Title
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                // Message preview
                Text(notification.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var severityIcon: some View {
        ZStack {
            Circle()
                .fill(severityColor.opacity(0.2))
                .frame(width: 40, height: 40)

            Image(systemName: notification.severity.icon)
                .foregroundColor(severityColor)
                .font(.system(size: 16))
        }
    }

    private var typeColor: Color {
        switch notification.type {
        case .depeg: return .orange
        case .apy: return .blue
        }
    }

    private var severityColor: Color {
        switch notification.severity {
        case .min: return .gray
        case .low: return .blue
        case .default: return .green
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

#Preview {
    let env = AppEnvironment()
    return NotificationFeedView(notificationService: env.notificationService)
        .environmentObject(env)
}
