;=============================================================================
; global.s
; Shared RAM only
;=============================================================================

        AREA    VARIABLES, DATA, READWRITE
        ALIGN

        EXPORT  g_sys_state
        EXPORT  g_prev_state
        EXPORT  g_alarm_flags
        EXPORT  g_keycode
        EXPORT  g_med_timer
        EXPORT  g_smoke_level
        EXPORT  g_breath_level
        EXPORT  g_bpm
        EXPORT  g_spo2
        EXPORT  g_hr_red_raw
        EXPORT  g_hr_ir_raw
        EXPORT  g_motion_state

; --- System core globals ---
g_sys_state         SPACE   4       ; current top-level state
g_prev_state        SPACE   4       ; previous state, used to detect redraws
g_alarm_flags       SPACE   4       ; active alert bits

; --- Input / UI globals ---
g_keycode           SPACE   4       ; last decoded keypad key
g_med_timer         SPACE   4       ; medicine timer value

; --- Sensor data globals ---
g_smoke_level       SPACE   4       ; processed smoke value
g_breath_level      SPACE   4       ; processed breathing value
g_bpm               SPACE   4       ; heart rate result
g_spo2              SPACE   4       ; SpO2 result
g_hr_red_raw        SPACE   4       ; raw MAX30102 red sample
g_hr_ir_raw         SPACE   4       ; raw MAX30102 IR sample

; --- Motion / actuation globals ---
g_motion_state      SPACE   4       ; current motion mode / direction

        END