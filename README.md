# 🤖 Nursing Assistant Robot

![Assembled Robot](imgs/Robo.jpg)

> An autonomous clinical assistance robot written entirely in **ARM Assembly (Thumb-2)** targeting the **STM32F401RC** microcontroller. Designed to navigate hospital corridors, monitor patient vitals, sanitise hands, and dispense medications—programmed at the bare-metal register level with no HAL, CMSIS, or OS libraries.

---

## 📋 Table of Contents

- [About the Project](#-about-the-project)
- [System Architecture \& Keypad Mapping](#-system-architecture--keypad-mapping)
- [Hardware Architecture \& Circuit Components](#-hardware-architecture--circuit-components)
- [Software Directory Structure](#-software-directory-structure)
- [Getting Started \& Building](#-getting-started--building)
- [Interrupt Map](#-interrupt-map)
- [Core Code Architecture](#-core-code-architecture)
  - [Constants \& RAM Memory Layout](#-constants--ram-memory-layout)
  - [Super-Loop Scheduler (main.s)](#-super-loop-scheduler-mains)
  - [Central State Machine (ui_state.s)](#-central-state-machine-uistates)
- [🔬 Driver Deep Dives](#-driver-deep-dives)
  - [🔌 ADC Driver (adc.s)](#-adc-driver-adcs)
  - [📡 I2C Driver (i2c.s)](#-i2c-driver-i2cs)
  - [⚙️ PWM Driver (pwm.s)](#-pwm-driver-pwms)
  - [🖥️ TFT SPI Driver (tft_low.s)](#-tft-spi-driver-tft_lows)
  - [📻 IR Remote Driver (ir_driver.s)](#-ir-remote-driver-ir_drivers)
  - [📱 Bluetooth Driver (bluetooth.s \& bluetooth_buffer.s)](#-bluetooth-driver-bluetooths--bluetooth_buffers)
  - [📏 Ultrasonic Driver (ultrasonic.s)](#-ultrasonic-driver-ultrasonics)
  - [⚓ IR Station Alignment Driver (ir_stations.s)](#-ir-station-alignment-driver-ir_stationss)
- [📂 File-by-File Technical Deep Dive](#-file-by-file-technical-deep-dive)
  - [Core Files](#1-core-system-files)
  - [Feature Files](#2-clinical-feature-files)
  - [Low-Level Drivers](#3-peripheral-driver-files)
- [🔬 Core Feature Specifications \& File Collaborations](#-core-feature-specifications--file-collaborations)
  - [1. Heart Rate \& SpO₂ Monitor](#1-heart-rate--spo₂-monitor-max30102)
  - [2. Breathing Waveform Monitor](#2-breathing-waveform-monitor)
  - [3. Volatility Stress Index](#3-volatility-stress-index)
  - [4. Sub-Dermal Vein Finder](#4-sub-dermal-vein-finder)
  - [5. Body Temperature Monitor](#5-body-temperature-monitor)
  - [6. Servo Medication Dispenser](#6-servo-medication-dispenser)
  - [7. Environmental Smoke Alert](#7-environmental-smoke-alert)
  - [8. IR Hand Sanitizer](#8-ir-hand-sanitizer)
  - [9. Landolt C Vision Test](#9-landolt-c-vision-test)
  - [10. Autonomous Line-Tracking Guidance](#10-autonomous-line-tracking-guidance)
  - [11. Mobile App Bluetooth Override](#11-mobile-app-bluetooth-override)
  - [12. Bedside IR station call-docking feature](#12-bedside-ir-station-call-docking-feature)
- [📱 Mobile App Control](#-mobile-app-control)
- [📷 Visual Walkthrough \& Simulation](#-visual-walkthrough--simulation)
- [🙏 Acknowledgements](#-acknowledgements)

---

## 📖 About the Project

In medical wards, reducing contact between clinical staff and infectious patients is critical. The **Nursing Assistant Robot** is a modular, low-cost autonomous assistant that navigates wards, delivers scheduled medications, detects fires, and checks patient diagnostics.

This project is a bare-metal engineering endeavor written entirely in **ARM Assembly**. Every operation—from software I2C bit-banging to high-speed SPI display transmissions and multi-channel analog filtration—is done by directly manipulating registers. No HAL, no CMSIS-Drivers, no C libraries.

---

## 📱 System Architecture & numbers Mapping

The user interface is driven by an IR Remote Control mapped to a central state machine. Pressing key numbers triggers hardware-level interrupts that transition the robot between screens and operational routines. Key `0` is an independent selection key that directs users to the sub-feature menu.

```
                               Home / Main Menu (Default)
                                           │
      ┌──────────────┬─────────────────┼──────────────┬──────────────┬──────────────┐
      │ (Key 1)      │ (Key 2)         │ (Key 3)      │ (Key 4)      │ (Key 5)      │ (Key 0)
      ▼              ▼                 ▼              ▼              ▼              ▼
┌───────────┐  ┌───────────┐     ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐
│ Sanitise  │  │ Heart     │     │ Breathing │  │ Meds      │  │ Body      │  │ More Menu │
│ Routine   │  │ Diagnostics│    │ Waveform  │  │ Timer     │  │ Temp      │  └─────┬─────┘
└───────────┘  └───────────┘     └───────────┘  └─────┬─────┘  └───────────┘        │
                                                      │                             │
                                                      ▼ (Trigger)                   │ (Keys 6, 7, 8)
                                                ┌───────────┐                       ▼
                                                │ Med Alert │                 ┌───────────┐
                                                │ & Dispense│                 │ Sub-Menu  │
                                                └───────────┘                 │ features  │
                                                                              └───────────┘
```

**Key Mappings:**

| Key | Feature | Pins Involved |
|-----|---------|---------------|
| 1 | Hand Sanitizer | PA4 (proximity), PA5 (relay pump) |
| 2 | Heart Rate & SpO₂ | PB8/PB9 I2C → MAX30102 |
| 3 | Breathing Waveform | PA0 → ADC CH0 |
| 4 | Medication Timer + Servo | PA6 (TIM3 CH1 servo) |
| 5 | Body Temperature | PB8/PB9 I2C → MAX30102 |
| 0 | More Menu | — |
| 6 | Landolt C Eye Test | TFT display |
| 7 | Vein Finder | PA7 → ADC CH7 |
| 8 | Stress Index | g_bpm calculation |
| C/# | Return to Home | — |

**Background Routines (always running):**
- **Line Tracking**: 3-bit IR reflective array on `PB12–PB14` for autonomous navigation.
- **Bluetooth Override**: Commands from the Robo Mobile App via USART2 (`PA2/PA3`) override autonomous movement.
- **Bedside IR Stations**: IR beacons at bedsides or charging stations halt the robot for clinical care delivery.

---

## 🔧 Hardware Architecture & Circuit Components

```
       [3x Li-ion Batteries (11.1V)] ───► [Buck Converter (5V Output)]
                                                  │
             ┌────────────────────────────────────┴────────────────────────────────────┐
             ▼                                                                         ▼
   [STM32F401RC MCU Core]                                                       [Actuators & Sensors]
    ├─ SPI1 Bus ───────────────────────────────────────────────────────────────► ILI9341 3.2" TFT Display
    ├─ I2C1 Bus ───────────────────────────────────────────────────────────────► MAX30102 Pulse Oximeter
    ├─ USART2 ─────────────────────────────────────────────────────────────────► HC-05 Bluetooth Module
    ├─ ADC1 (PA0/PA1/PA7) ─────────────────────────────────────────────────────► MQ-2, Breathing, Vein Sensors
    ├─ GPIO Inputs (PA4, PB10, PB12-15) ───────────────────────────────────────► Sanitizer, IR Remote, Line Trackers
    ├─ GPIO Outputs (PA5, PB4, PA8-11) ────────────────────────────────────────► Pump Relay, Buzzer, DC Motors
    ├─ TIM3 PWM (PA6) ─────────────────────────────────────────────────────────► Positional Medicine Servo
    ├─ TIM4 PWM (PB6/PB7) ─────────────────────────────────────────────────────► DC Motor Speed Control
    └─ TIM2 + EXTI10 (PB10) ───────────────────────────────────────────────────► IR Remote Decode
```

**Component List:**

1. **Chassis & Motion**: 6-wheel drive chassis, 6 TT DC Motors driven by two motor drivers, 1 line tracker sensor board (3 IR sensors on `PB12–PB14`).
2. **Core MCU**: STM32F401RC (ARM Cortex-M4, 16 MHz), ST-Link V2 SWD debugger, 3x 18650 Li-ion batteries (11.1V), 5V step-down buck converter.
3. **Display & UI**: ILI9341 3.2" Color TFT LCD over SPI1, piezo buzzer on `PB4`, IR receiver on `PB10` + IR remote.
4. **Actuators**: SG90/MG995 servo on `PA6` (TIM3 CH1) for medicine dispensing, mini submersible 5V water pump via relay on `PA5`.
5. **Sensors**: MAX30102 pulse oximeter on I2C1 (`PB8/PB9`), MQ-2 gas sensor on `PA1` (ADC CH1), HC-SR04 sonar on `PC15` (Trig) / `PC14` (Echo), sanitizer proximity IR on `PA4`, bedside IR alignment receiver.
6. **Discrete Components**: Safety diodes, push-buttons, IR LEDs, pull-down resistors, 74HC logic latches, decoders, battery holder, 3 breadboards, and jumper wires.

---

## 🗂️ Software Directory Structure

```
project/
│
├── README.md
├── motion.s                     # Guidance control loop + motor driving vectors
│
├── core/
│   ├── main.s                   # Entry point, SysTick 1ms & super-loop scheduler
│   ├── constants.s              # Hardware register offsets, state IDs, bit masks
│   ├── global.s                 # Shared RAM variable allocations
│   ├── gpio.s                   # GPIO clock/mode configuration library
│   ├── motion_constants.s       # Motor velocities and BT speed parameters
│   └── ui_state.s               # State-machine dispatcher & keypad transitions
│
├── features/
│   ├── max.s                    # I2C driver + high-pass filters for MAX30102
│   ├── breathing.s              # ADC breathing sampler + baseline drift tracking
│   ├── stress.s                 # Live heart-rate volatility analyzer
│   ├── vein.s                   # ADC signal averager + state-aware buzzer feedback
│   ├── medicine.s               # Background medication timers + servo rotation
│   ├── smoke.s                  # MQ-2 safety gates, warmup, and alarms
│   ├── santizing.s              # Hand proximity detection + relay sequencer
│   ├── motion_bt.s              # Bluetooth driving command parser
│   ├── ultrasonic.s             # Obstacle range calculations (HC-SR04)
│   └── ir_stations.s            # Charging/medical station alignment beacons
│
└── Drivers/
    ├── adc.s                    # ADC1 analog controller + Analog Watchdog (AWD)
    ├── i2c.s                    # I2C1 hardware master protocol driver
    ├── pwm.s                    # TIM3/TIM4 PWM for servo and motor speed
    ├── bluetooth.s              # USART2 peripheral + interrupts + queues
    ├── bluetooth_buffer.s       # Non-blocking RAM ring buffers (Rx/Tx)
    ├── buzzer.s                 # Periodic alert beeper on PB4
    ├── tft_low.s                # SPI1 ILI9341 register-level screen driver
    └── tft_gfx.s                # Graphics engine (shapes, waves, text rendering)
```

---

## 🚀 Getting Started & Building

### Keil MDK Toolchain Setup
1. Install **Keil MDK-ARM v5.39+** and the **Keil.STM32F4xx_DFP.2.17.1** device pack.
2. Open the `.uvprojx` workspace file.
3. In **Project → Options for Target → Output**, enable **"Create HEX File"**.

### Simulating in Proteus
1. Press **F7** in Keil to compile the `.hex` file.
2. Open the Proteus schematic, double-click the STM32F401RC, set Clock to `16MHz`, and point **Program File** to your `.hex`.
3. Press the green **Play** button to simulate.

### Hardware Flash
1. Connect ST-Link V2 to the SWD header (SWDIO, SWCLK, GND, 3.3V).
2. In Keil: **Options for Target → Debug → ST-Link Debugger**.
3. Press **F8** to flash. Press hardware `RESET` to boot.

---

## ⚡ Interrupt Map

The project relies on **three hardware interrupts** for time-critical operations. Everything else runs in the super-loop.

| Interrupt | Source | IRQ # | What it does |
|-----------|--------|-------|--------------|
| `EXTI15_10_IRQHandler` | Falling edge on PB10 (IR receiver) | IRQ 40 | Decodes NEC IR pulses using TIM2 timestamps. Each falling edge is timed and classified as a start frame, a `0` bit, or a `1` bit. After 32 bits are collected and checksummed, `g_ir_raw_code` is set. |
| `ADC_IRQHandler` (AWD) | ADC1 Analog Watchdog, CH1 (MQ-2) | IRQ 18 | Fires when the smoke sensor reading exceeds **3000** (out of 4095). Sets `Smoke_Alert_Flag` in `g_alarm_flags`, forcing the state machine to jump to `STATE_SMOKE_ALERT` on the next UI tick. |
| `SysTick_Handler` | SysTick core timer, 1ms reload | — | Increments `g_ms_ticks` every 1ms. Used throughout the codebase for non-blocking timeouts, draw-rate throttling (100ms), and medication countdown timers. |

> **Note:** USART2 (Bluetooth) also uses interrupts internally to fill ring buffers without blocking the main loop.

---

## 🧭 Core Code Architecture

### 📌 Constants & RAM Memory Layout

**Files:** `core/constants.s`, `core/global.s`

Hardware register locations and shared variables are declared globally. Constants map addresses inside `constants.s` while variables are reserved within `global.s` to manage memory maps systematically.

```assembly
;=============================================================================
; constants.s - Peripheral Addresses and UI Key Definitions
;=============================================================================
RCC_BASE            EQU     0x40023800
GPIOA_BASE          EQU     0x40020000
GPIOB_BASE          EQU     0x40020400

; System states
STATE_MAIN_MENU     EQU     0
STATE_SANITIZING    EQU     1
STATE_HEART_RATE    EQU     2
STATE_BREATHING     EQU     3
STATE_VEIN_FINDER   EQU     14
STATE_STRESS        EQU     16

;=============================================================================
; global.s - RAM memory declarations
;=============================================================================
        AREA    VARIABLES, DATA, READWRITE
        ALIGN
        EXPORT  g_sys_state
        EXPORT  g_bpm
        EXPORT  g_spo2
        EXPORT  g_ms_ticks

g_sys_state             SPACE   4       ; Current active menu/feature state
g_bpm                   SPACE   4       ; Calculated beats-per-minute
g_spo2                  SPACE   4       ; Blood oxygen saturation level
g_ms_ticks              SPACE   4       ; Uptime clock in milliseconds
        END
```

*   **Address Mapping**: Hardware registers are set using the base-plus-offset address pattern (e.g., `RCC_BASE` + `RCC_AHB1ENR` offset). This decouples physical configurations from high-level logical assignments.
*   **Access Scoping**: Global system variables are declared inside `global.s` inside the `READWRITE` data section, aligned to standard 32-bit boundaries. Access across the compiler boundaries is granted by marking them as `EXPORT` at the source and `IMPORT` inside individual assemblies.

---

### 🔄 Super-Loop Scheduler (main.s)

**File:** `core/main.s`

The main loop runs continuously after boot, coordinating non-blocking tasks.

```
                  INIT (Wakes up microcontroller)
                   │
                   ▼
       [ Main_InitGlobals ]   <-- Reset RAM values to zero
                   │
                   ▼
         [ Main_InitCore ]    <-- Set up SysTick (1ms) & load drivers
                   │
                   ▼
┌──────────────────────────────────────────────┐
│             MAIN LOOP (Continuous)           │
│                                              │
│  1. Check incoming Bluetooth serial stream   │
│  2. Inject virtual keypad presses from BT    │
│  3. Handle Bluetooth motion mode overrides   │
│  4. Read & debounce IR Remote commands       │
│  5. Run environmental fire check (MQ-2 ADC)  │
│  6. Run Background Tasks (Meds, buzzer, etc.)│
│  7. Execute active state logic (vein, ppg)   │
│  8. Check if 100ms has elapsed since draw    │
│     ├─ YES: Trigger TFT UI Update screen     │
│     └─ NO:  Skip draw step                   │
│  9. Run State Transition Cleanup routines    │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
                 Loops Forever
```

```assembly
Main_Loop
        BL      BT_RxTask                   ; Check incoming Bluetooth serial stream
        BL      Main_ProcessBTKeyInjection  ; Inject virtual keypad presses from BT
        BL      Main_ProcessBluetoothCmd    ; Handle driving mode overrides
        BL      Main_CheckIRInput           ; Debounce and check IR keypad inputs
        BL      Smoke_Check                 ; Read smoke sensor and check alarm flags
        BL      Main_BackgroundTasks        ; Execute medicine timers & buzzer beeps
        BL      Main_DispatchByState        ; Run active features (vein, ppg, breathing)
        
        ; Refresh the screen display every 100ms
        LDR     R0, =g_ms_ticks
        LDR     R1, [R0]
        LDR     R0, =ui_last_draw_tick
        LDR     R2, [R0]
        SUBS    R3, R1, R2
        CMP     R3, #100
        BLO     Main_SkipUI                 ; Skip if 100ms has not passed yet
        
Main_ForceUI
        STR     R1, [R0]                    ; Save current draw tick
        BL      UI_Update                   ; Render screens/graphs to TFT
        
Main_SkipUI
        BL      Main_HandleStateTransitions ; Clean up exiting states
        B       Main_Loop                   ; Repeat scheduler
```

---

### 🧭 Central State Machine (ui_state.s)

**File:** `core/ui_state.s`

Directs page routing based on the state machine variables. 

Alarms take absolute priority, with medication alarms locking down the display and smoke alarms applying a **5-second safety snooze cooldown** (`SMOKE_COOLDOWN_MS`) between dismissals. During active medication programming, smoke interrupts are suppressed to prevent data loss.

Redrawing is split into two pathways:
1. **Transition Redraw**: Triggered only when `g_sys_state != g_prev_state`, running `TFT_Clear_Screen` and drawing background layouts.
2. **Partial Updates**: Executed on every loop cycle to update numbers and waves without clearing the screen, preventing LCD flicker.

```assembly
UI_Update FUNCTION
        PUSH    {R4, R5, LR}
        
        ; 1) Alarm Check: Force state change to MED_ALERT or SMOKE_ALERT
        LDR     R0, =g_alarm_flags
        LDR     R1, [R0]
        TST     R1, #Med_Alert_Flag
        BNE.W   Handle_Med_Alert
        TST     R1, #Smoke_Alert_Flag
        BNE.W   UI_Trigger_Smoke_Alert

UI_Handle_Input_Then_Route
        BL      UI_Handle_Input             ; Check key codes and update active state
        
        LDR     R4, =g_sys_state
        LDR     R1, [R4]
        LDR     R5, =g_prev_state
        LDR     R0, [R5]
        
        CMP     R1, R0
        BEQ.W   UI_Partial_Update           ; No state change -> perform partial refresh
        
        ; 2) State Changed: Clear screen and perform full redraw
        STR     R1, [R5]
        MOV     R4, R1
        BL      TFT_Clear_Screen
        
        CMP     R4, #STATE_MAIN_MENU
        BEQ.W   UI_Render_Main_Menu
        CMP     R4, #STATE_VEIN_FINDER
        BEQ.W   UI_Render_Vein
        CMP     R4, #STATE_STRESS
        BEQ.W   UI_Render_Stress
        ; ... Rest of the state comparisons
```

**State Machine Dispatched Pages:**

| State Value (`g_sys_state`) | Name Code | Page Description |
| :---: | :--- | :--- |
| `0` | `STATE_MAIN_MENU` | Home landing page showing operational modes. |
| `1` | `STATE_SANITIZING` | Hand sanitizer activation status page. |
| `2` | `STATE_HEART_RATE` | Numeric BPM and $SpO_2$ pulse parameters readout. |
| `3` | `STATE_BREATHING` | Real-time respiratory graph plotting. |
| `4` | `STATE_MED_ALERT` | Flashing alert indicating dose is ready. |
| `6` | `STATE_MED_INPUT` | Input keypad console to program timer values. |
| `7` | `STATE_MED_DISPENSE` | Animates active dispenser servo rotations. |
| `8` | `STATE_SMOKE_ALERT` | Full-screen fire alarm siren. |
| `9` | `STATE_MED_WAITING` | Background countdown status check page. |
| `10` | `STATE_TEMP` | Body temperature display. |
| `11` | `STATE_PPG_WAVE` | Live raw PPG signal wave plotting. |
| `12` | `STATE_VISION` | Active Landolt C vision chart optotype test page. |
| `13` | `STATE_VISION_RES` | Vision exam scorecard calculation page. |
| `14` | `STATE_VEIN_FINDER` | Live vein mapper graph. |
| `16` | `STATE_STRESS` | Heart-rate volatility stress calculator page. |
| `17` | `STATE_MORE_MENU` | Sub-directory menu page. |

---

## 🔬 Driver Deep Dives

### 🔌 ADC Driver (`adc.s`)

**What this file does:** Configures the STM32 ADC1 peripheral and provides a universal `ADC_Read(channel)` function. It also sets up a hardware **Analog Watchdog** that automatically triggers an interrupt if the smoke sensor goes dangerously high — no polling needed for fire detection.

**Step-by-step initialization (`ADC_Init`):**

1. Enable GPIOA clock via `RCC_AHB1ENR` (bit 0).
2. Enable ADC1 clock via `RCC_APB2ENR` (bit 8).
3. Set `PA0` and `PA1` to analog mode in `GPIO_MODER` — both pin pairs get `11b` which disconnects the digital buffer entirely to prevent noise on analog pins.
4. Write `ADC_CR1`: set resolution to 12-bit (clear bits [25:24]).
5. Write `ADC_CR2`: select software trigger (clear [29:28]), right-align result (clear bit 11).
6. Write `ADC_SMPR2`: assign **84 cycles** sample time to CH0 and CH1, and a longer **480 cycles** sample time for CH7 (the vein sensor needs more settling time due to the high-impedance IR sensor).
7. Set sequence length to 1 in `ADC_SQR1`.
8. Power on: set `ADON` in `ADC_CR2`, then spin in a 1000-count stabilization delay before the ADC is considered ready.

**Reading a sample (`ADC_Read`):**

```assembly
; 1. Write the channel number into SQR3[4:0]
; 2. Clear the EOC (End-Of-Conversion) flag in ADC_SR
; 3. Set SWSTART in ADC_CR2 to fire a software conversion
; 4. Poll EOC with a 100,000-count timeout watchdog
; 5. Read 12-bit result from ADC_DR, mask with 0xFFF
```

**Tricky part — the timeout fail-safe:** Without a timeout, if the ADC hardware ever locks up (e.g., glitch during simulation), the loop `ADC_WaitEOC` would spin forever, freezing the entire robot. The fix returns `4095` (max value) on timeout, which the smoke logic treats as "clean air" — the safer default.

**Analog Watchdog (`ADC_AWD_Init`):**

Configures the hardware to watch channel 1 (MQ-2) automatically. Sets `HTR = 3000` (high threshold) and `LTR = 0`. In `ADC_CR1`, sets `AWDSGL` to watch a single channel, `AWDEN` to enable the watchdog, and `AWDIE` to fire an interrupt when the threshold is exceeded. Enables IRQ #18 in `NVIC_ISER0`. This means **no polling** is needed — the smoke alarm is purely interrupt-driven.

---

### 📡 I2C Driver (`i2c.s`)

**What this file does:** Implements a full **hardware I2C1 master** on `PB8` (SCL) and `PB9` (SDA) to communicate with the MAX30102 pulse oximeter. Provides three entry points: single-byte write, single-byte read, and a 6-byte burst read (needed for reading the MAX30102 FIFO which holds 3 bytes of red + 3 bytes of IR in one go).

**Initialization (`I2C_Init`):**

1. Enable GPIOB clock (`RCC_AHB1ENR` bit 1) and I2C1 clock (`RCC_APB1ENR` bit 21).
2. Set `PB8/PB9` MODER to `AF` (alternate function), OTYPER to **open-drain** (required by I2C spec — the line must be able to be pulled low by any device), OSPEEDR to high, PUPDR to pull-up.
3. Set AFRH for `PB8/PB9` to `AF4` (I2C1 alternate function).
4. **Software reset trick**: Write `SWRST` to `I2C_CR1` then clear it. This is critical — without it, a previously stuck bus state (e.g., after a bad transfer) will prevent `START` from being generated. This was a real bug encountered during development.
5. Write `I2C_CR2` with `FREQ = 42` (tells the I2C peripheral the APB1 clock speed in MHz so it can calculate timing correctly).
6. Write `I2C_CCR = 210` to set 100 kHz standard-mode clock speed: `CCR = F_APB1 / (2 × F_SCL) = 42MHz / 200kHz = 210`.
7. Write `I2C_TRISE = 43`: maximum rise time in standard mode = `(1000ns / (1/42MHz)) + 1 = 43`.
8. Enable the peripheral: `I2C_CR1 = 0x0401` (sets `PE` + `ACK`).

**Writing a register (`I2C_WriteReg`):**

The NEC I2C protocol requires: START → device address (write) → register address → data byte → STOP. Each step has a corresponding status flag in `I2C_SR1` that must be polled before proceeding.

```
START → wait SB (Start Bit)
→ write (device_addr << 1) → wait ADDR
→ clear ADDR by reading SR1 then SR2
→ wait TXE → write register address
→ wait TXE → write data byte
→ wait BTF (Byte Transfer Finished) → send STOP
```

**Reading a register (`I2C_ReadReg`):**

Reading over I2C requires two bus transactions: first write the register address (like a write, but without data), then issue a repeated START and switch to read mode with the address LSB = 1. The tricky part for single-byte reads is that **ACK must be disabled and STOP must be queued BEFORE clearing the ADDR flag** — if you do it after, the hardware has already started the next byte clock and you end up reading garbage.

**6-byte burst read (`I2C_Read6Bytes`):**

Used exclusively for MAX30102 FIFO data. Reads bytes 0–4 with ACK enabled, then on byte 4 atomically disables ACK and queues STOP so the final byte (byte 5) is NACKed correctly, signaling the device to release the bus.

**Tricky part — `I2C_WaitSR1_Set` with timeout:** Every wait in this driver goes through a shared helper that counts down from `I2C_TIMEOUT = 60000`. If any flag never arrives (e.g., device not connected), `I2C_ForceStop` is called to pull the bus to idle and the function returns an error code instead of freezing.

---

### ⚙️ PWM Driver (`pwm.s`)

**What this file does:** Configures two hardware timers to produce PWM signals — TIM3 for the medicine servo and TIM4 for the DC motor speed controllers.

**Initialization (`PWM_Init`):**

1. Enable GPIOA and GPIOB clocks, then TIM3 and TIM4 via `RCC_APB1ENR` (bits 2 and 3).
2. Set `PA6` to AF mode and assign `AF2` (TIM3 CH1) in `GPIO_AFRL`. **Important:** PA7 is intentionally left alone here because it's used by the ADC for the vein sensor — touching it would break analog readings.
3. Set `PB6/PB7` to AF mode with `AF2` (TIM4 CH1/CH2) for motor PWM.

**TIM3 — Servo at 50 Hz:**

```
Prescaler = 15  →  Timer clock = 16MHz / 16 = 1 MHz
ARR = 19999     →  Period = 20000 µs = 20 ms = 50 Hz
CCR1 range: 500 (0°) to 2500 (180°), center at 1500 (90°)
```

CCMR1 is set to `0x6868` which configures both CH1 and CH2 in **PWM Mode 1** (output HIGH while counter < CCR, LOW after). CCER `0x0011` enables both channels' outputs.

**TIM4 — DC Motors at 1 kHz:**

```
Prescaler = 15  →  Timer clock = 1 MHz
ARR = 999       →  Period = 1000 µs = 1 kHz
CCR range: 0 (stopped) to 999 (full speed)
```

**`PWM_Set_Motor_Speed(R0=left_speed, R1=right_speed)`:** Clamps both values to max 999 before writing to CCR1/CCR2, preventing over-range writes that would break the PWM ratio.

**`PWM_Set_Servo_Pos(R0=pulse_us, R1=servo_select)`:** Clamps pulse to [500, 2500] µs. R1=0 writes to CCR1 (medicine servo on PA6), R1=1 writes to CCR2.

**Tricky part:** The `TIM_EGR` update event (`STR #1, [R4, TIM_EGR]`) must be triggered after writing PSC/ARR so the timer loads the new values immediately rather than waiting for the next overflow. Missing this causes the timer to run on old prescaler values until the first natural update, which can produce one incorrect PWM cycle.

---

### 🖥️ TFT SPI Driver (`tft_low.s`)

**What this file does:** Initializes the ILI9341 display controller over SPI1 and provides the low-level primitives that the graphics engine (`tft_gfx.s`) builds on top of. This is the most latency-sensitive driver in the project — every pixel written goes through here.

**Pin map:**
```
PB0 → CS   (Chip Select, active LOW)
PB1 → DC   (Data/Command: LOW=command, HIGH=data)
PB2 → RST  (Hardware reset, active LOW)
PB3 → SCK  (SPI1 clock, AF5)
PB5 → MOSI (SPI1 data out, AF5)
```

**GPIO + SPI setup (`TFT_GPIO_SPI_Init`):**

1. Enable GPIOB and SPI1 clocks.
2. Set PB0/PB1/PB2 as push-pull outputs, PB3/PB5 as AF5 (SPI1). The OSPEEDR for all pins is set to maximum (0xFF…) to support the high toggle rate needed for SPI.
3. Idle state: CS=HIGH, DC=HIGH, RST=HIGH using a single BSRR write.
4. Configure SPI1_CR1 = `0x035C`:
   - Master mode, software NSS
   - CPOL=0, CPHA=0 (SPI Mode 0 — ILI9341 requirement)
   - Baud rate divider: `/4` gives 4 MHz SPI clock from the 16 MHz APB2

**Reset sequence (`TFT_Reset`):** Pulses RST LOW for a short delay then HIGH — this is a hardware reset that brings the ILI9341 back to factory defaults before sending init commands.

**Sending a byte (`SPI_SendByte`):** The trickiest part. Two TXE checks are needed:

```assembly
Wait TXE  → write byte to SPI_DR  → wait TXE again → wait BSY=0
```

The reason for the second TXE wait: writing to DR starts the shift, but the byte isn't fully transmitted until both TXE is set again (shift register emptied into DR) AND BSY clears. Skipping the BSY check causes the next CS deassert to arrive while the last bit is still being clocked out, corrupting the final byte.

**Command vs Data mode:** The ILI9341 uses the DC pin to distinguish register commands from pixel data. `TFT_BeginCommand` pulls both CS and DC LOW, `TFT_SwitchToData` raises DC HIGH (keeping CS LOW), and `TFT_EndTransaction` raises CS HIGH to close the transfer.

**Setting a pixel window (`TFT_SetAddressWindow(x0, y0, x1, y1)`):**

```
Send CASET (0x2A) command + 4 data bytes: x0_high, x0_low, x1_high, x1_low
Send PASET (0x2B) command + 4 data bytes: y0_high, y0_low, y1_high, y1_low
Send RAMWR (0x2C) to begin pixel data stream
```

After this, any 16-bit color values sent via `TFT_WriteData16` fill the window left-to-right, top-to-bottom automatically — no coordinate math needed per pixel.

**ILI9341 Init sequence (`TFT_Init`):** After reset, the init sequence sends power control, VCOM, frame rate, display function, and finally MADCTL `0x28` (landscape orientation, BGR color order). `PIXFMT 0x55` sets RGB565 — 5 bits red, 6 bits green, 5 bits blue, 2 bytes per pixel.

> **Simulation screenshot of TFT waveforms in Proteus:**
> ![TFT SPI Simulation](imgs/tft_ui_menu.png)

---

### 📻 IR Remote Driver (`ir_driver.s`)

**What this file does:** Decodes NEC protocol IR remote signals using **a falling-edge interrupt** on `PB10` and **TIM2 as a free-running 1 MHz stopwatch**. This is entirely interrupt-driven — the main loop just polls `g_ir_ready`.

**The NEC Protocol:**

```
Leader pulse:   9ms HIGH + 4.5ms LOW
Bit '0':        562µs HIGH + 562µs LOW   (total ~1.12ms)
Bit '1':        562µs HIGH + 1687µs LOW  (total ~2.25ms)
Frame:          32 bits = address(8) + ~address(8) + command(8) + ~command(8)
```

**Initialization (`IR_Init`):**

1. Enable GPIOB, SYSCFG, and TIM2 clocks.
2. Set `PB10` as input with pull-up (the IR receiver output is active-LOW).
3. Configure TIM2: PSC=15 → 1 µs ticks, ARR=0xFFFFFFFF (free-running 32-bit counter), start it.
4. Route `EXTI10` to port B via `SYSCFG_EXTICR3`.
5. Enable EXTI10 in `EXTI_IMR`, configure falling-edge trigger in `EXTI_FTSR`, disable rising edge in `EXTI_RTSR`.
6. Enable IRQ 40 (`EXTI15_10`) in `NVIC_ISER1` bit 8.

**Interrupt handler (`EXTI15_10_IRQHandler`):**

The handler runs a 3-state machine, executing in microseconds on each falling edge:

```
State 0 (IDLE):
  → First falling edge seen. Save TIM2 count, move to State 1.

State 1 (ARMED — waiting for leader):
  → Measure gap since last falling edge.
  → If 12500–14500 µs: valid 9ms+4.5ms leader detected → State 2, reset bit counter.
  → Otherwise: stay in State 1 (wait for a fresh leader).

State 2 (RECEIVING BITS):
  → Classify gap:
     900–1400 µs  → bit = 0
     1800–2800 µs → bit = 1
     Anything else → bad timing, reset to State 0.
  → Shift bit into ir_temp_code (LSB first).
  → After 32 bits: call IR_PublishIfValid.
```

**Checksum validation (`IR_PublishIfValid`):** Extracts the 4 bytes from the 32-bit code. Verifies `addr + ~addr = 0xFF` and `cmd + ~cmd = 0xFF`. If either check fails, the frame is silently dropped. Only the 8-bit command byte is published to `g_ir_raw_code`.

**Tricky part:** The falling-edge-only approach means the timing window is measured **between falling edges**, not pulse widths. This is more noise-resistant than measuring pulse HIGH time because the sensor output has slow rise times that distort pulse width measurements. The 900–1400 µs and 1800–2800 µs windows are intentionally wide to handle clock tolerance across different remote brands.

---

### 📶 Bluetooth Driver (bluetooth.s & bluetooth_buffer.s)

**What these files do:** Implement a full two-way Bluetooth communication layer over USART2, connecting the robot to the Robo Mobile App via an HC-05 module. The layer handles three responsibilities cleanly separated from the rest of the code: receiving and parsing motion commands from the app, periodically transmitting structured vitals packets to the app, and remotely dismissing alerts (smoke and medication) over the air.

**Three-file split:**

| File | Role |
|---|---|
| `bluetooth_constants.s` | All `EQU` definitions — USART2 register offsets, baud rate value, GPIO masks, buffer sizes, ASCII codes, command IDs |
| `bluetooth_buffer.s` | RAM allocations only — the RX/TX buffers and all shared flags that the motion layer reads |
| `bluetooth.s` | All executable logic — init, receive task, parse, transmit task, packet builders |

**USART2 Initialization (`BT_Init`):**
1. Enable GPIOA clock and USART2 clock (`RCC_APB1ENR` bit 17).
2. Set `PA2` and `PA3` to alternate function mode (`MODER` bits 10), assign `AF7` (USART2) in `GPIO_AFRL`.
3. Apply pull-up only on `PA3` (RX) — `PA2` (TX) is left floating. Without the pull-up, a disconnected RX line floats and generates framing errors that fill the RX buffer with garbage.
4. Set output speed to fast on both pins (needed to cleanly drive 9600 baud transitions).
5. Configure USART2: clear CR1/CR2/CR3, write `BRR = 0x0683` (derived from 16MHz / 9600 = 1666.7, mantissa 104, fraction 3 in OVER8=0 mode), then write CR1 = UE + TE + RE to enable the peripheral with both TX and RX active.
6. Clear any stale byte already sitting in DR by reading it if RXNE is set on startup.
7. Zero all flags: `g_bt_cmd_ready`, `g_bt_motion_mode_request`, `g_bt_motion_dir_request`, all tick timestamps.

**Receiving a command (`BT_RxTask`):**
Called once per main loop iteration. Deliberately reads at most one full line per call to avoid starving the scheduler.
*   Poll USART2_SR for RXNE (Receive Not Empty):
    *   No byte ready: exit immediately (non-blocking).
    *   Byte ready: read USART2_DR (clears RXNE automatically).
        *   CR (0x0D): ignore, continue polling.
        *   LF (0x0A): line complete → null-terminate buffer → call `BT_ParseLine` → clear buffer.
        *   Any other byte: append to `bt_rx_buffer[bt_rx_index++]`.
            *   If `bt_rx_index >= 79` (buffer full): discard entire line (overflow protection).
*   Every received byte also updates `g_bt_last_rx_tick` with the current SysTick millisecond count. The motion layer uses this timestamp to detect the 2-second BT inactivity timeout and resume autonomous line tracking.

**Parsing a command (`BT_ParseLine`):**
Uses substring matching rather than exact string equality. This means the app can send "CMD=FWD\n", "DIR:FWD\n", or just "FWD\n" — any format containing the keyword is accepted. This made the app development much easier and made the robot robust to minor protocol changes.

```assembly
; BT_Contains scans bt_rx_buffer byte-by-byte using BT_StartsWith at each position
; BT_StartsWith does a byte-by-byte comparison until the substring runs out (match) or a mismatch

Check for "FWD"        -> BT_SetDirRequest(BT_DIR_FWD=1)   + BT_QueueACK
Check for "BACK"       -> BT_SetDirRequest(BT_DIR_BACK=2)  + BT_QueueACK
Check for "LEFT"       -> BT_SetDirRequest(BT_DIR_LEFT=3)  + BT_QueueACK
Check for "RIGHT"      -> BT_SetDirRequest(BT_DIR_RIGHT=4) + BT_QueueACK
Check for "STOP"       -> BT_SetDirRequest(BT_DIR_STOP=5)  + BT_QueueACK
Check for "PHONE"      -> BT_SetModeRequest(BT_MODE_PHONE=2)+ BT_QueueACK
Check for "LINE"       -> BT_SetModeRequest(BT_MODE_LINE=1) + BT_QueueACK
Check for "CMD=UI"     -> BT_Handle_UIKey + BT_QueueACK     (virtual keypad)
Check for "OFF"        -> check if also contains "MED" or "SMOKE" -> clear alarm flag
```

`BT_SetDirRequest` and `BT_SetModeRequest` both write to the shared RAM flags (`g_bt_motion_dir_request`, `g_bt_motion_mode_request`, `g_bt_cmd_ready = 1`) that the motion layer polls each cycle. Only one of the two request fields is set per command — the other is explicitly zeroed to prevent stale commands.

**Remote alarm dismissal (`BT_Handle_SmokeAlertOff` / `BT_Handle_MedAlertOff`):**
When the app sends a command containing both "OFF" and "SMOKE", the handler clears `Smoke_Alert_Flag` from `g_alarm_flags`, resets `g_smoke_ignore_counter` to the ignore threshold (prevents immediate re-trigger), and if the current state is `STATE_SMOKE_ALERT`, forces `g_sys_state` back to `STATE_MAIN_MENU`. The medication equivalent does the same for `Med_Alert_Flag`. This means a nurse can dismiss robot alarms from their phone without physically touching the robot.

**Transmitting packets (`BT_TxTask` + `BT_PeriodicTask`):**
The TX side uses a flat byte buffer in RAM (`bt_tx_buffer`, 192 bytes). Packets are assembled in-place by calling:
*   `BT_StartPacket`     -> resets `bt_tx_len` and `bt_tx_index` to 0
*   `BT_AppendString`    -> copies a null-terminated string from flash into `bt_tx_buffer` byte by byte
*   `BT_AppendU32`       -> converts a 32-bit integer to decimal ASCII digits using `UDIV`/`MLS` (digits are built in reverse order into `bt_num_buffer`, then copied forward)
*   `BT_AppendChar`      -> appends a single character, always keeps the buffer null-terminated

`BT_TxTask` sends the assembled packet by polling `USART_SR_TXE` (Transmit Empty) before writing each byte to `USART_DR`. Critically, it calls `BT_RxTask` on every iteration of the TX wait loop — so incoming joystick commands are never dropped while a vitals packet is being sent out.

**`BT_PeriodicTask` — the scheduler for outgoing packets:**
Every main loop call:
1. Run `BT_TxTask` (drain any pending bytes).
2. If TX buffer is idle:
   a. `BT_CheckMedEvent`   -> if `sys_state` just left `STATE_MED_DISPENSE`, queue `"TYPE=MED_EVENT,...,STATUS=DISPENSED\r\n"`.
   b. `BT_CheckSmokeAlert` -> if `Smoke_Alert_Flag` is set and 5000ms since last alert TX, queue `"TYPE=ALERT,...,SMOKE=<level>\r\n"`.
   c. Every 250ms: `BT_QueueVitals` -> queue full vitals packet.

**Vitals packet format (sent every 250ms):**
`TYPE=VITALS,PATIENT=001,BPM=<bpm>,SPO2=<spo2>,BREATH=<breath>,SMOKE=<smoke>,MED=<timer>,ALERT=<NONE|SMOKE_DETECTED|MED_ALERT|SMOKE_AND_MED>\r\n`

All numeric values (`g_bpm`, `g_spo2`, `g_breath_level`, `g_smoke_level`, `g_med_timer`) are read directly from shared RAM and converted to decimal ASCII on the fly by `BT_AppendU32`. The `ALERT` field combines both alarm flags with bitwise AND checks to produce one of four string values.

**Tricky part — `BT_AppendU32` digit reversal:** The standard decimal conversion (`% 10` loop) naturally produces digits in LSB-first order (least significant digit first). The function writes them into `bt_num_buffer` (12 bytes) in that reversed order, tracking the count in `R5`, then copies them out in reverse to get the correct string. Special-casing 0 is also required because the loop would exit immediately and produce an empty string otherwise.

**Tricky part — `LTORG` placement:** Every large function in `bluetooth.s` ends with `ALIGN` + `LTORG`. Without this, the assembler's literal pool (used for `LDR R0, =some_address` loads) can exceed 4KB distance from the instruction, causing an `A1284E` assembler error. Since this file is large and uses many address literals, `LTORG blocks` are mandatory after every ~30–50 instructions.


---

### 📏 Ultrasonic Driver (`ultrasonic.s`)

**What this file does:** Drives the HC-SR04 sensor to measure distance to obstacles. Uses **TIM5 as a µs stopwatch** to measure the echo pulse duration, then converts it to centimeters.

**Initialization (`HCSR04_Init`):**

1. Enable GPIOA clock. Enable TIM5 clock via `RCC_APB1ENR` bit 3.
2. Set `PA12` as output (Trig), `PA15` as input (Echo).
3. Ensure PA12 starts LOW (idle state).
4. Configure TIM5: PSC=15 → 1 µs ticks, ARR=0xFFFFFFFF (32-bit free-running), start with `TIM_CR1 = 1`.

**Reading distance (`HCSR04_Read`):**

```
1. Pulse PA12 HIGH for ~100 loop cycles (≈10 µs) then LOW.
2. Wait for PA15 (Echo) to go HIGH — with a 10,000-count timeout.
3. Reset TIM5_CNT to zero (start stopwatch).
4. Wait for PA15 to go LOW — with a 0x20000-count timeout.
5. Read TIM5_CNT = echo duration in microseconds.
6. Distance (cm) = duration / 58
   (derived from: distance = (duration × speed_of_sound) / 2
                           = (duration × 0.0343 cm/µs) / 2 ≈ duration / 58)
```

Returns **999** on either timeout, which the motion module treats as "no obstacle detected" to avoid false stops.

**Tricky part:** The two separate timeouts (one for Echo going HIGH, one for Echo going LOW) are intentional. If only one timeout covered the whole measurement, a long echo from a far object would time out incorrectly. The counter is reset **only after Echo goes HIGH**, so only the actual echo duration is measured, not the sensor's internal processing delay.

---

### ⚓ IR Station Alignment Driver (`ir_stations.s`)

**What this file does:** Implements a non-blocking, debounced bedside/charging station detection system using an active-low infrared receiver module connected to `PB13`. This allows the robot to align with and dock at bedside locations to deliver clinical care.

**Initialization (`StationIR_Init`):**
1. Clear the local variables `station_debounce_cnt` and `g_station_detected` in RAM to zero.
2. Enable the clock for GPIOB (where `STATION_IR_PORT` is `GPIOB_BASE`) by calling `GPIO_EnableClock`.
3. Configure `PB13` (`STATION_IR_PIN`) as a digital input by calling `GPIO_ConfigInput`.

**Debounced Detection Logic (`StationIR_Update`):**
Called frequently in the main scheduler loop (via `Main_BackgroundTasks`). It implements a 5-sample consecutive debounce filter to filter out ambient infrared noise:
```assembly
; Read the pin and invert it since the IR sensor output is active-LOW (0 = active/detected)
LDR     R0, =STATION_IR_PORT
MOVS    R1, #STATION_IR_PIN
BL      GPIO_ReadPin
EOR     R0, R0, #1              ; Invert logic (0 -> 1 = detected, 1 -> 0 = not detected)
```
*   If the current pin state matches the globally stored status (`g_station_detected`), the debounce counter (`station_debounce_cnt`) is reset to `0`.
*   If the pin state differs from the current global status, the debounce counter is incremented by `1`.
*   When the debounce counter reaches `DEBOUNCE_THRESHOLD = 5`, it toggles the global state variable `g_station_detected` to the new stable reading and resets the counter to `0`.

**Checking detection state (`StationIR_IsDetected`):**
Returns the debounced state stored in `g_station_detected` (returns `1` if the robot is aligned at a station, `0` if not) in register `R0`.

**Tricky part — Active-Low Signal & Ambient Noise Filtering:** Since the sensor output is active-low (pulls to `0` when sensing an IR beacon), raw readings must be inverted with `EOR R0, R0, #1`. Without the 5-sample debounce verification window, ambient light fluctuations in a hospital corridor or sensor jitter would trigger false stops, causing the robot to dock prematurely.



## 📂 File-by-File Technical Deep Dive

Every source file in the repository corresponds to a modular component of the robot's hardware or logical flow. Below is the full file-by-file breakdown highlighting the logic and registers utilized.

### 1. Core System Files

*   **`core/main.s`**:
    *   *Purpose*: The primary scheduler and initialization module.
    *   *Logic*: Performs memory sweeps during boot (`Main_InitGlobals`), calls setup subroutines, and sets up a $1\text{ms}$ metronome interrupt using the **SysTick** timer reload register. It schedules non-blocking checks in a loop, routes states, and throttles visual drawing refreshes.
*   **`core/constants.s`**:
    *   *Purpose*: Hardware and state symbol definitions.
    *   *Logic*: Defines assembly constants (`EQU`) for peripheral addresses (RCC, GPIO, ADC, TIM, USART, SPI), TFT color profiles, state indices, and key codes. Contains no executable code to save memory.
*   **`core/global.s`**:
    *   *Purpose*: Declares shared variables in RAM.
    *   *Logic*: Declares 32-bit aligned variables (using the `SPACE 4` command) within the `VARIABLES` SRAM read-write data section. These variables are `EXPORT`ed for project-wide visibility.
*   **`core/gpio.s`**:
    *   *Purpose*: Low-level port controller library.
    *   *Logic*: Implements modular routines to enable peripheral clocks (`GPIO_EnableClock`) via `RCC_AHB1ENR`, configure inputs (`GPIO_ConfigInput`), configure outputs (`GPIO_ConfigOutput`), write pin states (`GPIO_WritePin`/`GPIO_ClearPin`) using the bit set/reset register (`GPIO_BSRR`), and read pin states (`GPIO_ReadPin`) using the input data register (`GPIO_IDR`).
*   **`core/motion_constants.s`**:
    *   *Purpose*: Static motion parameters.
    *   *Logic*: Contains `EQU` constants for motor speed PWM duty cycles (straight driving, slow turning, tank spin-in-place) and the 2-second Bluetooth manual control timeout fail-safe.
*   **`core/ui_state.s`**:
    *   *Purpose*: Core UI event router and state dispatcher.
    *   *Logic*: Processes raw IR keypresses, coordinates menu navigation, handles global alarms (fire and medication alert overrides), clears the TFT screen during transitions, and limits wave plotting update rates.

### 2. Clinical Feature Files

*   **`features/breathing.s`**:
    *   *Purpose*: Breathing waveform processor.
    *   *Logic*: Samples `PA0` via the ADC, tracks baseline drift to keep the signal centered, and amplifies the signal to display scrolling breathing waveforms on the TFT screen.
*   **`features/ir_stations.s`**:
    *   *Purpose*: Bedside call and alignment module.
    *   *Logic*: Monitors bedside IR call beacons. When a call signal is detected, the robot stops to administer clinical care.
*   **`features/max.s`**:
    *   *Purpose*: Vitals acquisition module using the MAX30102.
    *   *Logic*: Manages bit-banged I2C read and write transactions. It configures I2C registers, checks FIFO pointers, reads raw red and infrared channel data, filters raw values, and calculates BPM and blood oxygen saturation ($SpO_2$) when a finger is detected.
*   **`features/medicine.s`**:
    *   *Purpose*: Medication scheduler and dispenser actuator.
    *   *Logic*: Converts user input into a background countdown. Once the timer reaches zero, the system sounds an alarm, waits for user confirmation, and rotates a positional servo motor using step-by-step PWM pulses on `PA6` ($0^{\circ}$ at $500\text{ }\mu\text{s}$, $90^{\circ}$ at $1500\text{ }\mu\text{s}$, $180^{\circ}$ at $2500\text{ }\mu\text{s}$).
*   **`features/motion_bt.s`**:
    *   *Purpose*: Bluetooth driving command parser.
    *   *Logic*: Maps Bluetooth remote commands (forward, backward, spin turn, stop) to low-level motor drivers.
*   **`features/santizing.s`**:
    *   *Purpose*: Automatic gel dispenser module.
    *   *Logic*: Reads the active-low proximity sensor on `PA4`. When a hand is detected, the system activates the relay pump on `PA5` and runs a software delay loop to dispense gel.
*   **`features/smoke.s`**:
    *   *Purpose*: Fire alarm monitor.
    *   *Logic*: Samples the MQ-2 sensor on `PA1`. It implements a 30-second startup delay to allow the sensor to warm up, averages readings to prevent false alarms, and flags a system-wide fire alarm if sustained smoke is detected.
*   **`features/stress.s`**:
    *   *Purpose*: Heart rate volatility analyzer.
    *   *Logic*: Calculates a psychological stress score based on heart rate fluctuations:
        $$\text{Stress Score} = (\text{BPM} - 60) \times 2$$
        It adds subtle visual noise (`g_ms_ticks & 3`) to keep the graph display animated.
*   **`features/ultrasonic.s`**:
    *   *Purpose*: Collision avoidance module.
    *   *Logic*: Emits trigger pulses on trigger pin `PC15` and reads the return pulse duration on echo pin `PC14` to calculate the distance to obstacles for safety stops.
*   **`features/vein.s`**:
    *   *Purpose*: Sub-dermal vein finder.
    *   *Logic*: Samples the IR reflectance sensor on `PA7`. It averages **8 readings** to filter out noise, establishes a baseline from **128 readings**, and maps light absorption levels to dynamic buzzer beep frequencies to guide clinicians.

### 3. Peripheral Driver Files

*   **`Drivers/adc.s`**:
    *   *Purpose*: Bare-metal ADC1 driver.
    *   *Logic*: Enables the ADC1 peripheral clock, configures `PA0` and `PA1` pins for analog mode, and sets sample time sequences. It also configures the **Analog Watchdog (AWD)** to monitor channel 1 and trigger interrupts in the NVIC if readings exceed thresholds.
*   **`Drivers/i2c.s`**:
    *   *Purpose*: Bit-banged I2C Master driver.
    *   *Logic*: Implements standard I2C start, stop, write, read, ack, and nack operations by toggling the GPIO open-drain SDA (`PB9`) and SCL (`PB8`) lines.
*   **`Drivers/pwm.s`**:
    *   *Purpose*: Hardware Timer PWM driver.
    *   *Logic*: Sets up `TIM3` and `TIM4` registers to output PWM waveforms for the positional medicine servo and motor speed controllers.
*   **`Drivers/bluetooth.s` & `Drivers/bluetooth_buffer.s`**:
    *   *Purpose*: USART2 driver and ring buffers.
    *   *Logic*: Configures `PA2` (TX) and `PA3` (RX) to alternate functions. It implements non-blocking serial communication using USART interrupts and circular ring buffers in RAM.
*   **`Drivers/buzzer.s`**:
    *   *Purpose*: Beeper driver on `PB4`.
    *   *Logic*: Manages periodic buzzer beeps during active alarm states.
*   **`Drivers/tft_low.s`**:
    *   *Purpose*: ILI9341 register and SPI1 driver.
    *   *Logic*: Configures `PB0` (CS), `PB1` (DC), `PB2` (RST), and SPI1 alternate function pins (`PB3`/`PB5`). It configures the SPI1 register block, manages command and data modes, and initializes the ILI9341 display.
*   **`Drivers/tft_gfx.s`**:
    *   *Purpose*: Custom 2D graphics rendering engine.
    *   *Logic*: Defines subroutines to clear the screen, define active pixel coordinate windows, fill rectangular blocks, render ASCII characters using custom font arrays, plot coordinate vectors, and draw real-time scrolling wave graphs.
*   **`motion.s` (Root File)**:
    *   *Purpose*: Unified motor guidance manager.
    *   *Logic*: Reads the line tracking sensor array, determines direction adjustments using a decision tree, and controls motor inputs. It also implements safety checks that stop the robot if an obstacle is detected within $15\text{cm}$ or when bedside call beacons are aligned.

---

## 🔬 Core Feature Specifications & File Collaborations

Below is the implementation matrix for the robot's active features, detailing both high-level metaphors and bare-metal file collaborations.

### 1. Heart Rate & SpO₂ Monitor (MAX30102)

*   **Metaphor (ELIF5)**: When your heart beats, blood rushes through your finger and absorbs light. The oximeter sensor shines red and infrared lights into your skin to count how fast your pulse is going and see how clean your blood oxygen is!
*   **File Collaboration**:
    *   `Drivers/i2c.s`: Handles registers using bit-banged start, stop, and repeated reads.
    *   `features/max.s`: Reads data from the MAX30102 FIFO registers, implements a DC estimator filter, and calculates SpO₂ and BPM values.
    *   `core/main.s`: Calls `HR_ReadFIFO` inside the state dispatcher loop.
    *   `core/ui_state.s` & `Drivers/tft_gfx.s`: Processes numeric vitals to display and graph results.

---

### 2. Breathing Waveform Monitor

*   **Metaphor (ELIF5)**: Think of this as drawing a wave line on a chalkboard that tracks your breathing. To prevent the line from drifting off the board, a helper calculates the average room temperature (baseline) and automatically centers the drawing line.
*   **File Collaboration**:
    *   `Drivers/adc.s`: Samples analog thermistors on `PA0` (ADC Channel 0).
    *   `features/breathing.s`: Tracks dynamic baselines over 64-reading cycles, amplifies variations ($\times 8$), and centers coordinates around `2048`.
    *   `core/main.s`: Triggers `BREATHE_Update` in the super-loop.
    *   `core/ui_state.s` & `Drivers/tft_gfx.s`: Limits updates of the wave plotting graph to a stable $40\text{Hz}$ (25ms) refresh rate.

---

### 3. Volatility Stress Index

*   **Metaphor (ELIF5)**: When you are calm, your heart beats steadily. When you are excited or stressed, your heart rate increases. This script calculates how high your heart rate is compared to resting, and adds micro-movements on the screen to show live feedback.
*   **File Collaboration**:
    *   `features/max.s` & `core/global.s`: Generates heart-rate data (`g_bpm`).
    *   `features/stress.s`: Computes stress levels by scaling values over resting rates `(BPM - 60) * 2`.
    *   `core/main.s`: Calls `Stress_Update` continuously while in stress mode.
    *   `core/ui_state.s`: References `g_ms_ticks` to inject a $0\text{--}3\%$ variation mask, keeping graph lines dynamically animated.

---

### 4. Sub-Dermal Vein Finder

*   **Metaphor (ELIF5)**: Veins look like dark underground rivers under our skin. The robot shines an invisible flashlight (infrared) down. If it finds a river (vein), it absorbs the light, making the robot beep faster the closer it gets to the center.
*   **File Collaboration**:
    *   `Drivers/adc.s`: Configures `PA7` for analog mode, assigning an extended **480 clock cycle** sampling time to stabilize light sensors.
    *   `features/vein.s`: Integrates 8-sample averages to eliminate noise, calibrates a baseline using the first 128 readings, and calculates absorption differences.
    *   `core/main.s`: Executes `VEIN_Update` at regular intervals.
    *   `Drivers/buzzer.s`: Directs the buzzer on `PB4` to beep at frequencies matching sub-dermal density measurements ($200\text{ms}$ up to solid tones).

---

### 5. Body Temperature Monitor

*   **Metaphor (ELIF5)**: This is a digital thermometer that reads your body temperature and splits it into a whole number (like 37) and a fraction (like .5) to show on the screen.
*   **File Collaboration**:
    *   `Drivers/i2c.s`: Directs register read transactions to sensor memory space `0x1F` and `0x20`.
    *   `features/max.s`: Triggers one-shot temperature conversions in register `0x21` and handles hardware timeouts.
    *   `core/main.s`: Schedules temperature conversion tasks every $500\text{ms}$.
    *   `core/ui_state.s` & `Drivers/tft_gfx.s`: Formats and displays the calculated parameters as decimals on the LCD screen.

---

### 6. Servo Medication Dispenser

*   **Metaphor (ELIF5)**: The robot acts like a smart pillbox. You set a timer, and when it runs out, the robot rings a bell (buzzer) and turns a wheel (servo) to drop a pill into your hand!
*   **File Collaboration**:
    *   `core/ui_state.s`: Reads keypad inputs to set countdown times (stored in `g_med_timer`).
    *   `features/medicine.s`: Compares millisecond ticks `g_ms_ticks` to handle background timers and flags medication alerts (`Med_Alert_Flag`).
    *   `Drivers/pwm.s`: Configures `TIM3` on `PA6` for 50Hz PWM output, adjusting pulse widths ($500\text{--}2500\text{ }\mu\text{s}$) to sweep the dispensing servo $0^{\circ} \to 90^{\circ} \to 180^{\circ} \to 0^{\circ}$.
    *   `Drivers/buzzer.s` & `core/main.s`: Directs the buzzer on `PB4` to sound alerts and handles user confirmation inputs.

---

### 7. Environmental Smoke Alert

*   **Metaphor (ELIF5)**: If the robot smells smoke, it counts to 15 to make sure it's not just a false alarm (like a blown candle), then sounds a fire alarm and switches the screen to a warning display.
*   **File Collaboration**:
    *   `Drivers/adc.s`: Sets up ADC1 Analog Watchdog limits on channel 1 (MQ-2) to trigger high-priority interrupts (`ADC_IRQHandler`) when readings exceed `3000`.
    *   `features/smoke.s`: Handles startup warm-ups (150 readings) and counts consecutive high samples (15 readings over 3 seconds) to prevent false alerts.
    *   `core/main.s` & `core/ui_state.s`: Renders full-screen fire alarms and handles user snooze commands.
    *   `Drivers/buzzer.s`: Drives periodic beeps on `PB4` until the sensor reading drops below `2000`.

---

### 8. IR Hand Sanitizer

*   **Metaphor (ELIF5)**: When you place your hand under the sensor, it blocks a light beam. The robot detects this and turns on a pump to dispense sanitizer, then turns it off.
*   **File Collaboration**:
    *   `core/main.s`: Initializes sanitizer ports and runs update tasks in the background.
    *   `features/santizing.s`: Polls the active-low proximity sensor on `PA4`. When triggered, it turns on the relay pump output on `PA5` and runs a software delay loop before turning it off.

---

### 9. Landolt C Vision Test

*   **Metaphor (ELIF5)**: The robot displays a circle with a small gap on the screen (like a letter "C"). You press arrow buttons on the remote to point to where the gap is. If you get it right, the circle gets smaller and smaller!
*   **File Collaboration**:
    *   `Drivers/ir_driver.s`: Decodes directional remote commands (`KEY_UP`/`KEY_DOWN`/`KEY_LEFT`/`KEY_RIGHT`) via `PB10` falling-edge interrupts.
    *   `core/ui_state.s`: Compares remote button inputs to randomized optotype gap positions, calculates correct scores, and adjusts Landolt C chart sizes.
    *   `Drivers/tft_gfx.s`: Renders the high-contrast Landolt C rings onto coordinates on the LCD.

---

### 10. Autonomous Line-Tracking Guidance

*   **Metaphor (ELIF5)**: The robot acts like a toy train on a track. It uses three light sensors underneath to watch the floor. If it drifts too far left or right, it adjusts its wheels to stay on the line. If it loses the line entirely, it remembers where it last saw it and turns back!
*   **File Collaboration**:
    *   `core/gpio.s`: Configures `PB12` (Left), `PB15` (Center), and `PB14` (Right) as digital inputs.
    *   `motion.s`: Reads tracking inputs, processes turn memory states (`Last_Turn`), and stops if the ultrasonic sensor registers an obstacle within $15\text{ cm}$.
    *   `Drivers/pwm.s`: Directs `TIM4` registers to output correct PWM speeds to the DC motors.

---

### 11. Mobile App Bluetooth Override

*   **Metaphor (ELIF5)**: Usually, the robot drives itself. But if you connect your phone over Bluetooth, you can drive it like a remote-controlled car! If you close the app, the robot safely stops and goes back to tracking the line.
*   **File Collaboration**:
    *   `Drivers/bluetooth.s` & `Drivers/bluetooth_buffer.s`: Buffers serial streams via USART2 interrupts and maps them to directional variables.
    *   `features/motion_bt.s`: Captures mobile remote flags (joystick steps) and triggers a 2-second timeout stopwatch if communications are lost.
    *   `motion.s`: Bypasses autonomous line tracking and hands control over to Bluetooth command inputs when manual mode is active.

---

### 12. Bedside IR Station Call-Docking Feature

*   **Metaphor (ELIF5)**: Imagine the robot is a mail carrier. When a patient clicks a calling button at their bedside, it turns on an invisible beacon (Infrared light). The robot is drawn to this light, navigates to the bedside, and stops to deliver medication.
*   **File Collaboration**:
    *   `core/constants.s` & `core/gpio.s`: Configures pin `PB13` (`STATION_IR_PIN`) as a digital input.
    *   `features/ir_stations.s`: Monitors sensor inputs on `PB13`. It inverts the active-low signal and runs a 5-cycle debounce filter to set `g_station_detected`.
    *   `core/main.s`: Calls `StationIR_Update` on every super-loop cycle.
    *   `motion.s`: Checks the status of `g_station_detected`. If active (alignment beacon detected), the guidance loop calls `MOT_StopNow` to halt the DC motors, docking the robot at the patient's bedside.

---

### 🔌 Bedside IR Beacon Selection Circuit — Hardware Deep Dive

The challenge: a hospital ward may have **multiple bedsides**, but the robot must always dock at exactly **one** at a time. Rather than adding another microcontroller to arbitrate, a fully passive hardware circuit handles this using three inexpensive components.

#### The Problem It Solves

If two patients press their call buttons simultaneously, two IR beacons would emit at once. The robot's single IR receiver on `PB13` cannot tell them apart — it would detect a combined signal and navigate ambiguously between the two stations. The circuit ensures this situation is physically impossible: **only one IR transmitter can be powered at any moment**, regardless of how many buttons are pressed.

#### Components

| Component | Part | Role |
|-----------|------|------|
| **Latch push-buttons** | Momentary latching switches | Patient calls the robot by pressing and holding their bedside button |
| **3-to-8 decoder** | 74HC238 | Converts the 3-bit binary station address into a single active output line |
| **Isolation diodes** | Signal diodes (1N4148) | Prevent reverse current and cross-triggering between stations |
| **IR LED transmitters** | 940nm IR LEDs | Emit the infrared beacon that the robot detects on `PB13` |

#### How It Works — Step by Step

**Step 1 — Patient presses a latch button.**
Each bedside has a latching push-button. When pressed, it stores the call request mechanically (stays pressed until reset). The button outputs connect to the `A`, `B`, `C` select lines of the 74HC238 decoder, encoding which station is calling as a 3-bit binary number (Station 1 = `001`, Station 2 = `010`, Station 3 = `011`, etc.).

**Step 2 — The 74HC238 decoder activates exactly one output.**
The decoder reads the 3-bit address on its select lines and pulls exactly one of its eight outputs (`Y0`–`Y7`) HIGH. All other outputs remain LOW. This is the core hardware guarantee — the decoder's combinational logic makes it physically impossible for two outputs to be HIGH simultaneously for the same select combination.

**Step 3 — Diode isolation routes power to one IR transmitter.**
Each decoder output (`Y0`–`Y7`) connects to one IR LED transmitter through a series diode. The diodes serve two purposes:
- **Forward direction**: current flows from the active decoder output through the diode to power the IR LED.
- **Reverse direction**: the diode blocks any back-current from flowing from one output into another, preventing cross-triggering where an active LED on Y1 could inadvertently feed current back into Y2's circuit.

**Step 4 — The active IR beacon emits.**
Only the one IR LED connected to the active decoder output has a complete current path and emits infrared light at 940nm. All other IR LEDs remain off.

**Step 5 — The robot detects and docks.**
The robot's `PB13` IR receiver module sees the single active beacon. `StationIR_Update` debounces the signal over 5 samples and sets `g_station_detected = 1`. The `motion.s` guidance loop calls `MOT_StopNow`, halting the robot precisely at that bedside station.

#### Why This Design Was Chosen

**No microcontroller needed.** The entire arbitration is handled combinationally by the 74HC238. This removes firmware complexity, eliminates interrupt latency, and reduces BOM cost significantly.

**Deterministic priority.** If multiple buttons are pressed simultaneously, the 74HC238 selects based on the binary value present on its select lines (whichever button combination produces the lowest or highest address wins). This gives predictable, repeatable behavior in a multi-patient scenario.

**Diodes as one-way valves.** The diode network is the safety layer. Without diodes, an active HIGH on `Y1` could flow backward through the IR LED of station 2 and into the `Y2` output pin of the decoder — potentially damaging the IC or falsely illuminating two LEDs. The diodes make each output's power path strictly one-directional.

**Hospital-safe single-source guarantee.** The robot always has exactly one docking target. This prevents ambiguous navigation in multi-room environments and ensures medication is delivered to the correct patient.

#### Circuit Truth Table (74HC238 select lines → active IR beacon)

| Station | Button Address (C B A) | Active Decoder Output | IR Beacon |
|---------|------------------------|----------------------|-----------|
| Station 1 | `0 0 1` | Y1 | LED 1 ON |
| Station 2 | `0 1 0` | Y2 | LED 2 ON |
| Station 3 | `0 1 1` | Y3 | LED 3 ON |
| Station 4 | `1 0 0` | Y4 | LED 4 ON |
| Station 5 | `1 0 1` | Y5 | LED 5 ON |
| Station 6 | `1 1 0` | Y6 | LED 6 ON |
| Station 7 | `1 1 1` | Y7 | LED 7 ON |
| None / Reset | `0 0 0` | Y0 (unused) | All LEDs OFF |

#### Proteus Simulation

> ![IR Station Alignment Hardware Simulation](imgs/ir_station_sim.jpg)
>
> **Figure:** Proteus simulation of the low-cost IR bedside selection circuit. Latch buttons feed the `A/B/C` select lines of the 74HC238 decoder. The single active output powers one IR LED through a diode, while all other LEDs remain off. The robot's receiver on `PB13` picks up the isolated beacon signal.

---

## 📱 Mobile App Control

The robot is controlled via the custom **RoboCare Mobile App** — a full-featured Android application for patient monitoring, robot motion control, and remote alert management over Bluetooth (HC-05 / USART2).

**[▶ Download RoboCare APK (Google Drive)](https://drive.google.com/file/d/1s6VO7PZKef49Cyw4DefM6DDQRT3lJbKn/view?usp=sharing)**

---

### 📸 App Screenshots

| Home Screen | Patient List | Vitals Dashboard | Motion Control |
|:-----------:|:------------:|:----------------:|:--------------:|
| ![Home Screen](imgs/app1.jpg) | ![Patient List](imgs/app2.jpg) | ![Vitals Dashboard](imgs/app3.jpg) | ![Motion Control](imgs/app4.jpg) |

**Home Screen** — Connect to HC-05 via Bluetooth, navigate to Patients, Bluetooth settings, or Motion Control.

**Patient List** — Add, edit, and delete patient profiles (name, ID, room number). Tap a patient to begin live monitoring.

**Vitals Dashboard** — Live BPM, SpO₂, Breathing level, Smoke level, Medication timer, and Alert status updated every 250ms from the robot's USART2 vitals stream. Save readings to patient history.

**Motion Control** — Full D-Pad joystick to drive the robot manually. Supports Forward, Backward, Left, Right, Stop, and toggle between Phone Control and autonomous Line Tracker mode.

---

### 🔑 App Features

| Feature | Description |
|---------|-------------|
| **Bluetooth Connection** | Pair and connect to HC-05 module directly from the app |
| **Patient Management** | Add, edit, and delete patient profiles (Name, ID, Room) |
| **Live Vitals Dashboard** | Real-time BPM, SpO₂, Breath, Smoke level, Med timer, and Alert status |
| **Save Readings** | Persist vitals snapshots per patient with history log |
| **Motion Control** | D-Pad joystick to drive the robot (Forward, Back, Left, Right, Stop) |
| **Phone / Line Mode** | Switch robot between manual phone control and autonomous line tracking |
| **Remote Alert Dismiss** | Dismiss smoke and medication alerts over Bluetooth from the app |
| **Virtual Keypad** | Send UI navigation keys (0–9, A–D, CAM_UP/DOWN/LEFT/RIGHT) to control all robot screens remotely |

---

### 📡 Bluetooth Command Protocol

The app communicates with the robot over USART2 at **9600 baud** via the HC-05 module. Commands are plain ASCII strings terminated with `\r\n`.

**Motion Commands** (parsed in `motion_bt.s` / `bluetooth.s`):

| Command String | Action |
|----------------|--------|
| `DIR=FWD` | Move Forward |
| `DIR=BACK` | Move Backward |
| `DIR=LEFT` | Spin Left |
| `DIR=RIGHT` | Spin Right |
| `DIR=STOP` | Stop Motors |
| `MODE=PHONE` | Enter manual phone-control mode |
| `MODE=LINE` | Resume autonomous line tracking |
| `OFF,SMOKE` | Dismiss active smoke alert |
| `OFF,MED` | Dismiss active medication alert |

**Virtual Keypad Commands** (parsed via `BT_Handle_UIKey` in `bluetooth.s`):

| Command String | Key Injected | Effect |
|----------------|-------------|--------|
| `CMD=UI,KEY=0` … `KEY=9` | `KEY_0` … `KEY_9` | Navigate menus / select features |
| `CMD=UI,KEY=A` … `KEY=D` | `KEY_A` … `KEY_D` | Function keys |
| `CMD=UI,KEY=CAM_UP` | `KEY_UP` | D-Pad Up (Vision/Vein/Stress modes) |
| `CMD=UI,KEY=CAM_DOWN` | `KEY_DOWN` | D-Pad Down |
| `CMD=UI,KEY=CAM_LEFT` | `KEY_LEFT` | D-Pad Left |
| `CMD=UI,KEY=CAM_RIGHT` | `KEY_RIGHT` | D-Pad Right |

The `CAM_` prefix on directional keys ensures they **do not collide** with the robot's `DIR=LEFT/RIGHT` motion commands. The parser checks for `CMD=UI` first, routes through `BT_Handle_UIKey`, and stores the result in `g_bt_ui_key_request`. The main loop's `Main_ProcessBTKeyInjection` then writes this into `g_keycode` — making a virtual keypad press indistinguishable from a physical IR remote press.

**Vitals Packet** (transmitted by the robot every 250 ms):
```
TYPE=VITALS,PATIENT=001,BPM=72,SPO2=98,BREATH=1840,SMOKE=120,MED=300,ALERT=NONE\r\n
```

---

### 🛠️ Assembly Integration: Bluetooth Virtual Keypad

The virtual keypad required coordinated changes across three assembly files to safely inject app D-Pad inputs into the robot's UI state machine without disturbing the motion command pipeline.

#### 1. `bluetooth_buffer.s` — New Global Variable

```assembly
; Add to EXPORT list:
EXPORT  g_bt_ui_key_request

; Add below g_bt_last_rx_tick:
g_bt_ui_key_request        DCD     0    ; KEY_x value from CMD=UI,KEY=... (0=none)
```

#### 2. `bluetooth.s` — Parser Extension

**A. New strings in `BT_RODATA`** (`CAM_` prefix prevents collision with `DIR=LEFT/RIGHT`):

```assembly
BT_TEXT_CMD_UI          DCB "CMD=UI",0
BT_TEXT_KEY_PREFIX      DCB "KEY=",0
BT_TEXT_KEY_UP          DCB "KEY=CAM_UP",0
BT_TEXT_KEY_DOWN        DCB "KEY=CAM_DOWN",0
BT_TEXT_KEY_LEFT        DCB "KEY=CAM_LEFT",0
BT_TEXT_KEY_RIGHT       DCB "KEY=CAM_RIGHT",0
BT_TEXT_KEY_0           DCB "KEY=0",0
; ... KEY=1 through KEY=9, KEY=A through KEY=D
```

**B. `BT_ParseLine` — New check (inserted after `MODE=LINE`, before `OFF`):**

```assembly
; 8. Check for CMD=UI,KEY=... (virtual keypad injection)
        LDR     R0, =bt_rx_buffer
        LDR     R1, =BT_TEXT_CMD_UI
        BL      BT_Contains
        CMP     R0, #1
        BEQ     BTP_UIKey

BTP_UIKey
        BL      BT_Handle_UIKey
        BL      BT_QueueACK
        B       BTP_Exit
```

**C. `BT_Handle_UIKey` subroutine** (place at the bottom of `bluetooth.s`, above `END`):

Checks multi-char keys first (`CAM_UP/DOWN/LEFT/RIGHT`), then single-char keys (`0–9`, `A–D`). Uses `BEQ.W` (forced 32-bit branch encoding) to prevent assembler out-of-range errors. Stores the matched `KEY_x` constant into `g_bt_ui_key_request`.

```assembly
BT_Handle_UIKey
        PUSH    {R4-R7, LR}
        ; Check CAM_UP first (multi-char, must precede single-char "U" check)
        LDR     R0, =bt_rx_buffer
        LDR     R1, =BT_TEXT_KEY_UP
        BL      BT_Contains
        CMP     R0, #1
        BEQ.W   BTUI_Up
        ; ... repeat for DOWN, LEFT, RIGHT, then 0-9, A-D
BTUI_Up
        MOVS    R4, #KEY_UP
        B       BTUI_Store
        ; ... other labels
BTUI_Store
        LDR     R5, =g_bt_ui_key_request
        STR     R4, [R5]
BTUI_Exit
        POP     {R4-R7, PC}
        ALIGN
        LTORG
```

#### 3. `main.s` — Key Injection into the Super Loop

```assembly
; Import the shared variable:
IMPORT  g_bt_ui_key_request

; Updated Main_Loop (add after BT_RxTask):
Main_Loop
        BL      BT_RxTask                       ; Pull Bluetooth bytes
        BL      Main_ProcessBTKeyInjection       ; ← Inject virtual keypad presses
        BL      Main_ProcessBluetoothCmd         ; Act on motion commands
        BL      Main_CheckIRInput                ; IR remote
        ; ... rest unchanged

; Injection subroutine (place below Main_BackgroundTasks):
Main_ProcessBTKeyInjection
        PUSH    {R4-R6, LR}
        LDR     R4, =g_bt_ui_key_request
        LDR     R5, [R4]
        CMP     R5, #0
        BEQ     MPBK_Exit                ; No pending key — skip
        LDR     R6, =g_keycode
        STR     R5, [R6]                 ; Inject into g_keycode (same as IR remote)
        MOVS    R5, #0
        STR     R5, [R4]                 ; Clear the request
MPBK_Exit
        POP     {R4-R6, PC}
```

> **Design note:** Writing into `g_keycode` means the virtual keypad press flows through exactly the same `UI_Handle_Input` dispatch path as a physical IR remote press — no duplicate state-machine logic required anywhere.

---


## 🙏 Acknowledgements

- **STMicroelectronics** — [STM32F401 Reference Manual](https://www.st.com/resource/en/reference_manual/dm00031020-stm32f405-415-stm32f407-417-stm32f427-437-and-stm32f429-439-advanced-arm-based-32-bit-mcus-stmicroelectronics.pdf)
- **Ilitek** — [ILI9341 Controller Datasheet](https://download.mikroe.com/documents/smart-displays/easytft/ILI9341-ILITEK.pdf)
- **MikroElektronika** — EasyMX Pro v7 board designs
- **Our Classmates and Partners** — This repository serves as a shared base for low-level microprocessor collaboration.

---

> *Built with ❤️ and ARM Assembly — no HAL libraries, no shortcuts, just registers.*
