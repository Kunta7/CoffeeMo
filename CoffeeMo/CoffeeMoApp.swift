//
//  CoffeeMoApp.swift
//  CoffeeMo
//
//  Created by MAC on 20.05.2026.
//

import SwiftUI

@main
struct CoffeeMoApp: App {
    @StateObject private var systemVM = IoTSystemViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(systemVM)
        }
    }
}
