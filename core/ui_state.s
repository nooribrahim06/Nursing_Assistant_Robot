; =============================================================================
; ui_state.s
; UI State Machine — screen routing, full/partial refresh logic
; =============================================================================
        INCLUDE constants.s
        AREA    UI_STATE, CODE, READONLY
        THUMB

        EXPORT  UI_Update

        IMPORT  g_sys_state
        IMPORT  g_prev_state
        IMPORT  g_bpm
        IMPORT  g_spo2
        IMPORT  g_smoke_level
        IMPORT  g_breath_level
        IMPORT  g_alarm_flags
        IMPORT  g_med_timer
        IMPORT  g_keycode
        IMPORT  g_hr_red_raw
        IMPORT  g_hr_ir_raw
        IMPORT  TFT_Clear_Screen
        IMPORT  TFT_Render_Main_Menu
        IMPORT  TFT_Render_Sanitizing
        IMPORT  TFT_Render_Heart_Rate
        IMPORT  TFT_Render_Breathing
        IMPORT  TFT_Render_Med_Input
        IMPORT  TFT_Render_Med_Alert
        IMPORT  TFT_Render_Med_Despense
        IMPORT  TFT_Render_Smoke_ALERT
        IMPORT  TFT_Update_Smoke_Level
        IMPORT  TFT_Update_Breathing_Level
        IMPORT  TFT_Update_Heart_Values


; =============================================================================
; UI_Update
; =============================================================================
UI_Update FUNCTION
        PUSH    {R4, R5, LR}

        LDR     R0, =g_alarm_flags
        LDR     R1, [R0]

        TST     R1, #Smoke_Alert_Flag
        BNE     Handle_Smoke_Alert

        TST     R1, #Med_Alert_Flag
        BNE     Handle_Med_Alert

        BL      UI_Handle_Input

        LDR     R4, =g_sys_state
        LDR     R1, [R4]

        LDR     R5, =g_prev_state
        LDR     R0, [R5]

        CMP     R1, R0
        BEQ     UI_Partial_Update

        STR     R1, [R5]

        MOV     R4, R1
        BL      TFT_Clear_Screen

        CMP     R4, #STATE_MAIN_MENU
        BEQ     UI_Render_Main_Menu

        CMP     R4, #STATE_SANITIZING
        BEQ     UI_Render_Sanitizing

        CMP     R4, #STATE_HEART_RATE
        BEQ     UI_Render_Heart_Rate

        CMP     R4, #STATE_BREATHING
        BEQ     UI_Render_Breathing

        CMP     R4, #STATE_MED_INPUT
        BEQ     UI_Render_Med_Input

        CMP     R4, #STATE_MED_ALERT
        BEQ     UI_Render_Med_Alert

        CMP     R4, #STATE_MED_DISPENSE
        BEQ     UI_Render_Med_Dispense

        CMP     R4, #STATE_SMOKE_ALERT
        BEQ     UI_Render_Smoke_ALERT

        B       UI_EXIT
        ENDFUNC


; =============================================================================
; UI_Partial_Update
; =============================================================================
UI_Partial_Update FUNCTION
        LDR     R4, =g_sys_state
        LDR     R1, [R4]

        CMP     R1, #STATE_MAIN_MENU
        BEQ     UI_Load_Smoke_Level

        CMP     R1, #STATE_SMOKE_ALERT
        BEQ     UI_Load_Smoke_Level

        CMP     R1, #STATE_BREATHING
        BEQ     UI_Load_Breath_Level

        CMP     R1, #STATE_HEART_RATE
        BEQ     UI_Load_Heart_Values

        B       UI_EXIT
        ENDFUNC


UI_Load_Smoke_Level FUNCTION
        LDR     R3, =g_smoke_level
        LDR     R2, [R3]
        BL      TFT_Update_Smoke_Level
        B       UI_EXIT
        ENDFUNC

UI_Load_Breath_Level FUNCTION
        LDR     R3, =g_breath_level
        LDR     R2, [R3]
        BL      TFT_Update_Breathing_Level
        B       UI_EXIT
        ENDFUNC

UI_Load_Heart_Values FUNCTION
        LDR     R0, =g_bpm
        LDR     R2, [R0]

        LDR     R0, =g_spo2
        LDR     R3, [R0]

        BL      TFT_Update_Heart_Values
        B       UI_EXIT
        ENDFUNC

; =============================================================================
; Render Functions
; =============================================================================
UI_Render_Main_Menu FUNCTION
        BL      TFT_Render_Main_Menu
        B       UI_EXIT
        ENDFUNC

