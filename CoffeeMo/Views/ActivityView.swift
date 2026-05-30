//
//  ActivityView.swift
//  CoffeeMo
//

import Charts
import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var vm: IoTSystemViewModel
    @State private var selectedSegment: Segment = .alerts
    @State private var selectedMetric: HistoryMetric = .temperature

    enum Segment: String, CaseIterable, Identifiable {
        case alerts  = "Alerts"
        case history = "History"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()
                VStack(spacing: 12) {
                    segmentPicker
                        .padding(.horizontal)
                        .padding(.top, 4)

                    Group {
                        switch selectedSegment {
                        case .alerts:  alertsSection
                        case .history: historySection
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if selectedSegment == .alerts {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                vm.markAllNotificationsRead()
                            } label: {
                                Label("Mark All as Read", systemImage: "checkmark.circle")
                            }
                            Button(role: .destructive) {
                                vm.clearAllNotifications()
                            } label: {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Segment picker

    private var segmentPicker: some View {
        Picker("Section", selection: $selectedSegment.animation(.easeInOut(duration: 0.2))) {
            ForEach(Segment.allCases) { segment in
                Text(segment.rawValue).tag(segment)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Alerts section

    private var alertsSection: some View {
        Group {
            if vm.alerts.isEmpty {
                alertsEmptyState
            } else {
                alertsList
            }
        }
    }

    private var alertsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(vm.alerts) { alert in
                    AlertRow(alert: alert)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
    }

    private var alertsEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.caramel.opacity(0.6))
            Text("All Clear")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.primaryText)
            Text("No notifications right now.\nWe'll alert you when anything changes.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - History section

    private var historySection: some View {
        ScrollView {
            VStack(spacing: 18) {
                statusCard
                metricPicker
                chartCard
                batchCard
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .refreshable {
            await vm.refreshSupabaseData()
        }
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(vm.isSupabaseConnected ? AppTheme.leaf : AppTheme.warning)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.supabaseStatusMessage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                if let refresh = vm.lastSupabaseRefresh {
                    Text("Last refresh \(refresh.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Pull down to retry if no data appears.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if vm.isLoadingSupabase {
                ProgressView()
            }
        }
        .cardStyle()
    }

    private var metricPicker: some View {
        Picker("Metric", selection: $selectedMetric) {
            ForEach(HistoryMetric.allCases) { metric in
                Label(metric.title, systemImage: metric.systemImage).tag(metric)
            }
        }
        .pickerStyle(.segmented)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "\(selectedMetric.title) · Last 5 Days",
                subtitle: "\(chartRows.count) readings",
                systemImage: selectedMetric.systemImage
            )

            if chartRows.isEmpty {
                ContentUnavailableView(
                    "No \(selectedMetric.title.lowercased()) history yet",
                    systemImage: selectedMetric.systemImage,
                    description: Text("Once the ESP8266 posts readings, this chart will fill automatically.")
                )
                .frame(minHeight: 220)
            } else {
                Chart(chartRows) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value(selectedMetric.title, point.value)
                    )
                    .foregroundStyle(selectedMetric.tint)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time", point.date),
                        y: .value(selectedMetric.title, point.value)
                    )
                    .foregroundStyle(selectedMetric.tint.opacity(0.16))
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxisLabel(selectedMetric.unit)
                .frame(height: 240)
            }
        }
        .cardStyle()
    }

    private var batchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Coffee Batches",
                subtitle: "Cloud traceability records",
                systemImage: "shippingbox.fill"
            )

            if vm.coffeeBatches.isEmpty {
                Text("No batches found in Supabase yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(vm.coffeeBatches.prefix(5)) { batch in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(batch.batchCode)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.primaryText)
                            Spacer()
                            Text(batch.currentStage.capitalized)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.leaf.opacity(0.16), in: Capsule())
                                .foregroundStyle(AppTheme.leaf)
                        }
                        HStack {
                            Text(batch.location ?? "No location")
                            Spacer()
                            if let moisture = batch.moistureContent {
                                Text(String(format: "%.1f%% moisture", moisture))
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    if batch.id != vm.coffeeBatches.prefix(5).last?.id {
                        Divider().opacity(0.4)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var chartRows: [HistoryPoint] {
        vm.recentReadings.compactMap { row in
            guard let value = selectedMetric.value(from: row) else { return nil }
            return HistoryPoint(date: row.recordedAt, value: value)
        }
    }
}

// MARK: - Alert row

private struct AlertRow: View {
    let alert: AlertItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(alert.severity.tint.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: alert.severity.systemImage)
                    .foregroundStyle(alert.severity.tint)
                    .font(.subheadline.weight(.bold))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(alert.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.primaryText)
                    if !alert.isRead {
                        Circle()
                            .fill(AppTheme.alertRed)
                            .frame(width: 7, height: 7)
                    }
                    Spacer()
                    Text(alert.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(alert.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.cardBackground.opacity(alert.isRead ? 0.75 : 1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(alert.severity.tint.opacity(alert.isRead ? 0.1 : 0.3), lineWidth: 1)
        )
    }
}

// MARK: - History metric

private enum HistoryMetric: String, CaseIterable, Identifiable {
    case temperature
    case humidity
    case moisture
    case rain
    case motion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .temperature: return "Temperature"
        case .humidity: return "Humidity"
        case .moisture: return "Moisture"
        case .rain: return "Rain"
        case .motion: return "Motion"
        }
    }

    var unit: String {
        switch self {
        case .temperature: return "°C"
        case .humidity, .moisture, .rain: return "%"
        case .motion: return "0 = none, 1 = detected"
        }
    }

    var systemImage: String {
        switch self {
        case .temperature: return "thermometer.medium"
        case .humidity: return "humidity.fill"
        case .moisture: return "leaf.fill"
        case .rain: return "cloud.rain.fill"
        case .motion: return "figure.walk.motion"
        }
    }

    var tint: Color {
        switch self {
        case .temperature: return AppTheme.caramel
        case .humidity: return AppTheme.sky
        case .moisture: return AppTheme.leaf
        case .rain: return AppTheme.rain
        case .motion: return AppTheme.alertRed
        }
    }

    func value(from row: SensorReadingRow) -> Double? {
        switch self {
        case .temperature: return row.temperature
        case .humidity:    return row.humidity
        case .moisture:    return row.moisture
        case .rain:        return row.rainValue
        case .motion:
            guard let motionDetected = row.motionDetected else { return nil }
            return motionDetected ? 1 : 0
        }
    }
}

private struct HistoryPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

#Preview {
    ActivityView()
        .environmentObject(IoTSystemViewModel())
}
