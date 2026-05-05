; =============================================================================
; ui_state.s
; =============================================================================
        INCLUDE constants.s

        AREA    UI_STATE_DATA, DATA, READWRITE
        ALIGN
breath_ui_tick  SPACE   4

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
        IMPORT  g_smoke_ignore_counter
        IMPORT  g_med_wait_ui
        
        IMPORT  TFT_Clear_Screen
        IMPORT  TFT_Render_Main_Menu
        IMPORT  TFT_Render_Sanitizing
        IMPORT  TFT_Render_Heart_Rate
        IMPORT  TFT_Render_Breathing
        IMPORT  TFT_Render_Med_Input
        IMPORT  TFT_Render_Med_Waiting
        IMPORT  TFT_Render_Med_Alert
        IMPORT  TFT_Render_Med_Despense
        IMPORT  TFT_Render_Smoke_ALERT
        IMPORT  TFT_Update_Smoke_Level
        IMPORT  TFT_Update_Breathing_Level
        IMPORT  TFT_Update_Heart_Values
        IMPORT  TFT_Draw_Number6
        IMPORT  TFT_Fill_Rect
        
        IMPORT  TFT_Render_Temp
        IMPORT  TFT_Update_Temp_Values
        IMPORT  TFT_Render_PPG_Wave
        IMPORT  TFT_Update_PPG_Wave

        IMPORT  g_ms_ticks
        IMPORT  g_vision_level
        IMPORT  g_vision_ring_idx
        IMPORT  g_vision_level_score
        IMPORT  g_vision_results
        IMPORT  g_vision_dirs
        IMPORT  TFT_Render_Vision
        IMPORT  TFT_Render_Vision_Res
        
        IMPORT  MED_StartFromDisplayedMinutes

COLOR_BLACK         EQU     0x0000
COLOR_WHITE         EQU     0xFFFF

; =============================================================================
; UI_Update
; =============================================================================
UI_Update FUNCTION
        PUSH    {R4, R5, LR}
        
        LDR     R0, =g_sys_state
        LDR     R1, [R0]
        CMP     R1, #STATE_MED_DISPENSE
        BEQ     UI_Handle_Input_Then_Route
        
        LDR     R0, =g_alarm_flags
        LDR     R1, [R0]
        
        TST     R1, #Med_Alert_Flag
        BNE.W   Handle_Med_Alert
        
        TST     R1, #Smoke_Alert_Flag
        BEQ.W   UI_Handle_Input_Then_Route
        
        LDR     R4, =g_smoke_ignore_counter
        LDR     R5, [R4]
        CMP     R5, #0
        BEQ     UI_Trigger_Smoke_Alert
        
        SUBS    R5, R5, #1
        STR     R5, [R4]
        B       UI_Handle_Input_Then_Route

UI_Trigger_Smoke_Alert
        LDR     R0, =g_sys_state
        MOVS    R1, #STATE_SMOKE_ALERT
        STR     R1, [R0]
        B       UI_Handle_Input_Then_Route

UI_Handle_Input_Then_Route
        BL      UI_Handle_Input
        
        LDR     R4, =g_sys_state
        LDR     R1, [R4]
        
        LDR     R5, =g_prev_state
        LDR     R0, [R5]
        
        CMP     R1, R0
        BEQ.W     UI_Partial_Update
        
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
        CMP     R4, #STATE_MED_WAITING
        BEQ.W     UI_Render_Med_Waiting
        CMP     R4, #STATE_MED_ALERT
        BEQ     UI_Render_Med_Alert
        CMP     R4, #STATE_MED_DISPENSE
        BEQ     UI_Render_Med_Dispense
        CMP     R4, #STATE_SMOKE_ALERT
        BEQ     UI_Render_Smoke_ALERT
        CMP     R4, #STATE_TEMP
        BEQ     UI_Render_Temp
        CMP     R4, #STATE_PPG_WAVE
        BEQ     UI_Render_PPG_Wave
        CMP     R4, #STATE_VISION
        BEQ     UI_Render_Vision
        CMP     R4, #STATE_VISION_RES
        BEQ     UI_Render_Vision_Res
        CMP     R4, #STATE_MOTION
        BEQ.W   UI_Render_Motion
        
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG

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
        CMP     R1, #STATE_MED_INPUT
        BEQ.W   UI_Update_Med_Number
        CMP     R1, #STATE_TEMP
        BEQ     UI_Load_Temp_Values
        CMP     R1, #STATE_PPG_WAVE
        BEQ     UI_Update_PPG_Wave
        
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG

