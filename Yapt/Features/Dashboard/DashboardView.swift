//
//  DashboardView.swift
//  Yapt
//
//  Dashboard screen
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject private var viewModel: DashboardViewModel

    init(portfolioService: PortfolioService) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(
            portfolioService: portfolioService
        ))
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading && viewModel.summary == nil {
                    ProgressView("Loading portfolio...")
                } else if let errorMessage = viewModel.errorMessage, viewModel.summary == nil {
                    errorView(errorMessage)
                } else if let summary = viewModel.summary {
                    contentView(summary)
                } else {
                    emptyView
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.loadSummary()
            }
        }
    }

    @ViewBuilder
    private func contentView(_ summary: PortfolioSummary) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Total Value Card
                MetricCard(
                    title: "Total Value",
                    value: summary.totalValueUsd.asCurrency(),
                    subtitle: "Last updated \(summary.lastUpdated)",
                    backgroundColor: .blue
                )

                // Income Projections
                HStack(spacing: 12) {
                    SmallMetricCard(
                        title: "Daily",
                        value: summary.estDailyUsd.asCurrency()
                    )
                    SmallMetricCard(
                        title: "Monthly",
                        value: summary.estMonthlyUsd.asCurrency()
                    )
                    SmallMetricCard(
                        title: "Yearly",
                        value: summary.estYearlyUsd.asCurrency()
                    )
                }

                // Recent Positions
                if !summary.positions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Positions")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(Array(summary.positions.prefix(5))) { position in
                            PositionRow(position: position)
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            Text("No portfolio data")
                .font(.headline)
            Button("Load Portfolio") {
                viewModel.loadSummary()
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            Text("Failed to load portfolio")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                viewModel.loadSummary()
            }
        }
    }
}

// MARK: - Metric Cards
struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let backgroundColor: Color

    init(title: String, value: String, subtitle: String? = nil, backgroundColor: Color = .blue) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))

            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(backgroundColor.gradient)
        .cornerRadius(12)
    }
}

struct SmallMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct PositionRow: View {
    let position: Position

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(position.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if position.hasAPY, let apy = position.apy {
                    Text("\(apy.asPercentage()) APY")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if position.isRewardBased {
                    Text("Rewards-based")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(position.valueUsd.asCurrency())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()

                Text("\(position.estDailyUsd.asCurrency())/day")
                    .font(.caption)
                    .foregroundColor(.green)
                    .monospacedDigit()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    let env = AppEnvironment()
    return DashboardView(portfolioService: env.portfolioService)
        .environmentObject(env)
}
