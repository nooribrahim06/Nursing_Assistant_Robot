<p align="center">
  <img src="app/src/main/res/mipmap-hdpi/ic_launcher.webp" width="100" alt="RoboCare Logo"/>
</p>

<h1 align="center">🤖 RoboCare Monitor</h1>

<p align="center">
  <strong>Android companion app for a robotic patient-monitoring system</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white" alt="Platform: Android"/>
  <img src="https://img.shields.io/badge/Min%20SDK-24%20(Nougat)-brightgreen" alt="Min SDK 24"/>
  <img src="https://img.shields.io/badge/Target%20SDK-34%20(Android%2014)-blue" alt="Target SDK 34"/>
  <img src="https://img.shields.io/badge/Language-Java%208-orange?logo=java" alt="Java 8"/>
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="MIT License"/>
  <img src="https://img.shields.io/badge/Bluetooth-HC--05%20Classic-2196F3" alt="Bluetooth HC-05"/>
  <img src="https://img.shields.io/badge/Backend-Firebase%20RTDB-FFCA28?logo=firebase" alt="Firebase"/>
</p>

---

An STM32-powered healthcare robot collects real-time vitals — heart rate, SpO₂, respiration, smoke level — via onboard sensors and streams them to this app over **Bluetooth Classic (HC-05)**. The app provides a **live dashboard** with automatic health triage, **medicine & smoke alerts**, full **patient management** with Firebase persistence, **remote motion control** of the robot, and a **TFT Remote** interface for controlling the robot's onboard display — all from a single dark-themed Material Design UI.

---

## ✨ Features

### 📊 Live Dashboard & Health Triage
- Real-time BPM, SpO₂, respiration rate, smoke level, and medicine timer displayed in a dark-themed card UI
- **Automatic triage** — vitals are classified as *Stable* 🟢, *Needs Attention* 🟠, or *Critical Alert* 🔴 with colour-coded indicators and explanatory reasons
- Raw packet display for debugging

### 🔥 Smoke Detection
- Raw ADC values mapped to **SAFE** (< 2000), **WARNING** (2000–3000), and **DANGER** (≥ 3000) levels
- Dismissible visual alert banner when smoke reaches dangerous levels or the STM32 raises a `SMOKE` / `FIRE` alert
- Dismiss command sent back to the robot to silence the onboard alarm

### 💊 Medicine Alerts
- When the STM32 raises a `MED` alert, the app displays the patient's **active prescriptions** (name, dose, notes) pulled from Firebase
- One-tap dismiss sends `CMD=MED,ALERT=OFF` back to the robot
- Timer countdown (0–600 s) visible on dashboard

### 👥 Patient Management
- **Add, edit, and delete** patient records (ID, name, age, room, notes)
- Patient list with RecyclerView, inline edit/delete buttons with confirmation dialogs
- Select a patient to enter their live dashboard
- All data persisted to Firebase Realtime Database

### 💊 Medicine Management
- Assign medicines (name, dose, notes) to each patient
- Toggle medicines **active / inactive** — only active medicines appear during alerts
- Full CRUD operations via Firebase

### 📜 Reading History
- Browse and review all saved vitals readings per patient
- Each reading stored with full timestamp in Firebase

### 📡 Bluetooth Classic
- **Singleton `BluetoothManager`** keeps the HC-05 socket alive across activity transitions
- Continuous background read thread with line-buffered parsing (splits by `\n`, strips `\r`)
- All callbacks posted to UI thread via `Handler`
- Audible tone feedback — ascending beep on connect, descending beep on disconnect
- Status indicator (connected / connecting / disconnected) with colour-coded dot on every screen

### 🎮 Motion Control
- Directional pad — **Forward / Back / Left / Right / Stop**
- **LINE ↔ PHONE mode handshake** — must explicitly enter phone control before directions are enabled
- Safe exit sequence — automatically sends `STOP` + `LINE` mode on back press or activity destroy
- Direction buttons disabled when not in phone control mode or when Bluetooth is disconnected

### 🖥️ TFT Remote Control *(New)*
- **Full remote interface** for the robot's onboard TFT display over Bluetooth
- **Four switchable panels:**
  - **Main** — 6 robot mode buttons matching the TFT menu order (Sanitizing, Heart Rate, Breathing, Medicine, Temperature, More)
  - **Medicine** — numeric keypad (0–9) for timer/dose input, with OK (A), Clear (B), and Back (C) controls
  - **Vision** — D-pad for camera/vision navigation (`CAM_UP`, `CAM_DOWN`, `CAM_LEFT`, `CAM_RIGHT`) with OK and Exit buttons
  - **More Menu** — extended modes: Vision, Vein Finder, Stress Test
