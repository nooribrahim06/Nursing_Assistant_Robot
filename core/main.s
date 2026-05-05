;=============================================================================
; main.s - Bluetooth base + Stable old IR mapping
;=============================================================================
        GET     constants.s

        AREA    MAIN_DATA, DATA, READWRITE
        ALIGN
ir_last_ui_code         SPACE   4
ir_last_ui_tick         SPACE   4
temp_last_read_tick     SPACE   4
main_prev_state         SPACE   4

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
        IMPORT  g_smoke_ignore_counter

        IMPORT  g_ir_ready
        IMPORT  g_ir_raw_code
        IMPORT  IR_Init
        IMPORT  g_bpm
        IMPORT  g_spo2

        IMPORT  SAN_Init
        IMPORT  SAN_Update
        IMPORT  SAN_StopNow
        IMPORT  SAN_ResetSequence

        IMPORT  TFT_Init
        IMPORT  ADC_Init
        IMPORT  PWM_Init
        IMPORT  MED_Init
        IMPORT  Smoke_Check
        IMPORT  UI_Update
        IMPORT  HR_Init
        IMPORT  HR_ReadFIFO
        IMPORT  HR_ReadTemp
        IMPORT  MED_BackgroundTask
        IMPORT  Main_State_MedWaiting
        IMPORT  Main_State_MedDispense
        IMPORT  MOT_Init
        IMPORT  MOT_Update
        IMPORT  MotionBT_Init
        IMPORT  MotionBT_SetMode
        IMPORT  MotionBT_ApplyDirection

        IMPORT  g_bt_cmd_ready
        IMPORT  g_bt_motion_mode_request
        IMPORT  g_bt_motion_dir_request

        IMPORT  GPIO_EnableClock
        IMPORT  GPIO_ConfigOutput
        IMPORT  Buzzer_Init
        IMPORT  Buzzer_Update

        IMPORT  BREATHE_Init
        IMPORT  BREATHE_Update

        IMPORT  BT_Init
        IMPORT  BT_RxTask
        IMPORT  BT_PeriodicTask

__main
Main_Entry
        BL      Main_InitGlobals
        BL      Main_InitCore
        BL      Main_SetInitialState
        BL      UI_Update

Main_Loop
        BL      BT_RxTask
        BL      Main_CheckIRInput
        BL      Smoke_Check
        BL      Main_BackgroundTasks
        BL      Main_DispatchByState
        BL      UI_Update
        BL      BT_PeriodicTask
        BL      Main_HandleStateTransitions

        B       Main_Loop


;=============================================================================
; Main_CheckIRInput
;
; OLD WORKING raw IR values:
; 0=25, 1=69, 2=70, 3=71, 4=68, 5=64,
; 6=67, 7=7, 8=21, 9=9,
; OK=28, *=22, #=13, Down=2
;=============================================================================
Main_CheckIRInput
        PUSH    {R4-R7, LR}

        LDR     R4, =g_ir_ready
        LDR     R5, [R4]
        CMP     R5, #1
        BNE.W   MCI_Exit

        MOVS    R5, #0
        STR     R5, [R4]

        LDR     R4, =g_ir_raw_code
        LDR     R5, [R4]
        CMP     R5, #0
        BEQ.W   MCI_Exit

        ; debounce same key
        LDR     R4, =g_ms_ticks
        LDR     R7, [R4]

        LDR     R4, =ir_last_ui_code
        LDR     R6, [R4]
        CMP     R5, R6
        BNE     MCI_StoreNow

        LDR     R4, =ir_last_ui_tick
        LDR     R6, [R4]
        SUBS    R6, R7, R6
        MOVS    R0, #120
        CMP     R6, R0
        BLO.W   MCI_Exit