UI_Load_Smoke_Level FUNCTION
        LDR     R3, =g_smoke_level
        LDR     R2, [R3]
        BL      TFT_Update_Smoke_Level
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG

UI_Load_Breath_Level FUNCTION
        LDR     R0, =g_ms_ticks
        LDR     R1, [R0]
        LDR     R0, =breath_ui_tick
        LDR     R2, [R0]
        SUBS    R3, R1, R2
        CMP     R3, #25         ; 25ms = 40Hz update rate
        BLO     UI_EXIT_Breath
        STR     R1, [R0]

        LDR     R3, =g_breath_level
        LDR     R2, [R3]
        BL      TFT_Update_Breathing_Level
UI_EXIT_Breath
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG

UI_Load_Heart_Values FUNCTION
        LDR     R0, =g_bpm
        LDR     R2, [R0]
        LDR     R0, =g_spo2
        LDR     R3, [R0]
        BL      TFT_Update_Heart_Values
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG

; =============================================================================
; Render Functions
; =============================================================================
UI_Render_Temp FUNCTION
        BL      TFT_Render_Temp
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG
UI_Load_Temp_Values FUNCTION
        BL      TFT_Update_Temp_Values
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG
UI_Render_PPG_Wave FUNCTION
        BL      TFT_Render_PPG_Wave
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG
UI_Update_PPG_Wave FUNCTION
        BL      TFT_Update_PPG_Wave
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG
UI_Render_Main_Menu FUNCTION
        BL      TFT_Render_Main_Menu
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG
UI_Render_Sanitizing FUNCTION
        BL      TFT_Render_Sanitizing
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG
UI_Render_Heart_Rate FUNCTION
        BL      TFT_Render_Heart_Rate
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG
UI_Render_Breathing FUNCTION
        BL      TFT_Render_Breathing
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG
UI_Render_Med_Input FUNCTION
        BL      TFT_Render_Med_Input
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG
UI_Render_Med_Alert FUNCTION
        BL      TFT_Render_Med_Alert
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG
UI_Render_Med_Dispense FUNCTION
        BL      TFT_Render_Med_Despense
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG
UI_Render_Smoke_ALERT FUNCTION
        BL      TFT_Render_Smoke_ALERT
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG
UI_Render_Med_Waiting FUNCTION
        BL      TFT_Render_Med_Waiting
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG
UI_Render_Vision FUNCTION
        BL      TFT_Render_Vision
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG
UI_Render_Vision_Res FUNCTION
        BL      TFT_Render_Vision_Res
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG
UI_Render_Motion FUNCTION
        BL      TFT_Render_Main_Menu
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG

; =============================================================================
; Alert Handlers
; =============================================================================
Handle_Smoke_Alert FUNCTION
        LDR     R0, =g_sys_state
        MOVS    R1, #STATE_SMOKE_ALERT
        STR     R1, [R0]
        B       UI_Update_Recheck
        ENDFUNC
        ALIGN
        LTORG

Handle_Med_Alert FUNCTION
        LDR     R0, =g_sys_state
        MOVS    R1, #STATE_MED_ALERT
        STR     R1, [R0]
        B       UI_Handle_Input_Then_Route
        ENDFUNC
        ALIGN
        LTORG

