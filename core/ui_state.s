;=============================================================================
; ui_state.s
; UI state machine and screen ownership
;
; Responsibilities:
;   - apply alarm-priority state overrides
;   - consume g_keycode and update high-level state
;   - compare g_sys_state vs g_prev_state
;   - full redraw on state change
;   - partial refresh for dynamic elements
;=============================================================================

        AREA    UI_STATE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

        EXPORT  UI_Update

        IMPORT  g_sys_state
        IMPORT  g_prev_state
        IMPORT  g_smoke_level
        IMPORT  g_alarm_flags
        IMPORT  g_med_timer
        IMPORT  g_keycode

        IMPORT  TFT_Clear_Screen
        IMPORT  TFT_Render_Main_Menu
        IMPORT  TFT_Render_Sanitizing
        IMPORT  TFT_Render_Heart_Rate
        IMPORT  TFT_Render_Breathing
        IMPORT  TFT_Render_Motion
        IMPORT  TFT_Render_Med_Input
        IMPORT  TFT_Render_Med_Waiting
        IMPORT  TFT_Render_Med_Alert
        IMPORT  TFT_Render_Med_Dispense
        IMPORT  TFT_Render_Smoke_Alert
        IMPORT  TFT_Update_Smoke_Level

;=============================================================================
; UI_Update
; Called every loop from main.s.
;=============================================================================
UI_Update
        PUSH    {R4, R5, LR}

        ; Apply high-priority alert states first.
        BL      UI_Apply_AlarmPriority

        ; Then let keypad input update the logical state.
        BL      UI_Handle_Input

        ; Compare current state vs previous state.
        LDR     R4, =g_sys_state
        LDR     R1, [R4]

        LDR     R5, =g_prev_state
        LDR     R0, [R5]

        CMP     R1, R0
        BEQ     UI_Partial_Update

        ; State changed -> remember it, clear, and fully redraw.
        STR     R1, [R5]
        BL      TFT_Clear_Screen

        CMP     R1, #STATE_MAIN_MENU
        BEQ     UI_Render_Main_Menu

        CMP     R1, #STATE_SANITIZING
        BEQ     UI_Render_Sanitizing

        CMP     R1, #STATE_HEART_RATE
        BEQ     UI_Render_Heart_Rate

        CMP     R1, #STATE_BREATHING
        BEQ     UI_Render_Breathing

        CMP     R1, #STATE_MOTION
        BEQ     UI_Render_Motion

        CMP     R1, #STATE_MED_INPUT
        BEQ     UI_Render_Med_Input

        CMP     R1, #STATE_MED_WAITING
        BEQ     UI_Render_Med_Waiting

        CMP     R1, #STATE_MED_ALERT
        BEQ     UI_Render_Med_Alert

        CMP     R1, #STATE_MED_DISPENSE
        BEQ     UI_Render_Med_Dispense

        CMP     R1, #STATE_SMOKE_ALERT
        BEQ     UI_Render_Smoke_Alert

        B       UI_Exit

;=============================================================================
; Partial update path
;=============================================================================
UI_Partial_Update
        LDR     R4, =g_sys_state
        LDR     R1, [R4]

        ; Main menu and smoke alert only refresh the smoke bar for now.
        CMP     R1, #STATE_MAIN_MENU
        BEQ     UI_Update_Smoke

        CMP     R1, #STATE_SMOKE_ALERT
        BEQ     UI_Update_Smoke

        ; These pages are redrawn without clearing the whole screen.
        CMP     R1, #STATE_HEART_RATE
        BEQ     UI_Render_Heart_Rate_NoClear

        CMP     R1, #STATE_BREATHING
        BEQ     UI_Render_Breathing_NoClear

        CMP     R1, #STATE_MED_INPUT
        BEQ     UI_Render_Med_Input_NoClear

        CMP     R1, #STATE_MED_WAITING
        BEQ     UI_Render_Med_Waiting_NoClear

        B       UI_Exit

;=============================================================================
; Full render labels
;=============================================================================
UI_Render_Main_Menu
        BL      TFT_Render_Main_Menu
        B       UI_Exit

