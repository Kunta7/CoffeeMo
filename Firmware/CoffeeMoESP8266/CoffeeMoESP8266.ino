

#include <ArduinoJson.h>
#include <ESP8266HTTPClient.h>
#include <ESP8266WiFi.h>
#include <SoftwareSerial.h>
#include <WiFiClientSecureBearSSL.h>

#include "secrets.h"

#define UNO_RX_PIN D5  // GPIO14 - receives from UNO TX (through voltage divider)
#define UNO_TX_PIN D6  // GPIO12 - sends to UNO RX (reserved for future commands)

SoftwareSerial unoLink(UNO_RX_PIN, UNO_TX_PIN);

String lastFanState = "";
String lastCoverState = "";
unsigned long lastCommandPollAt = 0;
long lastForwardedCommandId = 0;

const unsigned long COMMAND_POLL_INTERVAL_MS = 3000UL;

void setup() {
  Serial.begin(9600);
  unoLink.begin(9600);
  delay(200);

  connectWiFi();
  Serial.println(F("CoffeeMo ESP8266 bridge started"));
}

void loop() {
  ensureWiFi();

  unsigned long now = millis();
  if (now - lastCommandPollAt >= COMMAND_POLL_INTERVAL_MS || lastCommandPollAt == 0) {
    lastCommandPollAt = now;
    pollPendingCommand();
  }

  if (unoLink.available()) {
    String line = unoLink.readStringUntil('\n');
    line.trim();
    if (line.length() > 0) {
      Serial.print(F("From UNO: "));
      Serial.println(line);
      handleArduinoPayload(line);
    }
  }
}

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.disconnect(true);
  delay(200);

  Serial.println();
  Serial.print(F("Scanning visible Wi-Fi networks: "));
  int n = WiFi.scanNetworks();
  Serial.print(n);
  Serial.println(F(" found"));
  bool ssidVisible = false;
  for (int i = 0; i < n; i++) {
    Serial.print(F("  "));
    Serial.print(WiFi.SSID(i));
    Serial.print(F("  ("));
    Serial.print(WiFi.RSSI(i));
    Serial.println(F(" dBm)"));
    if (WiFi.SSID(i) == String(WIFI_SSID)) {
      ssidVisible = true;
    }
  }
  if (!ssidVisible) {
    Serial.print(F("WARNING: SSID not seen in scan: "));
    Serial.println(WIFI_SSID);
  }

  Serial.print(F("Connecting to '"));
  Serial.print(WIFI_SSID);
  Serial.println(F("'"));

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

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
    Serial.print(F("Wi-Fi connection failed (status="));
    Serial.print(WiFi.status());
    Serial.println(F("); will retry"));
    Serial.println(F("status meanings:"));
    Serial.println(F("  1 = WL_NO_SSID_AVAIL  (network name not found)"));
    Serial.println(F("  4 = WL_CONNECT_FAILED (wrong password)"));
    Serial.println(F("  6 = WL_DISCONNECTED   (auth/router rejection)"));
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

void pollPendingCommand() {
  if (WiFi.status() != WL_CONNECTED) return;

  std::unique_ptr<BearSSL::WiFiClientSecure> client(new BearSSL::WiFiClientSecure);
  client->setInsecure();
  client->setBufferSizes(1024, 1024);

  HTTPClient https;
  String endpoint = String(SUPABASE_URL) +
                    "/rest/v1/actuator_commands"
                    "?select=command_id,actuator_id,command"
                    "&status=eq.pending"
                    "&order=requested_at.asc"
                    "&limit=1";

  if (!https.begin(*client, endpoint)) {
    Serial.println(F("Command GET begin failed"));
    return;
  }

  https.addHeader("apikey", SUPABASE_ANON_KEY);
  https.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
  https.addHeader("Accept", "application/json");

  int status = https.GET();
  if (status < 200 || status >= 300) {
    Serial.print(F("Command GET failed, HTTP "));
    Serial.println(status);
    https.end();
    return;
  }

  String response = https.getString();
  https.end();

  StaticJsonDocument<512> commands;
  DeserializationError error = deserializeJson(commands, response);
  if (error) {
    Serial.print(F("Invalid command JSON: "));
    Serial.println(error.c_str());
    return;
  }

  JsonArray rows = commands.as<JsonArray>();
  if (rows.size() == 0) return;

  JsonObject row = rows[0];
  long commandId = row["command_id"] | 0;
  const char* actuatorId = row["actuator_id"] | "";
  const char* command = row["command"] | "";

  // Avoid forwarding the same command twice if Supabase update fails.
  if (commandId == lastForwardedCommandId) {
    Serial.print(F("Skipping already-forwarded command: "));
    Serial.println(commandId);
    // Still try to mark it processed (in case the previous PATCH failed).
    markCommandProcessed(commandId);
    return;
  }

  StaticJsonDocument<192> outbound;
  outbound["command_id"] = commandId;
  outbound["actuator_id"] = actuatorId;
  outbound["command"] = command;

  String line;
  serializeJson(outbound, line);
  unoLink.println(line);
  lastForwardedCommandId = commandId;

  Serial.print(F("Command sent to UNO: "));
  Serial.println(line);

  // Give the GET socket time to fully release before opening PATCH.
  delay(150);
  markCommandProcessed(commandId);
}

void markCommandProcessed(long commandId) {
  if (commandId <= 0 || WiFi.status() != WL_CONNECTED) return;

  std::unique_ptr<BearSSL::WiFiClientSecure> client(new BearSSL::WiFiClientSecure);
  client->setInsecure();
  // Reduce TLS memory footprint so consecutive HTTPS calls don't run out of heap.
  client->setBufferSizes(1024, 1024);

  HTTPClient https;
  String endpoint = String(SUPABASE_URL) +
                    "/rest/v1/actuator_commands?command_id=eq." +
                    String(commandId);

  if (!https.begin(*client, endpoint)) {
    Serial.println(F("Command PATCH begin failed"));
    return;
  }

  https.addHeader("Content-Type", "application/json");
  https.addHeader("apikey", SUPABASE_ANON_KEY);
  https.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
  https.addHeader("Prefer", "return=minimal");

  int status = https.sendRequest("PATCH", String("{\"status\":\"processed\"}"));
  https.end();

  if (status >= 200 && status < 300) {
    Serial.print(F("Command processed: "));
    Serial.println(commandId);
    return;
  }

  Serial.print(F("Command PATCH failed, HTTP "));
  Serial.print(status);
  Serial.println(F(" - falling back to DELETE"));

  // Fallback: just remove the row so it stops being polled. Audit history is
  // still preserved by actuator_events when state actually changes.
  std::unique_ptr<BearSSL::WiFiClientSecure> deleteClient(new BearSSL::WiFiClientSecure);
  deleteClient->setInsecure();
  deleteClient->setBufferSizes(1024, 1024);

  HTTPClient httpsDelete;
  if (!httpsDelete.begin(*deleteClient, endpoint)) {
    Serial.println(F("Command DELETE begin failed"));
    return;
  }
  httpsDelete.addHeader("apikey", SUPABASE_ANON_KEY);
  httpsDelete.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
  httpsDelete.addHeader("Prefer", "return=minimal");

  int deleteStatus = httpsDelete.sendRequest("DELETE");
  httpsDelete.end();

  if (deleteStatus >= 200 && deleteStatus < 300) {
    Serial.print(F("Command deleted (cleaned up): "));
    Serial.println(commandId);
  } else {
    Serial.print(F("Command DELETE also failed, HTTP "));
    Serial.println(deleteStatus);
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
