//
//  StatCard.swift
//  CoffeeMo
//

import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String
    let tint: Color
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                Spacer()
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
                Text(unit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    HStack {
        StatCard(title: "Temperature", value: "24.3", unit: "°C",
                 systemImage: "thermometer.medium", tint: AppTheme.caramel,
                 caption: "Within range")
        StatCard(title: "Humidity", value: "58", unit: "%",
                 systemImage: "humidity.fill", tint: AppTheme.sky)
    }
    .padding()
    .background(AppTheme.backgroundGradient)
}
