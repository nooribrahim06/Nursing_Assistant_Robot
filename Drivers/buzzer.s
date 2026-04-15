;=============================================================================
; buzzer.s
; PB4 buzzer active ONLY while alert screen is currently shown:
;   - STATE_SMOKE_ALERT
;   - STATE_MED_ALERT
; No sound on main menu even if a flag still exists in background.
;=============================================================================
        GET     constants.s

        AREA    BUZZER_DATA, DATA, READWRITE
        ALIGN
buzzer_counter          SPACE   4

        AREA    BUZZER_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        IMPORT  g_sys_state
        IMPORT  GPIO_EnableClock
        IMPORT  GPIO_ConfigOutput
        IMPORT  GPIO_WritePin
        IMPORT  GPIO_ClearPin

        EXPORT  Buzzer_Init
        EXPORT  Buzzer_Update

BUZZER_BEEP_ON          EQU     60
BUZZER_BEEP_CYCLE       EQU     120

;-----------------------------------------------------------------------------
; Buzzer_Init
;-----------------------------------------------------------------------------
Buzzer_Init
        PUSH    {R0-R2, LR}

        LDR     R0, =GPIOB_BASE
        BL      GPIO_EnableClock

        LDR     R0, =GPIOB_BASE
        MOVS    R1, #BUZZER_PIN
        BL      GPIO_ConfigOutput

        LDR     R0, =GPIOB_BASE
        MOVS    R1, #BUZZER_PIN
        BL      GPIO_ClearPin

        LDR     R0, =buzzer_counter
        MOVS    R1, #0
        STR     R1, [R0]

        POP     {R0-R2, PC}

;-----------------------------------------------------------------------------
; Buzzer_Update
; ON only if current UI state is an alert screen.
;-----------------------------------------------------------------------------
Buzzer_Update
        PUSH    {R0-R7, LR}

        ; Read current system state
        LDR     R0, =g_sys_state
        LDR     R1, [R0]

        ; Allow buzzer only in visible alert states
        CMP     R1, #STATE_SMOKE_ALERT
        BEQ     BU_Active

        CMP     R1, #STATE_MED_ALERT
        BEQ     BU_Active

        ; Otherwise no buzzer
        B       BU_NoAlert

BU_Active
        LDR     R6, =buzzer_counter
        LDR     R7, [R6]

        ADDS    R7, R7, #1
        LDR     R0, =BUZZER_BEEP_CYCLE
        CMP     R7, R0
        BLT     BU_StoreCount
        MOVS    R7, #0

BU_StoreCount
        STR     R7, [R6]

        LDR     R0, =BUZZER_BEEP_ON
        CMP     R7, R0
        BGE     BU_TurnOff

BU_TurnOn
        LDR     R0, =GPIOB_BASE
        MOVS    R1, #BUZZER_PIN
        BL      GPIO_WritePin
        B       BU_Exit

BU_NoAlert
        LDR     R6, =buzzer_counter
        MOVS    R7, #0
        STR     R7, [R6]

BU_TurnOff
        LDR     R0, =GPIOB_BASE
        MOVS    R1, #BUZZER_PIN
        BL      GPIO_ClearPin

BU_Exit
        POP     {R0-R7, PC}

        ALIGN
        END