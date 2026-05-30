//
//  GaugeView.swift
//  CoffeeMo
//

import SwiftUI

struct CircularGauge: View {
    let value: Double             // current value
    let range: ClosedRange<Double>
    let label: String
    let unit: String
    let tint: Color
    var systemImage: String? = nil

    private var progress: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), style: StrokeStyle(lineWidth: 14, lineCap: .round))

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(colors: [tint.opacity(0.6), tint],
                                    center: .center),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)

            VStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                        .font(.title3)
                }
                Text(String(format: "%.1f", value))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
                Text(unit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 160, height: 160)
    }
}

struct LinearProgressGauge: View {
    let value: Double
    let range: ClosedRange<Double>
    let tint: Color

    private var progress: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(0.18))
                Capsule()
                    .fill(
                        LinearGradient(colors: [tint.opacity(0.7), tint],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * progress)
                    .animation(.easeInOut(duration: 0.5), value: progress)
            }
        }
        .frame(height: 12)
    }
}

#Preview {
    VStack(spacing: 20) {
        CircularGauge(value: 24.3, range: 10...40, label: "Temperature",
                      unit: "°C", tint: AppTheme.caramel,
                      systemImage: "thermometer.medium")
        LinearProgressGauge(value: 58, range: 0...100, tint: AppTheme.sky)
            .padding(.horizontal)
    }
    .padding()
    .background(AppTheme.backgroundGradient)
}
