//
//  Models.swift
//  CoffeeMo
//

import Foundation
import SwiftUI

// MARK: - Fan & Cover Modes

enum FanMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case on   = "On"
    case off  = "Off"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .auto: return "gearshape.2.fill"
        case .on:   return "fan.fill"
        case .off:  return "power"
        }
    }
}

enum CoverState: String {
    case retracted = "Retracted"
    case deploying = "Deploying"
    case deployed  = "Deployed"
    case retracting = "Retracting"

    var description: String { rawValue }

    var isMoving: Bool { self == .deploying || self == .retracting }

    var systemImage: String {
        switch self {
        case .retracted:  return "arrow.up.and.down.righttriangle.up.righttriangle.down"
        case .deploying:  return "arrow.down.to.line"
        case .deployed:   return "umbrella.fill"
        case .retracting: return "arrow.up.to.line"
        }
    }

    var tint: Color {
        switch self {
        case .retracted:                 return AppTheme.caramel
        case .deploying, .retracting:    return AppTheme.warning
        case .deployed:                  return AppTheme.rain
        }
    }
}

// MARK: - Weather

enum WeatherCondition: String, CaseIterable {
    case sunny       = "Sunny"
    case partlyCloudy = "Partly Cloudy"
    case cloudy      = "Cloudy"
    case rainy       = "Rainy"
    case stormy      = "Stormy"

    var systemImage: String {
        switch self {
        case .sunny:        return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy:       return "cloud.fill"
        case .rainy:        return "cloud.rain.fill"
        case .stormy:       return "cloud.bolt.rain.fill"
        }
    }

    var tint: Color {
        switch self {
        case .sunny:        return .orange
        case .partlyCloudy: return AppTheme.sky
        case .cloudy:       return .gray
        case .rainy:        return AppTheme.rain
        case .stormy:       return .purple
        }
    }
}

struct ForecastDay: Identifiable, Hashable {
    let id = UUID()
    let day: String
    let condition: WeatherCondition
    let highC: Int
    let lowC: Int
    let rainChance: Int
}

// MARK: - Notifications

enum AlertSeverity: String {
    case info, warning, critical, success

    var tint: Color {
        switch self {
        case .info:     return AppTheme.sky
        case .warning:  return AppTheme.warning
        case .critical: return AppTheme.alertRed
        case .success:  return AppTheme.leaf
        }
    }

    var systemImage: String {
        switch self {
        case .info:     return "info.circle.fill"
        case .warning:  return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        case .success:  return "checkmark.seal.fill"
        }
    }
}

struct AlertItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let message: String
    let timestamp: Date
    let severity: AlertSeverity
    var isRead: Bool = false
}

// MARK: - Sensor / Device

struct SensorDevice: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let location: String
    let systemImage: String
    let isOnline: Bool
    let batteryLevel: Int?
}
