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

    init(portfolioService: PortfolioService, positionService: PositionService) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(
            portfolioService: portfolioService,
            positionService: positionService
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

                // Actual Yields Section (Historical Data)
                if let actualYields = viewModel.actualYields {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Actual Yield")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Historical performance")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            ActualYieldCard(
                                title: "24h",
                                value: actualYields.actual24hYield.asCurrency()
                            )
                            ActualYieldCard(
                                title: "7d",
                                value: actualYields.actual7dYield.asCurrency()
                            )
                            ActualYieldCard(
                                title: "30d",
                                value: actualYields.actual30dYield.asCurrency()
                            )
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }

                // Projected Income Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Projected Income")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Estimated based on current APY")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        ProjectedIncomeCard(
                            title: "Daily",
                            value: summary.estDailyUsd.asCurrency()
                        )
                        ProjectedIncomeCard(
                            title: "Monthly",
                            value: summary.estMonthlyUsd.asCurrency()
                        )
                        ProjectedIncomeCard(
                            title: "Yearly",
                            value: summary.estYearlyUsd.asCurrency()
                        )
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)

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

struct ActualYieldCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct ProjectedIncomeCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

/// Generic position row that works with any PositionDisplayable
struct PositionRow<P: PositionDisplayable>: View {
    let position: P

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
    return DashboardView(
        portfolioService: env.portfolioService,
        positionService: env.positionService
    )
    .environmentObject(env)
}