; =============================================================================
; UI_Update_Recheck
; =============================================================================
UI_Update_Recheck FUNCTION
        LDR     R4, =g_sys_state
        LDR     R1, [R4]
        LDR     R5, =g_prev_state
        LDR     R0, [R5]
        CMP     R1, R0
        BEQ.W    UI_Partial_Update
        
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
        CMP     R4, #STATE_MED_WAITING
        BEQ.W     UI_Render_Med_Waiting
        CMP     R4, #STATE_MED_ALERT
        BEQ     UI_Render_Med_Alert
        CMP     R4, #STATE_MED_DISPENSE
        BEQ     UI_Render_Med_Dispense
        CMP     R4, #STATE_SMOKE_ALERT
        BEQ     UI_Render_Smoke_ALERT
        CMP     R4, #STATE_TEMP
        BEQ     UI_Render_Temp
        CMP     R4, #STATE_PPG_WAVE
        BEQ     UI_Render_PPG_Wave
        CMP     R4, #STATE_VISION
        BEQ     UI_Render_Vision
        CMP     R4, #STATE_VISION_RES
        BEQ     UI_Render_Vision_Res
        CMP     R4, #STATE_MOTION
        BEQ.W   UI_Render_Motion
        B       UI_EXIT
        ENDFUNC
        ALIGN
        LTORG

UI_Update_Med_Number
        LDR     R4, =COLOR_BLACK
        MOVS    R0, #95
        MOVS    R1, #185
        MOVS    R2, #40
        MOVS    R3, #8
        BL      TFT_Fill_Rect
        LDR     R2, =g_med_timer
        LDR     R2, [R2]
        MOVS    R0, #95
        MOVS    R1, #185
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_Number6
        B       UI_EXIT

; =============================================================================
; UI_EXIT
; =============================================================================
UI_EXIT FUNCTION
        POP     {R4, R5, PC}
        ENDFUNC
        ALIGN
        LTORG

; =============================================================================
; UI_Handle_Input
; =============================================================================
UI_Handle_Input FUNCTION
        PUSH    {R4, R5, LR}
        
        LDR     R4, =g_keycode
        LDR     R0, [R4]
        CMP     R0, #KEY_NONE
        BNE     UI_Handle_Input_Continue
        B.W     UI_Handle_Input_EXIT

UI_Handle_Input_Continue
        LDR     R5, =g_sys_state
        LDR     R1, [R5]
        
        CMP     R1, #STATE_MAIN_MENU
        BEQ.W   Input_Main_Menu
        CMP     R1, #STATE_SANITIZING
        BEQ.W   Input_Exit_State
        CMP     R1, #STATE_HEART_RATE
        BEQ.W   Input_Heart_Rate
        CMP     R1, #STATE_BREATHING
        BEQ.W   Input_Exit_State
        CMP     R1, #STATE_TEMP
        BEQ.W   Input_Exit_State
        CMP     R1, #STATE_PPG_WAVE
        BEQ.W   Input_Exit_State
        CMP     R1, #STATE_MED_INPUT
        BEQ.W   Input_Med_Input
        CMP     R1, #STATE_MED_ALERT
        BEQ.W   Input_Med_Alert
        CMP     R1, #STATE_SMOKE_ALERT
        BEQ.W   Input_Smoke_Alert
        CMP     R1, #STATE_VISION
        BEQ.W   Input_Vision
        CMP     R1, #STATE_VISION_RES
        BEQ.W   Input_Exit_State
        
        B.W     UI_Handle_Input_EXIT
        ENDFUNC
        ALIGN
        LTORG

; =============================================================================
; Input_Main_Menu
; =============================================================================
Input_Main_Menu FUNCTION
        CMP     R0, #KEY_1
        BNE     MM_try2
        MOVS    R2, #STATE_SANITIZING
        STR     R2, [R5]
        B.W     UI_Handle_Input_EXIT
MM_try2
        CMP     R0, #KEY_2
        BNE     MM_try3
        MOVS    R2, #STATE_HEART_RATE
        STR     R2, [R5]
        B.W     UI_Handle_Input_EXIT