UI_Render_Sanitizing FUNCTION
        BL      TFT_Render_Sanitizing
        B       UI_EXIT
        ENDFUNC

UI_Render_Heart_Rate FUNCTION
        BL      TFT_Render_Heart_Rate
        B       UI_EXIT
        ENDFUNC

UI_Render_Breathing FUNCTION
        BL      TFT_Render_Breathing
        B       UI_EXIT
        ENDFUNC

UI_Render_Med_Input FUNCTION
        BL      TFT_Render_Med_Input
        B       UI_EXIT
        ENDFUNC

UI_Render_Med_Alert FUNCTION
        BL      TFT_Render_Med_Alert
        B       UI_EXIT
        ENDFUNC

UI_Render_Med_Dispense FUNCTION
        BL      TFT_Render_Med_Despense
        B       UI_EXIT
        ENDFUNC

UI_Render_Smoke_ALERT FUNCTION
        BL      TFT_Render_Smoke_ALERT
        B       UI_EXIT
        ENDFUNC


; =============================================================================
; Alert Handlers
; =============================================================================
Handle_Smoke_Alert FUNCTION
        LDR     R0, =g_sys_state
        MOV     R1, #STATE_SMOKE_ALERT
        STR     R1, [R0]
        B       UI_Update_Recheck
        ENDFUNC

Handle_Med_Alert FUNCTION
        LDR     R0, =g_sys_state
        MOV     R1, #STATE_MED_ALERT
        STR     R1, [R0]
        B       UI_Update_Recheck
        ENDFUNC


; =============================================================================
; UI_Update_Recheck
; =============================================================================
UI_Update_Recheck FUNCTION
        LDR     R4, =g_sys_state
        LDR     R1, [R4]

        LDR     R5, =g_prev_state
        LDR     R0, [R5]

        CMP     R1, R0
        BEQ     UI_Partial_Update

        STR     R1, [R5]

        MOV     R4, R1
        BL      TFT_Clear_Screen

        CMP     R4, #STATE_MAIN_MENU
        BEQ     UI_Render_Main_Menu

        CMP     R4, #STATE_SANITIZING
        BEQ     UI_Render_Sanitizing

        CMP     R4, #STATE_HEART_RATE
        BEQ     UI_Render_Heart_Rate

        CMP     R4, #STATE_BREATHING
        BEQ     UI_Render_Breathing

        CMP     R4, #STATE_MED_INPUT
        BEQ     UI_Render_Med_Input

        CMP     R4, #STATE_MED_ALERT
        BEQ     UI_Render_Med_Alert

        CMP     R4, #STATE_MED_DISPENSE
        BEQ     UI_Render_Med_Dispense

        CMP     R4, #STATE_SMOKE_ALERT
        BEQ     UI_Render_Smoke_ALERT

        B       UI_EXIT
        ENDFUNC


; =============================================================================
; UI_EXIT
; =============================================================================
UI_EXIT FUNCTION
        POP     {R4, R5, PC}
        ENDFUNC


; =============================================================================
; UI_Handle_Input
; =============================================================================
UI_Handle_Input FUNCTION
        PUSH    {R4, R5, LR}

        LDR     R4, =g_keycode
        LDR     R0, [R4]

        CMP     R0, #KEY_NONE
        BNE     UI_Handle_Input_Continue
        B       UI_Handle_Input_EXIT

UI_Handle_Input_Continue

        LDR     R5, =g_sys_state
        LDR     R1, [R5]

        CMP     R1, #STATE_MAIN_MENU
        BEQ     Input_Main_Menu

        CMP     R1, #STATE_SANITIZING
        BEQ     Input_Exit_State

        CMP     R1, #STATE_HEART_RATE
        BEQ     Input_Exit_State

        CMP     R1, #STATE_BREATHING
        BEQ     Input_Exit_State

        CMP     R1, #STATE_MED_INPUT
        BEQ     Input_Med_Input

        CMP     R1, #STATE_MED_ALERT
        BEQ     Input_Med_Alert

        B       UI_Handle_Input_EXIT
        ENDFUNC


; =============================================================================
; Input_Main_Menu
; =============================================================================
Input_Main_Menu FUNCTION
        CMP     R0, #KEY_1
        BNE     MM_try2
        MOV     R2, #STATE_SANITIZING
        STR     R2, [R5]
        B       UI_Handle_Input_EXIT

