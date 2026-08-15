# CoffeeMo — IoT-Based Coffee Process Monitoring & Conservation System

CoffeeMo is an IoT-based digitalization system designed to improve monitoring and conservation of coffee during post-harvest processing.

The project combines an iOS mobile application, IoT hardware, embedded firmware, Supabase backend services, and real-time data monitoring to provide better visibility into environmental conditions and support operational decision-making.

## Project Overview

Coffee processing requires reliable monitoring of environmental conditions to help maintain product quality.

CoffeeMo addresses this challenge by connecting sensors and actuators to a digital platform that allows users to monitor system conditions and interact with connected hardware through a mobile application.

## System Architecture

```text
Sensors / Actuators
                ▼
 Arduino / ESP8266
        │
        │ Sensor Data
        ▼
    Supabase
 Backend / Database
        │
        │ Real-Time Data
        ▼
   CoffeeMo iOS App
        │
        │ Control Commands
        ▼
 Arduino / ESP8266
## Key Features

- Real-time IoT monitoring
- Sensor data acquisition
- Mobile-based system monitoring
- IoT actuator control
- Bidirectional communication between mobile application and hardware
- Supabase database integration
- Database-backed actuator command management
- Embedded firmware for Arduino and ESP8266
- Environmental monitoring for coffee processing
- Data-driven process visibility

## Technology Stack

### Mobile Application

- Swift
- SwiftUI
- Xcode
- iOS

### Backend & Data

- Supabase
- PostgreSQL
- SQL
- Real-time data communication

### IoT & Embedded Systems

- Arduino
- ESP8266
- Sensors
- Actuators
- Embedded C/C++

### Development

- Git
- GitHub
- Xcode
- Arduino IDE

## IoT Architecture

The system uses connected hardware to collect environmental and process data and communicate with the backend.

The ESP8266 and Arduino components handle hardware-level operations, while the CoffeeMo mobile application provides a user-facing interface for monitoring and control.

The architecture supports bidirectional communication:

**Hardware → Backend → Mobile Application**

for monitoring data, and:

**Mobile Application → Backend → Hardware**

for actuator commands.

## Database Integration

Supabase/PostgreSQL is used as the backend data layer.

The project includes database structures for managing actuator commands, including:

- Command identification
- Actuator identification
- Command status
- Request timestamps
- Processing timestamps
- Command lifecycle tracking

The SQL implementation also includes database indexes, triggers, and row-level security policies.

## Project Structure

```text
CoffeeMo/
├── CoffeeMo/                    # iOS application
│   ├── Components/
│   ├── Models/
│   ├── Services/
│   ├── Theme/
│   ├── ViewModels/
│   └── Views/
│
├── Firmware/
│   ├── CoffeeMoArduino/         # Arduino firmware
│   ├── CoffeeMoESP8266/         # ESP8266 firmware
│   └── README.md
│
├── Supabase/
│   └── actuator_commands.sql    # Database/control schema
│
├── CoffeeMoTests/               # Unit tests
├── CoffeeMoUITests/             # UI tests
└── CoffeeMo.xcodeproj

## Configuration

Sensitive configuration values are intentionally excluded from the repository.

For the ESP8266 firmware, copy:

`Firmware/CoffeeMoESP8266/secrets.example.h`

to:

`Firmware/CoffeeMoESP8266/secrets.h`

and configure the required local credentials.

Sensitive environment files such as `.env` and `.env.local` are excluded through `.gitignore`.

## Engineering Focus

CoffeeMo demonstrates practical application of:

- IoT system integration
- Process digitalization
- Embedded systems
- Mobile application development
- Database systems
- Real-time data monitoring
- Automation concepts
- Systems integration
- Software architecture
- Data-driven decision support

## Academic Context

CoffeeMo was developed as a final-year Information Technology project focused on applying IoT and software engineering to coffee-process monitoring and conservation.

The project explores how connected systems can improve visibility, monitoring, and operational decision-making in agricultural processing environments.

## Future Development

Potential improvements include:

- Advanced automated control strategies
- Predictive analytics
- Historical data visualization
- Automated alerts
- Additional sensors
- Machine-learning-based process optimization
- Role-based access control
- Expanded industrial IoT integration

## Author

**Arakaza Patience**

Information Technology | IT Projects | Digitalization | Automation

GitHub: https://github.com/Kunta7