MM_try3
        CMP     R0, #KEY_3
        BNE     MM_try4
        MOVS    R2, #STATE_BREATHING
        STR     R2, [R5]
        B.W     UI_Handle_Input_EXIT
MM_try4
        CMP     R0, #KEY_4
        BNE     MM_try5
        MOVS    R2, #STATE_MED_INPUT
        STR     R2, [R5]
        LDR     R2, =g_med_timer
        MOVS    R3, #0
        STR     R3, [R2]
        B.W     UI_Handle_Input_EXIT
MM_try5
        CMP     R0, #KEY_5
        BNE     MM_try6
        MOVS    R2, #STATE_TEMP
        STR     R2, [R5]
        B.W     UI_Handle_Input_EXIT
MM_try6
        CMP     R0, #KEY_6
        BNE.W   UI_Handle_Input_EXIT
        MOVS    R2, #STATE_VISION
        STR     R2, [R5]

        ; Reset Vision Variables
        MOVS    R3, #0
        LDR     R2, =g_vision_level
        STR     R3, [R2]
        LDR     R2, =g_vision_ring_idx
        STR     R3, [R2]
        LDR     R2, =g_vision_level_score
        STR     R3, [R2]

        ; Randomize first dir
        LDR     R2, =g_ms_ticks
        LDR     R2, [R2]
        MOVS    R0, #3
        ANDS    R2, R2, R0
        LDR     R3, =g_vision_dirs
        STR     R2, [R3]
        
        B.W     UI_Handle_Input_EXIT
        ENDFUNC
        ALIGN
        LTORG

; =============================================================================
; Input_Heart_Rate
; =============================================================================
Input_Heart_Rate FUNCTION
        CMP     R0, #KEY_B
        BNE     HR_try_exit
        MOVS    R2, #STATE_PPG_WAVE
        STR     R2, [R5]
        B.W     UI_Handle_Input_EXIT
HR_try_exit
        CMP     R0, #KEY_D
        BNE.W   UI_Handle_Input_EXIT
        MOVS    R2, #STATE_MAIN_MENU
        STR     R2, [R5]
        B.W     UI_Handle_Input_EXIT
        ENDFUNC
        ALIGN
        LTORG

; =============================================================================
; Input_Exit_State
; =============================================================================
Input_Exit_State FUNCTION
        CMP     R0, #KEY_D
        BNE.W   UI_Handle_Input_EXIT
        MOVS    R2, #STATE_MAIN_MENU
        STR     R2, [R5]
        B.W     UI_Handle_Input_EXIT
        ENDFUNC
        ALIGN
        LTORG

; =============================================================================
; Input_Smoke_Alert
; =============================================================================
Input_Smoke_Alert FUNCTION
        CMP     R0, #KEY_D
        BNE.W   UI_Handle_Input_EXIT
        MOVS    R2, #STATE_MAIN_MENU
        STR     R2, [R5]
        LDR     R2, =g_smoke_ignore_counter
        LDR     R3, =SMOKE_IGNORE_ITERATIONS
        STR     R3, [R2]
        LDR     R2, =g_alarm_flags
        LDR     R3, [R2]
        BIC     R3, R3, #Smoke_Alert_Flag
        STR     R3, [R2]
        B.W     UI_Handle_Input_EXIT
        ENDFUNC
        ALIGN
        LTORG

; =============================================================================
; Input_Med_Input
; =============================================================================
Input_Med_Input FUNCTION
        CMP     R0, #KEY_A
        BNE.W   MI_try_B
        LDR     R2, =g_med_timer
        LDR     R3, [R2]
        CMP     R3, #0
        BEQ.W   UI_Handle_Input_EXIT
        BL      MED_StartFromDisplayedMinutes
        B.W     UI_Handle_Input_EXIT
MI_try_B
        CMP     R0, #KEY_B
        BNE.W   MI_try_C
        LDR     R2, =g_med_timer
        MOVS    R3, #0
        STR     R3, [R2]
        B.W     UI_Handle_Input_EXIT
