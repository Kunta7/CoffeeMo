#include <Adafruit_Sensor.h>

/*
  

  Wiring used by this sketch:
  - DHT11 data       -> D7
  - PIR OUT          -> D8
  - Fan relay IN     -> D10
  - Servo signal     -> D9
  - ESP8266 TX       -> D6 (UNO RX via SoftwareSerial)
  - ESP8266 RX       -> A1 (UNO TX via SoftwareSerial, use voltage divider)
  - Rain sensor AOUT -> A0
  - LCD RS           -> D12
  - LCD EN           -> D11
  - LCD D4           -> D5
  - LCD D5           -> D4
  - LCD D6           -> D3
  - LCD D7           -> D2


*/

#include <ArduinoJson.h>
#include <DHT.h>
#include <LiquidCrystal.h>
#include <Servo.h>
#include <SoftwareSerial.h>

#define DHT_PIN 7
#define DHT_TYPE DHT11
#define PIR_PIN 8
#define FAN_RELAY_PIN 10
#define COVER_SERVO_PIN 9
#define ESP_RX_PIN 6
#define ESP_TX_PIN A1
#define RAIN_SENSOR_PIN A0

#define LCD_RS 12
#define LCD_EN 11
#define LCD_D4 5
#define LCD_D5 4
#define LCD_D6 3
#define LCD_D7 2

#define LCD_COLUMNS 16
#define LCD_ROWS 2

// Most cheap 5V blue-PCB relay modules are ACTIVE-LOW (LOW = relay engaged).
// If your module behaves the opposite way, set this to false.
#define RELAY_ACTIVE_LOW false

inline uint8_t relayLevel(bool on) {
  if (RELAY_ACTIVE_LOW) {
    return on ? LOW : HIGH;
  }
  return on ? HIGH : LOW;
}

// Time the LCD spends on each page before swapping.
const unsigned long LCD_PAGE_INTERVAL_MS = 2500UL;
const uint8_t LCD_PAGE_COUNT = 3;

// Keep motion visible briefly after a PIR pulse so it is easy to see on the LCD.
const unsigned long MOTION_HOLD_MS = 5000UL;
const unsigned long MANUAL_OVERRIDE_MS = 5UL * 60UL * 1000UL;

// Demo interval: 15 seconds. For field deployment, change to 15UL * 60UL * 1000UL.
const unsigned long SAMPLE_INTERVAL_MS = 15UL * 1000UL;

const float TEMP_MAX_C = 28.0;
const float HUMIDITY_MAX_PCT = 70.0;

// Some rain modules report LOW analog values when wet (typical FC-37),
// others report HIGH analog values when wet (different LM393 wiring).
// Set this to true if YOUR module's raw value goes UP as it gets wetter.
#define RAIN_ANALOG_HIGH_WHEN_WET true

// Threshold expressed as a raw 0-1023 reading. Calibrate using the Serial
// Monitor: pick a value between your DRY raw and your WET raw.
const int RAIN_WET_THRESHOLD = 150;

// Direction note: deployed must end at 90 degrees. To reverse the rotation
// direction (clockwise instead of counter-clockwise), the retracted angle is
// placed above the deployed one so deploying sweeps 180 -> 90.
const int COVER_RETRACTED_DEG = 180;
const int COVER_DEPLOYED_DEG  = 90;

DHT dht(DHT_PIN, DHT_TYPE);
Servo coverServo;
SoftwareSerial espSerial(ESP_RX_PIN, ESP_TX_PIN);
LiquidCrystal lcd(LCD_RS, LCD_EN, LCD_D4, LCD_D5, LCD_D6, LCD_D7);

unsigned long lastSampleAt = 0;
unsigned long lastLcdSwapAt = 0;
unsigned long lastMotionSeenAt = 0;
bool coverIsDeployed = false;
uint8_t lcdPageIndex = 0;
unsigned long fanOverrideUntil = 0;
unsigned long coverOverrideUntil = 0;
bool manualFanOn = false;
bool manualCoverDeployed = false;
long lastHandledCommandId = 0;

// Last known sensor + actuator values, used by the LCD between samples.
float lastTemperatureC = NAN;
float lastHumidityPct = NAN;
float lastRainPercent = 0.0;
bool lastMotionDetected = false;
bool lastFanOn = false;
bool lastCoverDeployed = false;
bool haveReadingForLcd = false;

