;=============================================================================
; main.s  –  Unified build
;
; TFT display  (via stolen tft_low.s – self-contained GPIO init):
;   PA2  = RS   PA3  = WR   PA4  = RD   PA5  = CS   PA12 = RST
;   PB0..PB7 = D0..D7
;
; Smoke sensor:
;   PA1  -> MQ2 analog input  (ADC1_IN1)
;
; LED alarm:
;   PB8  -> alarm LED  (moved OFF PB12 to avoid RST conflict)
;
; Servos:
;   PA6  -> sanitizing servo  (TIM3_CH1)
;   PA7  -> medicine servo    (TIM3_CH2)
;
; Keypad:
;   Rows  PA8..PA11  /  Cols PB10,PB13..PB15
;=============================================================================

        GET     constants.s

        AREA    MAIN_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        EXPORT  __main
        EXPORT  Main_Entry

;-----------------------------------------------------------------------------
; Globals
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

        IMPORT  TFT_Init
        IMPORT  UI_Update

        IMPORT  Keypad_Init
        IMPORT  Keypad_Scan

;-----------------------------------------------------------------------------
; LED is on PB8 (moved from PB12 which conflicts with TFT RST on PA12
; – same pin NUMBER 12 causes confusion; keep them on different numbers)
;-----------------------------------------------------------------------------
ALARM_LED_PIN   EQU     8       ; PB8

;=============================================================================
; Entry point
;=============================================================================
__main
Main_Entry
        BL      Main_InitGlobals
        BL      Main_InitCore
        BL      Main_SetInitialState
        BL      UI_Update               ; first full screen draw

;=============================================================================
; Superloop
;=============================================================================
Main_Loop
        BL      Keypad_Scan             ; fills g_keycode
        BL      UI_Update               ; redraws screen if state changed

        BL      Smoke_Check             ; updates g_smoke_level / g_alarm_flags
        BL      Main_AlarmTask          ; drives alarm LED from g_alarm_flags

        BL      Main_BackgroundTasks
        BL      Main_DispatchByState

        B       Main_Loop


;=============================================================================
; Main_InitGlobals – zero all shared RAM
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
;
; TFT_Init is self-contained – it calls TFT_GPIO_Init internally which
; enables GPIOA/GPIOB clocks and configures all TFT pins. Do NOT
; duplicate that work here.
;
; After TFT is up, init the alarm LED, ADC, PWM, and keypad.
;=============================================================================
Main_InitCore
        PUSH    {LR}

        ;------------------------------------------------------------------
        ; 1. TFT – handles its own GPIO/clock setup internally
        ;------------------------------------------------------------------
        BL      TFT_Init

        ;------------------------------------------------------------------
        ; 2. Alarm LED on PB8
        ;    GPIOB clock was already enabled by TFT_GPIO_Init (data bus),
        ;    but calling GPIO_EnableClock again is harmless (it ORRs bits).
        ;------------------------------------------------------------------
        LDR     R0, =GPIOB_BASE
        BL      GPIO_EnableClock

        LDR     R0, =GPIOB_BASE
        MOVS    R1, #ALARM_LED_PIN
        BL      GPIO_ConfigOutput

        LDR     R0, =GPIOB_BASE
        MOVS    R1, #ALARM_LED_PIN
        BL      GPIO_ClearPin           ; LED off at startup

        ;------------------------------------------------------------------
        ; 3. Smoke sensor ADC on PA1
        ;------------------------------------------------------------------
        BL      ADC_Init

        ;------------------------------------------------------------------
        ; 4. Servo / motor PWM
        ;------------------------------------------------------------------
        BL      PWM_Init

        ; Safe startup: center both servos
        LDR     R0, =1500
        MOVS    R1, #0
        BL      PWM_Set_Servo_Pos

        LDR     R0, =1500
        MOVS    R1, #1
        BL      PWM_Set_Servo_Pos

        ;------------------------------------------------------------------
        ; 5. Keypad
        ;------------------------------------------------------------------
        BL      Keypad_Init

        POP     {PC}


;=============================================================================
; Main_SetInitialState
;=============================================================================
Main_SetInitialState
        PUSH    {LR}

        LDR     R0, =g_sys_state
        MOVS    R1, #STATE_MAIN_MENU
        STR     R1, [R0]

        LDR     R0, =g_prev_state
        LDR     R1, =STATE_INVALID
        STR     R1, [R0]

        POP     {PC}


;=============================================================================
; Main_AlarmTask – PB8 LED mirrors Smoke_Alert_Flag
;=============================================================================
Main_AlarmTask
        PUSH    {R2, LR}

        LDR     R0, =g_alarm_flags
        LDR     R2, [R0]

        TST     R2, #Smoke_Alert_Flag
        BNE     MAT_LedOn

MAT_LedOff
        LDR     R0, =GPIOB_BASE
        MOVS    R1, #ALARM_LED_PIN
        BL      GPIO_ClearPin
        B       MAT_Done

MAT_LedOn
        LDR     R0, =GPIOB_BASE
        MOVS    R1, #ALARM_LED_PIN
        BL      GPIO_WritePin

MAT_Done
        POP     {R2, PC}


;=============================================================================
; Main_BackgroundTasks – hook for future sensor polling etc.
;=============================================================================
Main_BackgroundTasks
        BX      LR


;=============================================================================
; Main_DispatchByState – calls active state handler
;=============================================================================
Main_DispatchByState
        PUSH    {LR}

        LDR     R0, =g_sys_state
        LDR     R0, [R0]

        CMP     R0, #STATE_MAIN_MENU
        BEQ     Dispatch_Exit

        CMP     R0, #STATE_SANITIZING
        BEQ     Dispatch_Sanitizing

        CMP     R0, #STATE_HEART_RATE
        BEQ     Dispatch_HeartRate

        CMP     R0, #STATE_BREATHING
        BEQ     Dispatch_Breathing

        CMP     R0, #STATE_MED_ALERT
        BEQ     Dispatch_Exit

        CMP     R0, #STATE_MOTION
        BEQ     Dispatch_Motion

        CMP     R0, #STATE_MED_INPUT
        BEQ     Dispatch_Exit

        CMP     R0, #STATE_MED_DISPENSE
        BEQ     Dispatch_MedDispense

        CMP     R0, #STATE_SMOKE_ALERT
        BEQ     Dispatch_Exit

        CMP     R0, #STATE_MED_WAITING
        BEQ     Dispatch_MedWaiting

        B       Dispatch_Exit

Dispatch_Sanitizing
        BL      Main_State_Sanitizing
        B       Dispatch_Exit

Dispatch_HeartRate
        BL      Main_State_HeartRate
        B       Dispatch_Exit

Dispatch_Breathing
        BL      Main_State_Breathing
        B       Dispatch_Exit

Dispatch_Motion
        BL      Main_State_Motion
        B       Dispatch_Exit

Dispatch_MedDispense
        BL      Main_State_MedDispense
        B       Dispatch_Exit

Dispatch_MedWaiting
        BL      Main_State_MedWaiting
        B       Dispatch_Exit

Dispatch_Exit
        POP     {PC}


;=============================================================================
; State hooks – fill these in as features are implemented
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