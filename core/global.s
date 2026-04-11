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
		EXPORT g_smoke_ignore_counter	
		EXPORT 	g_med_wait_ui
		EXPORT 	g_ms_ticks  			
		EXPORT 	g_last_med_tick 
; --- System core globals ---
g_sys_state             SPACE   4       ; current top-level state
g_prev_state            SPACE   4       ; previous state, used to detect redraws
g_alarm_flags           SPACE   4       ; active alert bits
g_smoke_ignore_counter  SPACE  4
; --- Input / UI globals ---
g_keycode               SPACE   4       ; last decoded keypad key
g_med_timer             SPACE   4       ; medicine timer value
g_med_wait_ui            SPACE   4       ; short waiting-screen counter
g_ms_ticks               SPACE   4       ; increments every 1 ms
g_last_med_tick          SPACE   4       ; last second boundary for med timer
; --- Sensor data globals ---
g_smoke_level           SPACE   4       ; processed smoke value
g_breath_level          SPACE   4       ; processed breathing value
g_bpm                   SPACE   4       ; heart rate result
g_spo2                  SPACE   4       ; SpO2 result
g_hr_red_raw            SPACE   4       ; raw MAX30102 red sample
g_hr_ir_raw             SPACE   4       ; raw MAX30102 IR sample

; --- Heart-only processing state ---
g_hr_sample_count       SPACE   4       ; running sample counter
g_hr_last_beat_sample   SPACE   4       ; sample index of last detected beat
g_hr_prev_above         SPACE   4       ; previous threshold-cross state
g_hr_red_dc             SPACE   4       ; filtered red DC component
g_hr_ir_dc              SPACE   4       ; filtered IR DC component
g_hr_window_count       SPACE   4       ; SpO2 window sample count
g_hr_red_min            SPACE   4       ; window red minimum
g_hr_red_max            SPACE   4       ; window red maximum
g_hr_ir_min             SPACE   4       ; window IR minimum
g_hr_ir_max             SPACE   4       ; window IR maximum
g_warmup_cnt      	 	SPACE 4
g_snooze_cnt       		SPACE 4
; --- Motion / actuation globals ---
g_motion_state          SPACE   4       ; current motion mode / direction

        END