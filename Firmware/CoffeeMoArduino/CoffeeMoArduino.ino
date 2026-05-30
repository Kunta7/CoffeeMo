/*
  CoffeeMoArduino.ino

  Board: Arduino UNO R3

  Responsibilities:
  - Read DHT11 temperature + humidity in the storage room.
  - Read rain/water sensor on the coffee beds.
  - Read PIR motion sensor in the storage room.
  - Control the storage-room fan through a relay.
  - Control the protective cover through an SG90 servo.
  - Send one compact JSON line to the ESP8266 over SoftwareSerial.

  Wiring used by this sketch:
  - DHT11 data       -> D2
  - PIR OUT          -> D3
  - Fan relay IN     -> D7
  - Servo signal     -> D9
  - ESP8266 TX       -> D10 (UNO RX via SoftwareSerial)
  - ESP8266 RX       -> D11 (UNO TX via SoftwareSerial, use voltage divider)
  - Rain sensor AOUT -> A0

  Important hardware notes:
  - ESP8266 must be powered from a stable 3.3V supply, not directly from UNO 3.3V.
  - Connect all grounds together.
  - UNO TX is 5V; ESP8266 RX is 3.3V. Use a voltage divider or level shifter.
*/

#include <DHT.h>
#include <Servo.h>
#include <SoftwareSerial.h>

#define DHT_PIN 2
#define DHT_TYPE DHT11
#define PIR_PIN 3
#define FAN_RELAY_PIN 7
#define COVER_SERVO_PIN 9
#define ESP_RX_PIN 10
#define ESP_TX_PIN 11
#define RAIN_SENSOR_PIN A0

// Demo interval: 15 seconds. For field deployment, change to 15UL * 60UL * 1000UL.
const unsigned long SAMPLE_INTERVAL_MS = 15UL * 1000UL;

const float TEMP_MAX_C = 28.0;
const float HUMIDITY_MAX_PCT = 70.0;

// Many rain modules produce lower analog values when wet.
// Calibrate this using Serial Monitor if your module behaves differently.
const int RAIN_WET_THRESHOLD = 650;

const int COVER_RETRACTED_DEG = 0;
const int COVER_DEPLOYED_DEG = 180;

DHT dht(DHT_PIN, DHT_TYPE);
Servo coverServo;
SoftwareSerial espSerial(ESP_RX_PIN, ESP_TX_PIN);

unsigned long lastSampleAt = 0;
bool coverIsDeployed = false;

void setup() {
  Serial.begin(9600);
  espSerial.begin(9600);

  pinMode(PIR_PIN, INPUT);
  pinMode(FAN_RELAY_PIN, OUTPUT);
  digitalWrite(FAN_RELAY_PIN, LOW);

  dht.begin();
  coverServo.attach(COVER_SERVO_PIN);
  coverServo.write(COVER_RETRACTED_DEG);

  Serial.println(F("CoffeeMo Arduino node started"));
}

void loop() {
  unsigned long now = millis();
  if (now - lastSampleAt >= SAMPLE_INTERVAL_MS || lastSampleAt == 0) {
    lastSampleAt = now;
    sampleAndSend();
  }
}

void sampleAndSend() {
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();
  int rainRaw = analogRead(RAIN_SENSOR_PIN);
  bool motionDetected = digitalRead(PIR_PIN) == HIGH;

  if (isnan(temperature) || isnan(humidity)) {
    Serial.println(F("DHT11 read failed; skipping sample"));
    return;
  }

  float rainPercent = rainToPercent(rainRaw);

  bool shouldRunFan = (temperature > TEMP_MAX_C) || (humidity > HUMIDITY_MAX_PCT);
  digitalWrite(FAN_RELAY_PIN, shouldRunFan ? HIGH : LOW);

  bool rainDetected = rainRaw < RAIN_WET_THRESHOLD;
  if (rainDetected && !coverIsDeployed) {
    coverServo.write(COVER_DEPLOYED_DEG);
    coverIsDeployed = true;
  } else if (!rainDetected && coverIsDeployed) {
    coverServo.write(COVER_RETRACTED_DEG);
    coverIsDeployed = false;
  }

  sendJson(temperature, humidity, rainPercent, motionDetected, shouldRunFan, coverIsDeployed);
}

float rainToPercent(int raw) {
  // Dry is close to 1023, wet is lower. Convert to intuitive 0-100 scale.
  float percent = (1023.0 - raw) / 1023.0 * 100.0;
  if (percent < 0) return 0;
  if (percent > 100) return 100;
  return percent;
}

void sendJson(float temperature,
              float humidity,
              float rainPercent,
              bool motionDetected,
              bool fanOn,
              bool coverDeployed) {
  String payload = "{";
  payload += "\"sensor_id\":\"DHT11-01\",";
  payload += "\"batch_id\":\"GIH-2026-001\",";
  payload += "\"temperature\":";
  payload += String(temperature, 1);
  payload += ",\"humidity\":";
  payload += String(humidity, 1);
  payload += ",\"rain_value\":";
  payload += String(rainPercent, 1);
  payload += ",\"motion_detected\":";
  payload += motionDetected ? "true" : "false";
  payload += ",\"fan_on\":";
  payload += fanOn ? "true" : "false";
  payload += ",\"cover_deployed\":";
  payload += coverDeployed ? "true" : "false";
  payload += "}";

  Serial.println(payload);
  espSerial.println(payload);
}
