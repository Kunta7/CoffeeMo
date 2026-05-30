//
//  AppTheme.swift
//  CoffeeMo
//

import SwiftUI
import UIKit

enum AppTheme {
    // Brand accents (same in both modes)
    static let espresso   = Color(red: 0.22, green: 0.13, blue: 0.09)
    static let mocha      = Color(red: 0.36, green: 0.22, blue: 0.15)
    static let caramel    = Color(red: 0.78, green: 0.55, blue: 0.32)
    static let cream      = Color(red: 0.97, green: 0.93, blue: 0.86)
    static let latte      = Color(red: 0.92, green: 0.86, blue: 0.74)
    static let leaf       = Color(red: 0.36, green: 0.62, blue: 0.42)
    static let sky        = Color(red: 0.36, green: 0.66, blue: 0.85)
    static let rain       = Color(red: 0.28, green: 0.48, blue: 0.76)
    static let alertRed   = Color(red: 0.86, green: 0.30, blue: 0.30)
    static let warning    = Color(red: 0.95, green: 0.66, blue: 0.20)

    // Adaptive — follow the phone's light / dark setting
    static let primaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.95, alpha: 1)
            : UIColor(red: 0.22, green: 0.13, blue: 0.09, alpha: 1)
    })

    static let secondaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.65, alpha: 1)
            : UIColor(white: 0.45, alpha: 1)
    })

    static let cardBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1)
            : UIColor(white: 1.0, alpha: 0.95)
    })

    static let cardBorder = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.28, alpha: 1)
            : UIColor(white: 1.0, alpha: 0.6)
    })

    static let screenBackgroundTop = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.black
            : UIColor(red: 0.99, green: 0.96, blue: 0.91, alpha: 1)
    })

    static let screenBackgroundBottom = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1)
            : UIColor(red: 0.94, green: 0.88, blue: 0.78, alpha: 1)
    })

    static let backgroundGradient = LinearGradient(
        colors: [screenBackgroundTop, screenBackgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [mocha, espresso],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let shadowColor = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.black
            : UIColor(red: 0.22, green: 0.13, blue: 0.09, alpha: 1)
    })
}

// Convenience modifier for the soft card style used everywhere.
struct CardStyle: ViewModifier {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.cardBackground)
                    .shadow(color: AppTheme.shadowColor.opacity(0.12),
                            radius: 12, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle(padding: CGFloat = 16, cornerRadius: CGFloat = 20) -> some View {
        modifier(CardStyle(padding: padding, cornerRadius: cornerRadius))
    }
}
