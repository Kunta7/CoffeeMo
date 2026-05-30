//
//  SupabaseModels.swift
//  CoffeeMo
//

import Foundation

struct SensorReadingRow: Codable, Identifiable, Hashable {
    let readingId: Int
    let sensorId: String
    let batchId: String?
    let recordedAt: Date
    let temperature: Double?
    let humidity: Double?
    let rainValue: Double?
    let moisture: Double?
    let motionDetected: Bool?

    var id: Int { readingId }

    enum CodingKeys: String, CodingKey {
        case readingId = "reading_id"
        case sensorId = "sensor_id"
        case batchId = "batch_id"
        case recordedAt = "recorded_at"
        case temperature
        case humidity
        case rainValue = "rain_value"
        case moisture
        case motionDetected = "motion_detected"
    }
}

struct CoffeeBatchRow: Codable, Identifiable, Hashable {
    let batchId: String
    let batchCode: String
    let variety: String?
    let processingMethod: String
    let harvestDate: Date
    let initialWeightKg: Double
    let currentWeightKg: Double?
    let currentStage: String
    let location: String?
    let moistureContent: Double?
    let qualityScore: Double?
    let startedAt: Date
    let closedAt: Date?
    let createdBy: String?
    let notes: String?

    var id: String { batchId }

    enum CodingKeys: String, CodingKey {
        case batchId = "batch_id"
        case batchCode = "batch_code"
        case variety
        case processingMethod = "processing_method"
        case harvestDate = "harvest_date"
        case initialWeightKg = "initial_weight_kg"
        case currentWeightKg = "current_weight_kg"
        case currentStage = "current_stage"
        case location
        case moistureContent = "moisture_content"
        case qualityScore = "quality_score"
        case startedAt = "started_at"
        case closedAt = "closed_at"
        case createdBy = "created_by"
        case notes
    }
}

struct AlertLogRow: Codable, Identifiable, Hashable {
    let alertLogId: Int
    let readingId: Int?
    let thresholdId: Int?
    let batchId: String?
    let triggeredAt: Date
    let acknowledged: Bool
    let acknowledgedBy: String?
    let acknowledgedAt: Date?

    var id: Int { alertLogId }

    enum CodingKeys: String, CodingKey {
        case alertLogId = "alert_log_id"
        case readingId = "reading_id"
        case thresholdId = "threshold_id"
        case batchId = "batch_id"
        case triggeredAt = "triggered_at"
        case acknowledged
        case acknowledgedBy = "acknowledged_by"
        case acknowledgedAt = "acknowledged_at"
    }
}

struct AlertThresholdRow: Codable, Identifiable, Hashable {
    let thresholdId: Int
    let sensorType: String
    let parameter: String
    let minValue: Double?
    let maxValue: Double?
    let alertLevel: Int
    let alertMessage: String

    var id: Int { thresholdId }

    enum CodingKeys: String, CodingKey {
        case thresholdId = "threshold_id"
        case sensorType = "sensor_type"
        case parameter
        case minValue = "min_value"
        case maxValue = "max_value"
        case alertLevel = "alert_level"
        case alertMessage = "alert_message"
    }
}

struct ActuatorEventRow: Codable, Identifiable, Hashable {
    let eventId: Int
    let actuatorId: String
    let eventTime: Date
    let eventType: String
    let triggeredBy: String

    var id: Int { eventId }

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case actuatorId = "actuator_id"
        case eventTime = "event_time"
        case eventType = "event_type"
        case triggeredBy = "triggered_by"
    }
}