UI_Render_Sanitizing
        BL      TFT_Render_Sanitizing
        B       UI_Exit

UI_Render_Heart_Rate
        BL      TFT_Render_Heart_Rate
        B       UI_Exit

UI_Render_Breathing
        BL      TFT_Render_Breathing
        B       UI_Exit

UI_Render_Motion
        BL      TFT_Render_Motion
        B       UI_Exit

UI_Render_Med_Input
        BL      TFT_Render_Med_Input
        B       UI_Exit

UI_Render_Med_Waiting
        BL      TFT_Render_Med_Waiting
        B       UI_Exit

UI_Render_Med_Alert
        BL      TFT_Render_Med_Alert
        B       UI_Exit

UI_Render_Med_Dispense
        BL      TFT_Render_Med_Dispense
        B       UI_Exit

UI_Render_Smoke_Alert
        BL      TFT_Render_Smoke_Alert
        B       UI_Exit

;=============================================================================
; Partial render labels
;=============================================================================
UI_Render_Heart_Rate_NoClear
        BL      TFT_Render_Heart_Rate
        B       UI_Exit

UI_Render_Breathing_NoClear
        BL      TFT_Render_Breathing
        B       UI_Exit

UI_Render_Med_Input_NoClear
        BL      TFT_Render_Med_Input
        B       UI_Exit

UI_Render_Med_Waiting_NoClear
        BL      TFT_Render_Med_Waiting
        B       UI_Exit

UI_Update_Smoke
        ; TFT_Update_Smoke_Level expects the smoke value in R2.
        LDR     R3, =g_smoke_level
        LDR     R2, [R3]
        BL      TFT_Update_Smoke_Level
        B       UI_Exit

;=============================================================================
; UI_Apply_AlarmPriority
; Smoke alert overrides medicine alert.
;=============================================================================
UI_Apply_AlarmPriority
        LDR     R0, =g_alarm_flags
        LDR     R1, [R0]

        TST     R1, #Smoke_Alert_Flag
        BEQ     UI_Check_Med_Alert

        LDR     R0, =g_sys_state
        MOVS    R1, #STATE_SMOKE_ALERT
        STR     R1, [R0]
        BX      LR

UI_Check_Med_Alert
        TST     R1, #Med_Alert_Flag
        BEQ     UI_Apply_AlarmPriority_Exit

        LDR     R0, =g_sys_state
        MOVS    R1, #STATE_MED_ALERT
        STR     R1, [R0]

UI_Apply_AlarmPriority_Exit
        BX      LR

;=============================================================================
; UI_Handle_Input
; Reads g_keycode and updates top-level state / timer values.
;=============================================================================
UI_Handle_Input
        PUSH    {R4, R5, LR}

        LDR     R4, =g_keycode
        LDR     R0, [R4]                    ; R0 = current key code

        CMP     R0, #KEY_NONE
        BEQ     UI_Handle_Input_Exit

        LDR     R5, =g_sys_state
        LDR     R1, [R5]                    ; R1 = current UI state

        ; Use near conditional branches plus far unconditional branches
        ; to avoid Thumb short-branch range errors in this long file.

        CMP     R1, #STATE_MAIN_MENU
        BNE     UIHI_Not_Main_Menu
        B       Input_Main_Menu

UIHI_Not_Main_Menu
        CMP     R1, #STATE_SANITIZING
        BNE     UIHI_Not_Sanitizing
        B       Input_Exit_State

UIHI_Not_Sanitizing
        CMP     R1, #STATE_HEART_RATE
        BNE     UIHI_Not_Heart
        B       Input_Exit_State

UIHI_Not_Heart
        CMP     R1, #STATE_BREATHING
        BNE     UIHI_Not_Breathing
        B       Input_Exit_State

UIHI_Not_Breathing
        CMP     R1, #STATE_MOTION
        BNE     UIHI_Not_Motion
        B       Input_Exit_State

UIHI_Not_Motion
        CMP     R1, #STATE_MED_INPUT
        BNE     UIHI_Not_Med_Input
        B       Input_Med_Input

