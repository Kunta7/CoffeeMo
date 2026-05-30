//
//  HomeView.swift
//  CoffeeMo
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var vm: IoTSystemViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        weatherHero
                        statusSummary
                        quickStats
                        quickActions
                        recentActivity
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("CoffeeMo")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Hero weather card

    private var weatherHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppTheme.heroGradient)
                .shadow(color: AppTheme.shadowColor.opacity(0.25), radius: 16, y: 8)

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Conservatory")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(vm.currentWeather.rawValue)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text(String(format: "%.0f°C outside", vm.outsideTemperatureC))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))

                    HStack(spacing: 14) {
                        HeroMetric(systemImage: "drop.fill",
                                   value: String(format: "%.0f%%", vm.bedSoilMoisture),
                                   label: "Soil")
                        HeroMetric(systemImage: "cloud.rain.fill",
                                   value: String(format: "%.0f mm/h", vm.rainIntensity),
                                   label: "Rain")
                    }
                    .padding(.top, 6)
                }

                Spacer()

                Image(systemName: vm.currentWeather.systemImage)
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 4)
            }
            .padding(22)
        }
        .frame(height: 180)
    }

    // MARK: - Status banner

    private var statusSummary: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(vm.systemHealthTint.opacity(0.18))
                    .frame(width: 46, height: 46)
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(vm.systemHealthTint)
                    .font(.title3)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("System Status")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(vm.systemHealthSummary)
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryText)
            }
            Spacer()
            if vm.unreadCount > 0 {
                Text("\(vm.unreadCount) new")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(vm.systemHealthTint.opacity(0.2), in: Capsule())
                    .foregroundStyle(vm.systemHealthTint)
            }
        }
        .cardStyle()
    }

    // MARK: - Quick stats

    private var quickStats: some View {
        HStack(spacing: 12) {
            StatCard(title: "Storage Temp",
                     value: String(format: "%.1f", vm.storageTemperatureC),
                     unit: "°C",
                     systemImage: "thermometer.medium",
                     tint: vm.temperatureSeverity.tint,
                     caption: vm.temperatureSeverity == .success ? "Optimal" : "Watch")
            StatCard(title: "Storage Humidity",
                     value: String(format: "%.0f", vm.storageHumidity),
                     unit: "%",
                     systemImage: "humidity.fill",
                     tint: vm.humiditySeverity.tint,
                     caption: vm.humiditySeverity == .success ? "Optimal" : "Watch")
        }
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick Actions",
                          subtitle: "Tap to control your system",
                          systemImage: "bolt.fill")

            QuickActionButton(title: "Conservatory Gate",
                              subtitle: vm.gateIsOpen ? "Currently open" : "Currently closed",
                              systemImage: vm.gateIsOpen ? "door.left.hand.open" : "door.left.hand.closed",
                              tint: AppTheme.caramel,
                              isActive: vm.gateIsOpen) {
                vm.toggleGate()
            }

            QuickActionButton(title: "Protective Cover",
                              subtitle: vm.coverState.description,
                              systemImage: vm.coverState.systemImage,
                              tint: AppTheme.rain,
                              isActive: vm.coverState == .deployed) {
                if vm.coverState == .deployed {
                    vm.retractCover()
                } else {
                    vm.deployCover()
                }
            }

            QuickActionButton(title: "Storage Fan",
                              subtitle: vm.fanIsSpinning
                                  ? String(format: "Running · %.0f%%", vm.fanSpeed)
                                  : "Idle",
                              systemImage: "fan.fill",
                              tint: AppTheme.leaf,
                              isActive: vm.fanIsSpinning) {
                vm.setFanMode(vm.fanIsSpinning ? .off : .on)
            }
        }
    }

    // MARK: - Recent activity

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Activity",
                          subtitle: "Latest system events",
                          systemImage: "clock.fill")

            VStack(spacing: 10) {
                ForEach(vm.alerts.prefix(3)) { alert in
                    HStack(spacing: 12) {
                        Image(systemName: alert.severity.systemImage)
                            .foregroundStyle(alert.severity.tint)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)
                            Text(alert.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text(alert.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                    if alert.id != vm.alerts.prefix(3).last?.id {
                        Divider().opacity(0.4)
                    }
                }
                if vm.alerts.isEmpty {
                    Text("No activity yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                }
            }
            .cardStyle()
        }
    }
}

private struct HeroMetric: View {
    let systemImage: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.caption.weight(.bold))
                Text(label)
                    .font(.system(size: 9))
                    .opacity(0.8)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.18), in: Capsule())
    }
}

#Preview {
    HomeView()
        .environmentObject(IoTSystemViewModel())
}
