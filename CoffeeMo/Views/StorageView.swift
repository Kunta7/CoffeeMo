//
//  StorageView.swift
//  CoffeeMo
//

import SwiftUI

struct StorageView: View {
    @EnvironmentObject private var vm: IoTSystemViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        cloudStatusCard
                        temperatureCard
                        humidityCard
                        motionSecurityCard
                        fanControlCard
                        thresholdInfoCard
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Storage Room")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Temperature

    private var cloudStatusCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(vm.isSupabaseConnected ? AppTheme.leaf : AppTheme.warning)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.supabaseStatusMessage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(vm.lastSupabaseRefresh.map { "Updated \($0.formatted(date: .omitted, time: .shortened))" } ?? "Waiting for cloud data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if vm.isLoadingSupabase {
                ProgressView()
            }
        }
        .cardStyle()
    }

    private var temperatureCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Temperature",
                              subtitle: "DHT11 Sensor · Live",
                              systemImage: "thermometer.medium")
                Spacer()
                StatusPill(severity: vm.temperatureSeverity)
            }

            HStack(spacing: 16) {
                CircularGauge(value: vm.storageTemperatureC,
                              range: 10...40,
                              label: "Temperature",
                              unit: "°C",
                              tint: vm.temperatureSeverity.tint,
                              systemImage: "thermometer.medium")
                VStack(alignment: .leading, spacing: 12) {
                    MetricRow(label: "Threshold",
                              value: String(format: "%.0f °C", vm.temperatureThresholdC),
                              tint: AppTheme.mocha)
                    MetricRow(label: "Outside",
                              value: String(format: "%.1f °C", vm.outsideTemperatureC),
                              tint: AppTheme.sky)
                    MetricRow(label: "Status",
                              value: vm.temperatureSeverity == .success ? "Normal" : "Alert",
                              tint: vm.temperatureSeverity.tint)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Humidity

    private var humidityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "Humidity",
                              subtitle: "DHT11 · Same sensor as temperature",
                              systemImage: "humidity.fill")
                Spacer()
                StatusPill(severity: vm.humiditySeverity)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.0f", vm.storageHumidity))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
                Text("%")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "Limit %.0f%%", vm.humidityThresholdPct))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LinearProgressGauge(value: vm.storageHumidity,
                                range: 0...100,
                                tint: vm.humiditySeverity.tint)

            HStack {
                Label("Dry", systemImage: "sun.max.fill")
                    .labelStyle(.titleAndIcon)
                Spacer()
                Label("Humid", systemImage: "cloud.fill")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    // MARK: - Fan control

    private var motionSecurityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(
                    title: "Storage Motion",
                    subtitle: "PIR sensor · Security",
                    systemImage: "figure.walk.motion"
                )
                Spacer()
                Text(vm.motionDetected ? "Detected" : "Clear")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((vm.motionDetected ? AppTheme.alertRed : AppTheme.leaf).opacity(0.16), in: Capsule())
                    .foregroundStyle(vm.motionDetected ? AppTheme.alertRed : AppTheme.leaf)
            }

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill((vm.motionDetected ? AppTheme.alertRed : AppTheme.leaf).opacity(0.15))
                        .frame(width: 58, height: 58)
                    Image(systemName: vm.motionDetected ? "figure.walk.motion" : "checkmark.shield.fill")
                        .font(.title2)
                        .foregroundStyle(vm.motionDetected ? AppTheme.alertRed : AppTheme.leaf)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.motionDetected ? "Movement inside storage room" : "No movement detected")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(vm.lastMotionAt.map { "Last detected \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "Awaiting first PIR reading from Supabase")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .cardStyle()
    }

    private var fanControlCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Exhaust Fan",
                          subtitle: vm.fanIsSpinning
                            ? String(format: "Running · %.0f%% speed", vm.fanSpeed)
                            : "Idle",
                          systemImage: "fan.fill")

            HStack(spacing: 18) {
                SpinningFan(isSpinning: vm.fanIsSpinning,
                            speed: vm.fanSpeed,
                            tint: AppTheme.leaf)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Mode")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Fan Mode", selection: Binding(
                        get: { vm.fanMode },
                        set: { vm.setFanMode($0) }
                    )) {
                        ForEach(FanMode.allCases) { mode in
                            Label(mode.rawValue, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(vm.fanIsSpinning ? AppTheme.leaf : .gray.opacity(0.4))
                            .frame(width: 8, height: 8)
                        Text(vm.fanIsSpinning ? "Active" : "Standby")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Fan Speed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LinearProgressGauge(value: vm.fanSpeed, range: 0...100, tint: AppTheme.leaf)
                Text(String(format: "%.0f%%", vm.fanSpeed))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .cardStyle()
    }

    // MARK: - Threshold info

    private var thresholdInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Auto-Fan Logic",
                          subtitle: "Trigger conditions",
                          systemImage: "wand.and.stars")

            Text("In Auto mode the fan activates when storage temperature exceeds \(Int(vm.temperatureThresholdC - 2))°C or humidity rises above \(Int(vm.humidityThresholdPct - 5))%. Adjust thresholds from Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }
}

// MARK: - Helpers

private struct StatusPill: View {
    let severity: AlertSeverity
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: severity.systemImage)
            Text(severity == .success ? "Normal" :
                 severity == .info ? "Info" :
                 severity == .warning ? "Warning" : "Critical")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(severity.tint.opacity(0.15), in: Capsule())
        .foregroundStyle(severity.tint)
    }
}

private struct MetricRow: View {
    let label: String
    let value: String
    let tint: Color
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
    }
}

#Preview {
    StorageView()
        .environmentObject(IoTSystemViewModel())
}
