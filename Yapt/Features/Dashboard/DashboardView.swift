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
    @State private var animatedTotalValue: Double = 0
    @State private var hasAnimatedTotalValue = false
    @State private var activeFloatingDelta: FloatingDelta?
    @State private var floatingDeltaRemovalTask: DispatchWorkItem?

    init(portfolioService: PortfolioService, positionService: PositionService, portfolioValueCache: PortfolioValueCache) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(
            portfolioService: portfolioService,
            positionService: positionService,
            portfolioValueCache: portfolioValueCache
        ))
    }

    var body: some View {
        NavigationView {
            Group {
                if let summary = viewModel.summary {
                    contentView(summary)
                } else if let cached = viewModel.cachedTotalValue {
                    cachedContentView(value: cached)
                } else if viewModel.isLoading {
                    ProgressView("Loading portfolio...")
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(errorMessage)
                } else {
                    emptyView
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.loadSummary()
                initializeAnimatedValueIfNeeded()
            }
            .onChange(of: viewModel.cachedTotalValue) { _, _ in
                initializeAnimatedValueIfNeeded()
            }
            .onChange(of: viewModel.summary?.totalValueUsd) { _, _ in
                initializeAnimatedValueIfNeeded()
            }
            .onChange(of: viewModel.valueAnimationTrigger?.id) { _, _ in
                guard let trigger = viewModel.valueAnimationTrigger else { return }
                startValueAnimation(using: trigger)
            }
        }
        .onDisappear {
            floatingDeltaRemovalTask?.cancel()
            floatingDeltaRemovalTask = nil
        }
    }

    @ViewBuilder
    private func contentView(_ summary: PortfolioSummary) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Total Value Card
                PortfolioTotalValueCard(
                    subtitle: "Last updated \(summary.lastUpdated)",
                    displayedValue: hasAnimatedTotalValue ? animatedTotalValue : nil,
                    isLoading: viewModel.isRefreshing,
                    floatingDelta: activeFloatingDelta
                )

                // Projected Income Section (Highlighted - "Can I live off this?")
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.orange)
                        Text("Projected Income")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }

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
                .background(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.15), Color.yellow.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color.orange.opacity(0.1), radius: 8, x: 0, y: 4)

                // Actual Yields Section ("How much did I make lately?")
                if let actualYields = viewModel.actualYields {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.green)
                            Text("Actual Earnings")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }

                        Text("What you've actually earned")
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
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
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

    @ViewBuilder
    private func cachedContentView(value: Double) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                PortfolioTotalValueCard(
                    subtitle: cachedSubtitle,
                    displayedValue: hasAnimatedTotalValue ? animatedTotalValue : value,
                    isLoading: true,
                    floatingDelta: activeFloatingDelta
                )

                VStack(alignment: .leading, spacing: 12) {
                    ProgressView("Fetching your latest balances...")
                        .progressViewStyle(.circular)
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("Hang tight—latest data will appear as soon as the sync completes.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    private var cachedSubtitle: String {
        if let timestamp = viewModel.cachedTotalValueTimestamp {
            return "Last seen \(timestamp.asRelativeString())"
        }
        return "Last seen recently"
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

    private func initializeAnimatedValueIfNeeded() {
        guard !hasAnimatedTotalValue else { return }
        if let cachedValue = viewModel.cachedTotalValue {
            animatedTotalValue = cachedValue
            hasAnimatedTotalValue = true
        } else if let loadedValue = viewModel.summary?.totalValueUsd {
            animatedTotalValue = loadedValue
            hasAnimatedTotalValue = true
        }
    }

    private func startValueAnimation(using trigger: PortfolioValueAnimationTrigger) {
        hasAnimatedTotalValue = true
        animatedTotalValue = trigger.previousValue

        withAnimation(.easeOut(duration: 2.0).delay(0.3)) {
            animatedTotalValue = trigger.newValue
        }

        spawnFloatingDelta(amount: trigger.delta)
    }

    private func spawnFloatingDelta(amount: Double) {
        guard abs(amount) >= 1 else { return }

        floatingDeltaRemovalTask?.cancel()
        let delta = FloatingDelta(amount: amount)
        activeFloatingDelta = delta

        let removalTask = DispatchWorkItem { [self] in
            if activeFloatingDelta?.id == delta.id {
                withAnimation(.easeOut(duration: 0.2)) {
                    activeFloatingDelta = nil
                }
                floatingDeltaRemovalTask = nil
            }
        }

        floatingDeltaRemovalTask = removalTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4, execute: removalTask)
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

// MARK: - Portfolio Hero Card
struct PortfolioTotalValueCard: View {
    let subtitle: String?
    let displayedValue: Double?
    let isLoading: Bool
    let floatingDelta: FloatingDelta?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Total Value")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .progressViewStyle(.circular)
                        .tint(.white.opacity(0.8))
                }
            }

            if let value = displayedValue {
                AnimatedCurrencyText(value: value)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .overlay(alignment: .trailing) {
                        if let delta = floatingDelta {
                            FloatingValueDeltaView(delta: delta)
                                .allowsHitTesting(false)
                        }
                    }
            } else {
                Text("--")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .monospacedDigit()
            }

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.gradient)
        .cornerRadius(16)
        .shadow(color: Color.blue.opacity(0.25), radius: 12, x: 0, y: 6)
    }
}

struct FloatingDelta: Identifiable, Equatable {
    let id = UUID()
    let amount: Double

    var isGain: Bool { amount >= 0 }

    static func == (lhs: FloatingDelta, rhs: FloatingDelta) -> Bool {
        lhs.id == rhs.id
    }
}

struct FloatingValueDeltaView: View {
    let delta: FloatingDelta

    @State private var floatUp = false
    @State private var shimmerOffset: CGFloat = -90

    var body: some View {
        Text(delta.amount.asCurrencyWithSign())
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundColor(textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(badgeBackground, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
            .overlay(shimmerOverlay.mask(Capsule().fill(Color.white)))
            .offset(y: floatUp ? -60 : 0)
            .opacity(floatUp ? 0 : 1)
            .onAppear {
                withAnimation(.linear(duration: 2.8)) {
                    shimmerOffset = 90
                }
                withAnimation(.easeOut(duration: 3.1).delay(0.15)) {
                    floatUp = true
                }
            }
    }

    private var textColor: Color {
        .white
    }

    private var badgeBackground: Color {
        if delta.isGain {
            return Color(red: 0.45, green: 0.85, blue: 0.55).opacity(0.95)
        } else {
            return Color(red: 0.95, green: 0.55, blue: 0.55).opacity(0.95)
        }
    }

    private var shimmerOverlay: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0),
                Color.white.opacity(0.8),
                Color.white.opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 90, height: 40)
        .offset(x: shimmerOffset)
        .blendMode(.screen)
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
        positionService: env.positionService,
        portfolioValueCache: env.portfolioValueCache
    )
    .environmentObject(env)
}
