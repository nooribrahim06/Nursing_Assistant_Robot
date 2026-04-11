;=============================================================================
; main.s
; Smoke build + servo test build
;
; Keeps the existing smoke path working:
;   PA1  -> MQ2 analog input  (ADC1_IN1)
;   PB12 -> LED alarm output
;
; Adds servo test output:
;   PA6 -> sanitizing servo   (TIM3_CH1)
;   PA7 -> medicine servo     (TIM3_CH2)
;
; Notes:
;   - PWM_Init owns the timer/GPIO AF setup for PA6/PA7.
;   - Main_Wait_With_Smoke keeps Smoke_Check running while we wait for servo motion.
;=============================================================================

        AREA    MAIN_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

        EXPORT  __main
        EXPORT  Main_Entry

;-----------------------------------------------------------------------------
; Shared globals
;-----------------------------------------------------------------------------
        IMPORT  g_sys_state
        IMPORT  g_prev_state
        IMPORT  g_alarm_flags
        IMPORT  g_keycode
        IMPORT  g_med_timer
        IMPORT  g_smoke_level
        IMPORT  g_breath_level
        IMPORT  g_bpm
        IMPORT  g_spo2
        IMPORT  g_hr_red_raw
        IMPORT  g_hr_ir_raw
        IMPORT  g_motion_state

;-----------------------------------------------------------------------------
; External routines
;-----------------------------------------------------------------------------
        IMPORT  GPIO_EnableClock
        IMPORT  GPIO_ConfigOutput
        IMPORT  GPIO_WritePin
        IMPORT  GPIO_ClearPin
        IMPORT  ADC_Init
        IMPORT  Smoke_Check
        IMPORT  PWM_Init
        IMPORT  PWM_Set_Servo_Pos
		IMPORT  MOT_Init
        IMPORT  MOT_Update

;=============================================================================
; Entry point
;=============================================================================
__main
Main_Entry
        BL      Main_InitGlobals
        BL      Main_InitCore
        BL      Main_SetInitialState

;=============================================================================
; Superloop
; Runs a simple servo demo while still servicing smoke detection.
;=============================================================================
Main_Loop
        ; Always refresh smoke logic before each demo sequence step.
        BL      Smoke_Check
        BL      Main_AlarmTask

        ;-------------------------------------------------------------
        ; PA6 sanitizing servo: move to one end, then the other end.
        ;-------------------------------------------------------------
        LDR     R0, =1000
        MOVS    R1, #0                  ; 0 -> PA6 / sanitizing servo
        BL      PWM_Set_Servo_Pos
        LDR     R0, =220
        BL      Main_Wait_With_Smoke

        LDR     R0, =2000
        MOVS    R1, #0
        BL      PWM_Set_Servo_Pos
        LDR     R0, =220
        BL      Main_Wait_With_Smoke

        LDR     R0, =1500
        MOVS    R1, #0
        BL      PWM_Set_Servo_Pos
        LDR     R0, =180
        BL      Main_Wait_With_Smoke

        ;-------------------------------------------------------------
        ; PA7 medicine servo: continuous-rotation style test.
        ; 1500 = stop, >1500 one direction, <1500 opposite direction.
        ;-------------------------------------------------------------
        LDR     R0, =1700
        MOVS    R1, #1                  ; 1 -> PA7 / medicine servo
        BL      PWM_Set_Servo_Pos
        LDR     R0, =220
        BL      Main_Wait_With_Smoke

        LDR     R0, =1500
        MOVS    R1, #1
        BL      PWM_Set_Servo_Pos
        LDR     R0, =180
        BL      Main_Wait_With_Smoke

        LDR     R0, =1300
        MOVS    R1, #1
        BL      PWM_Set_Servo_Pos
        LDR     R0, =220
        BL      Main_Wait_With_Smoke

        LDR     R0, =1500
        MOVS    R1, #1
        BL      PWM_Set_Servo_Pos
        LDR     R0, =180
        BL      Main_Wait_With_Smoke

        B       Main_Loop