- Quick action buttons: smoke alert dismiss, medicine alert dismiss, exit view
- Direct navigation to Motion Control from within the TFT Remote
- Send-only interface — does not bind a message listener, only shows connection status
- All commands follow the `CMD=UI,KEY=X` protocol

### ☁️ Firebase Sync
- Latest reading and full history stored under each patient node
- Real-time updates to Firebase on every incoming packet
- Patient and medicine data fully managed through Firebase CRUD

---

## 🏗️ Architecture

```
com.robot.patientmonitor
├── activities/
│   ├── MainActivity              # Home hub — Patients, Bluetooth, Motion, TFT Remote
│   ├── PatientListActivity       # List, select, edit, delete patients
│   ├── AddPatientActivity        # Create or edit a patient record
│   ├── DashboardActivity         # Live vitals dashboard + health triage + alerts
│   ├── HistoryActivity           # Past readings browser
│   ├── MedicinesActivity         # Manage patient medicines (CRUD)
│   ├── BluetoothConnectActivity  # Pair & connect to HC-05
│   ├── MotionControlActivity     # Remote directional control with LINE/PHONE modes
│   └── TftRemoteActivity         # Multi-panel TFT display remote control
├── bluetooth/
│   └── BluetoothManager          # Singleton — socket, read thread, command TX, audio feedback
├── data/
│   ├── AppState                  # In-memory singleton for selected patient & latest reading
│   └── FirebaseRepository        # All Firebase CRUD operations
├── models/
│   ├── Patient                   # Patient POJO
│   ├── Reading                   # Vitals reading POJO + breath description helper
│   └── Medicine                  # Medicine POJO
└── parser/
    └── PacketParser              # Parses serial packets into Reading objects (fault-tolerant)
```

---

## 📡 Serial Protocol

The STM32 sends newline-terminated, comma-separated key-value packets over HC-05:

```
TYPE=VITALS,PATIENT=001,BPM=82,SPO2=97,BREATH=540,SMOKE=120,MED=300,ALERT=NONE\n
```

| Field     | Type   | Description                                   |
|-----------|--------|-----------------------------------------------|
| `TYPE`    | String | Packet type — only `VITALS` is processed      |
| `PATIENT` | String | Patient ID (falls back to selected patient)   |
| `BPM`     | int    | Heart rate in beats per minute                |
| `SPO2`    | int    | Blood oxygen saturation (%)                   |
| `BREATH`  | int    | Respiration sensor reading                    |
| `SMOKE`   | int    | MQ-series smoke sensor ADC value              |
| `MED`     | int    | Medicine timer countdown (0–600 s)            |
| `ALERT`   | String | Alert flag — `NONE`, `MED`, `SMOKE`, `FIRE`, etc. |

### Commands (App → Robot)

#### Motion Control
| Command | Purpose |
|---------|---------|
| `CMD=MOTION,MODE=PHONE\n` | Switch robot to phone-controlled mode |
| `CMD=MOTION,MODE=LINE\n`  | Switch robot back to line-tracking mode |
| `CMD=MOTION,DIR=FWD\n`    | Move forward |
| `CMD=MOTION,DIR=BACK\n`   | Move backward |
| `CMD=MOTION,DIR=LEFT\n`   | Turn left |
| `CMD=MOTION,DIR=RIGHT\n`  | Turn right |
| `CMD=MOTION,DIR=STOP\n`   | Stop |

#### Alert Dismissal
| Command | Purpose |
|---------|---------|
| `CMD=MED,ALERT=OFF\n`   | Dismiss medicine alert |
| `CMD=SMOKE,ALERT=OFF\n` | Dismiss smoke alert |

#### TFT UI Control
| Command | Purpose |
|---------|---------|
| `CMD=UI,KEY=1` ... `KEY=8` | Select TFT menu mode (1–8) |
| `CMD=UI,KEY=0`             | Open "More" submenu |
| `CMD=UI,KEY=A`             | OK / Confirm |
| `CMD=UI,KEY=B`             | Clear input |
| `CMD=UI,KEY=C`             | Back / Return |
| `CMD=UI,KEY=D`             | Exit current view |
| `CMD=UI,KEY=CAM_UP`       | Vision D-pad — Up |
| `CMD=UI,KEY=CAM_DOWN`     | Vision D-pad — Down |
| `CMD=UI,KEY=CAM_LEFT`     | Vision D-pad — Left |
| `CMD=UI,KEY=CAM_RIGHT`    | Vision D-pad — Right |

---

## 🔧 Tech Stack

