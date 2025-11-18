//
//  PositionsListView.swift
//  Yapt
//
//  Positions list screen
//

import SwiftUI

struct PositionsListView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject private var viewModel: PositionsViewModel

    init(positionService: PositionService) {
        _viewModel = StateObject(wrappedValue: PositionsViewModel(
            positionService: positionService
        ))
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading && viewModel.positions.isEmpty {
                    ProgressView("Loading positions...")
                } else if let errorMessage = viewModel.errorMessage, viewModel.positions.isEmpty {
                    errorView(errorMessage)
                } else if !viewModel.positions.isEmpty {
                    contentView
                } else {
                    emptyView
                }
            }
            .navigationTitle("Positions")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.loadPositions()
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        List {
            // Summary Section
            if let summary = viewModel.summary {
                Section {
                    SummaryRow(label: "24h Yield", value: summary.actual24hYield.asCurrency())
                    SummaryRow(label: "7d Yield", value: summary.actual7dYield.asCurrency())
                    SummaryRow(label: "30d Yield", value: summary.actual30dYield.asCurrency())
                } header: {
                    Text("Actual Yields")
                }
            }

            // Positions Section
            Section {
                ForEach(viewModel.positions) { position in
                    PositionDetailRow(position: position)
                }
            } header: {
                Text("All Positions (\(viewModel.positions.count))")
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

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            Text("No positions")
                .font(.headline)
            Button("Load Positions") {
                viewModel.loadPositions()
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            Text("Failed to load positions")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                viewModel.loadPositions()
            }
        }
    }
}

// MARK: - Supporting Views
struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }
}

struct PositionDetailRow: View {
    let position: Position

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(position.displayName)
                        .font(.headline)

                    HStack(spacing: 8) {
                        Text(position.baseAsset)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)

                        Text(position.countingMode.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                    }
                }

                Spacer()

                Text(position.valueUsd.asCurrency())
                    .font(.headline)
                    .monospacedDigit()
            }

            Divider()

            // Metrics - Different display based on measure method
            if position.isRewardBased {
                // Rewards-based position - show absolute yields, NO APY
                rewardBasedMetrics(position)
            } else {
                // APY-based position - show APY and estimates
                apyBasedMetrics(position)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func rewardBasedMetrics(_ position: Position) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "gift")
                    .foregroundColor(.orange)
                Text("Rewards-Based Position")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fontWeight(.medium)
                Spacer()
            }

            if let absoluteYield = position.absoluteYield {
                VStack(spacing: 6) {
                    MetricRow(
                        label: "Avg Daily Yield",
                        value: absoluteYield.avgDailyYield.asCurrency(),
                        color: .green
                    )
                    MetricRow(
                        label: "Projected Monthly",
                        value: absoluteYield.projectedMonthlyYield.asCurrency(),
                        color: .green
                    )
                    MetricRow(
                        label: "Projected Yearly",
                        value: absoluteYield.projectedYearlyYield.asCurrency(),
                        color: .green
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func apyBasedMetrics(_ position: Position) -> some View {
        VStack(spacing: 8) {
            // APY Section
            if position.hasAPY {
                HStack(spacing: 16) {
                    if let apy = position.apy {
                        MetricColumn(label: "APY", value: apy.asPercentage())
                    }
                    if let apy7d = position.apy7d {
                        MetricColumn(label: "APY 7d", value: apy7d.asPercentage())
                    }
                    if let apy30d = position.apy30d {
                        MetricColumn(label: "APY 30d", value: apy30d.asPercentage())
                    }
                    Spacer()
                }
            }

            // Income Estimates
            VStack(spacing: 6) {
                MetricRow(
                    label: "Est. Daily",
                    value: position.estDailyUsd.asCurrency(),
                    color: .green
                )
                MetricRow(
                    label: "Est. Monthly",
                    value: position.estMonthlyUsd.asCurrency(),
                    color: .green
                )
                MetricRow(
                    label: "Est. Yearly",
                    value: position.estYearlyUsd.asCurrency(),
                    color: .green
                )
            }
        }
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
                .monospacedDigit()
        }
    }
}

struct MetricColumn: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }
}

#Preview {
    let env = AppEnvironment()
    return PositionsListView(positionService: env.positionService)
        .environmentObject(env)
}
