; =====================================================================
; FILE: ir_station.s
; DESCRIPTION: Non-blocking, debounced IR Station Detection module.
; PIN: PB13 (Input)
; =====================================================================

        AREA    IRSTATION_DATA, DATA, READWRITE
        ALIGN
station_debounce_cnt    SPACE   4       ; Counter for debouncing

        AREA    IRSTATION_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

        EXPORT  StationIR_Init
        EXPORT  StationIR_Update
        EXPORT  StationIR_IsDetected

        IMPORT  GPIO_EnableClock
        IMPORT  GPIO_ConfigInput
        IMPORT  GPIO_ReadPin
        IMPORT  g_station_detected

STATION_IR_PORT     EQU     GPIOB_BASE

; Number of consecutive identical reads required to change state
DEBOUNCE_THRESHOLD  EQU     5

; =====================================================================
; StationIR_Init
; Configures the GPIO pin and resets variables.
; =====================================================================
StationIR_Init
        PUSH    {R4, LR}

        ; Initialize variables to 0
        MOVS    R0, #0
        LDR     R1, =station_debounce_cnt
        STR     R0, [R1]
        
        LDR     R1, =g_station_detected
        STR     R0, [R1]

        ; Configure GPIO
        LDR     R0, =STATION_IR_PORT
        BL      GPIO_EnableClock
        
        LDR     R0, =STATION_IR_PORT
        MOVS    R1, #STATION_IR_PIN
        BL      GPIO_ConfigInput

        POP     {R4, PC}

; =====================================================================
; StationIR_Update
; Must be called frequently (e.g., in Main_BackgroundTasks).
; Reads the pin and applies debounce logic.
; =====================================================================
StationIR_Update
        PUSH    {R4-R6, LR}

        LDR     R0, =STATION_IR_PORT
        MOVS    R1, #STATION_IR_PIN
        BL      GPIO_ReadPin
        EOR     R0, R0, #1              ; Invert: active-low sensor (0=detected -> 1)
        MOV     R4, R0                  ; R4 = Current pin state (1 = station present)

        ; Load debounce counter and current global state
        LDR     R5, =station_debounce_cnt
        LDR     R6, [R5]
        
        LDR     R1, =g_station_detected
        LDR     R2, [R1]

        ; If pin state matches current global state, reset debounce counter
        CMP     R4, R2
        BEQ     Reset_Debounce

        ; Pin state differs from current state, increment debounce counter
        ADDS    R6, R6, #1
        CMP     R6, #DEBOUNCE_THRESHOLD
        BLO     Save_Debounce

        ; Threshold reached: flip the global state and reset counter
        STR     R4, [R1]                ; Update g_station_detected
        MOVS    R6, #0                  ; Reset counter
        B       Save_Debounce

Reset_Debounce
        MOVS    R6, #0

Save_Debounce
        STR     R6, [R5]                ; Save debounce counter back to memory

        POP     {R4-R6, PC}

; =====================================================================
; StationIR_IsDetected
; Returns the current detection state in R0 (1 = detected, 0 = not).
; =====================================================================
StationIR_IsDetected
        LDR     R1, =g_station_detected 
        LDR     R0, [R1]
        BX      LR

        ALIGN
        END
 