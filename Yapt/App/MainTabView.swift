//
//  MainTabView.swift
//  Yapt
//
//  Main tab navigation
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }

            WalletsListView()
                .tabItem {
                    Label("Wallets", systemImage: "wallet.pass")
                }

            PositionsListView()
                .tabItem {
                    Label("Positions", systemImage: "list.bullet.rectangle")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