;=============================================================================
; Main_InitGlobals
;=============================================================================
Main_InitGlobals
        PUSH    {LR}

        LDR     R0, =g_sys_state
        MOVS    R1, #0
        STR     R1, [R0]

        LDR     R0, =g_prev_state
        MOVS    R1, #0
        STR     R1, [R0]

        LDR     R0, =g_alarm_flags
        MOVS    R1, #0
        STR     R1, [R0]

        LDR     R0, =g_keycode
        MOVS    R1, #KEY_NONE
        STR     R1, [R0]

        LDR     R0, =g_med_timer
        MOVS    R1, #0
        STR     R1, [R0]

        LDR     R0, =g_smoke_level
        MOVS    R1, #0
        STR     R1, [R0]

        LDR     R0, =g_breath_level
        MOVS    R1, #0
        STR     R1, [R0]

        LDR     R0, =g_bpm
        MOVS    R1, #0
        STR     R1, [R0]

        LDR     R0, =g_spo2
        MOVS    R1, #0
        STR     R1, [R0]

        LDR     R0, =g_hr_red_raw
        MOVS    R1, #0
        STR     R1, [R0]

        LDR     R0, =g_hr_ir_raw
        MOVS    R1, #0
        STR     R1, [R0]

        LDR     R0, =g_motion_state
        MOVS    R1, #MOTION_STOP
        STR     R1, [R0]

        POP     {PC}


;=============================================================================
; Main_InitCore
; Initializes the smoke build hardware, then starts PWM for the servos.
;=============================================================================
Main_InitCore
        PUSH    {LR}

        ; PB12 alarm LED
        LDR     R0, =GPIOB_BASE
        BL      GPIO_EnableClock

        LDR     R0, =GPIOB_BASE
        MOVS    R1, #LED_PIN
        BL      GPIO_ConfigOutput

        LDR     R0, =GPIOB_BASE
        MOVS    R1, #LED_PIN
        BL      GPIO_ClearPin

        ; Smoke sensor on PA1 / ADC1
        BL      ADC_Init

        ; Servo PWM on PA6 / PA7 and motor PWM on PB8 / PB9
        ;BL      PWM_Init
        BL 	MOT_Init
        ; Safe startup: center/stop both servos
        LDR     R0, =1500
        MOVS    R1, #0
        BL      PWM_Set_Servo_Pos

        LDR     R0, =1500
        MOVS    R1, #1
        BL      PWM_Set_Servo_Pos

        POP     {PC}


;=============================================================================
; Main_SetInitialState
; Keep the smoke-monitoring state exactly as before.
;=============================================================================
Main_SetInitialState
        PUSH    {LR}

        LDR     R0, =g_sys_state
        MOVS    R1, #STATE_SMOKE_ALERT
        STR     R1, [R0]

        LDR     R0, =g_prev_state
        LDR     R1, =STATE_INVALID
        STR     R1, [R0]

        POP     {PC}


;=============================================================================
; Main_AlarmTask
; PB12 follows Smoke_Alert_Flag.
;=============================================================================
Main_AlarmTask
        PUSH    {R2, LR}

        LDR     R0, =g_alarm_flags
        LDR     R2, [R0]

        TST     R2, #Smoke_Alert_Flag
        BNE     MAT_LedOn

MAT_LedOff
        LDR     R0, =GPIOB_BASE
        MOVS    R1, #LED_PIN
        BL      GPIO_ClearPin
        B       MAT_Done

MAT_LedOn
        LDR     R0, =GPIOB_BASE
        MOVS    R1, #LED_PIN
        BL      GPIO_WritePin

MAT_Done
        POP     {R2, PC}


;=============================================================================
; Main_Wait_With_Smoke
; In: R0 = outer wait count
; Keeps smoke detection alive while allowing time for servo motion.
;=============================================================================
Main_Wait_With_Smoke
        PUSH    {R4, R5, LR}

        MOV     R4, R0

MWWS_Outer
        CMP     R4, #0
        BEQ     MWWS_Done

        BL      Smoke_Check
        BL      Main_AlarmTask
		BL      MOT_Update
        LDR     R5, =12000
MWWS_Inner
        SUBS    R5, R5, #1
        BNE     MWWS_Inner

        SUBS    R4, R4, #1
        B       MWWS_Outer

MWWS_Done
        POP     {R4, R5, PC}


;=============================================================================
; Stub state handlers kept for future integration
;=============================================================================
Main_State_Sanitizing
        BX      LR

Main_State_HeartRate
        BX      LR

Main_State_Breathing
        BX      LR

Main_State_Motion
        BX      LR

Main_State_MedDispense
        BX      LR

Main_State_MedWaiting
        BX      LR

        ALIGN
        END
