//
//  NotificationDetailView.swift
//  Yapt
//
//  Detailed view for a single notification
//

import SwiftUI

struct NotificationDetailView: View {
    let notification: NotificationLog
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with icon and type
                    headerSection

                    Divider()

                    // Title and Message
                    contentSection

                    Divider()

                    // Metadata
                    if let metadata = notification.metadata {
                        metadataSection(metadata)
                        Divider()
                    }

                    // Timestamp
                    timestampSection
                }
                .padding()
            }
            .navigationTitle("Notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(severityColor.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: notification.type.icon)
                    .foregroundColor(typeColor)
                    .font(.system(size: 24))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.type.displayName)
                    .font(.headline)
                    .foregroundColor(typeColor)

                HStack(spacing: 6) {
                    Image(systemName: notification.severity.icon)
                    Text(notification.severity.displayName)
                }
                .font(.caption)
                .foregroundColor(severityColor)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(notification.title)
                .font(.title3)
                .fontWeight(.semibold)

            Text(notification.message)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func metadataSection(_ metadata: NotificationMetadata) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                // Depeg-specific metadata
                if let symbol = metadata.symbol {
                    metadataRow(label: "Symbol", value: symbol)
                }

                if let price = metadata.price {
                    metadataRow(label: "Price", value: price.asCurrency())
                }

                if let deviation = metadata.deviation {
                    let deviationPercent = String(format: "%.2f%%", deviation * 100)
                    metadataRow(
                        label: "Deviation",
                        value: deviationPercent,
                        color: deviation > 0 ? .red : .green
                    )
                }

                // APY-specific metadata
                if let oldApy = metadata.oldApy, let newApy = metadata.newApy {
                    metadataRow(label: "Old APY", value: oldApy.asPercentage())
                    metadataRow(label: "New APY", value: newApy.asPercentage())

                    if let change = metadata.change {
                        let changePercent = String(format: "%+.2f%%", change * 100)
                        metadataRow(
                            label: "Change",
                            value: changePercent,
                            color: change > 0 ? .green : .red
                        )
                    }
                }

                // IDs
                if let positionId = metadata.positionId {
                    metadataRow(
                        label: "Position ID",
                        value: positionId.uuidString,
                        isMonospaced: true
                    )
                }

                if let walletId = metadata.walletId {
                    metadataRow(
                        label: "Wallet ID",
                        value: walletId.uuidString,
                        isMonospaced: true
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var timestampSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Received")
                .font(.headline)

            Text(notification.formattedTimestamp)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(notification.createdAt.formatted(date: .complete, time: .standard))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func metadataRow(
        label: String,
        value: String,
        color: Color? = nil,
        isMonospaced: Bool = false
    ) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)

            if isMonospaced {
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(color ?? .primary)
            } else {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color ?? .primary)
            }

            Spacer()
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
