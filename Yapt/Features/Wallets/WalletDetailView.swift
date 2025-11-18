//
//  WalletDetailView.swift
//  Yapt
//
//  Wallet detail screen with positions and rescan functionality
//

import SwiftUI

struct WalletDetailView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject private var viewModel: WalletDetailViewModel
    @State private var showingRescanProgress = false

    init(wallet: Wallet, walletService: WalletService, positionService: PositionService) {
        _viewModel = StateObject(wrappedValue: WalletDetailViewModel(
            wallet: wallet,
            walletService: walletService,
            positionService: positionService
        ))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.positions.isEmpty {
                ProgressView("Loading positions...")
            } else if viewModel.positions.isEmpty {
                emptyView
            } else {
                contentView
            }
        }
        .navigationTitle(viewModel.wallet.ensName ?? "Wallet")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingRescanProgress = true
                    viewModel.rescan()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isRescanning)
            }
        }
        .sheet(isPresented: $showingRescanProgress, onDismiss: {
            // Sheet dismissed
        }) {
            rescanProgressView
        }
        .onAppear {
            viewModel.loadPositions()
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        List {
            // Wallet info section
            Section {
                walletInfoRow
            }

            // Positions section
            Section {
                ForEach(viewModel.positions) { position in
                    PositionRow(position: position)
                }
            } header: {
                Text("Positions (\(viewModel.positions.count))")
            }

            // Error message
            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }

    private var walletInfoRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Address
            VStack(alignment: .leading, spacing: 4) {
                Text("Address")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(viewModel.wallet.address)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }

            Divider()

            // Created date
            VStack(alignment: .leading, spacing: 4) {
                Text("Added")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(viewModel.wallet.createdAt.asRelativeString())
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            Text("No positions")
                .font(.headline)
            Text("This wallet has no DeFi positions yet")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Rescan Wallet") {
                showingRescanProgress = true
                viewModel.rescan()
            }
        }
        .padding()
    }

    // MARK: - Rescan Progress View

    private var rescanProgressView: some View {
        NavigationView {
            VStack(spacing: 24) {
                if viewModel.isRescanning {
                    if let progress = viewModel.progress {
                        DiscoveryProgressView(progress: progress)
                    } else {
                        ProgressView("Starting rescan...")
                            .padding()
                    }
                } else {
                    // Rescan complete
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)

                        Text("Rescan Complete")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Positions have been updated")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Rescanning Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.isRescanning {
                        Button("Done") {
                            showingRescanProgress = false
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    let env = AppEnvironment()
    let wallet = Wallet(
        id: UUID(),
        address: "0x1234567890123456789012345678901234567890",
        ensName: "vitalik.eth",
        createdAt: Date()
    )
    NavigationView {
        WalletDetailView(
            wallet: wallet,
            walletService: env.walletService,
            positionService: env.positionService
        )
        .environmentObject(env)
    }
}