MCI_StoreNow
        LDR     R4, =ir_last_ui_code
        STR     R5, [R4]

        LDR     R4, =ir_last_ui_tick
        STR     R7, [R4]

        LDR     R4, =g_sys_state
        LDR     R6, [R4]

        CMP     R6, #STATE_MAIN_MENU
        BEQ     MCI_State_MainMenu

        CMP     R6, #STATE_MED_INPUT
        BEQ     MCI_State_MedInput

        CMP     R6, #STATE_MED_ALERT
        BEQ     MCI_State_MedAlert

        CMP     R6, #STATE_HEART_RATE
        BEQ     MCI_State_Heart

        CMP     R6, #STATE_PPG_WAVE
        BEQ     MCI_State_PPG
        CMP     R6, #STATE_VISION
        BEQ     MCI_State_Vision

        CMP     R6, #STATE_VISION_RES
        BEQ     MCI_State_ExitOnly
        B       MCI_State_ExitOnly


MCI_State_MainMenu
        CMP     R5, #69
        BEQ     MCI_Key1

        CMP     R5, #70
        BEQ     MCI_Key2

        CMP     R5, #71
        BEQ     MCI_Key3

        CMP     R5, #68
        BEQ     MCI_Key4

        CMP     R5, #64
        BEQ     MCI_Key5

        CMP     R5, #67
        BEQ     MCI_Key6

        B.W     MCI_Exit


MCI_State_MedInput
        CMP     R5, #25
        BEQ     MCI_Key0

        CMP     R5, #69
        BEQ     MCI_Key1

        CMP     R5, #70
        BEQ     MCI_Key2

        CMP     R5, #71
        BEQ     MCI_Key3

        CMP     R5, #68
        BEQ     MCI_Key4

        CMP     R5, #64
        BEQ     MCI_Key5

        CMP     R5, #67
        BEQ     MCI_Key6

        CMP     R5, #7
        BEQ     MCI_Key7

        CMP     R5, #21
        BEQ     MCI_Key8

        CMP     R5, #9
        BEQ     MCI_Key9

        CMP     R5, #28
        BEQ     MCI_KeyA

        CMP     R5, #22
        BEQ     MCI_KeyB

        CMP     R5, #13
        BEQ     MCI_KeyC

        B       MCI_Exit


MCI_State_MedAlert
        CMP     R5, #28
        BEQ     MCI_KeyA

        CMP     R5, #13
        BEQ     MCI_KeyC

        B       MCI_Exit


MCI_State_Heart
        CMP     R5, #22
        BEQ     MCI_KeyB

        CMP     R5, #13
        BEQ     MCI_KeyD

        CMP     R5, #2
        BEQ     MCI_KeyD

        B       MCI_Exit


MCI_State_PPG
        CMP     R5, #13
        BEQ     MCI_KeyD

        CMP     R5, #2
        BEQ     MCI_KeyD

        B       MCI_Exit

MCI_State_Vision
        CMP     R5, #25          ; 0 = EXIT
        BEQ     MCI_Key0

        CMP     R5, #70          ; 2 = UP
        BEQ     MCI_KeyUp

        CMP     R5, #21          ; 8 = DOWN
        BEQ     MCI_KeyDown

        CMP     R5, #68          ; 4 = LEFT
        BEQ     MCI_KeyLeft

        CMP     R5, #67          ; 6 = RIGHT
        BEQ     MCI_KeyRight

        B       MCI_Exit
		
MCI_State_ExitOnly
        CMP     R5, #13
        BEQ     MCI_KeyD

        CMP     R5, #2
        BEQ     MCI_KeyD

        B       MCI_Exit


MCI_Key0
        MOVS    R7, #KEY_0
        B       MCI_Save
MCI_Key1
        MOVS    R7, #KEY_1
        B       MCI_Save
MCI_Key2
        MOVS    R7, #KEY_2
        B       MCI_Save
MCI_Key3
        MOVS    R7, #KEY_3
        B       MCI_Save
MCI_Key4
        MOVS    R7, #KEY_4
        B       MCI_Save
MCI_Key5
        MOVS    R7, #KEY_5
        B       MCI_Save
MCI_Key6
        MOVS    R7, #KEY_6
        B       MCI_Save
