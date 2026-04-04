;=============================================================================
; main.s
; Top-level core control for the nurse assistant robot
;
; This file owns:
;   - entry point
;   - shared globals initialization
;   - initial state setup
;   - the infinite superloop
;   - top-level dispatch shape
;
; This file does NOT own:
;   - screen content decisions        -> ui_state.s
;   - keypad scan implementation      -> keypad.s
;   - feature logic                   -> feature modules
;   - low-level hardware access       -> drivers
;=============================================================================

        AREA    MAIN_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

        EXPORT  __main
        EXPORT  Main_Entry

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

        IMPORT  UI_Update

;=============================================================================
; Entry
;=============================================================================
__main
Main_Entry
        ; Clear all shared RAM to known defaults.
        BL      Main_InitGlobals

        ; Keep future driver/module init calls centralized here.
        BL      Main_InitCore

        ; Choose the first visible state.
        BL      Main_SetInitialState

        ; Let the UI layer draw the first screen.
        BL      UI_Update

;=============================================================================
; Main loop
;=============================================================================
Main_Loop
        ; Input polling hook.
        BL      Main_PollInputs

        ; Always-on background work hook.
        BL      Main_BackgroundTasks

        ; State-based active feature work.
        BL      Main_DispatchByState

        ; Alarm output policy hook.
        BL      Main_AlarmTask

        ; UI layer decides whether to redraw or partially refresh.
        BL      UI_Update

        B       Main_Loop

;=============================================================================
; Main_InitGlobals
; Initialize every shared global to a deterministic boot value.
;=============================================================================
Main_InitGlobals
        PUSH    {LR}

        ; Current state starts cleared.
        LDR     R0, =g_sys_state
        MOVS    R1, #0
        STR     R1, [R0]

        ; Previous state starts cleared too. It will be forced invalid later.
        LDR     R0, =g_prev_state
        MOVS    R1, #0
        STR     R1, [R0]

        ; No active alarms at boot.
        LDR     R0, =g_alarm_flags
        MOVS    R1, #0
        STR     R1, [R0]

        ; No key pressed yet.
        LDR     R0, =g_keycode
        MOVS    R1, #KEY_NONE
        STR     R1, [R0]

        ; Medicine timer starts empty.
        LDR     R0, =g_med_timer
        MOVS    R1, #0
        STR     R1, [R0]

        ; Clear sensor-derived values.
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

        ; Motion state starts in stop / idle.
        LDR     R0, =g_motion_state
        MOVS    R1, #MOTION_STOP
        STR     R1, [R0]

        POP     {PC}

;=============================================================================
; Main_InitCore
; Single official place for future init calls.
;
; Later this is where you add:
;   BL GPIO_Init
;   BL PWM_Init
;   BL ADC_Init
;   BL I2C1_Init
;   BL TFT_Init
;   BL Keypad_Init
;   BL Motion_Init
;   BL SensorsADC_Init
;   BL MAX30102_Init
;=============================================================================
Main_InitCore
        BX      LR

;=============================================================================
; Main_SetInitialState
; Boot into main menu and force the first UI redraw.
;=============================================================================
Main_SetInitialState
        PUSH    {LR}

        ; First visible state is the main menu.
        LDR     R0, =g_sys_state
        MOVS    R1, #STATE_MAIN_MENU
        STR     R1, [R0]

        ; Force the first UI pass to see a state change.
        LDR     R0, =g_prev_state
        LDR     R1, =STATE_INVALID
        STR     R1, [R0]

        POP     {PC}

;=============================================================================
; Main_PollInputs
; Placeholder for keypad scan/update logic.
;=============================================================================
Main_PollInputs
        BX      LR

;=============================================================================
; Main_BackgroundTasks
; Placeholder for always-on work like sensing and timer updates.
;=============================================================================
Main_BackgroundTasks
        BX      LR

;=============================================================================
; Main_DispatchByState
; Top-level scheduler/router.
;=============================================================================
Main_DispatchByState
        PUSH    {LR}

        ; Read the current high-level state.
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

        ; Unknown state -> do nothing safely.
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
; State hook routines
; Keep them local and empty until the real feature modules are frozen.
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

;=============================================================================
; Main_AlarmTask
; Placeholder for physical alarm output behavior.
; UI already handles alert state routing through g_alarm_flags.
;=============================================================================
Main_AlarmTask
        BX      LR

        END