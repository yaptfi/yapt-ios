//
//  Wallet.swift
//  Yapt
//
//  Wallet model
//

import Foundation

struct Wallet: Codable, Identifiable, Equatable {
    let id: UUID
    let address: String
    let ensName: String?
    let createdAt: Date

    var displayName: String {
        ensName ?? address.truncatedAddress
    }
}

// MARK: - API Response
struct WalletsResponse: Codable {
    let wallets: [Wallet]
}

// MARK: - Address Helpers
extension String {
    var truncatedAddress: String {
        guard self.starts(with: "0x"), self.count >= 10 else {
            return self
        }
        let start = self.prefix(6)
        let end = self.suffix(4)
        return "\(start)...\(end)"
    }

    var isValidEthereumAddress: Bool {
        let pattern = "^0x[a-fA-F0-9]{40}$"
        return self.range(of: pattern, options: .regularExpression) != nil
    }
}
