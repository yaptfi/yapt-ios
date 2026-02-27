//
//  MainTabView.swift
//  Yapt
//
//  Main tab navigation
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment

    var body: some View {
        TabView {
            DashboardView(
                portfolioService: appEnvironment.portfolioService,
                positionService: appEnvironment.positionService,
                portfolioValueCache: appEnvironment.portfolioValueCache
            )
            .tabItem {
                Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
            }

            WalletsListView(walletService: appEnvironment.walletService)
                .tabItem {
                    Label("Wallets", systemImage: "wallet.pass")
                }

            PositionsListView(
                positionService: appEnvironment.positionService,
                positionChangeSettings: appEnvironment.positionChangeSettings
            )
                .tabItem {
                    Label("Positions", systemImage: "list.bullet.rectangle")
                }

            SettingsView(authService: appEnvironment.authService)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
