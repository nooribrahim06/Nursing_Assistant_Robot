;=============================================================================
; main.s - IR + TFT integrated main
; FIXED:
;   - keeps IR behavior
;   - keeps SysTick at 14250
;   - keeps medicine timing/background logic
;   - fixes MED_INPUT so digits stay digits
;   - filters duplicate IR presses better
;   - ignores raw code 0
;=============================================================================
        GET     constants.s

        AREA    MAIN_DATA, DATA, READWRITE
        ALIGN
ir_last_ui_code         SPACE   4
ir_last_ui_tick         SPACE   4

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

        ; -------- IR imports --------
        IMPORT  g_ir_ready
        IMPORT  g_ir_raw_code
        IMPORT  IR_Init

        IMPORT  SAN_Init
        IMPORT  SAN_Update
        IMPORT  TFT_Init
        IMPORT  ADC_Init
        IMPORT  PWM_Init
        IMPORT  MED_Init
        IMPORT  Smoke_Check
        IMPORT  UI_Update
        IMPORT  HR_Init
        IMPORT  HR_ReadFIFO
        IMPORT  MED_BackgroundTask
        IMPORT  Main_State_MedWaiting
        IMPORT  Main_State_MedDispense

        IMPORT  MOT_Init
        IMPORT  MOT_Update

        IMPORT  GPIO_EnableClock
        IMPORT  GPIO_ConfigOutput
		IMPORT Buzzer_Init
        IMPORT Buzzer_Update
__main
Main_Entry
        BL      Main_InitGlobals
        BL      Main_InitCore
        BL      Main_SetInitialState
        BL      UI_Update

Main_Loop
        BL      Main_CheckIRInput
        BL      Smoke_Check
        BL      Main_BackgroundTasks
        BL      Main_DispatchByState
        BL      UI_Update

        LDR     R0, =150000
WaitLoop
        SUBS    R0, R0, #1
        BNE     WaitLoop
        B       Main_Loop


;=============================================================================
; Main_CheckIRInput
;
; measured remote values:
;   1 = 69
;   2 = 70
;   3 = 71
;   4 = 68
;   5 = 64
;   6 = 67
;   7 = 7
;   8 = 21
;   9 = 9
;   0 = 25
;   * = 22
;   # = 13
;   up = 24
;   down = 2
;   left = 8
;   right = 90
;   ok = 28
;
; direct key values:
;   KEY_0 = 1
;   KEY_1 = 2
;   KEY_2 = 3
;   KEY_3 = 4
;   KEY_4 = 5
;   KEY_5 = 6
;   KEY_6 = 7
;   KEY_7 = 8
;   KEY_8 = 9
;   KEY_9 = 10
;   KEY_A = 11
;   KEY_B = 12
;   KEY_C = 13
;   KEY_D = 14
;=============================================================================
Main_CheckIRInput
        PUSH    {R4-R7, LR}

        ; new IR frame?
        LDR     R4, =g_ir_ready
        LDR     R5, [R4]
        CMP     R5, #1
        BNE     MCI_Exit

        ; clear ready
        MOVS    R5, #0
        STR     R5, [R4]

        ; read raw code
        LDR     R4, =g_ir_raw_code
        LDR     R5, [R4]

        ; ignore null / repeat-like empty code
        CMP     R5, #0
        BEQ     MCI_Exit

        ; ------------------------------------------------------------
        ; duplicate filter: ignore same raw code within 120 ms
        ; ------------------------------------------------------------
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
        BLO     MCI_Exit

MCI_StoreNow
        LDR     R4, =ir_last_ui_code
        STR     R5, [R4]
        LDR     R4, =ir_last_ui_tick
        STR     R7, [R4]

        ; current state
        LDR     R4, =g_sys_state
        LDR     R6, [R4]

        ; ============================================================
        ; MAIN MENU ONLY: 1..4 switch modes through existing UI logic
        ; ============================================================
        CMP     R6, #STATE_MAIN_MENU
        BNE     MCI_CheckMedInput

        CMP     R5, #69         ; 1
        BEQ     MCI_Key1

        CMP     R5, #70         ; 2
        BEQ     MCI_Key2

        CMP     R5, #71         ; 3
        BEQ     MCI_Key3

        CMP     R5, #68         ; 4
        BEQ     MCI_Key4

        B       MCI_Exit

