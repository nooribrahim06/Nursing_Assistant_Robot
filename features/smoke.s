;=============================================================================
; smoke.s
; Smoke detection logic – reads MQ2 via ADC, updates alarm flag.
;
; FIXED VERSION:
;   - ignores first warm-up iterations
;   - requires consecutive high readings before setting smoke alert
;   - uses lower clear threshold (hysteresis) to avoid flicker
;=============================================================================

        AREA    SMOKE_DATA, DATA, READWRITE
        ALIGN

smoke_warmup_counter    SPACE   4
smoke_high_counter      SPACE   4

        AREA    SMOKE_DETECT, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

        IMPORT  g_smoke_level
        IMPORT  g_alarm_flags
        IMPORT  ADC_Read

        EXPORT  Smoke_Check

;-----------------------------------------------------------------------------
; Tunable thresholds
;-----------------------------------------------------------------------------
SMOKE_THRESHOLD_SET     EQU     3500    ; set alert if >= this
SMOKE_THRESHOLD_CLEAR   EQU     3200    ; clear alert only if < this
SMOKE_WARMUP_COUNT      EQU     300     ; ignore first iterations after startup
SMOKE_CONFIRM_COUNT     EQU     8       ; require 8 consecutive highs

;=============================================================================
; Smoke_Check
;
; 1. Warm-up ignore at startup
; 2. Read PA1 / ADC1_IN1
; 3. Store latest value in g_smoke_level
; 4. Require repeated high readings before setting smoke alert
; 5. Use hysteresis to clear alert
;=============================================================================
Smoke_Check
        PUSH    {R2-R7, LR}

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

        ; during warm-up: still read/store smoke level, but force flag clear
        MOV     R0, #SNS_SMOKE_ADC
        BL      ADC_Read

        LDR     R1, =g_smoke_level
        STR     R0, [R1]

        LDR     R1, =g_alarm_flags
        LDR     R2, [R1]
        BIC     R2, R2, #Smoke_Alert_Flag
        STR     R2, [R1]

        ; reset consecutive-high counter too
        LDR     R1, =smoke_high_counter
        MOVS    R2, #0
        STR     R2, [R1]

        B       Smoke_Done

; ------------------------------------------------------------
; 2) Real read after warm-up
; ------------------------------------------------------------
Smoke_DoRead
        MOV     R0, #SNS_SMOKE_ADC
        BL      ADC_Read               ; R0 = ADC value

        ; store latest reading
        LDR     R1, =g_smoke_level
        STR     R0, [R1]

        ; current alarm flags
        LDR     R5, =g_alarm_flags
        LDR     R6, [R5]

        ; ------------------------------------------------------------
        ; 3) If smoke alert already active, clear only below lower threshold
        ; ------------------------------------------------------------
        TST     R6, #Smoke_Alert_Flag
        BEQ     Smoke_CheckSetPath

        LDR     R3, =SMOKE_THRESHOLD_CLEAR
        CMP     R0, R3
        BLO     Smoke_ClearAlarm

        ; keep alert active
        B       Smoke_Done

; ------------------------------------------------------------
; 4) If smoke alert not active, require consecutive highs to set
; ------------------------------------------------------------
Smoke_CheckSetPath
        LDR     R3, =SMOKE_THRESHOLD_SET
        CMP     R0, R3
        BLO     Smoke_ResetCounterOnly

        ; value is high -> increment counter
        LDR     R1, =smoke_high_counter
        LDR     R2, [R1]
        ADDS    R2, R2, #1
        STR     R2, [R1]

        LDR     R3, =SMOKE_CONFIRM_COUNT
        CMP     R2, R3
        BLO     Smoke_Done

        ; confirmed high repeatedly -> set smoke alert
        ORR     R6, R6, #Smoke_Alert_Flag
        STR     R6, [R5]
        B       Smoke_Done

; ------------------------------------------------------------
; 5) Below set threshold while not active -> just reset counter
; ------------------------------------------------------------
Smoke_ResetCounterOnly
        LDR     R1, =smoke_high_counter
        MOVS    R2, #0
        STR     R2, [R1]
        B       Smoke_Done

; ------------------------------------------------------------
; 6) Clear active smoke alert
; ------------------------------------------------------------
Smoke_ClearAlarm
        BIC     R6, R6, #Smoke_Alert_Flag
        STR     R6, [R5]

        ; also reset consecutive-high counter
        LDR     R1, =smoke_high_counter
        MOVS    R2, #0
        STR     R2, [R1]

Smoke_Done
        POP     {R2-R7, PC}

        ALIGN
        END