MI_try_C
        CMP     R0, #KEY_C
        BNE.W   MI_try_digits
        LDR     R2, =g_med_timer
        MOVS    R3, #0
        STR     R3, [R2]
        MOVS    R2, #STATE_MAIN_MENU
        STR     R2, [R5]
        B.W     UI_Handle_Input_EXIT
MI_try_digits
        CMP     R0, #KEY_0
        BNE     MI_d1
        MOVS    R2, #0
        B       Input_Add_Digit
MI_d1
        CMP     R0, #KEY_1
        BNE     MI_d2
        MOVS    R2, #1
        B       Input_Add_Digit
MI_d2
        CMP     R0, #KEY_2
        BNE     MI_d3
        MOVS    R2, #2
        B       Input_Add_Digit
MI_d3
        CMP     R0, #KEY_3
        BNE     MI_d4
        MOVS    R2, #3
        B       Input_Add_Digit
MI_d4
        CMP     R0, #KEY_4
        BNE     MI_d5
        MOVS    R2, #4
        B       Input_Add_Digit
MI_d5
        CMP     R0, #KEY_5
        BNE     MI_d6
        MOVS    R2, #5
        B       Input_Add_Digit
MI_d6
        CMP     R0, #KEY_6
        BNE     MI_d7
        MOVS    R2, #6
        B       Input_Add_Digit
MI_d7
        CMP     R0, #KEY_7
        BNE     MI_d8
        MOVS    R2, #7
        B       Input_Add_Digit
MI_d8
        CMP     R0, #KEY_8
        BNE     MI_d9
        MOVS    R2, #8
        B       Input_Add_Digit
MI_d9
        CMP     R0, #KEY_9
        BNE.W   UI_Handle_Input_EXIT
        MOVS    R2, #9
        B.W     Input_Add_Digit
        ENDFUNC
        ALIGN
        LTORG

; =============================================================================
; Input_Add_Digit
; =============================================================================
Input_Add_Digit FUNCTION
        LDR     R3, =g_med_timer
        LDR     R0, [R3]
        MOVS    R1, #10
        MUL     R0, R1, R0
        ADD     R0, R0, R2
        STR     R0, [R3]
        B.W     UI_Handle_Input_EXIT
        ENDFUNC
        ALIGN
        LTORG

; =============================================================================
; Input_Med_Alert
; =============================================================================
Input_Med_Alert FUNCTION
        CMP     R0, #KEY_A
        BNE     MA_try_C
        MOVS    R2, #STATE_MED_DISPENSE
        STR     R2, [R5]
        B       UI_Handle_Input_EXIT
MA_try_C
        CMP     R0, #KEY_C
        BNE     UI_Handle_Input_EXIT
        LDR     R2, =g_alarm_flags
        LDR     R3, [R2]
        BIC     R3, R3, #Med_Alert_Flag
        STR     R3, [R2]
        MOVS    R2, #STATE_MAIN_MENU
        STR     R2, [R5]
        B       UI_Handle_Input_EXIT
        ENDFUNC
        ALIGN
        LTORG

; =============================================================================
; Input_Vision
; =============================================================================
Input_Vision FUNCTION
        PUSH    {R4, LR}                ; save &g_keycode (R4) and LR
        
        CMP     R0, #KEY_0
        BNE     Check_Vis_Up
        MOVS    R2, #STATE_MAIN_MENU
        STR     R2, [R5]
        B       Vis_Exit

Check_Vis_Up
        MOVS    R4, #0xFF
        CMP     R0, #KEY_UP
        BNE     Check_Vis_Right
        MOVS    R4, #0
        B       Vis_Check_Dir
Check_Vis_Right
        CMP     R0, #KEY_RIGHT
        BNE     Check_Vis_Down
        MOVS    R4, #1
        B       Vis_Check_Dir
Check_Vis_Down
        CMP     R0, #KEY_DOWN
        BNE     Check_Vis_Left
        MOVS    R4, #2
        B       Vis_Check_Dir