MM_try2
        CMP     R0, #KEY_2
        BNE     MM_try3
        MOV     R2, #STATE_HEART_RATE
        STR     R2, [R5]
        B       UI_Handle_Input_EXIT

MM_try3
        CMP     R0, #KEY_3
        BNE     MM_try4
        MOV     R2, #STATE_BREATHING
        STR     R2, [R5]
        B       UI_Handle_Input_EXIT

MM_try4
        CMP     R0, #KEY_4
        BNE     UI_Handle_Input_EXIT
        MOV     R2, #STATE_MED_INPUT
        STR     R2, [R5]
        B       UI_Handle_Input_EXIT
        ENDFUNC


; =============================================================================
; Input_Exit_State
; =============================================================================
Input_Exit_State FUNCTION
        CMP     R0, #KEY_D
        BNE     UI_Handle_Input_EXIT
        MOV     R2, #STATE_MAIN_MENU
        STR     R2, [R5]
        B       UI_Handle_Input_EXIT
        ENDFUNC


; =============================================================================
; Input_Med_Input
; =============================================================================
Input_Med_Input FUNCTION
        CMP     R0, #KEY_A
        BNE     MI_try_B
        MOV     R2, #STATE_MED_WAITING
        STR     R2, [R5]
        B       UI_Handle_Input_EXIT

MI_try_B
        CMP     R0, #KEY_B
        BNE     MI_try_C
        LDR     R2, =g_med_timer
        MOV     R3, #0
        STR     R3, [R2]
        B       UI_Handle_Input_EXIT

MI_try_C
        CMP     R0, #KEY_C
        BNE     MI_try_digits
        LDR     R2, =g_med_timer
        MOV     R3, #0
        STR     R3, [R2]
        MOV     R2, #STATE_MAIN_MENU
        STR     R2, [R5]
        B       UI_Handle_Input_EXIT

MI_try_digits
        CMP     R0, #KEY_0
        BNE     MI_d1
        MOV     R2, #0
        B       Input_Add_Digit

MI_d1
        CMP     R0, #KEY_1
        BNE     MI_d2
        MOV     R2, #1
        B       Input_Add_Digit

MI_d2
        CMP     R0, #KEY_2
        BNE     MI_d3
        MOV     R2, #2
        B       Input_Add_Digit

MI_d3
        CMP     R0, #KEY_3
        BNE     MI_d4
        MOV     R2, #3
        B       Input_Add_Digit

MI_d4
        CMP     R0, #KEY_4
        BNE     MI_d5
        MOV     R2, #4
        B       Input_Add_Digit

MI_d5
        CMP     R0, #KEY_5
        BNE     MI_d6
        MOV     R2, #5
        B       Input_Add_Digit

MI_d6
        CMP     R0, #KEY_6
        BNE     MI_d7
        MOV     R2, #6
        B       Input_Add_Digit

MI_d7
        CMP     R0, #KEY_7
        BNE     MI_d8
        MOV     R2, #7
        B       Input_Add_Digit

MI_d8
        CMP     R0, #KEY_8
        BNE     MI_d9
        MOV     R2, #8
        B       Input_Add_Digit

MI_d9
        CMP     R0, #KEY_9
        BNE     UI_Handle_Input_EXIT
        MOV     R2, #9
        B       Input_Add_Digit
        ENDFUNC


; =============================================================================
; Input_Add_Digit
; =============================================================================
Input_Add_Digit FUNCTION
        LDR     R3, =g_med_timer
        LDR     R0, [R3]
        MOV     R1, #10
        MUL     R0, R1, R0
        ADD     R0, R0, R2
        STR     R0, [R3]
        B       UI_Handle_Input_EXIT
        ENDFUNC


; =============================================================================
; Input_Med_Alert
; =============================================================================
Input_Med_Alert FUNCTION
        CMP     R0, #KEY_A
        BNE     MA_try_C
        MOV     R2, #STATE_MED_DISPENSE
        STR     R2, [R5]
        B       UI_Handle_Input_EXIT

MA_try_C
        CMP     R0, #KEY_C
        BNE     UI_Handle_Input_EXIT
        MOV     R2, #STATE_MAIN_MENU
        STR     R2, [R5]
        B       UI_Handle_Input_EXIT
        ENDFUNC


; =============================================================================
; UI_Handle_Input_EXIT
; =============================================================================
UI_Handle_Input_EXIT FUNCTION
        MOV     R2, #KEY_NONE
        STR     R2, [R4]
        POP     {R4, R5, PC}
        ENDFUNC

        END