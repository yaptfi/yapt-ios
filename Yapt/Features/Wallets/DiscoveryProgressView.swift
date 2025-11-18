//
//  DiscoveryProgressView.swift
//  Yapt
//
//  Real-time discovery progress display for wallet scanning
//

import SwiftUI

struct DiscoveryProgressView: View {
    let progress: DiscoveryProgress

    var body: some View {
        VStack(spacing: 20) {
            // Progress indicator
            VStack(spacing: 12) {
                ProgressView(value: progress.progressPercentage)
                    .progressViewStyle(.linear)
                    .tint(.blue)

                Text("\(Int(progress.progressPercentage * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Status card
            VStack(alignment: .leading, spacing: 16) {
                // Current status
                HStack {
                    Image(systemName: "gearshape.2")
                        .foregroundColor(.blue)
                    Text(progress.status)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Divider()

                // Progress details
                VStack(spacing: 12) {
                    if let currentChain = progress.currentChain {
                        progressRow(
                            icon: "link",
                            label: "Current Chain",
                            value: currentChain,
                            valueColor: .blue
                        )
                    }

                    progressRow(
                        icon: "network",
                        label: "Chains Scanned",
                        value: "\(progress.chainsCompleted) / \(progress.chainsTotal)"
                    )

                    progressRow(
                        icon: "chart.bar",
                        label: "Positions Found",
                        value: "\(progress.positionsFound)",
                        valueColor: progress.positionsFound > 0 ? .green : .secondary
                    )

                    if let ensName = progress.ensName {
                        progressRow(
                            icon: "person.text.rectangle",
                            label: "ENS Name",
                            value: ensName,
                            valueColor: .purple
                        )
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Scanning animation
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseScale(for: index))
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: progress.chainsCompleted
                        )
                }

                Text("Scanning blockchains...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .padding()
    }

    private func progressRow(
        icon: String,
        label: String,
        value: String,
        valueColor: Color = .primary
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }

    private func pulseScale(for index: Int) -> CGFloat {
        let baseScale: CGFloat = 1.0
        let pulseScale: CGFloat = 1.5

        // Simple alternating animation based on progress changes
        return (progress.chainsCompleted + index) % 2 == 0 ? baseScale : pulseScale
    }
}

#Preview {
    VStack(spacing: 20) {
        // Early progress
        DiscoveryProgressView(progress: DiscoveryProgress(
            status: "Scanning Ethereum mainnet",
            currentChain: "Ethereum",
            chainsCompleted: 2,
            chainsTotal: 10,
            positionsFound: 3,
            ensName: "vitalik.eth"
        ))

        // Mid progress
        DiscoveryProgressView(progress: DiscoveryProgress(
            status: "Scanning Polygon",
            currentChain: "Polygon",
            chainsCompleted: 5,
            chainsTotal: 10,
            positionsFound: 12,
            ensName: nil
        ))

        // Near complete
        DiscoveryProgressView(progress: DiscoveryProgress(
            status: "Finalizing results",
            currentChain: nil,
            chainsCompleted: 9,
            chainsTotal: 10,
            positionsFound: 25,
            ensName: nil
        ))
    }
}