MCI_Key7
        MOVS    R7, #KEY_7
        B       MCI_Save
MCI_Key8
        MOVS    R7, #KEY_8
        B       MCI_Save
MCI_Key9
        MOVS    R7, #KEY_9
        B       MCI_Save
MCI_KeyA
        MOVS    R7, #KEY_A
        B       MCI_Save
MCI_KeyB
        MOVS    R7, #KEY_B
        B       MCI_Save
MCI_KeyC
        MOVS    R7, #KEY_C
        B       MCI_Save
MCI_KeyD
        MOVS    R7, #KEY_D
        B       MCI_Save

MCI_KeyUp
        MOVS    R7, #KEY_UP
        B       MCI_Save

MCI_KeyDown
        MOVS    R7, #KEY_DOWN
        B       MCI_Save

MCI_KeyLeft
        MOVS    R7, #KEY_LEFT
        B       MCI_Save

MCI_KeyRight
        MOVS    R7, #KEY_RIGHT
MCI_Save
        LDR     R4, =g_keycode
        STR     R7, [R4]

MCI_Exit
        POP     {R4-R7, PC}


;=============================================================================
; SysTick_Init
; 16MHz HSI -> 1ms tick = 16000 cycles, reload = 15999
;=============================================================================
SysTick_Init
        LDR     R0, =SYST_CSR
        MOVS    R1, #0
        STR     R1, [R0]

        LDR     R0, =SYST_RVR
        LDR     R1, =15999
        STR     R1, [R0]

        LDR     R0, =SYST_CVR
        MOVS    R1, #0
        STR     R1, [R0]

        LDR     R0, =SYST_CSR
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
        BL      PWM_Init
        BL      SAN_Init
        BL      BREATHE_Init
        BL      HR_Init
        BL      IR_Init
        BL      MOT_Init
        BL      MotionBT_Init
        BL      MED_Init
        BL      Buzzer_Init
        BL      BT_Init

        POP     {PC}


Main_InitGlobals
        PUSH    {LR}
        MOVS    R1, #0

        LDR     R0, =g_sys_state
        STR     R1, [R0]

        LDR     R0, =g_prev_state
        STR     R1, [R0]

        LDR     R0, =main_prev_state
        STR     R1, [R0]

        LDR     R0, =g_alarm_flags
        STR     R1, [R0]

        LDR     R0, =g_keycode
        STR     R1, [R0]

        LDR     R0, =g_ms_ticks
        STR     R1, [R0]

        LDR     R0, =g_last_med_tick
        STR     R1, [R0]

        LDR     R0, =g_med_wait_ui
        STR     R1, [R0]

        LDR     R0, =g_ir_ready
        STR     R1, [R0]

        LDR     R0, =g_ir_raw_code
        STR     R1, [R0]

        LDR     R0, =g_smoke_ignore_counter
        STR     R1, [R0]

        LDR     R0, =ir_last_ui_code
        STR     R1, [R0]

        LDR     R0, =ir_last_ui_tick
        STR     R1, [R0]

        LDR     R0, =temp_last_read_tick
        STR     R1, [R0]

        POP     {PC}


Main_SetInitialState
        LDR     R0, =g_sys_state
        MOVS    R1, #STATE_MAIN_MENU
        STR     R1, [R0]

        LDR     R0, =g_prev_state
        LDR     R1, =STATE_INVALID
        STR     R1, [R0]

        BX      LR


Main_BackgroundTasks
        PUSH    {LR}
        BL      MED_BackgroundTask
        BL      Main_ProcessBluetoothCmd
        BL      MOT_Update
        BL      Buzzer_Update
        POP     {PC}


