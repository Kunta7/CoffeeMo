//
//  ContentView.swift
//  CoffeeMo
//
//  Created by MAC on 20.05.2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var vm: IoTSystemViewModel
    @State private var selectedTab: Tab = .home

    enum Tab: Hashable {
        case home, storage, beds, activity, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(Tab.home)

            StorageView()
                .tabItem {
                    Label("Storage", systemImage: "fan.fill")
                }
                .tag(Tab.storage)

            CoffeeBedsView()
                .tabItem {
                    Label("Beds", systemImage: "cup.and.saucer.fill")
                }
                .tag(Tab.beds)

            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: "chart.line.text.clipboard")
                }
                .badge(vm.unreadCount)
                .tag(Tab.activity)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .tint(AppTheme.caramel)
    }
}

#Preview {
    ContentView()
        .environmentObject(IoTSystemViewModel())
}