void setup() {
  Serial.begin(9600);
  espSerial.begin(9600);

  pinMode(PIR_PIN, INPUT);
  pinMode(FAN_RELAY_PIN, OUTPUT);
  digitalWrite(FAN_RELAY_PIN, relayLevel(false)); // start with fan OFF

  dht.begin();
  // Move the cover to the retracted position once at boot, then release the
  // servo so its PWM stops fighting with SoftwareSerial timing.
  coverServo.attach(COVER_SERVO_PIN);
  coverServo.write(COVER_RETRACTED_DEG);
  delay(500);
  coverServo.detach();

  lcd.begin(LCD_COLUMNS, LCD_ROWS);
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(F("CoffeeMo IoT"));
  lcd.setCursor(0, 1);
  lcd.print(F("Booting..."));

  Serial.println(F("CoffeeMo Arduino node started"));
}

void loop() {
  unsigned long now = millis();

  handleIncomingCommand();

  // Update motion live on every loop so the LCD reflects movement immediately.
  bool rawMotionLive = digitalRead(PIR_PIN) == HIGH;
  if (rawMotionLive) {
    lastMotionSeenAt = now;
  }

  bool latchedMotion = lastMotionSeenAt != 0 && (now - lastMotionSeenAt <= MOTION_HOLD_MS);
  if (latchedMotion != lastMotionDetected) {
    lastMotionDetected = latchedMotion;
    if (haveReadingForLcd) {
      renderLcd();
    }
  }

  if (now - lastSampleAt >= SAMPLE_INTERVAL_MS || lastSampleAt == 0) {
    lastSampleAt = now;
    sampleAndSend();
  }

  if (haveReadingForLcd && (now - lastLcdSwapAt >= LCD_PAGE_INTERVAL_MS || lastLcdSwapAt == 0)) {
    lastLcdSwapAt = now;
    renderLcd();
    lcdPageIndex = (lcdPageIndex + 1) % LCD_PAGE_COUNT;
  }
}

void sampleAndSend() {
  unsigned long now = millis();
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();
  int rainRaw = analogRead(RAIN_SENSOR_PIN);
  bool motionDetected = lastMotionDetected || digitalRead(PIR_PIN) == HIGH;

  if (isnan(temperature) || isnan(humidity)) {
    Serial.println(F("DHT11 read failed; skipping sample"));
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print(F("DHT11 read err"));
    lcd.setCursor(0, 1);
    lcd.print(F("Check wiring"));
    return;
  }

  float rainPercent = rainToPercent(rainRaw);

  // Helpful calibration log: lets you trim the rain sensor's potentiometer
  // and verify dry / wet readings before adjusting RAIN_WET_THRESHOLD.
  Serial.print(F("Rain raw="));
  Serial.print(rainRaw);
  Serial.print(F(" -> "));
  Serial.print(rainPercent, 0);
  Serial.println(F("%"));

  bool fanManualActive = fanOverrideUntil != 0 && now < fanOverrideUntil;
  bool shouldRunFan = fanManualActive
      ? manualFanOn
      : (temperature > TEMP_MAX_C) || (humidity > HUMIDITY_MAX_PCT);
  digitalWrite(FAN_RELAY_PIN, relayLevel(shouldRunFan));

  bool rainDetected = rainSensorIsWet(rainRaw);
  bool coverManualActive = coverOverrideUntil != 0 && now < coverOverrideUntil;
  bool shouldDeployCover = coverManualActive ? manualCoverDeployed : rainDetected;
  setCoverPosition(shouldDeployCover);

  lastTemperatureC = temperature;
  lastHumidityPct = humidity;
  lastRainPercent = rainPercent;
  lastMotionDetected = motionDetected;
  lastFanOn = shouldRunFan;
  lastCoverDeployed = coverIsDeployed;
  haveReadingForLcd = true;

  sendJson(temperature, humidity, rainPercent, motionDetected, shouldRunFan, coverIsDeployed);
}

void handleIncomingCommand() {
  if (!espSerial.available()) return;

  String line = espSerial.readStringUntil('\n');
  line.trim();
  if (line.length() == 0) return;

  StaticJsonDocument<192> commandDoc;
  DeserializationError error = deserializeJson(commandDoc, line);
  if (error) {
    Serial.print(F("Invalid command from ESP8266: "));
    Serial.println(error.c_str());
    return;
  }

  long commandId = commandDoc["command_id"] | 0;
  const char* actuatorId = commandDoc["actuator_id"] | "";
  const char* command = commandDoc["command"] | "";

  if (commandId != 0 && commandId == lastHandledCommandId) {
    // Already applied this command; the ESP is just retrying because Supabase
    // hasn't been marked processed yet. Don't spam the relay/servo.
    return;
  }

  applyCommand(actuatorId, command);
  lastHandledCommandId = commandId;
}