UIHI_Not_Med_Input
        CMP     R1, #STATE_MED_WAITING
        BNE     UIHI_Not_Med_Waiting
        B       Input_Med_Waiting

UIHI_Not_Med_Waiting
        CMP     R1, #STATE_MED_ALERT
        BNE     UIHI_Not_Med_Alert
        B       Input_Med_Alert

UIHI_Not_Med_Alert
        CMP     R1, #STATE_MED_DISPENSE
        BNE     UIHI_Not_Med_Dispense
        B       Input_Med_Dispense

UIHI_Not_Med_Dispense
        ; Smoke alert ignores keypad here for now.
        B       UI_Handle_Input_Exit

UI_Handle_Input_Exit
        ; Clear the consumed key so one press is not processed twice.
        MOVS    R2, #KEY_NONE
        STR     R2, [R4]
        POP     {R4, R5, PC}

;-----------------------------------------------------------------------------
; Main menu:
;   1 -> sanitizing
;   2 -> heart rate
;   3 -> breathing
;   4 -> medicine input
;   5 -> motion
;-----------------------------------------------------------------------------
Input_Main_Menu
        CMP     R0, #KEY_1
        BNE     MM_Try_2
        MOVS    R2, #STATE_SANITIZING
        STR     R2, [R5]
        B       UI_Handle_Input_Exit

MM_Try_2
        CMP     R0, #KEY_2
        BNE     MM_Try_3
        MOVS    R2, #STATE_HEART_RATE
        STR     R2, [R5]
        B       UI_Handle_Input_Exit

MM_Try_3
        CMP     R0, #KEY_3
        BNE     MM_Try_4
        MOVS    R2, #STATE_BREATHING
        STR     R2, [R5]
        B       UI_Handle_Input_Exit

MM_Try_4
        CMP     R0, #KEY_4
        BNE     MM_Try_5
        MOVS    R2, #STATE_MED_INPUT
        STR     R2, [R5]
        B       UI_Handle_Input_Exit

MM_Try_5
        CMP     R0, #KEY_5
        BNE     MM_Ignore
        MOVS    R2, #STATE_MOTION
        STR     R2, [R5]
        B       UI_Handle_Input_Exit

MM_Ignore
        B       UI_Handle_Input_Exit

;-----------------------------------------------------------------------------
; Generic exit states:
;   D -> return to main menu
;-----------------------------------------------------------------------------
Input_Exit_State
        CMP     R0, #KEY_D
        BNE     ExitState_Ignore
        MOVS    R2, #STATE_MAIN_MENU
        STR     R2, [R5]
        B       UI_Handle_Input_Exit

ExitState_Ignore
        B       UI_Handle_Input_Exit

;-----------------------------------------------------------------------------
; Medicine input:
;   A -> confirm if timer != 0
;   B -> clear timer
;   C -> clear timer and return to main menu
;   digits -> append decimal digit
;-----------------------------------------------------------------------------
Input_Med_Input
        CMP     R0, #KEY_A
        BNE     MI_Try_B

        LDR     R2, =g_med_timer
        LDR     R3, [R2]
        CMP     R3, #0
        BNE     MI_Accept_Timer
        B       UI_Handle_Input_Exit      ; ignore A if timer is still zero

MI_Accept_Timer
        MOVS    R2, #STATE_MED_WAITING
        STR     R2, [R5]
        B       UI_Handle_Input_Exit

MI_Try_B
        CMP     R0, #KEY_B
        BNE     MI_Try_C
        BL      UI_Clear_Med_Timer
        B       UI_Handle_Input_Exit

MI_Try_C
        CMP     R0, #KEY_C
        BNE     MI_Try_Digits
        BL      UI_Clear_Med_Timer
        MOVS    R2, #STATE_MAIN_MENU
        STR     R2, [R5]
        B       UI_Handle_Input_Exit

MI_Try_Digits
        CMP     R0, #KEY_0
        BNE     MI_D1
        MOVS    R2, #0
        B       Input_Add_Digit

MI_D1
        CMP     R0, #KEY_1
        BNE     MI_D2
        MOVS    R2, #1
        B       Input_Add_Digit

