//
//  AddWalletView.swift
//  Yapt
//
//  Add wallet form with discovery progress display
//

import SwiftUI

struct AddWalletView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: AddWalletViewModel

    init(walletService: WalletService) {
        _viewModel = StateObject(wrappedValue: AddWalletViewModel(walletService: walletService))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.isDiscovering {
                        // Show discovery progress
                        if let progress = viewModel.progress {
                            DiscoveryProgressView(progress: progress)
                        } else {
                            ProgressView("Starting discovery...")
                                .padding()
                        }
                    } else if let result = viewModel.discoveryResult {
                        // Show success result
                        successView(result: result)
                    } else {
                        // Show input form
                        inputForm
                    }

                    // Error message
                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(message: errorMessage)
                    }
                }
                .padding()
            }
            .navigationTitle("Add Wallet")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !viewModel.isDiscovering {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.discoveryResult != nil {
                        Button("Done") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Input Form

    @ViewBuilder
    private var inputForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Address/ENS field
            VStack(alignment: .leading, spacing: 8) {
                Text("Wallet Address or ENS")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("0x... or name.eth", text: $viewModel.address)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.address) { _ in
                        viewModel.validateAddress()
                    }

                if let error = viewModel.addressError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Text("Enter an Ethereum address (0x...) or ENS name (name.eth)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Label field (optional)
            VStack(alignment: .leading, spacing: 8) {
                Text("Label (Optional)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("e.g., Main Wallet", text: $viewModel.label)
                    .textFieldStyle(.roundedBorder)

                Text("Add a friendly name to identify this wallet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Submit button
            Button(action: {
                viewModel.addWallet()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Wallet")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.canSubmit ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(!viewModel.canSubmit)
            .padding(.top, 8)

            // Info section
            VStack(alignment: .leading, spacing: 12) {
                Label("What happens next?", systemImage: "info.circle")
                    .font(.subheadline)
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 8) {
                    bulletPoint("We'll scan multiple blockchains for your DeFi positions")
                    bulletPoint("Track real-time progress as each chain is scanned")
                    bulletPoint("ENS names will be automatically resolved")
                    bulletPoint("All positions will be added to your portfolio")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.top, 8)
        }
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.blue)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Success View

    private func successView(result: DiscoveryResult) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            VStack(spacing: 8) {
                Text("Wallet Added!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Discovery complete")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                resultRow(label: "Wallets Created", value: "\(result.walletsCreated)")
                resultRow(label: "Positions Found", value: "\(result.positionsCreated)")
                resultRow(label: "Total Value", value: result.totalValueUsd.asCurrency())
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
    }

    private func resultRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    let env = AppEnvironment()
    return AddWalletView(walletService: env.walletService)
}