MCI_CheckMedInput
        ; ============================================================
        ; MED INPUT ONLY:
        ; digits + OK/*/# only
        ; no mode switching here
        ; ============================================================
        CMP     R6, #STATE_MED_INPUT
        BNE     MCI_CheckMedAlert

        CMP     R5, #25         ; 0
        BEQ     MCI_Key0

        CMP     R5, #69         ; 1
        BEQ     MCI_Key1

        CMP     R5, #70         ; 2
        BEQ     MCI_Key2

        CMP     R5, #71         ; 3
        BEQ     MCI_Key3

        CMP     R5, #68         ; 4
        BEQ     MCI_Key4

        CMP     R5, #64         ; 5
        BEQ     MCI_Key5

        CMP     R5, #67         ; 6
        BEQ     MCI_Key6

        CMP     R5, #7          ; 7
        BEQ     MCI_Key7

        CMP     R5, #21         ; 8
        BEQ     MCI_Key8

        CMP     R5, #9          ; 9
        BEQ     MCI_Key9

        CMP     R5, #28         ; OK
        BEQ     MCI_KeyA

        CMP     R5, #22         ; *
        BEQ     MCI_KeyB

        CMP     R5, #13         ; #
        BEQ     MCI_KeyC

        B       MCI_Exit

MCI_CheckMedAlert
        ; ============================================================
        ; MED ALERT:
        ; OK -> A (dispense)
        ; #  -> C (back)
        ; ============================================================
        CMP     R6, #STATE_MED_ALERT
        BNE     MCI_CheckOtherStates

        CMP     R5, #28         ; OK
        BEQ     MCI_KeyA

        CMP     R5, #13         ; #
        BEQ     MCI_KeyC

        B       MCI_Exit

MCI_CheckOtherStates
        ; ============================================================
        ; Other screens:
        ; # or Down -> D (exit)
        ; ============================================================
        CMP     R5, #13         ; #
        BEQ     MCI_KeyD

        CMP     R5, #2          ; down arrow
        BEQ     MCI_KeyD

        B       MCI_Exit


; --------------------------------------------------------------------
; Save direct key values
; --------------------------------------------------------------------
MCI_Key0
        MOVS    R7, #1
        B       MCI_Save
MCI_Key1
        MOVS    R7, #2
        B       MCI_Save
MCI_Key2
        MOVS    R7, #3
        B       MCI_Save
MCI_Key3
        MOVS    R7, #4
        B       MCI_Save
MCI_Key4
        MOVS    R7, #5
        B       MCI_Save
MCI_Key5
        MOVS    R7, #6
        B       MCI_Save
MCI_Key6
        MOVS    R7, #7
        B       MCI_Save
MCI_Key7
        MOVS    R7, #8
        B       MCI_Save
MCI_Key8
        MOVS    R7, #9
        B       MCI_Save
MCI_Key9
        MOVS    R7, #10
        B       MCI_Save

MCI_KeyA
        MOVS    R7, #11
        B       MCI_Save
MCI_KeyB
        MOVS    R7, #12
        B       MCI_Save
MCI_KeyC
        MOVS    R7, #13
        B       MCI_Save
MCI_KeyD
        MOVS    R7, #14

MCI_Save
        LDR     R4, =g_keycode
        STR     R7, [R4]

MCI_Exit
        POP     {R4-R7, PC}


;=============================================================================
; SysTick_Init
;=============================================================================
SysTick_Init
        LDR     R0, =SYST_CSR
        MOVS    R1, #0
        STR     R1, [R0]

        LDR     R0, =SYST_RVR
        LDR     R1, =14250
        STR     R1, [R0]

        LDR     R0, =SYST_CVR
        MOVS    R1, #0
        STR     R1, [R0]

        LDR     R0, =SYST_CSR
        MOVS    R1, #7
        STR     R1, [R0]

        BX      LR


;=============================================================================
; SysTick_Handler
;=============================================================================
SysTick_Handler
        PUSH    {R4, R5, LR}

        LDR     R4, =g_ms_ticks
        LDR     R5, [R4]
        ADDS    R5, R5, #1
        STR     R5, [R4]

        POP     {R4, R5, PC}


;=============================================================================
; Main_InitCore
;=============================================================================
Main_InitCore
        PUSH    {LR}

        BL      SysTick_Init
        BL      TFT_Init
        BL      ADC_Init
        BL      SAN_Init
        BL      HR_Init
        BL      IR_Init
        BL      PWM_Init
        BL      MOT_Init
        BL      MED_Init

        BL      Buzzer_Init
        POP     {PC}


;=============================================================================
; Main_InitGlobals
;=============================================================================
Main_InitGlobals
        PUSH    {LR}
        MOVS    R1, #0

        LDR     R0, =g_sys_state
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

        POP     {PC}


;=============================================================================
; Main_SetInitialState
;=============================================================================
Main_SetInitialState
        LDR     R0, =g_sys_state
        MOVS    R1, #STATE_MAIN_MENU
        STR     R1, [R0]

        LDR     R0, =g_prev_state
        LDR     R1, =STATE_INVALID
        STR     R1, [R0]

        BX      LR


;=============================================================================
; Main_BackgroundTasks
;=============================================================================
Main_BackgroundTasks
        PUSH    {LR}
        BL      MED_BackgroundTask
        BL      MOT_Update
		BL      Buzzer_Update        ; <-- added
        POP     {PC}


;=============================================================================
; Main_DispatchByState
; IMPORTANT:
; UI already handles STATE_MED_INPUT through g_keycode.
; Do NOT call Main_State_MedInput here.
;=============================================================================
Main_DispatchByState
        PUSH    {LR}

        LDR     R0, =g_sys_state
        LDR     R0, [R0]

        CMP     R0, #STATE_MED_WAITING
        BEQ     CallMedWaiting

        CMP     R0, #STATE_MED_DISPENSE
        BEQ     CallMedDispense

        CMP     R0, #STATE_HEART_RATE
        BEQ     CallHeartRate

        CMP     R0, #STATE_SANITIZING
        BEQ     CallSanitizing

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

CallSanitizing
        BL      SAN_Update
        B       DispatchEnd

DispatchEnd
        POP     {PC}

        ALIGN
        END