Check_Vis_Left
        CMP     R0, #KEY_LEFT
        BNE     Vis_Exit
        MOVS    R4, #3

Vis_Check_Dir
        LDR     R2, =g_vision_ring_idx
        LDR     R7, [R2]

        LDR     R3, =g_vision_dirs
        LSLS    R1, R7, #2
        LDR     R3, [R3, R1]

        MOVS    R6, #0                  ; Assume Wrong (R6 = 0)
        CMP     R4, R3
        BNE     Vis_Record_Result
        
        ; Correct! Update Score
        MOVS    R6, #1                  ; Set Right (R6 = 1)
        LDR     R3, =g_vision_level_score
        LDR     R4, [R3]
        ADDS    R4, R4, #1
        STR     R4, [R3]

Vis_Record_Result
        LDR     R3, =g_vision_results
        LSLS    R4, R7, #2
        STR     R6, [R3, R4]
        
        ADDS    R7, R7, #1
        STR     R7, [R2]                ; save ring_idx
        
        CMP     R7, #3
        BLO     Vis_Next_Ring

        ; Check if they passed the level (score >= 2)
        LDR     R3, =g_vision_level_score
        LDR     R4, [R3]
        CMP     R4, #2
        BLO     Vis_Fail_Level

        ; Passed! Go to next level
        LDR     R3, =g_vision_level
        LDR     R4, [R3]
        ADDS    R4, R4, #1
        STR     R4, [R3]

        CMP     R4, #5
        BEQ     Vis_Pass_All            ; Passed all 5 levels

        ; Setup next level
        MOVS    R3, #0
        LDR     R2, =g_vision_ring_idx
        STR     R3, [R2]
        LDR     R2, =g_vision_level_score
        STR     R3, [R2]
        MOVS    R7, #0
        B       Vis_Next_Ring

Vis_Fail_Level
Vis_Pass_All
        MOVS    R2, #STATE_VISION_RES
        STR     R2, [R5]
        B       Vis_Force_Redraw

Vis_Next_Ring
        ; Get initial random guess for new ring
        LDR     R2, =g_ms_ticks
        LDR     R2, [R2]
        MOVS    R0, #3
        ANDS    R2, R2, R0       ; Candidate direction in R2

Vis_Check_Unique
        MOVS    R1, #0           ; loop index i = 0 in R1
Vis_Uniq_Loop
        CMP     R1, R7           ; if i >= current ring_idx, candidate is uniquely new
        BHS     Vis_Uniq_Found

        LDR     R3, =g_vision_dirs
        LSLS    R0, R1, #2       ; offset = i * 4
        LDR     R6, [R3, R0]     ; Load past direction from this level into R6

        CMP     R2, R6           ; Compare candidate with past direction
        BNE     Vis_Uniq_Next

        ; Conflict found! Increment candidate, wrap at 3, and restart check from 0
        ADDS    R2, R2, #1
        MOVS    R0, #3
        ANDS    R2, R2, R0
        B       Vis_Check_Unique

Vis_Uniq_Next
        ADDS    R1, R1, #1
        B       Vis_Uniq_Loop

Vis_Uniq_Found
        ; R2 is now guaranteed unique! Store it for the current ring.
        LDR     R3, =g_vision_dirs
        LSLS    R0, R7, #2
        STR     R2, [R3, R0]     
        
Vis_Force_Redraw
        LDR     R2, =g_prev_state
        LDR     R3, =STATE_INVALID
        STR     R3, [R2]

Vis_Exit
        POP     {R4, LR}
        B.W     UI_Handle_Input_EXIT
        ENDFUNC
        ALIGN
        LTORG

; =============================================================================
; UI_Handle_Input_EXIT
; =============================================================================
UI_Handle_Input_EXIT FUNCTION
        MOVS    R2, #KEY_NONE
        STR     R2, [R4]
        POP     {R4, R5, PC}
        ENDFUNC
        ALIGN
        LTORG

        END