MI_D2
        CMP     R0, #KEY_2
        BNE     MI_D3
        MOVS    R2, #2
        B       Input_Add_Digit

MI_D3
        CMP     R0, #KEY_3
        BNE     MI_D4
        MOVS    R2, #3
        B       Input_Add_Digit

MI_D4
        CMP     R0, #KEY_4
        BNE     MI_D5
        MOVS    R2, #4
        B       Input_Add_Digit

MI_D5
        CMP     R0, #KEY_5
        BNE     MI_D6
        MOVS    R2, #5
        B       Input_Add_Digit

MI_D6
        CMP     R0, #KEY_6
        BNE     MI_D7
        MOVS    R2, #6
        B       Input_Add_Digit

MI_D7
        CMP     R0, #KEY_7
        BNE     MI_D8
        MOVS    R2, #7
        B       Input_Add_Digit

MI_D8
        CMP     R0, #KEY_8
        BNE     MI_D9
        MOVS    R2, #8
        B       Input_Add_Digit

MI_D9
        CMP     R0, #KEY_9
        BNE     MI_Ignore
        MOVS    R2, #9

Input_Add_Digit
        ; g_med_timer = (g_med_timer * 10) + new digit
        LDR     R3, =g_med_timer
        LDR     R1, [R3]
        MOVS    R0, #10
        MUL     R1, R1, R0
        ADDS    R1, R1, R2
        STR     R1, [R3]
        B       UI_Handle_Input_Exit

MI_Ignore
        B       UI_Handle_Input_Exit

;-----------------------------------------------------------------------------
; Medicine waiting:
;   C or D -> cancel waiting and return to main menu
;-----------------------------------------------------------------------------
Input_Med_Waiting
        CMP     R0, #KEY_C
        BEQ     IMW_Cancel
        CMP     R0, #KEY_D
        BNE     IMW_Ignore

IMW_Cancel
        BL      UI_Clear_Med_Timer
        BL      UI_Clear_Med_Alert_Flag
        MOVS    R2, #STATE_MAIN_MENU
        STR     R2, [R5]
        B       UI_Handle_Input_Exit

IMW_Ignore
        B       UI_Handle_Input_Exit

;-----------------------------------------------------------------------------
; Medicine alert:
;   A -> confirm dispense
;   C or D -> cancel and return to main menu
;-----------------------------------------------------------------------------
Input_Med_Alert
        CMP     R0, #KEY_A
        BNE     MA_Try_C

        BL      UI_Clear_Med_Alert_Flag
        MOVS    R2, #STATE_MED_DISPENSE
        STR     R2, [R5]
        B       UI_Handle_Input_Exit

MA_Try_C
        CMP     R0, #KEY_C
        BEQ     MA_Cancel
        CMP     R0, #KEY_D
        BNE     MA_Ignore

MA_Cancel
        BL      UI_Clear_Med_Alert_Flag
        BL      UI_Clear_Med_Timer
        MOVS    R2, #STATE_MAIN_MENU
        STR     R2, [R5]
        B       UI_Handle_Input_Exit

MA_Ignore
        B       UI_Handle_Input_Exit

;-----------------------------------------------------------------------------
; Medicine dispense:
;   D -> return to main menu
;-----------------------------------------------------------------------------
Input_Med_Dispense
        CMP     R0, #KEY_D
        BNE     MD_Ignore
        BL      UI_Clear_Med_Timer
        MOVS    R2, #STATE_MAIN_MENU
        STR     R2, [R5]
        B       UI_Handle_Input_Exit

MD_Ignore
        B       UI_Handle_Input_Exit

;=============================================================================
; Helpers
;=============================================================================
UI_Clear_Med_Timer
        LDR     R0, =g_med_timer
        MOVS    R1, #0
        STR     R1, [R0]
        BX      LR

UI_Clear_Med_Alert_Flag
        LDR     R0, =g_alarm_flags
        LDR     R1, [R0]
        BIC     R1, R1, #Med_Alert_Flag
        STR     R1, [R0]
        BX      LR

;=============================================================================
; Common exit for UI_Update
;=============================================================================
UI_Exit
        POP     {R4, R5, PC}

        END