Main_ProcessBluetoothCmd
        PUSH    {R4, R5, LR}

        ; Check if Bluetooth parser has a complete command
        LDR     R4, =g_bt_cmd_ready
        LDR     R5, [R4]
        CMP     R5, #1
        BNE     MPBC_Exit

        ; -------------------------------------------------------------
        ; 1) Check motion mode request
        ;    Expected values:
        ;      0 = no request
        ;      1 = LINE mode
        ;      2 = PHONE mode
        ; -------------------------------------------------------------
        LDR     R4, =g_bt_motion_mode_request
        LDR     R5, [R4]
        CMP     R5, #0
        BEQ     MPBC_CheckDir

        MOVS    R0, R5
        BL      MotionBT_SetMode

        ; clear mode request after applying
        LDR     R4, =g_bt_motion_mode_request
        MOVS    R5, #0
        STR     R5, [R4]

MPBC_CheckDir
        ; -------------------------------------------------------------
        ; 2) Check motion direction request
        ;    Expected values:
        ;      0 = no request
        ;      1 = FWD
        ;      2 = BACK
        ;      3 = LEFT
        ;      4 = RIGHT
        ;      5 = STOP
        ; -------------------------------------------------------------
        LDR     R4, =g_bt_motion_dir_request
        LDR     R5, [R4]
        CMP     R5, #0
        BEQ     MPBC_ClearReady

        MOVS    R0, R5
        BL      MotionBT_ApplyDirection

        ; clear direction request after applying
        LDR     R4, =g_bt_motion_dir_request
        MOVS    R5, #0
        STR     R5, [R4]

MPBC_ClearReady
        ; clear command-ready flag
        LDR     R4, =g_bt_cmd_ready
        MOVS    R5, #0
        STR     R5, [R4]

MPBC_Exit
        POP     {R4, R5, PC}

Main_DispatchByState
        PUSH    {R4, LR}

        LDR     R0, =g_sys_state
        LDR     R4, [R0]

        CMP     R4, #STATE_MED_WAITING
        BEQ     CallMedWaiting

        CMP     R4, #STATE_MED_DISPENSE
        BEQ     CallMedDispense

        CMP     R4, #STATE_HEART_RATE
        BEQ     CallHeartRate

        CMP     R4, #STATE_BREATHING
        BEQ     CallBreathing

        CMP     R4, #STATE_SANITIZING
        BEQ     CallSanitizing

        CMP     R4, #STATE_TEMP
        BEQ     CallTemp

        CMP     R4, #STATE_PPG_WAVE
        BEQ     CallPPG

        B       DispatchEnd

CallMedWaiting
        BL      Main_State_MedWaiting
        B       DispatchEnd

CallMedDispense
        BL      Main_State_MedDispense
        B       DispatchEnd

CallHeartRate
        BL      HR_ReadFIFO
        B       DispatchEnd

CallBreathing
        BL      BREATHE_Update
        B       DispatchEnd

CallSanitizing
        BL      SAN_Update
        B       DispatchEnd

CallTemp
        BL      HR_ReadFIFO

        LDR     R0, =g_ms_ticks
        LDR     R1, [R0]

        LDR     R0, =temp_last_read_tick
        LDR     R2, [R0]

        SUBS    R3, R1, R2
        LDR     R4, =500
        CMP     R3, R4
        BLO     DispatchEnd

        STR     R1, [R0]
        BL      HR_ReadTemp

        B       DispatchEnd

CallPPG
        BL      HR_ReadFIFO
        B       DispatchEnd

DispatchEnd
        POP     {R4, PC}


Main_HandleStateTransitions
        PUSH    {R4-R6, LR}

        LDR     R0, =g_sys_state
        LDR     R4, [R0]

        LDR     R0, =main_prev_state
        LDR     R5, [R0]

        CMP     R5, #STATE_SANITIZING
        BNE     MHT_NoLeaveSan

        CMP     R4, #STATE_SANITIZING
        BEQ     MHT_NoLeaveSan

        BL      SAN_ResetSequence
        B       MHT_StorePrev

MHT_NoLeaveSan
        CMP     R4, #STATE_SANITIZING
        BEQ     MHT_StorePrev

        BL      SAN_StopNow

MHT_StorePrev
        LDR     R0, =main_prev_state
        STR     R4, [R0]

        POP     {R4-R6, PC}

        ALIGN
        END