;=============================================================================
; breathing.s
; Breathing input processing for analog sensor on PA0 / ADC channel 0
;
; Output:
;   g_breath_level = centered waveform value
;   2048 = midline
;   >2048 = one side
;   <2048 = other side
;=============================================================================

        AREA    BREATH_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

        EXPORT  BREATHE_Init
        EXPORT  BREATHE_Update

        IMPORT  ADC_Read
        IMPORT  g_breath_level
        IMPORT  g_ms_ticks

; ================= DATA =================
        AREA    BREATH_DATA, DATA, READWRITE
        ALIGN
breath_baseline     SPACE   4
breath_started      SPACE   4
breath_filtered     SPACE   4
breath_last_tick    SPACE   4

        AREA    BREATH_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

;=============================================================================
; BREATHE_Init
;=============================================================================
BREATHE_Init
        PUSH    {R0-R2, LR}

        LDR     R0, =breath_baseline
        MOVS    R1, #0
        STR     R1, [R0]

        LDR     R0, =breath_started
        STR     R1, [R0]

        LDR     R0, =breath_filtered
        STR     R1, [R0]

        ; start UI at center line
        LDR     R0, =g_breath_level
        LDR     R1, =2048
        STR     R1, [R0]

        POP     {R0-R2, PC}

;=============================================================================
; BREATHE_Update
; Reads PA0 and generates a centered waveform around 2048.
;=============================================================================
BREATHE_Update
        PUSH    {R1-R7, LR}

        ; Limit update rate to ~40Hz (25ms)
        LDR     R1, =g_ms_ticks
        LDR     R2, [R1]
        LDR     R3, =breath_last_tick
        LDR     R4, [R3]
        SUBS    R5, R2, R4
        CMP     R5, #25
        BLO     BU_Skip
        STR     R2, [R3]

        ; ------------------------------------------------------------
        ; 1) Read analog breathing signal from PA0 / ADC channel 0
        ; ------------------------------------------------------------
        MOVS    R0, #SNS_BREATH_ADC
        BL      ADC_Read
        MOV     R6, R0                  ; raw sample

        ; ------------------------------------------------------------
        ; 2) First sample initializes baseline and filter
        ; ------------------------------------------------------------
        LDR     R1, =breath_started
        LDR     R2, [R1]
        CMP     R2, #0
        BNE     HasBaseline

        LDR     R3, =breath_baseline
        STR     R6, [R3]

        LDR     R3, =breath_filtered
        STR     R6, [R3]

        MOVS    R2, #1
        STR     R2, [R1]

        LDR     R3, =g_breath_level
        LDR     R2, =2048
        STR     R2, [R3]

        POP     {R1-R7, PC}

HasBaseline
        ; ------------------------------------------------------------
        ; 3) Load baseline
        ; ------------------------------------------------------------
        LDR     R3, =breath_baseline
        LDR     R4, [R3]

        ; ------------------------------------------------------------
        ; 4) Slow baseline tracking
        ;    baseline += (sample - baseline) / 64
        ; ------------------------------------------------------------
        SUB     R5, R6, R4              ; signed delta
        ASRS    R2, R5, #6
        ADD     R4, R4, R2
        STR     R4, [R3]

        ; ------------------------------------------------------------
        ; 5) High-pass like signal around baseline
        ;    signal = sample - baseline
        ; ------------------------------------------------------------
        SUB     R5, R6, R4              ; signed signal

        ; ------------------------------------------------------------
        ; 6) Amplify signal
        ; ------------------------------------------------------------
        LSLS    R5, R5, #3              ; *8

        ; clamp signed range to about +/-1024
        LDR     R2, =1024
        CMP     R5, R2
        BLE     CheckNegClamp
        MOV     R5, R2

CheckNegClamp
        LDR     R2, =-1024
        CMP     R5, R2
        BGE     FilterSignal
        MOV     R5, R2

        ; ------------------------------------------------------------
        ; 7) Smooth signal
        ;    filtered += (signal - filtered) / 4
        ; ------------------------------------------------------------
FilterSignal
        LDR     R3, =breath_filtered
        LDR     R6, [R3]
        SUB     R2, R5, R6
        ASRS    R2, R2, #2
        ADD     R6, R6, R2
        STR     R6, [R3]

        ; ------------------------------------------------------------
        ; 8) Convert to centered UI value:
        ;    2048 + filtered
        ; ------------------------------------------------------------
        LDR     R5, =2048
        ADD     R6, R6, R5

        ; clamp to 0..4095
        CMP     R6, #0
        BGE     CheckUpper
        MOVS    R6, #0

CheckUpper
        LDR     R2, =4095
        CMP     R6, R2
        BLE     StoreValue
        MOV     R6, R2

StoreValue
        LDR     R3, =g_breath_level
        STR     R6, [R3]

BU_Skip
        POP     {R1-R7, PC}

        END