void applyCommand(const char* actuatorId, const char* command) {
  String actuator = String(actuatorId);
  String action = String(command);
  actuator.toUpperCase();
  action.toLowerCase();

  unsigned long now = millis();

  if (actuator.indexOf("FAN") >= 0) {
    if (action == "auto") {
      fanOverrideUntil = 0;
      Serial.println(F("Fan command: AUTO"));
      return;
    }

    if (action == "on" || action == "off") {
      manualFanOn = action == "on";
      fanOverrideUntil = now + MANUAL_OVERRIDE_MS;
      digitalWrite(FAN_RELAY_PIN, relayLevel(manualFanOn));
      lastFanOn = manualFanOn;
      haveReadingForLcd = true;
      renderLcd();

      Serial.print(F("Fan command: "));
      Serial.println(manualFanOn ? F("ON") : F("OFF"));
      return;
    }
  }

  if (actuator.indexOf("COVER") >= 0) {
    if (action == "auto") {
      coverOverrideUntil = 0;
      Serial.println(F("Cover command: AUTO"));
      return;
    }

    if (action == "deployed" || action == "deploy" || action == "retracted" || action == "retract") {
      manualCoverDeployed = action == "deployed" || action == "deploy";
      coverOverrideUntil = now + MANUAL_OVERRIDE_MS;
      setCoverPosition(manualCoverDeployed);
      lastCoverDeployed = coverIsDeployed;
      haveReadingForLcd = true;
      renderLcd();

      Serial.print(F("Cover command: "));
      Serial.println(manualCoverDeployed ? F("DEPLOYED") : F("RETRACTED"));
      return;
    }
  }

  Serial.print(F("Unknown command: "));
  Serial.print(actuatorId);
  Serial.print(F(" / "));
  Serial.println(command);
}

void renderLcd() {
  lcd.clear();

  switch (lcdPageIndex) {
    case 0: {
      // Page 1 - Storage climate: temperature + humidity
      lcd.setCursor(0, 0);
      lcd.print(F("Temp: "));
      lcd.print(lastTemperatureC, 1);
      lcd.print((char)223); // degree symbol
      lcd.print(F("C"));

      lcd.setCursor(0, 1);
      lcd.print(F("Humidity: "));
      lcd.print(lastHumidityPct, 0);
      lcd.print(F("%"));
      break;
    }
    case 1: {
      // Page 2 - Coffee beds: rain + cover
      lcd.setCursor(0, 0);
      lcd.print(F("Rain: "));
      lcd.print(lastRainPercent, 0);
      lcd.print(F("%"));

      lcd.setCursor(0, 1);
      lcd.print(F("Cover: "));
      lcd.print(lastCoverDeployed ? F("DEPLOYED") : F("OPEN"));
      break;
    }
    case 2:
    default: {
      // Page 3 - Security: motion + fan
      lcd.setCursor(0, 0);
      lcd.print(F("Motion: "));
      lcd.print(lastMotionDetected ? F("ACTIVE") : F("IDLE"));

      lcd.setCursor(0, 1);
      lcd.print(F("Fan:    "));
      lcd.print(lastFanOn ? F("ON") : F("OFF"));
      break;
    }
  }
}

float rainToPercent(int raw) {
  float percent;
  if (RAIN_ANALOG_HIGH_WHEN_WET) {
    // Higher raw = wetter, so percent rises with raw.
    percent = raw / 1023.0 * 100.0;
  } else {
    // Lower raw = wetter (typical FC-37): percent falls as raw rises.
    percent = (1023.0 - raw) / 1023.0 * 100.0;
  }
  if (percent < 0) return 0;
  if (percent > 100) return 100;
  return percent;
}

bool rainSensorIsWet(int raw) {
  if (RAIN_ANALOG_HIGH_WHEN_WET) {
    return raw > RAIN_WET_THRESHOLD;
  }
  return raw < RAIN_WET_THRESHOLD;
}

// Drive the cover servo to a target state and immediately release it so
// the Servo library's PWM stops conflicting with SoftwareSerial.
// Does nothing if the cover is already in the requested position.
void setCoverPosition(bool deploy) {
  if (coverIsDeployed == deploy) return;
  coverServo.attach(COVER_SERVO_PIN);
  coverServo.write(deploy ? COVER_DEPLOYED_DEG : COVER_RETRACTED_DEG);
  delay(500); // give the SG90 time to physically reach the target
  coverServo.detach();
  coverIsDeployed = deploy;
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
