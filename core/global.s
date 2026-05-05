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
        
        EXPORT  g_motion_mode
        ; --- Vision Test globals (UPDATED) ---
        EXPORT  g_vision_level
        EXPORT  g_vision_ring_idx
        EXPORT  g_vision_level_score
        EXPORT  g_vision_results
        EXPORT  g_vision_dirs

        ; --- Heart-only processing globals ---
        EXPORT  g_hr_sample_count
        EXPORT  g_hr_last_beat_sample
        EXPORT  g_hr_prev_above
        EXPORT  g_hr_red_dc
        EXPORT  g_hr_ir_dc
        EXPORT  g_hr_window_count
        EXPORT  g_hr_red_min
        EXPORT  g_hr_red_max
        EXPORT  g_hr_ir_min
        EXPORT  g_hr_ir_max
        EXPORT  g_warmup_cnt
        EXPORT  g_snooze_cnt
        EXPORT  g_smoke_ignore_counter
        EXPORT  g_med_wait_ui
        EXPORT  g_ms_ticks
        EXPORT  g_last_med_tick

        ; --- IR globals ---
        EXPORT  g_ir_ready
        EXPORT  g_ir_raw_code

; --- System core globals ---
g_sys_state             SPACE   4
g_prev_state            SPACE   4
g_alarm_flags           SPACE   4
g_smoke_ignore_counter  SPACE   4

; --- Input / UI globals ---
g_keycode               SPACE   4
g_med_timer             SPACE   4
g_med_wait_ui           SPACE   4
g_ms_ticks              SPACE   4
g_last_med_tick         SPACE   4

; --- IR globals ---
g_ir_ready              SPACE   4       ; 1 when a fresh IR frame is decoded
g_ir_raw_code           SPACE   4       ; full 32-bit NEC code

; --- Sensor data globals ---
g_smoke_level           SPACE   4
g_breath_level          SPACE   4
g_bpm                   SPACE   4
g_spo2                  SPACE   4
g_hr_red_raw            SPACE   4
g_hr_ir_raw             SPACE   4

; --- Heart-only processing state ---
g_hr_sample_count       SPACE   4
g_hr_last_beat_sample   SPACE   4
g_hr_prev_above         SPACE   4
g_hr_red_dc             SPACE   4
g_hr_ir_dc              SPACE   4
g_hr_window_count       SPACE   4
g_hr_red_min            SPACE   4
g_hr_red_max            SPACE   4
g_hr_ir_min             SPACE   4
g_hr_ir_max             SPACE   4
g_warmup_cnt            SPACE   4
g_snooze_cnt            SPACE   4

; --- Motion / actuation globals ---
g_motion_state          SPACE   4

g_motion_mode           SPACE   4       ; 1=LINE, 2=PHONE
; --- Vision Test globals (UPDATED) ---
g_vision_level          SPACE   4   ; 0 to 4 (5 levels)
g_vision_ring_idx       SPACE   4   ; 0 to 2 (3 rings per level)
g_vision_level_score    SPACE   4   ; 0 to 3 (correct answers this level)
g_vision_results        SPACE   16  ; Stores right/wrong for rings
g_vision_dirs           SPACE   16  ; Stores direction for rings

        END