//
//  PositionChangeBannerView.swift
//  Yapt
//
//  Dismissible banner shown when position changes are detected
//

import SwiftUI

struct PositionChangeBannerView: View {
    let changes: [PositionChangeAlert]
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if changes.count == 1, let change = changes.first {
                singleChangeContent(change)
            } else {
                multipleChangesContent
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(bannerBackground)
    }

    // MARK: - Single change

    @ViewBuilder
    private func singleChangeContent(_ change: PositionChangeAlert) -> some View {
        Image(systemName: change.changeType.icon)
            .foregroundColor(change.changeType.color)
            .font(.system(size: 20))

        VStack(alignment: .leading, spacing: 2) {
            Text(change.positionName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
            Text(change.changeType.description(changePercent: change.changePercent))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Multiple changes

    private var multipleChangesContent: some View {
        HStack(spacing: 10) {
            // Show up to 3 icons
            HStack(spacing: -6) {
                ForEach(Array(changes.prefix(3).enumerated()), id: \.offset) { _, change in
                    Image(systemName: change.changeType.icon)
                        .foregroundColor(change.changeType.color)
                        .font(.system(size: 18))
                        .background(Circle().fill(Color(.systemBackground)).padding(-3))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(changes.count) position changes detected")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Pull to refresh to see updated values")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Background

    private var bannerBackground: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(Color(.secondarySystemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.separator)),
                alignment: .bottom
            )
    }
}

// MARK: - PositionChangeType helpers

extension PositionChangeType {
    var icon: String {
        switch self {
        case .appeared:     return "arrow.down.circle.fill"
        case .increased:    return "arrow.up.right.circle.fill"
        case .partialExit:  return "arrow.down.left.circle.fill"
        case .fullExit:     return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .appeared:     return .green
        case .increased:    return .green
        case .partialExit:  return .orange
        case .fullExit:     return .red
        }
    }

    func description(changePercent: Double) -> String {
        switch self {
        case .appeared:
            return "New position added"
        case .increased:
            let pct = Int(changePercent * 100)
            return "Increased by \(pct)%"
        case .partialExit:
            let pct = Int(abs(changePercent) * 100)
            return "Decreased by \(pct)%"
        case .fullExit:
            return "Fully exited"
        }
    }
}
