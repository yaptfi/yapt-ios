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
    @State private var isDashboardVisible = false
    @State private var isTotalPortfolioSectionVisible = false
    @State private var pendingValueAnimationTrigger: PortfolioValueAnimationTrigger?
    @State private var lastHandledValueAnimationTriggerID: UUID?

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
                isDashboardVisible = true
                viewModel.loadSummary()
                initializeAnimatedValueIfNeeded()
                handleValueAnimationTriggerChange(viewModel.valueAnimationTrigger)
                playPendingValueAnimationIfPossible()
            }
            .onChange(of: viewModel.cachedTotalValue) { _, _ in
                initializeAnimatedValueIfNeeded()
            }
            .onChange(of: viewModel.summary?.totalValueUsd) { _, _ in
                initializeAnimatedValueIfNeeded()
            }
            .onChange(of: viewModel.valueAnimationTrigger?.id) { _, _ in
                handleValueAnimationTriggerChange(viewModel.valueAnimationTrigger)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                viewModel.refresh()
            }
        }
        .onDisappear {
            isDashboardVisible = false
            isTotalPortfolioSectionVisible = false
            floatingDeltaRemovalTask?.cancel()
            floatingDeltaRemovalTask = nil
            activeFloatingDelta = nil
        }
    }

    @ViewBuilder
    private func contentView(_ summary: PortfolioSummary) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. Total Portfolio Section (plain text, no card)
                TotalPortfolioSection(
                    displayedValue: hasAnimatedTotalValue ? animatedTotalValue : summary.totalValueUsd,
                    isLoading: viewModel.isRefreshing,
                    floatingDelta: activeFloatingDelta,
                    onVisibilityChanged: handleTotalPortfolioSectionVisibilityChange(_:)
                )

                // 2. Annual Projected Income Card (blue gradient)
                AnnualProjectedIncomeCard(
                    yearlyValue: summary.estYearlyUsd,
                    monthlyValue: summary.estMonthlyUsd
                )

                // 3. Received Income Card
                if let actualYields = viewModel.actualYields {
                    ReceivedIncomeCard(yields: actualYields)
                }

                // 4. Expected Income Card
                ExpectedIncomeCard(
                    dailyValue: summary.estDailyUsd,
                    weeklyValue: summary.estDailyUsd * 7,
                    monthlyValue: summary.estMonthlyUsd
                )

                // 5. Performance vs Expected Section
                if viewModel.actualYields != nil {
                    PerformanceSection(
                        performance1D: viewModel.performance1D,
                        performance7D: viewModel.performance7D,
                        performance30D: viewModel.performance30D
                    )
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
                TotalPortfolioSection(
                    displayedValue: hasAnimatedTotalValue ? animatedTotalValue : value,
                    isLoading: true,
                    floatingDelta: activeFloatingDelta,
                    onVisibilityChanged: handleTotalPortfolioSectionVisibilityChange(_:)
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

    private var shouldPlayValueAnimation: Bool {
        isDashboardVisible && isTotalPortfolioSectionVisible
    }

    private func handleValueAnimationTriggerChange(_ trigger: PortfolioValueAnimationTrigger?) {
        guard let trigger else {
            pendingValueAnimationTrigger = nil
            return
        }

        guard lastHandledValueAnimationTriggerID != trigger.id else { return }

        if shouldPlayValueAnimation {
            lastHandledValueAnimationTriggerID = trigger.id
            startValueAnimation(using: trigger)
        } else {
            pendingValueAnimationTrigger = trigger
        }
    }

    private func handleTotalPortfolioSectionVisibilityChange(_ isVisible: Bool) {
        isTotalPortfolioSectionVisible = isVisible
        if isVisible {
            playPendingValueAnimationIfPossible()
        }
    }

    private func playPendingValueAnimationIfPossible() {
        guard shouldPlayValueAnimation,
              let pendingTrigger = pendingValueAnimationTrigger else { return }

        pendingValueAnimationTrigger = nil
        lastHandledValueAnimationTriggerID = pendingTrigger.id
        startValueAnimation(using: pendingTrigger)
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

// MARK: - Total Portfolio Section (Plain text, no card)

struct TotalPortfolioSection: View {
    let displayedValue: Double?
    let isLoading: Bool
    let floatingDelta: FloatingDelta?
    let onVisibilityChanged: ((Bool) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Total Portfolio")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .progressViewStyle(.circular)
                }
            }

            if let value = displayedValue {
                AnimatedCurrencyText(value: value)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .monospacedDigit()
                    .overlay(alignment: .trailing) {
                        if let delta = floatingDelta {
                            FloatingValueDeltaView(delta: delta)
                                .allowsHitTesting(false)
                        }
                    }
            } else {
                Text("--")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
        .onAppear {
            onVisibilityChanged?(true)
        }
        .onDisappear {
            onVisibilityChanged?(false)
        }
    }
}

// MARK: - Annual Projected Income Card (Blue gradient)

struct AnnualProjectedIncomeCard: View {
    let yearlyValue: Double
    let monthlyValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                Text("Annual Projected Income")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
            }

            Text(yearlyValue.asCurrency())
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()

            Text("\(monthlyValue.asCurrency())/month")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.gradient)
        .cornerRadius(16)
        .shadow(color: Color.blue.opacity(0.25), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Income Row Item (Reusable)

struct IncomeRowItem: View {
    let label: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(valueColor)
                .monospacedDigit()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Received Income Card

struct ReceivedIncomeCard: View {
    let yields: PositionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.green)
                Text("Earned")
                    .font(.headline)
                    .foregroundColor(.green)
            }

            Text("Income already in your wallet")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                IncomeRowItem(
                    label: "Last 24h",
                    value: yields.actual24hYield.asCurrency(),
                    valueColor: .green
                )
                Divider()
                IncomeRowItem(
                    label: "Last 7 days",
                    value: yields.actual7dYield.asCurrency(),
                    valueColor: .green
                )
                Divider()
                IncomeRowItem(
                    label: "Last 30 days",
                    value: yields.actual30dYield.asCurrency(),
                    valueColor: .green
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// MARK: - Expected Income Card

struct ExpectedIncomeCard: View {
    let dailyValue: Double
    let weeklyValue: Double
    let monthlyValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "target")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                Text("Expected")
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            Text("Projected income")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                IncomeRowItem(
                    label: "Next 24h",
                    value: dailyValue.asCurrency(),
                    valueColor: .blue
                )
                Divider()
                IncomeRowItem(
                    label: "Next 7 days",
                    value: weeklyValue.asCurrency(),
                    valueColor: .blue
                )
                Divider()
                IncomeRowItem(
                    label: "Next 30 days",
                    value: monthlyValue.asCurrency(),
                    valueColor: .blue
                )
            }
        }
        .padding()
        .background(Color.blue.opacity(0.08))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Performance Badge

struct PerformanceBadge: View {
    let period: String
    let percentage: Double?

    private var isPositive: Bool {
        (percentage ?? 0) >= 0
    }

    private var displayPercentage: String {
        guard let pct = percentage else { return "--" }
        let absValue = abs(pct * 100)
        let formatted = String(format: "%.1f%%", absValue)
        return isPositive ? "+\(formatted)" : "-\(formatted)"
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                Text(displayPercentage)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundColor(isPositive ? .green : .red)

            Text(period)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// MARK: - Performance Section

struct PerformanceSection: View {
    let performance1D: Double?
    let performance7D: Double?
    let performance30D: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PERFORMANCE VS EXPECTED")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .tracking(1)

            HStack(spacing: 8) {
                PerformanceBadge(period: "1D", percentage: performance1D)
                PerformanceBadge(period: "7D", percentage: performance7D)
                PerformanceBadge(period: "30D", percentage: performance30D)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Floating Delta

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

// MARK: - Position Row (kept for potential future use)

/// Generic position row that works with any PositionDisplayable
struct PositionRow<P: PositionDisplayable>: View {
    let position: P

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(position.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let apy = position.apy {
                    Text("\(apy.asPercentage()) APY")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if position.absoluteYield != nil {
                    Text("Rewards")
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
