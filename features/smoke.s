;=============================================================================
; smoke.s
; Smoke detection logic - reads MQ2 via ADC, updates alarm flag.
;
; FIXES:
;   - 200ms time-gate on ADC reads (5 reads/sec only)
;   - 15 consecutive HIGH reads = 3 real seconds of sustained smoke
;   - counter reset when flag is SET -> dismiss can't re-trigger instantly
;   - hysteresis: needs ADC < 2000 to auto-clear
;=============================================================================

        AREA    SMOKE_DATA, DATA, READWRITE
        ALIGN

smoke_warmup_counter    SPACE   4
smoke_high_counter      SPACE   4
smoke_read_tick         SPACE   4   ; timestamp of last ADC read

        AREA    SMOKE_DETECT, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

        IMPORT  g_smoke_level
        IMPORT  g_alarm_flags
        IMPORT  g_sys_state
        IMPORT  g_pre_smoke_state
        IMPORT  g_smoke_ignore_counter
        IMPORT  g_ms_ticks
        IMPORT  ADC_Read

        EXPORT  Smoke_Check
        EXPORT  ADC_IRQHandler

;-----------------------------------------------------------------------------
; Tunable thresholds
; clean air -> lower ADC
; smoke     -> higher ADC
;-----------------------------------------------------------------------------
SMOKE_THRESHOLD_SET     EQU     3000    ; smoke if reading >= this
SMOKE_THRESHOLD_CLEAR   EQU     2000    ; clear only if reading < this (hysteresis)
SMOKE_WARMUP_COUNT      EQU     150     ; 150 reads * 200ms = 30-second sensor warm-up
SMOKE_CONFIRM_COUNT     EQU     15      ; 15 reads * 200ms/read = 3 seconds of real smoke
SMOKE_READ_INTERVAL_MS  EQU     200     ; only sample ADC every 200ms

;=============================================================================
; Smoke_Check 
;=======================================
;====================================== 
Smoke_Check
        PUSH    {R2-R7, LR}

        ; ------------------------------------------------------------
        ; 0) Time-gate: only read ADC once every 200ms
        ; ------------------------------------------------------------
        LDR     R0, =g_ms_ticks
        LDR     R7, [R0]
        LDR     R0, =smoke_read_tick
        LDR     R1, [R0]
        SUBS    R2, R7, R1
        LDR     R3, =SMOKE_READ_INTERVAL_MS
        CMP     R2, R3
        BLO     Smoke_Exit              ; not time yet, skip everything
        STR     R7, [R0]               ; update last-read tick

        ; ------------------------------------------------------------
        ; 1) Warm-up ignore
        ; ------------------------------------------------------------
        LDR     R0, =smoke_warmup_counter
        LDR     R1, [R0]
        LDR     R2, =SMOKE_WARMUP_COUNT
        CMP     R1, R2
        BHS     Smoke_DoRead

        ADDS    R1, R1, #1
        STR     R1, [R0]

        ; during warm-up: store 0 so bar stays green (sensor not yet stable)
        MOVS    R0, #0
        LDR     R1, =g_smoke_level
        STR     R0, [R1]

        LDR     R1, =g_alarm_flags
        LDR     R2, [R1]
        BIC     R2, R2, #Smoke_Alert_Flag
        STR     R2, [R1]

        LDR     R1, =smoke_high_counter
        MOVS    R2, #0
        STR     R2, [R1]

        B       Smoke_Exit

; ------------------------------------------------------------
; 2) Real read after warm-up
; ------------------------------------------------------------
Smoke_DoRead
        MOVS    R0, #SNS_SMOKE_ADC
        BL      ADC_Read               ; R0 = ADC value

        LDR     R1, =g_smoke_level
        STR     R0, [R1]

        LDR     R5, =g_alarm_flags
        LDR     R6, [R5]

        ; ------------------------------------------------------------
        ; 3) If alert already active: clear only when ADC drops LOW
        ; ------------------------------------------------------------
        TST     R6, #Smoke_Alert_Flag
        BEQ     Smoke_CheckSetPath

        LDR     R3, =SMOKE_THRESHOLD_CLEAR
        CMP     R0, R3
        BLO     Smoke_ClearAlarm       ; ADC < 2000 -> auto-clear

        ; still high -> keep alert active, nothing to do
        B       Smoke_Exit

; ------------------------------------------------------------
; 4) If alert not active: require 15 consecutive HIGH reads
; ------------------------------------------------------------
Smoke_CheckSetPath
        LDR     R3, =SMOKE_THRESHOLD_SET
        CMP     R0, R3
        BLO     Smoke_ResetCounterOnly ; below threshold -> reset counter

        ; value is high -> increment counter
        LDR     R1, =smoke_high_counter
        LDR     R2, [R1]
        ADDS    R2, R2, #1
        STR     R2, [R1]

        LDR     R3, =SMOKE_CONFIRM_COUNT
        CMP     R2, R3
        BLO     Smoke_Exit             ; not enough reads yet

        ; confirmed 15 consecutive HIGH reads -> set alert
        ORR     R6, R6, #Smoke_Alert_Flag
        STR     R6, [R5]

        ; CRITICAL FIX: reset counter so after dismiss it needs
        ; another full 15 high-reads (3 seconds) before re-triggering
        LDR     R1, =smoke_high_counter
        MOVS    R2, #0
        STR     R2, [R1]

        B       Smoke_Exit

; ------------------------------------------------------------
; 5) Normal reading while not active -> reset counter
; ------------------------------------------------------------
Smoke_ResetCounterOnly
        LDR     R1, =smoke_high_counter
        MOVS    R2, #0
        STR     R2, [R1]
        B       Smoke_Exit

; ------------------------------------------------------------
; 6) Clear active smoke alert (ADC dropped back below clear threshold)
; ------------------------------------------------------------
Smoke_ClearAlarm
        BIC     R6, R6, #Smoke_Alert_Flag
        STR     R6, [R5]

        LDR     R1, =smoke_high_counter
        MOVS    R2, #0
        STR     R2, [R1]

        ; Restore the UI state that was active before the smoke alert
        LDR     R1, =g_pre_smoke_state
        LDR     R2, [R1]
        LDR     R1, =g_sys_state
        LDR     R3, [R1]
        CMP     R3, #STATE_SMOKE_ALERT
        BNE     Smoke_Exit
        STR     R2, [R1]

        ; Store dismiss timestamp for UI cooldown
        LDR     R1, =g_smoke_ignore_counter
        LDR     R2, =g_ms_ticks
        LDR     R2, [R2]
        STR     R2, [R1]

Smoke_Exit
Smoke_Done
        POP     {R2-R7, PC}


;=============================================================================
; ADC_IRQHandler  (Analog Watchdog ISR)
; Only clears the hardware AWD flag - does NOT set Smoke_Alert_Flag
; to avoid bypassing warm-up and confirmation counter.
;=============================================================================
ADC_IRQHandler
        PUSH    {R0-R1, LR}

        LDR     R0, =ADC1_BASE
        LDR     R1, [R0, #ADC_SR]
        BIC     R1, R1, #ADC_SR_AWD
        STR     R1, [R0, #ADC_SR]

AWD_ISR_Exit
        POP     {R0-R1, PC}

        ALIGN
        LTORG
        END

