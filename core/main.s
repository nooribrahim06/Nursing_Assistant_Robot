;=============================================================================
; main.s  –  Unified build
;=============================================================================

        GET     constants.s

        AREA    MAIN_BREATH_DATA, DATA, READWRITE
        ALIGN
g_fake_breath_idx   SPACE   4

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
        IMPORT  BREATHE_Init
        IMPORT  BREATHE_Update

        IMPORT  HR_Init
        IMPORT  HR_ReadFIFO

        IMPORT  PWM_Init
        IMPORT  PWM_Set_Servo_Pos

        IMPORT  TFT_Init
        IMPORT  UI_Update
        IMPORT  PWM_Set_Motor_Speed
        IMPORT  Keypad_Init
        IMPORT  Keypad_Scan

ALARM_LED_PIN   EQU     8       ; PB8

;=============================================================================
; Entry point
;=============================================================================
__main
Main_Entry
        BL      Main_InitGlobals
        BL      Main_InitCore
        BL      Main_SetInitialState
        BL      UI_Update

;=============================================================================
; Superloop
;=============================================================================
Main_Loop
        BL      Keypad_Scan
        BL      Smoke_Check
        ; BL    Main_AlarmTask        ; disable PB8 LED conflict
        BL      Main_BackgroundTasks
        BL      Main_DispatchByState
        BL      UI_Update
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

        ; fake breathing index init
        LDR     R0, =g_fake_breath_idx
        MOVS    R1, #0
        STR     R1, [R0]

        POP     {PC}


;=============================================================================
; Main_InitCore
;=============================================================================
Main_InitCore
        PUSH    {LR}

        ; 1. TFT
        BL      TFT_Init

        ; 2. ADC
        BL      ADC_Init

        ; 3. Breathing init
        BL      BREATHE_Init

        ; 4. MAX30102 init
        BL      HR_Init

        ; 5. Keypad
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
; Main_AlarmTask
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
; Main_BackgroundTasks
;=============================================================================
Main_BackgroundTasks
        BX      LR


;=============================================================================
; Main_DispatchByState
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
; State hooks
;=============================================================================
Main_State_Sanitizing
        BX      LR

Main_State_HeartRate
        PUSH    {LR}
        
        ; 1. ???? ?????? ??????? ?? ???????
        BL      HR_ReadFIFO
        
        ; 2. ???? ?????? ?? ??? RAM
        LDR     R0, =g_bpm
        LDR     R0, [R0]         ; ?????? R0 ??? ??? ????? (????? 72)
        
        ; 3. ?????? ???? ????? ????? ??? ?????? (?? ?????? ?????? ???)
        ; BL    TFT_PrintNumber  <-- (??? ??? ?????? ???? ????? ????? ????)

        ; (???? ?????? ??? SpO2)
        LDR     R0, =g_spo2
        LDR     R0, [R0]
        ; BL    TFT_PrintNumber  <-- (?????? ?????? ?????????)

        POP     {PC}

Main_State_Breathing
        PUSH    {R0-R4, LR}

        ; load current waveform index
        LDR     R0, =g_fake_breath_idx
        LDR     R1, [R0]

        ; wrap index 0..31
        CMP     R1, #32
        BLO     Breath_Index_OK
        MOVS    R1, #0

Breath_Index_OK
        ; get sample from lookup table
        LDR     R2, =FakeBreathWave
        LDRB    R3, [R2, R1]

        ; scale to 0..4080
        LSLS    R3, R3, #4

        ; store into g_breath_level
        LDR     R4, =g_breath_level
        STR     R3, [R4]

        ; next sample
        ADDS    R1, R1, #1
        STR     R1, [R0]

        POP     {R0-R4, PC}

Main_State_Motion
        BX      LR

Main_State_MedDispense
        BX      LR

Main_State_MedWaiting
        BX      LR

        ALIGN
FakeBreathWave
        DCB  120,140,160,180,200,220,235,245
        DCB  250,245,235,220,200,180,160,140
        DCB  120,100,80,60,40,25,15,8
        DCB  5,8,15,25,40,60,80,100

        ALIGN
        END