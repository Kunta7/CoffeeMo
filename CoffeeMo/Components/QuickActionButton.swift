//
//  QuickActionButton.swift
//  CoffeeMo
//

import SwiftUI

struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(isActive ? 0.9 : 0.18))
                        .frame(width: 46, height: 46)
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isActive ? Color.white : tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint.opacity(isActive ? 0.6 : 0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        QuickActionButton(title: "Gate", subtitle: "Closed",
                          systemImage: "door.left.hand.open",
                          tint: AppTheme.caramel) {}
        QuickActionButton(title: "Cover", subtitle: "Deployed",
                          systemImage: "umbrella.fill",
                          tint: AppTheme.rain, isActive: true) {}
    }
    .padding()
    .background(AppTheme.backgroundGradient)
}