| Component | Technology |
|-----------|-----------|
| **Language** | Java 8 |
| **Min SDK** | 24 (Android 7.0 Nougat) |
| **Target SDK** | 34 (Android 14) |
| **UI** | Material Design (Material Components 1.11) |
| **Backend** | Firebase Realtime Database (BOM 32.7.2) |
| **Bluetooth** | Bluetooth Classic SPP (HC-05 module) |
| **Build** | Gradle 8.13 + Android Gradle Plugin 8.13.2 |

---

## 🚀 Getting Started

### Prerequisites

- Android Studio Hedgehog (2023.1) or newer
- An Android device with Bluetooth Classic support (API 24+)
- An HC-05 Bluetooth module paired with the device
- A Firebase project with Realtime Database enabled

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/Jasminex6/RoboCare-.git
   cd RoboCare-
   ```

2. **Add your Firebase config**
   - Download `google-services.json` from your [Firebase Console](https://console.firebase.google.com/)
   - Place it in `app/google-services.json`
   - See [`app/google-services.json.example`](app/google-services.json.example) for the expected structure

3. **Open in Android Studio**
   - File → Open → select the project root
   - Let Gradle sync complete

4. **Pair the HC-05 module**
   - Go to Android Bluetooth settings and pair with the HC-05 (default PIN: `1234`)

5. **Build & Run**
   - Connect your Android device via USB
   - Click **Run ▶** in Android Studio (or `./gradlew installDebug`)

---

## 📱 App Flow

```
MainActivity (Home)
├── 📋 Patients → PatientListActivity
│   ├── ➕ Add Patient → AddPatientActivity
│   ├── ✏️ Edit Patient → AddPatientActivity (pre-filled)
│   ├── 🗑️ Delete Patient (confirmation dialog)
│   └── 👤 Select Patient → DashboardActivity
│       ├── 📊 Live Vitals (BPM, SpO₂, Breath, Smoke, Med timer)
│       ├── 🏥 Health Overview (auto-triage)
│       ├── 💊 Medicine Alert (active prescriptions + dismiss)
│       ├── 🔥 Smoke Alert (danger level + dismiss)
│       ├── 💾 Save Reading → Firebase
│       ├── 💊 Medicines → MedicinesActivity
│       ├── 📜 History → HistoryActivity
│       └── 🔗 Bluetooth → BluetoothConnectActivity
├── 🔗 Bluetooth → BluetoothConnectActivity
├── 🎮 Motion Control → MotionControlActivity
│   ├── 📡 Enter Phone Mode (LINE → PHONE handshake)
│   ├── ⬆️⬇️⬅️➡️ Direction Pad
│   └── 🛑 Stop + safe exit sequence
└── 🖥️ TFT Remote → TftRemoteActivity
    ├── 🏠 Main Panel (6 robot modes)
    ├── 💊 Medicine Panel (numeric keypad)
    ├── 👁️ Vision Panel (camera D-pad)
    └── ➕ More Panel (Vision, Vein Finder, Stress Test)
```

---

## 🗂️ Firebase Data Structure

```
robocare/
└── patients/
    └── {patientId}/
        ├── patientId: "001"
        ├── name: "John Doe"
        ├── age: "65"
        ├── room: "A12"
        ├── notes: "Heart condition"
        ├── createdAt: 1714600000000
        ├── latest/
        │   ├── bpm: 82
        │   ├── spo2: 97
        │   ├── breath: 540
        │   ├── smoke: 120
        │   ├── med: 300
        │   ├── alert: "NONE"
        │   └── timestamp: 1714600123456
        ├── readings/
        │   └── {pushId}/
        │       └── ... (same fields as latest)
        └── medicines/
            └── {medicineId}/
                ├── name: "Aspirin"
                ├── dose: "100mg"
                ├── notes: "After meals"
                ├── active: true
                └── createdAt: 1714600000000
```

---

## ⚠️ Health Thresholds

| Condition | Threshold | Severity |
|-----------|-----------|----------|
| SpO₂ < 92% | Critical | 🔴 Critical Alert |
| Smoke ≥ 3000 | Critical | 🔴 Critical Alert |
| Active alert ≠ NONE | Critical | 🔴 Critical Alert |
| SpO₂ < 95% | Warning | 🟠 Needs Attention |
| Smoke 2000–3000 | Warning | 🟠 Needs Attention |
| BPM < 55 or > 110 | Warning | 🟠 Needs Attention |
| All normal | Stable | 🟢 Stable |

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -m 'feat: add your feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a Pull Request

> **Note:** Make sure to create your own Firebase project and add your own `google-services.json` file before building. See the [setup instructions](#setup) above.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

Copyright © 2026 Yasmine Ismail Hamed
