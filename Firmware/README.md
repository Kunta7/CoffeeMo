# CoffeeMo Firmware

This folder contains the hardware firmware for Path B.

## Sketches

- `CoffeeMoArduino/CoffeeMoArduino.ino`
  - Upload to the **Arduino UNO R3**.
  - Reads DHT11, rain/water sensor, and PIR motion sensor.
  - Controls fan relay and cover servo.
  - Sends one JSON line to ESP8266 over SoftwareSerial.

- `CoffeeMoESP8266/CoffeeMoESP8266.ino`
  - Upload to the **ESP8266** board (NodeMCU / Wemos D1 mini recommended).
  - Receives JSON from the Arduino.
  - Posts separate rows to Supabase:
    - `DHT11-01` for temperature/humidity
    - `RAIN-01` for rain value
    - `PIR-01` for motion
  - Posts fan/cover state changes to `actuator_events`.

## Required Arduino libraries

Install these from Arduino IDE Library Manager:

- `DHT sensor library` by Adafruit
- `Adafruit Unified Sensor`
- `Servo` (usually included with Arduino AVR)
- `ArduinoJson` by Benoit Blanchon

For ESP8266 board support:

1. Arduino IDE -> Settings -> Additional Boards Manager URLs:
   `https://arduino.esp8266.com/stable/package_esp8266com_index.json`
2. Tools -> Board -> Boards Manager -> install `esp8266`.

## Wiring summary

Arduino UNO R3:

| Component | Arduino pin |
|---|---|
| DHT11 data | D2 |
| PIR OUT | D3 |
| Fan relay IN | D7 |
| Servo signal | D9 |
| ESP8266 TX | D10 |
| ESP8266 RX | D11 through voltage divider |
| Rain sensor AOUT | A0 |

Important:

- ESP8266 requires a stable **3.3V** supply.
- UNO TX is **5V**, ESP8266 RX is **3.3V**. Use a voltage divider or level shifter.
- Connect all grounds together.

## Secrets

`CoffeeMoESP8266/secrets.h` is ignored by Git.

Update it with:

```cpp
const char* WIFI_SSID = "YOUR_WIFI_NAME";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
```

The Supabase URL and anon key are already filled locally.

## Testing

1. Upload `CoffeeMoESP8266.ino` to ESP8266 and open Serial Monitor at `9600`.
2. Confirm it prints a Wi-Fi IP address.
3. Upload `CoffeeMoArduino.ino` to Arduino UNO.
4. Open Supabase Table Editor -> `sensor_readings`.
5. Every 15 seconds during demo mode, new rows should appear:
   - DHT11 temperature/humidity row
   - rain row
   - PIR motion row

For real field deployment, change:

```cpp
const unsigned long SAMPLE_INTERVAL_MS = 15UL * 1000UL;
```

to:

```cpp
const unsigned long SAMPLE_INTERVAL_MS = 15UL * 60UL * 1000UL;
```
