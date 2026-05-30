//
//  FanAnimation.swift
//  CoffeeMo
//

import SwiftUI

struct SpinningFan: View {
    let isSpinning: Bool
    let speed: Double          // 0–100
    let tint: Color

    @State private var rotation: Double = 0

    private var rpm: Double {
        // Map speed 0–100 to one rotation every 0.4s–4s.
        guard speed > 1 else { return 0 }
        return max(0.4, 4.0 - (speed / 100.0) * 3.6)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 110, height: 110)
            Image(systemName: "fan.fill")
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(tint)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear { restart() }
        .onChange(of: isSpinning) { _, _ in restart() }
        .onChange(of: speed) { _, _ in restart() }
    }

    private func restart() {
        rotation = 0
        guard isSpinning, rpm > 0 else { return }
        withAnimation(.linear(duration: rpm).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
}
