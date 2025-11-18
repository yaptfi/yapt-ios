//
//  WalletsListView.swift
//  Yapt
//
//  Wallets list screen
//

import SwiftUI

struct WalletsListView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject private var viewModel: WalletsViewModel
    @State private var showingAddWallet = false

    init(walletService: WalletService) {
        _viewModel = StateObject(wrappedValue: WalletsViewModel(
            walletService: walletService
        ))
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading && viewModel.wallets.isEmpty {
                    ProgressView("Loading wallets...")
                } else if let errorMessage = viewModel.errorMessage, viewModel.wallets.isEmpty {
                    errorView(errorMessage)
                } else if !viewModel.wallets.isEmpty {
                    contentView
                } else {
                    emptyView
                }
            }
            .navigationTitle("Wallets")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddWallet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddWallet, onDismiss: {
                // Refresh wallet list after adding a wallet
                viewModel.refresh()
            }) {
                AddWalletView(walletService: appEnvironment.walletService)
            }
            .onAppear {
                viewModel.loadWallets()
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        List {
            Section {
                ForEach(viewModel.wallets) { wallet in
                    WalletRow(wallet: wallet)
                }
            } header: {
                Text("Tracked Wallets (\(viewModel.wallets.count))")
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
            Image(systemName: "wallet.pass")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            Text("No wallets")
                .font(.headline)
            Text("Add a wallet to start tracking your DeFi positions")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(action: {
                showingAddWallet = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Wallet")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            Text("Failed to load wallets")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                viewModel.loadWallets()
            }
        }
    }
}

// MARK: - Wallet Row
struct WalletRow: View {
    let wallet: Wallet

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ENS Name or Address
            if let ensName = wallet.ensName {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                    Text(ensName)
                        .font(.headline)
                }
            } else {
                Text(wallet.address)
                    .font(.system(.subheadline, design: .monospaced))
            }

            // Address (if ENS is present)
            if wallet.ensName != nil {
                HStack {
                    Image(systemName: "number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(wallet.address.truncatedAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Created date
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Added \(wallet.createdAt.asRelativeString())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let env = AppEnvironment()
    return WalletsListView(walletService: env.walletService)
        .environmentObject(env)
}
