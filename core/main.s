;=============================================================================
; main.s - Calibration: 14250 | Target: 60.0s | Stable MAX30102
;=============================================================================
        GET     constants.s

        AREA    MAIN_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        EXPORT  __main
        EXPORT  Main_Entry
        EXPORT  SysTick_Handler

        IMPORT  g_sys_state
        IMPORT  g_prev_state
        IMPORT  g_alarm_flags
        IMPORT  g_keycode
        IMPORT  g_ms_ticks
        IMPORT  g_last_med_tick
        IMPORT  g_med_wait_ui
        
        IMPORT  TFT_Init
        IMPORT  ADC_Init
        IMPORT  Keypad_Init
        IMPORT  Keypad_Scan
        IMPORT  PWM_Init
        IMPORT  MED_Init
        IMPORT  Smoke_Check
        IMPORT  UI_Update
        IMPORT  HR_Init
        IMPORT  HR_ReadFIFO
        IMPORT  MED_BackgroundTask
        IMPORT  Main_State_MedInput
        IMPORT  Main_State_MedWaiting
        IMPORT  Main_State_MedDispense

__main
Main_Entry
        BL      Main_InitGlobals
        BL      Main_InitCore
        BL      Main_SetInitialState
        BL      UI_Update

Main_Loop
        BL      Keypad_Scan
        BL      Smoke_Check
        BL      Main_BackgroundTasks  
        BL      Main_DispatchByState
        BL      UI_Update

        ; ????? ?????? ??? ??????? ??? I2C ?????? ???? ?????
        LDR     R0, =150000 
WaitLoop
        SUBS    R0, R0, #1
        BNE     WaitLoop
        B       Main_Loop

SysTick_Init
        LDR     R0, =0xE000E010 ; SYST_CSR
        MOVS    R1, #0
        STR     R1, [R0]
        LDR     R0, =0xE000E014 ; SYST_RVR
        LDR     R1, =14250      ; <--- ????? ?????? ???? ??????? ????? ??? ??????
        STR     R1, [R0]
        LDR     R0, =0xE000E018 ; SYST_CVR
        MOVS    R1, #0
        STR     R1, [R0]
        LDR     R0, =0xE000E010
        MOVS    R1, #7          
        STR     R1, [R0]
        BX      LR

SysTick_Handler
        PUSH    {R4, R5, LR}
        LDR     R4, =g_ms_ticks
        LDR     R5, [R4]
        ADDS    R5, R5, #1
        STR     R5, [R4]
        POP     {R4, R5, PC}

Main_InitCore
        PUSH    {LR}
        BL      SysTick_Init
        BL      TFT_Init
        BL      ADC_Init
        BL      HR_Init
        BL      Keypad_Init
        BL      PWM_Init
        BL      MED_Init
        POP     {PC}

Main_InitGlobals
        PUSH    {LR}
        MOVS    R1, #0
        LDR     R0, =g_ms_ticks
        STR     R1, [R0]
        LDR     R0, =g_last_med_tick
        STR     R1, [R0]
        LDR     R0, =g_med_wait_ui
        STR     R1, [R0]
        POP     {PC}

Main_SetInitialState
        LDR     R0, =g_sys_state
        MOVS    R1, #0 ; STATE_MAIN_MENU
        STR     R1, [R0]
        BX      LR

Main_BackgroundTasks
        PUSH    {LR}
        BL      MED_BackgroundTask 
        POP     {PC}

Main_DispatchByState
        PUSH    {LR}
        LDR     R0, =g_sys_state
        LDR     R0, [R0]
        
        CMP     R0, #6 ; STATE_MED_INPUT
        BEQ     CallMedInput
        CMP     R0, #9 ; STATE_MED_WAITING
        BEQ     CallMedWaiting
        CMP     R0, #7 ; STATE_MED_DISPENSE
        BEQ     CallMedDispense
        CMP     R0, #2 ; STATE_HEART_RATE
        BEQ     CallHeartRate
        
        B       DispatchEnd

CallMedInput    BL Main_State_MedInput
        B DispatchEnd
CallMedWaiting  BL Main_State_MedWaiting
        B DispatchEnd
CallMedDispense BL Main_State_MedDispense
        B DispatchEnd
CallHeartRate   BL HR_ReadFIFO
        B DispatchEnd

DispatchEnd     POP {PC}
        ALIGN
        END