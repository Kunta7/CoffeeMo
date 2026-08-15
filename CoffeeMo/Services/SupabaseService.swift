//
//  SupabaseService.swift
//  CoffeeMo
//

import Foundation

enum SupabaseServiceError: LocalizedError {
    case invalidURL
    case invalidResponse(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Supabase URL."
        case .invalidResponse(let status):
            return "Supabase request failed with status \(status)."
        }
    }
}

actor SupabaseService {
    private let baseURL: URL
    private let anonKey: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        baseURL: URL = Secrets.supabaseURL,
        anonKey: String = Secrets.supabaseAnonKey,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601WithFractions
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func fetchRecentReadings(days: Int = 5) async throws -> [SensorReadingRow] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let iso = ISO8601DateFormatter.supabase.string(from: startDate)
        return try await get(
            path: "sensor_readings",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "recorded_at", value: "gte.\(iso)"),
                URLQueryItem(name: "order", value: "recorded_at.desc"),
                URLQueryItem(name: "limit", value: "1000")
            ]
        )
    }

    func fetchLatestReadings(limit: Int = 50) async throws -> [SensorReadingRow] {
        try await get(
            path: "sensor_readings",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "recorded_at.desc"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
    }

    func fetchCoffeeBatches(limit: Int = 20) async throws -> [CoffeeBatchRow] {
        try await get(
            path: "coffee_batches",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "started_at.desc"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
    }

    func fetchAlertThresholds() async throws -> [AlertThresholdRow] {
        try await get(
            path: "alert_thresholds",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "alert_level.desc")
            ]
        )
    }

    func fetchAlertLogs(limit: Int = 40) async throws -> [AlertLogRow] {
        try await get(
            path: "alert_logs",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "triggered_at.desc"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
    }

    func fetchActuatorEvents(limit: Int = 40) async throws -> [ActuatorEventRow] {
        try await get(
            path: "actuator_events",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "event_time.desc"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
    }

    func sendActuatorCommand(actuatorId: String, command: String) async throws {
        let payload = ActuatorCommandInsert(
            actuatorId: actuatorId,
            command: command,
            requestedBy: "ios_app"
        )
        try await post(path: "actuator_commands", body: payload)
    }

    private func get<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        var components = URLComponents(url: baseURL.appending(path: "rest/v1/\(path)"), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
        guard let url = components?.url else { throw SupabaseServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseServiceError.invalidResponse(-1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseServiceError.invalidResponse(http.statusCode)
        }
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Encodable>(path: String, body: T) async throws {
        let url = baseURL.appending(path: "rest/v1/\(path)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try encoder.encode(body)
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseServiceError.invalidResponse(-1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseServiceError.invalidResponse(http.statusCode)
        }
    }
}

private extension JSONDecoder.DateDecodingStrategy {
    static let iso8601WithFractions = custom { decoder in
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if let date = ISO8601DateFormatter.supabase.date(from: value) {
            return date
        }
        if let date = ISO8601DateFormatter.dateOnly.date(from: value) {
            return date
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Invalid ISO8601 date: \(value)"
        )
    }
}

private extension ISO8601DateFormatter {
    static let supabase: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let dateOnly: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
}
