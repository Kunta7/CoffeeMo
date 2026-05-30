//
//  WeatherService.swift
//  CoffeeMo
//
//  Fetches live weather + 7-day forecast from Open-Meteo (free, no API key).
//  Defaults to Kigali, Rwanda.
//

import Foundation

struct WeatherSnapshot {
    let currentTemperatureC: Double
    let currentCondition: WeatherCondition
    let forecast: [ForecastDay]
}

enum WeatherServiceError: Error {
    case invalidURL
    case invalidResponse
    case decoding(Error)
}

actor WeatherService {

    // Coordinates: Kigali, Rwanda. Override per-site if needed.
    let latitude: Double
    let longitude: Double

    init(latitude: Double = -1.9536, longitude: Double = 30.0606) {
        self.latitude = latitude
        self.longitude = longitude
    }

    func fetchSnapshot() async throws -> WeatherSnapshot {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude",  value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current",   value: "temperature_2m,weather_code"),
            URLQueryItem(name: "daily",
                         value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
            URLQueryItem(name: "forecast_days", value: "7"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        guard let url = components.url else { throw WeatherServiceError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw WeatherServiceError.invalidResponse
        }

        do {
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            return WeatherSnapshot(
                currentTemperatureC: decoded.current.temperature_2m,
                currentCondition: Self.condition(from: decoded.current.weather_code),
                forecast: Self.buildForecast(from: decoded.daily)
            )
        } catch {
            throw WeatherServiceError.decoding(error)
        }
    }

    // MARK: - Mapping helpers

    /// WMO weather interpretation codes:
    /// https://open-meteo.com/en/docs (search "weather code")
    static func condition(from code: Int) -> WeatherCondition {
        switch code {
        case 0:                    return .sunny
        case 1, 2:                 return .partlyCloudy
        case 3, 45, 48:            return .cloudy
        case 51...67, 80...82:     return .rainy
        case 71...77, 85, 86:      return .cloudy   // we don't model snow; treat as overcast
        case 95...99:              return .stormy
        default:                   return .partlyCloudy
        }
    }

    static func buildForecast(from daily: OpenMeteoResponse.Daily) -> [ForecastDay] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let weekday = DateFormatter()
        weekday.dateFormat = "EEE"

        var days: [ForecastDay] = []
        for index in daily.time.indices {
            let dateString = daily.time[index]
            let date = formatter.date(from: dateString)
            let label: String
            if let date, Calendar.current.isDateInToday(date) {
                label = "Today"
            } else if let date {
                label = weekday.string(from: date)
            } else {
                label = dateString
            }
            days.append(
                ForecastDay(
                    day: label,
                    condition: condition(from: daily.weather_code[index]),
                    highC: Int(daily.temperature_2m_max[index].rounded()),
                    lowC:  Int(daily.temperature_2m_min[index].rounded()),
                    rainChance: daily.precipitation_probability_max[index] ?? 0
                )
            )
        }
        return days
    }
}

// MARK: - Open-Meteo JSON

struct OpenMeteoResponse: Decodable {
    let current: Current
    let daily: Daily

    struct Current: Decodable {
        let temperature_2m: Double
        let weather_code: Int
    }

    struct Daily: Decodable {
        let time: [String]
        let weather_code: [Int]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let precipitation_probability_max: [Int?]
    }
}
