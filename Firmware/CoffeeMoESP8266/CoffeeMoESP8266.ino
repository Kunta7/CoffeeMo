/*
  CoffeeMoESP8266.ino

  Board: ESP8266 (NodeMCU / Wemos D1 mini recommended)

  Responsibilities:
  - Connect to Wi-Fi.
  - Receive JSON lines from Arduino UNO over serial.
  - POST sensor readings to Supabase REST API.
  - POST actuator events when fan/cover state changes.

  Libraries:
  - ESP8266WiFi (installed with ESP8266 board support)
  - ESP8266HTTPClient
  - ArduinoJson by Benoit Blanchon

  Arduino IDE setup:
  - Boards Manager URL: https://arduino.esp8266.com/stable/package_esp8266com_index.json
  - Board: NodeMCU 1.0 (ESP-12E Module), or your exact ESP8266 board
*/

#include <ArduinoJson.h>
#include <ESP8266HTTPClient.h>
#include <ESP8266WiFi.h>
#include <WiFiClientSecureBearSSL.h>

#include "secrets.h"

String lastFanState = "";
String lastCoverState = "";

void setup() {
  Serial.begin(9600);
  delay(200);

  connectWiFi();
  Serial.println(F("CoffeeMo ESP8266 bridge started"));
}

void loop() {
  ensureWiFi();

  if (Serial.available()) {
    String line = Serial.readStringUntil('\n');
    line.trim();
    if (line.length() > 0) {
      handleArduinoPayload(line);
    }
  }
}

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print(F("Connecting to Wi-Fi"));
  unsigned long startedAt = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startedAt < 20000) {
    delay(500);
    Serial.print(F("."));
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print(F("Wi-Fi connected: "));
    Serial.println(WiFi.localIP());
  } else {
    Serial.println(F("Wi-Fi connection failed; will retry"));
  }
}

void ensureWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  connectWiFi();
}

void handleArduinoPayload(const String& line) {
  StaticJsonDocument<512> input;
  DeserializationError error = deserializeJson(input, line);
  if (error) {
    Serial.print(F("Invalid JSON from Arduino: "));
    Serial.println(error.c_str());
    return;
  }

  const char* batchId = input["batch_id"] | "GIH-2026-001";
  float temperature = input["temperature"] | 0.0;
  float humidity = input["humidity"] | 0.0;
  float rainValue = input["rain_value"] | 0.0;
  bool motionDetected = input["motion_detected"] | false;
  bool fanOn = input["fan_on"] | false;
  bool coverDeployed = input["cover_deployed"] | false;

  bool ok = true;
  ok = postDHTReading(batchId, temperature, humidity) && ok;
  ok = postRainReading(batchId, rainValue) && ok;
  ok = postMotionReading(motionDetected) && ok;

  Serial.print(F("sensor_readings POSTs: "));
  Serial.println(ok ? F("ok") : F("partial failure"));

  postActuatorIfChanged("FAN-01", fanOn ? "on" : "off", lastFanState);
  postActuatorIfChanged("COVER-01", coverDeployed ? "deployed" : "retracted", lastCoverState);
}

float rounded1(float value) {
  return round(value * 10.0) / 10.0;
}

bool postDHTReading(const char* batchId, float temperature, float humidity) {
  StaticJsonDocument<256> reading;
  reading["sensor_id"] = "DHT11-01";
  reading["batch_id"] = batchId;
  reading["temperature"] = rounded1(temperature);
  reading["humidity"] = rounded1(humidity);

  String body;
  serializeJson(reading, body);
  return postToSupabase("sensor_readings", body);
}

bool postRainReading(const char* batchId, float rainValue) {
  StaticJsonDocument<256> reading;
  reading["sensor_id"] = "RAIN-01";
  reading["batch_id"] = batchId;
  reading["rain_value"] = rounded1(rainValue);

  String body;
  serializeJson(reading, body);
  return postToSupabase("sensor_readings", body);
}

bool postMotionReading(bool motionDetected) {
  StaticJsonDocument<256> reading;
  reading["sensor_id"] = "PIR-01";
  reading["motion_detected"] = motionDetected;

  String body;
  serializeJson(reading, body);
  return postToSupabase("sensor_readings", body);
}

void postActuatorIfChanged(const char* actuatorId, const char* state, String& previousState) {
  if (previousState == state) return;

  StaticJsonDocument<256> event;
  event["actuator_id"] = actuatorId;
  event["event_type"] = state;
  event["triggered_by"] = "auto";

  String body;
  serializeJson(event, body);
  if (postToSupabase("actuator_events", body)) {
    previousState = state;
  }
}

bool postToSupabase(const char* table, const String& jsonBody) {
  if (WiFi.status() != WL_CONNECTED) return false;

  std::unique_ptr<BearSSL::WiFiClientSecure> client(new BearSSL::WiFiClientSecure);
  client->setInsecure(); // For thesis prototype. Use a pinned CA certificate for production.

  HTTPClient https;
  String endpoint = String(SUPABASE_URL) + "/rest/v1/" + table;

  if (!https.begin(*client, endpoint)) {
    Serial.println(F("HTTPS begin failed"));
    return false;
  }

  https.addHeader("Content-Type", "application/json");
  https.addHeader("apikey", SUPABASE_ANON_KEY);
  https.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
  https.addHeader("Prefer", "return=minimal");

  int status = https.POST(jsonBody);
  bool ok = status >= 200 && status < 300;

  if (!ok) {
    Serial.print(F("POST failed, HTTP "));
    Serial.println(status);
    String response = https.getString();
    if (response.length() > 0) {
      Serial.println(response);
    }
  }

  https.end();
  return ok;
}
