//
//  SettingsView.swift
//  CoffeeMo
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var vm: IoTSystemViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        automationCard
                        notificationsCard
                        thresholdsCard
                        devicesCard
                        systemInfoCard
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Automation

    private var automationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Automation",
                          subtitle: "Hands-off control",
                          systemImage: "wand.and.stars")

            VStack(spacing: 0) {
                Toggle(isOn: $vm.autoCoverEnabled) {
                    SettingsRowLabel(icon: "umbrella.fill",
                                     tint: AppTheme.rain,
                                     title: "Auto Cover Deployment",
                                     subtitle: "Deploy cover when rain detected")
                }
                Divider().padding(.leading, 56)
                Toggle(isOn: $vm.autoFanEnabled) {
                    SettingsRowLabel(icon: "fan.fill",
                                     tint: AppTheme.leaf,
                                     title: "Auto Fan",
                                     subtitle: "Use threshold-based ventilation")
                }
            }
            .tint(AppTheme.leaf)
            .cardStyle(padding: 12)
        }
    }

    // MARK: - Notifications

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Notifications",
                          subtitle: "Stay informed",
                          systemImage: "bell.fill")

            VStack(spacing: 0) {
                Toggle(isOn: $vm.pushNotificationsEnabled) {
                    SettingsRowLabel(icon: "bell.badge.fill",
                                     tint: AppTheme.caramel,
                                     title: "Push Notifications",
                                     subtitle: "All system events")
                }
                Divider().padding(.leading, 56)
                Toggle(isOn: $vm.criticalAlertsEnabled) {
                    SettingsRowLabel(icon: "exclamationmark.octagon.fill",
                                     tint: AppTheme.alertRed,
                                     title: "Critical Alerts",
                                     subtitle: "Bypass Do Not Disturb")
                }
                Divider().padding(.leading, 56)
                Toggle(isOn: $vm.dailyDigestEnabled) {
                    SettingsRowLabel(icon: "calendar.badge.clock",
                                     tint: AppTheme.sky,
                                     title: "Daily Digest",
                                     subtitle: "Summary at 8 AM")
                }
            }
            .tint(AppTheme.leaf)
            .cardStyle(padding: 12)
        }
    }

    // MARK: - Thresholds

    private var thresholdsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Sensor Thresholds",
                          subtitle: "Trigger automated responses",
                          systemImage: "slider.horizontal.3")

            VStack(alignment: .leading, spacing: 16) {
                ThresholdSlider(
                    title: "Temperature Limit",
                    value: $vm.temperatureThresholdC,
                    range: 20...35,
                    unit: "°C",
                    tint: AppTheme.caramel,
                    icon: "thermometer.medium"
                )
                ThresholdSlider(
                    title: "Humidity Limit",
                    value: $vm.humidityThresholdPct,
                    range: 40...90,
                    unit: "%",
                    tint: AppTheme.sky,
                    icon: "humidity.fill"
                )
            }
            .cardStyle()
        }
    }

    // MARK: - Devices

    private var devicesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Connected Sensors",
                          subtitle: "\(vm.devices.filter(\.isOnline).count) of \(vm.devices.count) online",
                          systemImage: "antenna.radiowaves.left.and.right")

            VStack(spacing: 10) {
                ForEach(vm.devices) { device in
                    DeviceRow(device: device)
                    if device.id != vm.devices.last?.id {
                        Divider().opacity(0.4)
                    }
                }
            }
            .cardStyle()
        }
    }

    // MARK: - System info

    private var systemInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "System Information",
                          systemImage: "info.circle.fill")

            VStack(spacing: 0) {
                InfoRow(label: "App Version", value: "1.0.0")
                Divider()
                InfoRow(label: "Firmware", value: "v3.2.1")
                Divider()
                InfoRow(label: "Gateway", value: "CoffeeMo Hub")
                Divider()
                InfoRow(label: "Last Sync", value: Date(), style: .time)
            }
            .cardStyle(padding: 12)
        }
    }
}

// MARK: - Row helpers

private struct SettingsRowLabel: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tint.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .font(.subheadline.weight(.semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct ThresholdSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    let tint: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text(String(format: "%.0f %@", value, unit))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
            }
            Slider(value: $value, in: range)
                .tint(tint)
        }
    }
}

private struct DeviceRow: View {
    let device: SensorDevice
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.latte.opacity(0.5))
                    .frame(width: 36, height: 36)
                Image(systemName: device.systemImage)
                    .foregroundStyle(AppTheme.mocha)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(device.location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(device.isOnline ? AppTheme.leaf : .gray)
                        .frame(width: 7, height: 7)
                    Text(device.isOnline ? "Online" : "Offline")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(device.isOnline ? AppTheme.leaf : .gray)
                }
                if let battery = device.batteryLevel {
                    HStack(spacing: 3) {
                        Image(systemName: "battery.75")
                            .font(.caption2)
                        Text("\(battery)%")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct InfoRow: View {
    enum Style { case text, time }
    let label: String
    var value: Any
    var style: Style = .text

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            switch style {
            case .text:
                Text("\(value as? String ?? "")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            case .time:
                if let date = value as? Date {
                    Text(date, style: .time)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
    }
}

#Preview {
    SettingsView()
        .environmentObject(IoTSystemViewModel())
}
