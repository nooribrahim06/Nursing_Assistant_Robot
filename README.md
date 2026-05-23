# 🤖 [Project Name Here]

> ✍️ *Write a one-line description of your project here — what it does and why it's cool.*

---

## 📸 Demo

> ✍️ *Add a screenshot or GIF of your project in action.*

| Simulation | Hardware |
|-----------|----------|
| ![sim placeholder](img/sim_placeholder.png) | ![hw placeholder](img/hw_placeholder.png) |

---

## 📋 Table of Contents

- [About the Project](#about-the-project)
- [Features Overview](#features-overview)
- [Hardware Components](#hardware-components)
- [Software Structure](#software-structure)
- [Getting Started](#getting-started)
- [Core Code Explained](#core-code-explained)
  - [Constants \& Memory Layout](#constants--memory-layout)
  - [Main Loop](#main-loop)
  - [State Machine \& UI](#state-machine--ui)
  - [TFT Display Driver](#tft-display-driver)
- [Feature Details](#feature-details)
  - [Heart Rate \& SpO₂](#️-heart-rate--spo₂-max30102)
  - [Breathing Monitor](#️-breathing-monitor)
  - [Temperature](#️-temperature)
  - [Medicine Dispenser](#-medicine-dispenser)
  - [Smoke Alert](#-smoke-alert)
  - [Hand Sanitizer](#️-hand-sanitizer)
  - [Vision Test](#️-vision-test)
  - [Line Tracking](#-line-tracking--motion)
  - [Bluetooth Control](#-bluetooth-control)
- [Examples](#examples)
- [Acknowledgements](#acknowledgements)

---

## 📖 About the Project

> ✍️ *Tell the story of your project. What problem does it solve? What inspired you to build it? 2–4 sentences.*

This project is written entirely in **ARM Assembly** targeting the **STM32F407VG** microcontroller (EasyMX Pro v7). It was developed as part of [Course Name / Subject] at [University Name].

Special thanks to **[Teacher's Name]** for the ARM Assembly guide that made this project possible. This project follows the same educational spirit — understanding hardware from the ground up, one register at a time.

---

## ✨ Features Overview

| Feature | Description | Simulation | Hardware |
|---------|-------------|------------|----------|
| ❤️ Heart Rate Monitor | BPM via MAX30102 | ✅ | ✅ |
| 🩸 SpO₂ Monitor | Blood oxygen via MAX30102 | ✅ | ✅ |
| 🌬️ Breathing Monitor | Real-time waveform via ADC | ✅ | ✅ |
| 🌡️ Temperature | Internal temp from MAX30102 | ✅ | ✅ |
| 💊 Medicine Dispenser | Timer + servo-controlled release | ✅ | ✅ |
| 🚨 Smoke Alert | Threshold detection + buzzer | ✅ | ✅ |
| 🧴 Hand Sanitizer | IR-triggered pump | ❌ | ✅ |
| 👁️ Vision Test | Landolt C eye test on TFT | ✅ | ✅ |
| 🤖 Line Tracking | Autonomous IR-based navigation | ❌ | ✅ |
| 📱 Bluetooth Control | Remote override via HC-05 | ❌ | ✅ |
| 🖥️ TFT Display | Full UI with menus + animations | ✅ | ✅ |

> ✍️ *Update the ✅/❌ to match what you actually have in Proteus.*

---

## 🔧 Hardware Components

| Component | Description | Pin(s) |
|-----------|-------------|--------|
| STM32F407VG (EasyMX Pro v7) | Main microcontroller | — |
| ILI9341 TFT Display | 2.8" color display (8080 parallel) | PE0–PE15 |
| MAX30102 | Heart rate + SpO₂ + temp sensor | I2C |
| HC-05 | Bluetooth module | USART2 |
| MQ-2 Smoke Sensor | Analog smoke detection | PA1 |
| IR Receiver | Remote control input | — |
| IR Sensors ×3 | Line tracking | PB12–PB14 |
| Servo Motor | Medicine dispenser | PA6 (TIM3 PWM) |
| DC Motors ×2 | Chassis movement | PB6–PB7 (TIM4 PWM) |
| Piezo Buzzer | Audio alerts | — |
| IR Proximity Sensor | Hand sanitizer trigger | PA4 |
| Mini Pump / Valve | Sanitizer dispense | PA5 |

> ✍️ *Edit this table to match your exact wiring.*

---

## 🗂️ Software Structure

```
project/
│
├── main.s                  # Entry point + main loop
├── constants.s             # All EQU constants, state IDs, shared RAM vars
│
├── ui_state.s              # State machine + IR input handler
├── tft_low.s               # TFT low-level SPI/8080 driver
├── tft_gfx.s               # TFT graphics engine (shapes, text, screens)
│
├── bluetooth.s             # HC-05 USART2 non-blocking driver
├── bluetooth_buffers.s     # Shared RAM for BT receive buffer
│
├── breathing.s             # Breathing waveform (ADC + baseline tracking)
├── sanitizing.s            # Hand sanitizer (IR sensor + pump)
├── medicine.s              # Medicine timer + servo control
├── buzzer.s                # Alert buzzer (state-aware)
├── adc.s                   # ADC driver (smoke + breathing channels)
│
├── examples for Proteus/   # Standalone simulation examples
│   ├── Blinking LEDs/
│   ├── Button With LED/
│   ├── Fill Screen/
│   └── Drawing Image/
│
└── image generation/
    └── imgToData.py        # Python: image to pixel data array
```

> ✍️ *Update filenames to match your actual project files.*

---

## 🚀 Getting Started

### Prerequisites

- **Keil MDK (uVision)** — [Download here](https://www.keil.com/demo/eval/arm.htm)
- **Proteus V8.16** *(simulation only — requires valid commercial license)*
- **STM32F4xx DFP Pack v2.17.1** — [Direct download](https://www.keil.com/pack/Keil.STM32F4xx_DFP.2.17.1.pack)
- **ST-Link Driver** + **MikroProg Suite** — for hardware flashing

### Installation

1. Clone or download this repository.
2. Open Keil → **Project** → **Open Project** → select the `.uvprojx` file.
3. In **Options for Target**: select `STM32F407VG`, enable **CMSIS > Core** and **Device > Startup**.

### Running Simulation

1. Build in Keil (**F7**) — ensure **"Create HEX File"** is checked.
2. Open the Proteus file from `examples for Proteus/`.
3. Double-click the STM32 → set **Crystal Frequency** to `16MHz` → set Program File to the `.hex`.
4. Press ▶ to simulate.

### Flashing to Hardware

1. Connect EasyMX via the **MikroProg USB port** and verify in MikroProg Suite.
2. In Keil: **Options for Target → Debug → ST-Link Debugger**.
3. Flash via **Flash → Download** (F8). Reset board if needed.

---

---

# 🧠 Core Code Explained

> This section covers the foundational parts of the codebase that everything else depends on.  
> Read this before diving into individual features.

---

## 📌 Constants & Memory Layout

**Files:** `constants.s`

> ✍️ *Explain how you organized your constants and shared variables. Cover:*
> - *How you defined hardware addresses (base + offset pattern)*
> - *How shared variables like `g_sys_state` and `g_bpm` are declared in RAM*
> - *How other files access those shared variables (IMPORT/EXPORT)*

```assembly
; ✍️ Paste a representative snippet from constants.s here
; Good examples: your state ID definitions, a GPIO base+offset pair,
; or how you declared a shared RAM variable
```

---

## 🔄 Main Loop

**Files:** `main.s`

> ✍️ *Walk through what happens on every iteration of your main loop.
> This is the heartbeat of the entire system — explain it step by step.*

The main loop runs continuously after initialization and coordinates all subsystems:

```
INIT
 │
 ▼
┌─────────────────────────────────────┐
│           MAIN LOOP (while 1)        │
│                                     │
│  1. Read IR input                   │
│  2. Read sensors (ADC, I2C, GPIO)   │
│  3. Update subsystems               │
│     ├─ Breathing                    │
│     ├─ Smoke detection              │
│     ├─ Medicine countdown           │
│     └─ Motion / Bluetooth           │
│  4. Check alert flags               │
│  5. Update UI (state machine)       │
│  6. Background tasks                │
│     ├─ Bluetooth reporting          │
│     └─ Buzzer                       │
└─────────────────────────────────────┘
```

> ✍️ *Describe each step in more detail. What happens in "Read sensors"? How are alert flags checked — are they just CMP + branch? Paste key code snippets.*

```assembly
; ✍️ Paste the main loop body here (or the most important part of it)
```

**Initialization (before the loop):**

> ✍️ *What do you set up before entering the loop? List it, then paste the init code.*

1. Enable clocks for used GPIO ports
2. Configure GPIO pins (input / output / alternate function)
3. Initialize TFT display
4. ✍️ *Add your remaining init steps here...*

```assembly
; ✍️ Paste your init code here
```

---

## 🧭 State Machine & UI

**Files:** `ui_state.s`, `constants.s`

> ✍️ *Explain your state machine — this is one of the most important parts of the project.*
> - *What variable holds the current state?*
> - *How does a state change happen — on button press? On alert flag?*
> - *How does each state decide what to render?*

The entire UI is driven by a single shared variable `g_sys_state`. On each loop iteration:

1. Read current state
2. Handle IR input for that state  
3. Render the appropriate screen

**States defined in `constants.s`:**

> ✍️ *Fill in your actual states and what each one displays.*

| State ID | Name | Description |
|----------|------|-------------|
| 0x00 | `MAIN_MENU` | Home screen, shows all feature icons |
| 0x01 | `HEART_RATE` | BPM display + animated heart |
| 0x02 | `BREATHING` | Real-time breathing waveform |
| ... | ✍️ | ✍️ |

**State dispatch (how the machine routes to each screen):**

```assembly
; ✍️ Paste your CMP/BEQ chain or jump table here
; This is the core of the state machine
```

**State transitions (how states change):**

> ✍️ *Show a concrete example — e.g. pressing the back button returns to MAIN_MENU, or a smoke alert forcefully overrides the current state.*

```assembly
; ✍️ Example: a state transition triggered by IR input or alert flag
```

---

## 🖥️ TFT Display Driver

**Files:** `tft_low.s`, `tft_gfx.s`

The TFT driver is split into two layers:

```
tft_gfx.s  ←  draw_pixel, draw_rect, draw_text, draw_screen_X
    ↓
tft_low.s  ←  write_command, write_data  (8080 parallel protocol)
    ↓
ILI9341    ←  physical display
```

**`tft_low.s` — Low-level write cycle:**

> ✍️ *Explain how you implemented the 8080 write cycle in assembly.
> Which pins do you toggle? In what order? How do you send a command vs data?*

```assembly
; ✍️ Paste your write_command or write_data routine here
```

**`tft_gfx.s` — Graphics engine:**

> ✍️ *Explain how you draw things — pixels, rectangles, text, full screens.
> How do you set the drawing window before sending pixel data?*

```assembly
; ✍️ Paste your draw_pixel or fill_rect routine here
```

**Display initialization sequence:**

> ✍️ *List and briefly explain the ILI9341 init commands you send (soft reset, pixel format, sleep out, display on, etc.)*

```assembly
; ✍️ Paste your TFT init sequence here
```

---

---

# 🔬 Feature Details

> Each feature follows this format:  
> **What it does → Files involved → How it works → Key code → Simulation screenshot (if available)**

---

## ❤️ Heart Rate & SpO₂ (MAX30102)

**Files:** `✍️ file1.s`, `✍️ file2.s`

> ✍️ *One sentence: what does this feature do and what does it output?*

**How it works:**

1. ✍️ *How do you initialize the MAX30102 over I2C?*
2. ✍️ *How do you read the IR and RED channel values?*
3. ✍️ *How do you detect peaks to calculate BPM?*
4. ✍️ *How is the SpO₂ ratio derived from IR/RED?*
5. Results stored in `g_bpm` and `g_spo2` → rendered on TFT heart screen with animated icon

**Key code:**

```assembly
; ✍️ Paste the most important snippet — e.g. your peak detection logic
; or the I2C read sequence for the sensor registers
```

**Simulation:**
> ✍️ *Add Proteus screenshot here if available.*

---

## 🌬️ Breathing Monitor

**Files:** `breathing.s`, `adc.s`

> ✍️ *One sentence: what does this feature do and what does it output?*

**How it works:**

1. ADC channel **PA0** continuously samples the breathing sensor
2. A **dynamic baseline** is maintained to handle slow sensor drift
3. Breathing signal extracted: `waveform = sample − baseline`
4. Signal is amplified and smoothed
5. Converted to a centered display value — **2048 = neutral line**
6. Stored in `g_breath_level` → rendered as scrolling real-time graph on TFT

**Key code:**

```assembly
; ✍️ Paste your baseline tracking or waveform extraction code here
```

**Simulation:**
> ✍️ *Add Proteus screenshot here if available.*

---

## 🌡️ Temperature

**Files:** `✍️ file.s`

> ✍️ *One sentence: what does this feature do?*

**How it works:**

1. ✍️ *How do you read the temperature register from MAX30102?*
2. Integer part stored in `g_temp_int`, fractional part in `g_temp_frac`
3. Displayed on dedicated TFT temperature screen, updated periodically

**Key code:**

```assembly
; ✍️ Paste your temperature register read snippet here
```

**Simulation:**
> ✍️ *Add Proteus screenshot here if available.*

---

## 💊 Medicine Dispenser

**Files:** `medicine.s`, `buzzer.s`, `ui_state.s`

> A smart medicine dispenser that runs seamlessly in the background, using hardware PWM to deliver precise doses without freezing the robot's main tasks.

**How it works:**

1. User enters countdown time (minutes) via IR remote on the TFT input screen
2. System converts to seconds and starts a background countdown
3. When timer reaches zero:
   - `Medicine_Alert_Flag` is set
   - TFT auto-switches to alert screen
   - Buzzer activates
4. User presses confirm on IR remote
5. Servo rotates step-wise: **0° → 90° → 180° → 0°** to dispense
   - Controlled via **TIM3 PWM on PA6**

**Key code:**

```assembly
; --- Positional Servo Step-Rotation Logic ---
; Advances the servo index (0 -> 1 -> 2 -> 0) mapped to (0° -> 90° -> 180° -> 0°)
LDR     R4, =med_servo_pos_index
LDR     R5, [R4]
ADDS    R5, R5, #1          ; Increment position step
CMP     R5, #3              ; Check boundary (max 3 states)
BNE     MSD_SetPulse
MOVS    R5, #0              ; Reset to 0° if cycle is complete
MSD_SetPulse
STR     R5, [R4]            ; Save new position state
```

**Simulation:**
> ✍️ *Add Proteus screenshot here if available.*

---

## 🚨 Smoke Alert

**Files:** `adc.s`, `buzzer.s`, `ui_state.s`

> ✍️ *One sentence: what does this feature do?*

**How it works:**

1. ADC channel **PA1** continuously reads the smoke sensor value
2. Value compared against a hardcoded threshold
3. If dangerous → `Smoke_Alert_Flag` is set
4. An ignore counter prevents repeated trigger spam
5. UI auto-switches to smoke alert screen + buzzer activates

**Key code:**

```assembly
; ✍️ Paste your threshold comparison and flag-set code here
```

**Simulation:**
> ✍️ *Add Proteus screenshot here if available.*

---

## 🧴 Hand Sanitizer

**Files:** `sanitizing.s`

> ✍️ *One sentence: what does this feature do?*

**How it works:**

1. IR proximity sensor on **PA4** detects a hand (active-low signal)
2. If hand detected → pump on **PA5** turned ON
3. Fixed delay loop runs for dispense duration
4. Pump turned OFF
5. Repeats — no state machine needed, direct and immediate response

**Key code:**

```assembly
; ✍️ Paste your sensor read + pump on/off code here
```

> ⚠️ *No Proteus simulation for this feature — hardware only.*

---

## 👁️ Vision Test

**Files:** `tft_gfx.s`, `ui_state.s`

> ✍️ *One sentence: what does this feature do?*

**How it works:**

1. TFT renders a **Landolt C** shape in a randomized orientation
2. User selects the direction of the gap using the IR remote
3. System compares user answer to correct orientation
4. Result accumulated in `g_vision_results`
5. Final score shown on results screen after all rounds

**Key code:**

```assembly
; ✍️ Paste your Landolt C drawing code or the answer-checking logic here
```

**Simulation:**
> ✍️ *Add Proteus screenshot here if available.*

---

## 🤖 Line Tracking & Motion

**Files:** `✍️ motion file.s`

> ✍️ *One sentence: what does this feature do?*

**How it works:**

1. Three IR sensors on **PB12, PB13, PB14** read the line beneath the robot
2. Sensor combination determines required direction correction:

   | PB12 | PB13 | PB14 | Action |
   |------|------|------|--------|
   | ✍️ | ✍️ | ✍️ | ✍️ |
   | | | | |

3. Motor direction set via **PA8–PA11**
4. Speed controlled via **TIM4 PWM** on PB6–PB7

**Key code:**

```assembly
; ✍️ Paste your sensor read + motor direction decision code here
```

> ⚠️ *No Proteus simulation for this feature — hardware only.*

---

## 📱 Bluetooth Control

**Files:** `bluetooth.s`, `bluetooth_buffers.s`, `✍️ motion file.s`

> ✍️ *One sentence: what does this feature do?*

**How it works:**

1. HC-05 connected to **USART2** — receive is fully **non-blocking**
2. Incoming bytes are buffered in shared RAM (`bluetooth_buffers.s`)
3. Parser uses **substring matching** — robust against noisy/partial packets
4. Parsed command sets motion request flags:
   - `g_bt_motion_mode_request` — LINE or PHONE mode
   - `g_bt_motion_dir_request` — FWD / BACK / LEFT / RIGHT / STOP
5. Motion module reads flags and acts on them each loop iteration
6. If no BT command received within timeout → auto-returns to **LINE mode**

**Supported commands:**

| Command | Action |
|---------|--------|
| `FWD` | Move forward |
| `BACK` | Move backward |
| `LEFT` | Turn left |
| `RIGHT` | Turn right |
| `STOP` | Stop motors |
| `LINE` | Switch to autonomous line tracking |
| `PHONE` | Switch to manual Bluetooth control |

**Key code:**

```assembly
; ✍️ Paste your USART receive handler or command parser here
```

> ⚠️ *No Proteus simulation for this feature — hardware only.*

---

## 📷 Examples

### Simulation — Fill Screen with Color
![fill screen](examples%20for%20Proteus/Fill%20Screen/fillScreenExample.png)

### Simulation — Draw Image on TFT
![draw image](examples%20for%20Proteus/Drawing%20Image/drawingImage.png)

### Hardware
> ✍️ *Add photos of your assembled robot / device running here.*

---

## 🙏 Acknowledgements

- **[Teacher's Name]** — For the ARM Assembly guide this entire project is built on. The depth of documentation, the simulation examples, and the clear explanations of hardware registers gave us the foundation to write every single line of this project. This README is our attempt to document our work with the same care and clarity.
- **[Team Member 1]** — ✍️ *What they contributed*
- **[Team Member 2]** — ✍️ *What they contributed*
- **[Team Member 3]** — ✍️ *What they contributed*
- [STM32F407 Reference Manual](https://www.st.com/resource/en/reference_manual/dm00031020-stm32f405-415-stm32f407-417-stm32f427-437-and-stm32f429-439-advanced-arm-based-32-bit-mcus-stmicroelectronics.pdf)
- [ILI9341 Datasheet](https://download.mikroe.com/documents/smart-displays/easytft/ILI9341-ILITEK.pdf)
- [ARM Cortex M3 Instruction Set](https://os.mbed.com/media/uploads/4180_1/cortexm3_instructions.htm)

---

> *Built with ❤️ and ARM Assembly — no HAL libraries, no shortcuts, just registers.*
