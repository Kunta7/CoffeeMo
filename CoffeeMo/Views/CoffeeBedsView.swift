//
//  CoffeeBedsView.swift
//  CoffeeMo
//

import SwiftUI

struct CoffeeBedsView: View {
    @EnvironmentObject private var vm: IoTSystemViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        forecastCard
                        rainSensorCard
                        coverControlCard
                        soilMoistureCard
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                }
                .refreshable {
                    await vm.refreshWeather()
                }
            }
            .navigationTitle("Coffee Beds")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Forecast

    private var forecastCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "7-Day Forecast",
                              subtitle: forecastSubtitle,
                              systemImage: "calendar")
                Spacer()
                Button {
                    Task { await vm.refreshWeather() }
                } label: {
                    if vm.isLoadingWeather {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(AppTheme.sky)
                    }
                }
                .disabled(vm.isLoadingWeather)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vm.forecast) { day in
                        ForecastTile(day: day)
                    }
                }
            }

            if let message = vm.weatherErrorMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.warning)
            }
        }
        .cardStyle()
    }

    private var forecastSubtitle: String {
        if let stamp = vm.lastWeatherRefresh {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return "Kigali · Live · Updated \(formatter.string(from: stamp))"
        }
        if vm.isLoadingWeather {
            return "Kigali · Fetching live data…"
        }
        return "Kigali · Live forecast"
    }

    // MARK: - Rain sensor

    private var rainSensorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Rain Sensor",
                              subtitle: vm.rainIntensity > 0 ? "Rain detected" : "Dry",
                              systemImage: "cloud.rain.fill")
                Spacer()
                Circle()
                    .fill(vm.rainIntensity > 0 ? AppTheme.rain : AppTheme.leaf)
                    .frame(width: 10, height: 10)
            }

            HStack(spacing: 16) {
                CircularGauge(value: vm.rainIntensity,
                              range: 0...100,
                              label: "Intensity",
                              unit: "mm/h",
                              tint: AppTheme.rain,
                              systemImage: "drop.fill")

                VStack(alignment: .leading, spacing: 12) {
                    MetricRowSmall(label: "Status",
                                   value: vm.rainIntensity > 0 ? "Raining" : "No Rain")
                    MetricRowSmall(label: "Cover",
                                   value: vm.coverState.description)
                    MetricRowSmall(label: "Auto-Cover",
                                   value: vm.autoCoverEnabled ? "Enabled" : "Disabled")
                }
            }

            HStack(spacing: 10) {
                Button {
                    vm.simulateRain()
                } label: {
                    Label("Simulate Rain", systemImage: "cloud.heavyrain.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.rain, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }

                Button {
                    vm.clearRain()
                } label: {
                    Label("Clear", systemImage: "sun.max.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.caramel.opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(AppTheme.mocha)
                }
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
    }

    // MARK: - Cover control

    private var coverControlCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Protective Cover",
                          subtitle: "Automated retractable shield",
                          systemImage: "umbrella.fill")

            // Animated cover illustration
            CoverIllustration(state: vm.coverState)
                .frame(height: 120)
                .frame(maxWidth: .infinity)

            HStack {
                Text(vm.coverState.description)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(vm.coverState.tint)
                Spacer()
                if vm.coverState.isMoving {
                    ProgressView().scaleEffect(0.8)
                }
            }

            HStack(spacing: 10) {
                Button {
                    vm.deployCover()
                } label: {
                    Label("Deploy", systemImage: "arrow.down.to.line")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.rain, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                        .opacity(vm.coverState == .deployed || vm.coverState.isMoving ? 0.5 : 1)
                }
                .disabled(vm.coverState == .deployed || vm.coverState.isMoving)

                Button {
                    vm.retractCover()
                } label: {
                    Label("Retract", systemImage: "arrow.up.to.line")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.caramel, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                        .opacity(vm.coverState == .retracted || vm.coverState.isMoving ? 0.5 : 1)
                }
                .disabled(vm.coverState == .retracted || vm.coverState.isMoving)
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
    }

    // MARK: - Soil moisture

    private var soilMoistureCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Soil Moisture",
                          subtitle: "Coffee bed water sensor",
                          systemImage: "leaf.fill")

            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.0f", vm.bedSoilMoisture))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
                Text("%")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "drop.fill")
                    .foregroundStyle(AppTheme.rain)
                    .font(.title)
            }

            LinearProgressGauge(value: vm.bedSoilMoisture,
                                range: 0...100,
                                tint: AppTheme.leaf)

            HStack {
                Text("Dry")
                Spacer()
                Text("Moist")
                Spacer()
                Text("Saturated")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .cardStyle()
    }
}

// MARK: - Forecast tile

private struct ForecastTile: View {
    let day: ForecastDay
    var body: some View {
        VStack(spacing: 8) {
            Text(day.day)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Image(systemName: day.condition.systemImage)
                .symbolRenderingMode(.multicolor)
                .font(.title)
                .foregroundStyle(day.condition.tint)
                .frame(height: 36)
            Text("\(day.highC)°")
                .font(.headline)
                .foregroundStyle(AppTheme.primaryText)
            Text("\(day.lowC)°")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                Image(systemName: "drop.fill")
                Text("\(day.rainChance)%")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.rain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .frame(width: 76)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.latte.opacity(0.7), lineWidth: 1)
        )
    }
}

// MARK: - Animated cover illustration

private struct CoverIllustration: View {
    let state: CoverState

    private var coverOffset: CGFloat {
        switch state {
        case .retracted:  return -90
        case .deploying:  return -45
        case .deployed:   return 0
        case .retracting: return -45
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Coffee beds
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.mocha.opacity(0.85))
                            .frame(height: 24)
                            .overlay(
                                HStack(spacing: 3) {
                                    ForEach(0..<3, id: \.self) { _ in
                                        Circle()
                                            .fill(AppTheme.cream)
                                            .frame(width: 4, height: 4)
                                    }
                                }
                            )
                    }
                }
                .padding(.horizontal, 20)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 8)

                // Roof / posts
                HStack {
                    Rectangle().fill(AppTheme.espresso).frame(width: 4)
                    Spacer()
                    Rectangle().fill(AppTheme.espresso).frame(width: 4)
                }
                .padding(.horizontal, 12)

                // Sliding cover
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(colors: [AppTheme.rain.opacity(0.9),
                                                AppTheme.rain.opacity(0.6)],
                                       startPoint: .leading,
                                       endPoint: .trailing)
                    )
                    .frame(width: geo.size.width - 30, height: 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.white.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 3)
                    .offset(y: 26)
                    .offset(x: coverOffset)
                    .animation(.easeInOut(duration: 1.8), value: coverOffset)

                // Sun / rain
                if state == .retracted {
                    Image(systemName: "sun.max.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                        .position(x: geo.size.width - 30, y: 14)
                } else if state == .deployed {
                    Image(systemName: "cloud.rain.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.rain)
                        .position(x: geo.size.width - 30, y: 14)
                }
            }
        }
    }
}

private struct MetricRowSmall: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
        }
    }
}

#Preview {
    CoffeeBedsView()
        .environmentObject(IoTSystemViewModel())
}
