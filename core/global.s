; =====================================================================
; FILE: globals.s
; DESCRIPTION: Shared system variables in RAM
; =====================================================================

        AREA    VARIABLES, DATA, READWRITE
	EXPORT  g_sys_state
        EXPORT  g_prev_state
        EXPORT  g_bpm
        EXPORT  g_smoke_level
        EXPORT  g_alarm_flags
        EXPORT  g_med_timer
        EXPORT  g_keycode
        ALIGN

; --- System Core Globals ---
g_sys_state         SPACE   4           ; Current system operation mode
g_prev_state        SPACE   4           ; Previous mode for UI transitions
g_alarm_flags       SPACE   4           ; Bitmask for active system alerts[cite: 3]

; --- Input & UI Globals ---
g_keycode           SPACE   4           ; Last key pressed on 4x4 matrix[cite: 3]
g_med_timer         SPACE   4           ; User-defined medicine countdown[cite: 3]

; --- Sensor Data Globals ---
g_smoke_level       SPACE   4           ; Processed MQ2 analog value[cite: 3]
g_breath_level      SPACE   4           ; Processed breathing signal[cite: 3]
g_bpm               SPACE   4           ; Calculated Heart Rate (BPM)[cite: 3]
g_spo2              SPACE   4           ; Calculated SpO2 percentage[cite: 3]
g_hr_red_raw        SPACE   4           ; Raw MAX30102 Red LED data[cite: 3]
g_hr_ir_raw         SPACE   4           ; Raw MAX30102 IR LED data[cite: 3]

; --- Motion & Actuation Globals ---
g_motion_state      SPACE   4           ; Current movement direction/status[cite: 3]

        END