//
//  IoTSystemViewModel.swift
//  CoffeeMo
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class IoTSystemViewModel: ObservableObject {

    // MARK: - Live sensor readings

    @Published var storageTemperatureC: Double = 24.0
    @Published var storageHumidity: Double = 58.0          // 0–100
    @Published var bedSoilMoisture: Double = 32.0          // 0–100
    @Published var outsideTemperatureC: Double = 21.0
    @Published var motionDetected: Bool = false
    @Published var lastMotionAt: Date? = nil

    // MARK: - Weather

    @Published var currentWeather: WeatherCondition = .partlyCloudy
    @Published var rainIntensity: Double = 0.0             // 0–100 mm/h proxy
    @Published var forecast: [ForecastDay] = []

    // MARK: - Actuator state

    @Published var fanMode: FanMode = .auto
    @Published var fanIsSpinning: Bool = false
    @Published var fanSpeed: Double = 0.0                  // 0–100 %
    @Published var coverState: CoverState = .retracted
    @Published var gateIsOpen: Bool = false

    // MARK: - Settings

    @Published var autoCoverEnabled: Bool = true
    @Published var autoFanEnabled: Bool = true
    @Published var pushNotificationsEnabled: Bool = true
    @Published var criticalAlertsEnabled: Bool = true
    @Published var dailyDigestEnabled: Bool = false
    @Published var temperatureThresholdC: Double = 28.0
    @Published var humidityThresholdPct: Double = 70.0

    // MARK: - Notifications

    @Published var alerts: [AlertItem] = []
    var unreadCount: Int { alerts.filter { !$0.isRead }.count }

    // MARK: - Supabase data

    @Published var recentReadings: [SensorReadingRow] = []
    @Published var coffeeBatches: [CoffeeBatchRow] = []
    @Published var actuatorEvents: [ActuatorEventRow] = []
    @Published var isLoadingSupabase: Bool = false
    @Published var isSupabaseConnected: Bool = false
    @Published var supabaseStatusMessage: String = "Connecting to Supabase..."
    @Published var lastSupabaseRefresh: Date? = nil

    // MARK: - Devices

    @Published var devices: [SensorDevice] = [
        SensorDevice(name: "DHT11 Temp/Humidity", location: "Storage Room",
                     systemImage: "thermometer.medium", isOnline: true, batteryLevel: nil),
        SensorDevice(name: "PIR Motion Sensor", location: "Storage Room",
                     systemImage: "figure.walk.motion", isOnline: true, batteryLevel: nil),
        SensorDevice(name: "Exhaust Fan A1", location: "Storage Room",
                     systemImage: "fan.fill", isOnline: true, batteryLevel: nil),
        SensorDevice(name: "Rain Sensor R-09", location: "Coffee Bed #1",
                     systemImage: "drop.fill", isOnline: true, batteryLevel: 82),
        SensorDevice(name: "Soil Moisture S-21", location: "Coffee Bed #2",
                     systemImage: "leaf.fill", isOnline: true, batteryLevel: 74),
        SensorDevice(name: "Retractable Cover", location: "Coffee Beds",
                     systemImage: "umbrella.fill", isOnline: true, batteryLevel: nil),
        SensorDevice(name: "Conservatory Gate", location: "Main Entrance",
                     systemImage: "door.left.hand.open", isOnline: true, batteryLevel: nil)
    ]

    // MARK: - Weather service

    @Published var isLoadingWeather: Bool = false
    @Published var weatherErrorMessage: String? = nil
    @Published var lastWeatherRefresh: Date? = nil

    private let weatherService: WeatherService
    private let supabaseService: SupabaseService
    private var tickTask: Task<Void, Never>?
    private var weatherTask: Task<Void, Never>?
    private var supabaseTask: Task<Void, Never>?

    init(
        weatherService: WeatherService = WeatherService(),
        supabaseService: SupabaseService = SupabaseService()
    ) {
        self.weatherService = weatherService
        self.supabaseService = supabaseService
        seedForecast()              // placeholder until first network response arrives
        seedInitialAlerts()
        start()
        startWeatherRefresh()
        startSupabaseRefresh()
    }

    deinit {
        tickTask?.cancel()
        weatherTask?.cancel()
        supabaseTask?.cancel()
    }

    // MARK: - Derived helpers

    var systemHealthSummary: String {
        if alerts.contains(where: { $0.severity == .critical && !$0.isRead }) {
            return "Attention Needed"
        }
        if alerts.contains(where: { $0.severity == .warning && !$0.isRead }) {
            return "Minor Warnings"
        }
        return "All Systems Nominal"
    }

    var systemHealthTint: Color {
        if alerts.contains(where: { $0.severity == .critical && !$0.isRead }) {
            return AppTheme.alertRed
        }
        if alerts.contains(where: { $0.severity == .warning && !$0.isRead }) {
            return AppTheme.warning
        }
        return AppTheme.leaf
    }

    var temperatureSeverity: AlertSeverity {
        switch storageTemperatureC {
        case ..<10:  return .warning
        case 28...32: return .warning
        case 32...:  return .critical
        default:     return .success
        }
    }

    var humiditySeverity: AlertSeverity {
        switch storageHumidity {
        case ..<30:  return .warning
        case 70...80: return .warning
        case 80...:  return .critical
        default:     return .success
        }
    }

    // MARK: - User actions

    func setFanMode(_ mode: FanMode) {
        fanMode = mode
        switch mode {
        case .on:
            fanIsSpinning = true
            fanSpeed = max(fanSpeed, 80)
        case .off:
            fanIsSpinning = false
            fanSpeed = 0
        case .auto:
            evaluateAutoFan()
        }
        pushAlert(title: "Fan Mode Changed",
                  message: "Storage fan set to \(mode.rawValue).",
                  severity: .info)
        sendActuatorCommand(actuatorId: "FAN-01", command: mode.rawValue.lowercased())
    }

    func toggleGate() {
        gateIsOpen.toggle()
        pushAlert(title: gateIsOpen ? "Gate Opened" : "Gate Closed",
                  message: "Conservatory gate is now \(gateIsOpen ? "open" : "closed").",
                  severity: .info)
    }

    func deployCover() {
        guard coverState != .deployed && !coverState.isMoving else { return }
        animateCover(to: .deployed)
        sendActuatorCommand(actuatorId: "COVER-01", command: "deployed")
    }

    func retractCover() {
        guard coverState != .retracted && !coverState.isMoving else { return }
        animateCover(to: .retracted)
        sendActuatorCommand(actuatorId: "COVER-01", command: "retracted")
    }

    func simulateRain() {
        currentWeather = .rainy
        withAnimation(.easeInOut(duration: 0.6)) {
            rainIntensity = Double.random(in: 35...85)
        }
        pushAlert(title: "Rain Detected",
                  message: String(format: "Rain sensor reading %.0f mm/h. Evaluating cover deployment.", rainIntensity),
                  severity: .warning)
        if autoCoverEnabled {
            deployCover()
        }
    }

    func clearRain() {
        withAnimation(.easeInOut(duration: 0.6)) {
            rainIntensity = 0
        }
        currentWeather = .partlyCloudy
        pushAlert(title: "Skies Clearing",
                  message: "Rain sensor returned to baseline.",
                  severity: .success)
        if autoCoverEnabled {
            retractCover()
        }
    }

    func markAllNotificationsRead() {
        for index in alerts.indices { alerts[index].isRead = true }
    }

    func clearAllNotifications() {
        alerts.removeAll()
    }

    func refreshSupabaseData() async {
        isLoadingSupabase = true
        defer { isLoadingSupabase = false }

        do {
            async let recent = supabaseService.fetchRecentReadings(days: 5)
            async let latest = supabaseService.fetchLatestReadings(limit: 60)
            async let batches = supabaseService.fetchCoffeeBatches()
            async let thresholds = supabaseService.fetchAlertThresholds()
            async let alertLogs = supabaseService.fetchAlertLogs()
            async let events = supabaseService.fetchActuatorEvents()

            let (recentRows, latestRows, batchRows, thresholdRows, alertRows, eventRows) =
                try await (recent, latest, batches, thresholds, alertLogs, events)

            withAnimation(.easeInOut(duration: 0.4)) {
                recentReadings = recentRows.sorted { $0.recordedAt < $1.recordedAt }
                coffeeBatches = batchRows
                actuatorEvents = eventRows
                applyLatestSensorRows(latestRows)
                applyCloudAlerts(alertRows, thresholds: thresholdRows)
                applyActuatorEvents(eventRows)
                isSupabaseConnected = true
                supabaseStatusMessage = "Live from Supabase"
                lastSupabaseRefresh = Date()
            }
        } catch {
            isSupabaseConnected = false
            supabaseStatusMessage = "Using local fallback data"
        }
    }

    // MARK: - Simulation engine

    private func start() {
        tickTask?.cancel()
        tickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                self?.tick()
            }
        }
    }

    private func startSupabaseRefresh() {
        supabaseTask?.cancel()
        supabaseTask = Task { @MainActor [weak self] in
            await self?.refreshSupabaseData()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                await self?.refreshSupabaseData()
            }
        }
    }

    // MARK: - Live weather (Open-Meteo, Kigali)

    /// Kicks off the recurring fetch loop: immediate refresh, then every 30 minutes.
    private func startWeatherRefresh() {
        weatherTask?.cancel()
        weatherTask = Task { @MainActor [weak self] in
            await self?.refreshWeather()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
                await self?.refreshWeather()
            }
        }
    }

    /// User-triggerable manual refresh (e.g. pull-to-refresh, or a retry button).
    func refreshWeather() async {
        isLoadingWeather = true
        weatherErrorMessage = nil
        do {
            let snapshot = try await weatherService.fetchSnapshot()
            withAnimation(.easeInOut(duration: 0.6)) {
                outsideTemperatureC = snapshot.currentTemperatureC
                // Only update displayed weather icon if rain isn't being simulated,
                // so the demo "Simulate Rain" override isn't immediately overwritten.
                if rainIntensity == 0 {
                    currentWeather = snapshot.currentCondition
                }
                forecast = snapshot.forecast
            }
            lastWeatherRefresh = Date()
        } catch {
            weatherErrorMessage = "Couldn't refresh weather. Check connection."
            pushAlert(title: "Weather Sync Failed",
                      message: "Live forecast unavailable. Showing cached data.",
                      severity: .warning)
        }
        isLoadingWeather = false
    }

    private func tick() {
        guard !isSupabaseConnected else {
            evaluateAutoFan()
            return
        }

        // Drift the indoor / soil sensors like real hardware. The outside
        // temperature is owned by the live weather feed, so we don't touch it.
        let tempDelta = Double.random(in: -0.4...0.4)
        let humDelta  = Double.random(in: -0.8...0.8)
        let moistDelta = Double.random(in: -0.5...0.5) + (rainIntensity > 0 ? 1.2 : -0.2)

        withAnimation(.easeInOut(duration: 0.6)) {
            storageTemperatureC = clamp(storageTemperatureC + tempDelta, min: 14, max: 36)
            storageHumidity     = clamp(storageHumidity + humDelta,      min: 20, max: 95)
            bedSoilMoisture     = clamp(bedSoilMoisture + moistDelta,    min: 5,  max: 95)
        }

        evaluateAutoFan()
        evaluateThresholdAlerts()
    }

    private func applyLatestSensorRows(_ rows: [SensorReadingRow]) {
        guard !rows.isEmpty else { return }

        if let dht = rows.first(where: { $0.sensorId.uppercased().contains("DHT") }) {
            if let temperature = dht.temperature {
                storageTemperatureC = temperature
            }
            if let humidity = dht.humidity {
                storageHumidity = humidity
            }
        }

        if let rain = rows.first(where: { $0.sensorId.uppercased().contains("RAIN") }),
           let value = rain.rainValue {
            rainIntensity = value
            if value > 0 {
                currentWeather = .rainy
                if autoCoverEnabled {
                    coverState = .deployed
                }
            }
        }

        if let moisture = rows.first(where: { $0.moisture != nil }),
           let value = moisture.moisture {
            bedSoilMoisture = value
        }

        if let motion = rows.first(where: { $0.sensorId.uppercased().contains("PIR") || $0.motionDetected != nil }) {
            motionDetected = motion.motionDetected ?? false
            if motionDetected {
                lastMotionAt = motion.recordedAt
            }
        }
    }

    private func applyCloudAlerts(_ alertRows: [AlertLogRow], thresholds: [AlertThresholdRow]) {
        guard !alertRows.isEmpty else { return }
        let thresholdById = Dictionary(uniqueKeysWithValues: thresholds.map { ($0.thresholdId, $0) })
        let cloudAlerts = alertRows.prefix(30).map { row -> AlertItem in
            let threshold = row.thresholdId.flatMap { thresholdById[$0] }
            let severity = severity(for: threshold?.alertLevel ?? 1)
            return AlertItem(
                title: threshold?.alertMessage ?? "System Alert",
                message: cloudAlertMessage(for: threshold, batchId: row.batchId),
                timestamp: row.triggeredAt,
                severity: severity,
                isRead: row.acknowledged
            )
        }
        alerts = cloudAlerts
    }

    private func applyActuatorEvents(_ rows: [ActuatorEventRow]) {
        guard let latestFan = rows.first(where: { $0.actuatorId.uppercased().contains("FAN") }) else {
            return
        }
        if latestFan.eventType.lowercased() == "on" {
            fanIsSpinning = true
            fanSpeed = max(fanSpeed, 80)
        } else if latestFan.eventType.lowercased() == "off" {
            fanIsSpinning = false
            fanSpeed = 0
        }

        if let latestCover = rows.first(where: { $0.actuatorId.uppercased().contains("COVER") }) {
            switch latestCover.eventType.lowercased() {
            case "deployed":
                coverState = .deployed
            case "retracted":
                coverState = .retracted
            default:
                break
            }
        }
    }

    private func cloudAlertMessage(for threshold: AlertThresholdRow?, batchId: String?) -> String {
        let parameter = threshold?.parameter.replacingOccurrences(of: "_", with: " ") ?? "sensor value"
        if let batchId {
            return "\(parameter.capitalized) breached its threshold for batch \(batchId)."
        }
        return "\(parameter.capitalized) breached its configured threshold."
    }

    private func severity(for level: Int) -> AlertSeverity {
        switch level {
        case 3...:
            return .critical
        case 2:
            return .warning
        default:
            return .info
        }
    }

    private func evaluateAutoFan() {
        guard fanMode == .auto else { return }
        let shouldRun = storageTemperatureC > temperatureThresholdC - 2 ||
                        storageHumidity > humidityThresholdPct - 5
        let targetSpeed: Double
        if shouldRun {
            let tempOver = max(0, storageTemperatureC - (temperatureThresholdC - 2)) * 10
            let humOver  = max(0, storageHumidity - (humidityThresholdPct - 5)) * 4
            targetSpeed = clamp(40 + tempOver + humOver, min: 0, max: 100)
        } else {
            targetSpeed = 0
        }
        withAnimation(.easeInOut(duration: 0.5)) {
            fanSpeed = targetSpeed
            fanIsSpinning = targetSpeed > 0
        }
    }

    private func evaluateThresholdAlerts() {
        // Only insert a new alert if the most recent alert isn't already the same kind,
        // so we don't spam the timeline on every tick.
        let latestTitle = alerts.first?.title
        if storageTemperatureC > temperatureThresholdC,
           latestTitle != "High Temperature" {
            pushAlert(title: "High Temperature",
                      message: String(format: "Storage at %.1f°C exceeds %.0f°C threshold.",
                                      storageTemperatureC, temperatureThresholdC),
                      severity: .critical)
        }
        if storageHumidity > humidityThresholdPct,
           latestTitle != "High Humidity" {
            pushAlert(title: "High Humidity",
                      message: String(format: "Storage humidity at %.0f%% exceeds %.0f%%.",
                                      storageHumidity, humidityThresholdPct),
                      severity: .warning)
        }
    }

    private func animateCover(to newState: CoverState) {
        let transitional: CoverState = newState == .deployed ? .deploying : .retracting
        withAnimation(.easeInOut(duration: 0.3)) {
            coverState = transitional
        }
        pushAlert(title: newState == .deployed ? "Deploying Cover" : "Retracting Cover",
                  message: "Automated motor engaged.",
                  severity: .info)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation(.easeInOut(duration: 0.4)) {
                coverState = newState
            }
            pushAlert(title: newState == .deployed ? "Cover Deployed" : "Cover Retracted",
                      message: newState == .deployed
                          ? "Coffee beans are now protected."
                          : "Beds exposed to sunlight again.",
                      severity: .success)
        }
    }

    private func sendActuatorCommand(actuatorId: String, command: String) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await supabaseService.sendActuatorCommand(actuatorId: actuatorId, command: command)
            } catch {
                pushAlert(title: "Command Sync Failed",
                          message: "Could not send \(actuatorId) command to hardware. Check Supabase or Wi-Fi.",
                          severity: .warning)
            }
        }
    }

    private func pushAlert(title: String, message: String, severity: AlertSeverity) {
        let item = AlertItem(title: title, message: message,
                             timestamp: Date(), severity: severity, isRead: false)
        alerts.insert(item, at: 0)
        if alerts.count > 60 { alerts = Array(alerts.prefix(60)) }
    }

    private func seedForecast() {
        forecast = [
            ForecastDay(day: "Today",  condition: .partlyCloudy, highC: 26, lowC: 17, rainChance: 20),
            ForecastDay(day: "Fri",    condition: .sunny,        highC: 28, lowC: 18, rainChance: 5),
            ForecastDay(day: "Sat",    condition: .rainy,        highC: 22, lowC: 16, rainChance: 80),
            ForecastDay(day: "Sun",    condition: .stormy,       highC: 20, lowC: 15, rainChance: 95),
            ForecastDay(day: "Mon",    condition: .cloudy,       highC: 24, lowC: 16, rainChance: 30),
            ForecastDay(day: "Tue",    condition: .partlyCloudy, highC: 27, lowC: 17, rainChance: 15),
            ForecastDay(day: "Wed",    condition: .sunny,        highC: 29, lowC: 19, rainChance: 0)
        ]
    }

    private func seedInitialAlerts() {
        alerts = [
            AlertItem(title: "System Online",
                      message: "CoffeeMo gateway connected and all sensors reporting.",
                      timestamp: Date().addingTimeInterval(-60 * 12),
                      severity: .success, isRead: false),
            AlertItem(title: "Daily Maintenance",
                      message: "Scheduled diagnostic completed successfully.",
                      timestamp: Date().addingTimeInterval(-60 * 45),
                      severity: .info, isRead: false),
            AlertItem(title: "Humidity Trending Up",
                      message: "Storage humidity rose 6% over the last hour.",
                      timestamp: Date().addingTimeInterval(-60 * 90),
                      severity: .warning, isRead: true)
        ]
    }

    private func clamp(_ value: Double, min lo: Double, max hi: Double) -> Double {
        Swift.min(Swift.max(value, lo), hi)
    }
}
