//
//  SectionHeader.swift
//  CoffeeMo
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(AppTheme.mocha)
                    .font(.headline)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}
