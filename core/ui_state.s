; =============================================================================
; ui_state.s
; UI State Machine — screen routing, full/partial refresh logic
;
; Exports : UI_Update
; Imports : g_sys_state, g_prev_state, g_bpm, g_smoke_level  (globals.s)
;           TFT_Clear_Screen, TFT_Render_* , TFT_Update_Smoke_Level (tft_gfx.s)
;           All STATE_* constants come from constants.s via the assembler
; Call contract for UI_Update:
;   Inputs  : none  (reads globals directly)
;   Outputs : none  (side effect = TFT updated)
; =============================================================================
 
    AREA    UI_STATE, CODE, READONLY
  
    EXPORT  UI_Update
 

    IMPORT  g_sys_state
    IMPORT  g_prev_state
    IMPORT  g_bpm
    IMPORT  g_smoke_level
    IMPORT  g_alarm_flags
    Import  g_med_timer
    Import  g_keycode

    IMPORT  TFT_Clear_Screen
    IMPORT  TFT_Render_Main_Menu
    IMPORT  TFT_Render_Sanitizing
    IMPORT  TFT_Render_Heart_Rate
    IMPORT  TFT_Render_Breathing
    IMPORT  TFT_Render_Med_Input
    IMPORT  TFT_Render_Med_Alert
    IMPORT  TFT_Render_Med_Dispense
    IMPORT  TFT_Render_Smoke_ALERT
    IMPORT  TFT_Update_Smoke_Level

; =============================================================================
; UI_Update
; Called from the main loop every iteration.
; Responsibilities:
;   1.Flags Highest Priority
;   1. Compare g_sys_state vs g_prev_state
;   2. If changed  → full screen clear + full redraw for new state
;   3. If unchanged → partial update for dynamic elements only

UI_Update:

    push {R4,R5,LR}
    ;-- Flag Handling (Highest Priority) --
    LDR R0, =g_alarm_flags
    LDR R1, [R0]           

    ; Check Smoke Alert Flag
    TST R1, #Smoke_Alert_Flag
    BNE Handle_Smoke_Alert
    ; Check Med Alert Flag
    TST R1, #Med_Alert_Flag
    BNE Handle_Med_Alert

    BL      UI_Handle_Input    ; Check for user input and update state/timers as needed

UI_CHECK:

    ; Read current state 
    LDR R4, =g_sys_state
    LDR R1 , [R4]          ; Load current system state into R1
    ;Read Prev state 
    LDR R5, =g_prev_state
    LDR R0 , [R5]          ; Load previous system state into R0
    ; Compare states, if different update screen
    CMP R1, R0
    BEQ UI_Partial_Update ; If states are the same, skip to partial update for dynamic elements
    ; diff function to update the screen if state changed 
    STR R1, [R5]          ; Update previous state to current state
    BL TFT_Clear_Screen     ; Clear the screen before rendering new state

    ; State machine to determine which screen to display
    CMP R1, #STATE_MAIN_MENU
    BEQ UI_Render_Main_Menu

    CMP R1, #STATE_SANITIZING
    BEQ UI_Render_Sanitizing

    CMP R1, #STATE_HEART_RATE
    BEQ UI_Render_Heart_Rate

    CMP R1, #STATE_BREATHING
    BEQ UI_Render_Breathing

    CMP R1, #STATE_MED_INPUT
    BEQ UI_Render_Med_Input

    CMP R1, #STATE_MED_ALERT
    BEQ UI_Render_Med_Alert

    CMP R1, #STATE_MED_DISPENSE
    BEQ UI_Render_Med_Dispense

    CMP R1, #STATE_SMOKE_ALERT
    BEQ UI_Render_Smoke_ALERT

    B UI_EXIT

; UI_Partial_Update - Update dynamic elements on the screen without full redraw
; Our dynamic elements are currently just the smoke level in the main menu and smoke alert states

UI_Partial_Update:
    LDR R4, =g_sys_state
    LDR R1 , [R4]          ; Load current system state into R1

    LDR R3, =g_smoke_level
    LDR R2, [R3]           ; Load current smoke level into R2

    ; update just the smoke level if we are in the main menu or smoke alert state
    CMP R1, #STATE_MAIN_MENU
    BEQ UI_Update_Smoke_Level

    CMP R1, #STATE_SMOKE_ALERT
    BEQ UI_Update_Smoke_Level

    ; i think other states dont have dynamic elements that need updating, but we can add more cases here 

    B UI_EXIT



; UI_Render_Main_Menu - Render the main menu screen
UI_Render_Main_Menu:

    BL TFT_Render_Main_Menu
    B UI_EXIT

UI_Render_Sanitizing:
    BL TFT_Render_Sanitizing
    B UI_EXIT

UI_Render_Heart_Rate:
    BL TFT_Render_Heart_Rate
    B UI_EXIT

UI_Render_Breathing:
    BL TFT_Render_Breathing
    B UI_EXIT

UI_Render_Med_Input:
    BL TFT_Render_Med_Input
    B UI_EXIT

UI_Render_Med_Alert:
    BL TFT_Render_Med_Alert
    B UI_EXIT

UI_Render_Med_Dispense:
    BL TFT_Render_Med_Dispense
    B UI_EXIT

UI_Render_Smoke_ALERT:
    BL TFT_Render_Smoke_ALERT
    B UI_EXIT

UI_Update_Smoke_Level:
    ; Call TFT function to update smoke level, passing the new value in R2
    BL TFT_Update_Smoke_Level
    B UI_EXIT


; Handle_Smoke_Alert - Render smoke alert screen if flag is set
Handle_Smoke_Alert:
    ; Set system state to smoke alert to trigger full screen update
    LDR R0, =g_sys_state
    MOV R1, #STATE_SMOKE_ALERT
    STR R1, [R0]
    B UI_CHECK ; After handling the alert, check for any other flags or updates


Handle_Med_Alert:
    ; Change system state 
    LDR R0, =g_sys_state
    Mov R1,#STATE_MED_ALERT
    STR R1, [R0]
    B UI_CHECK 

; UI_EXIT - Common exit point for UI_Update
UI_EXIT:
    pop {R4,R5,PC}


; =============================================================================
; UI_Handle_Input
; Reads g_keycode and decides what to do based on current state
; Called at the top of UI_Update after flag handling
;
; Inputs  : none (reads g_keycode and g_sys_state directly)
; Outputs : none (writes g_sys_state and g_med_timer)
; =============================================================================

UI_Handle_Input:
    PUSH    {R4, R5, LR}

    LDR     R4, =g_keycode
    LDR     R0, [R4]                ; R0 = current key code

    CMP     R0, #KEY_NONE
    BEQ     UI_Handle_Input_EXIT    ; no key pressed, nothing to do

    LDR     R5, =g_sys_state
    LDR     R1, [R5]                ; R1 = current state

    CMP     R1, #STATE_MAIN_MENU
    BEQ     Input_Main_Menu

    CMP     R1, #STATE_SANITIZING
    BEQ     Input_Exit_State        ; in these states we have only one input D-> back to main menu

    CMP     R1, #STATE_HEART_RATE
    BEQ     Input_Exit_State

    CMP     R1, #STATE_BREATHING
    BEQ     Input_Exit_State

    CMP     R1, #STATE_MED_INPUT
    BEQ     Input_Med_Input

    CMP     R1, #STATE_MED_ALERT
    BEQ     Input_Med_Alert

    B       UI_Handle_Input_EXIT    ; unhandled state


; -----------------------------------------------------------------------------
; Main menu: 1-4 navigate to features
; -----------------------------------------------------------------------------
Input_Main_Menu:
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


; -----------------------------------------------------------------------------
; Sanitizing / Heart / Breathing: D exits back to main menu
; -----------------------------------------------------------------------------
Input_Exit_State:
    CMP     R0, #KEY_D
    BNE     UI_Handle_Input_EXIT
    MOV     R2, #STATE_MAIN_MENU
    STR     R2, [R5]
    B       UI_Handle_Input_EXIT


; -----------------------------------------------------------------------------
; Med input: digits build timer, A confirms, B clears, C cancels
; -----------------------------------------------------------------------------
Input_Med_Input:
    CMP     R0, #KEY_A
    BNE     MI_try_B
    MOV     R2, #STATE_MED_WAITING
    STR     R2, [R5]
    B       UI_Handle_Input_EXIT

MI_try_B
    CMP     R0, #KEY_B
    BNE     MI_try_C
    LDR     R2, =g_med_timer        ; B -> clear timer
    MOV     R3, #0
    STR     R3, [R2]
    B       UI_Handle_Input_EXIT

MI_try_C
    CMP     R0, #KEY_C
    BNE     MI_try_digits
    LDR     R2, =g_med_timer        ; C -> clear timer and go back
    MOV     R3, #0
    STR     R3, [R2]
    MOV     R2, #STATE_MAIN_MENU
    STR     R2, [R5]
    B       UI_Handle_Input_EXIT

MI_try_digits
    ; check each digit key and load the real numeric value into R2
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
    BNE     UI_Handle_Input_EXIT    ; not a digit we care about
    MOV     R2, #9

Input_Add_Digit
    ; g_med_timer = (g_med_timer * 10) + new digit
    LDR     R3, =g_med_timer
    LDR     R0, [R3]                ; current timer value
    MOV     R1, #10
    MUL     R0, R1, R0              ; shift left one decimal place
    ADD     R0, R0, R2              ; add new digit
    STR     R0, [R3]
    B       UI_Handle_Input_EXIT


; -----------------------------------------------------------------------------
; Med alert: A confirms dispense, C cancels
; -----------------------------------------------------------------------------
Input_Med_Alert:
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


; -----------------------------------------------------------------------------
UI_Handle_Input_EXIT:
    MOV     R2, #KEY_NONE
    STR     R2, [R4]                ; clear keycode so same key isn't processed twice

    POP     {R4, R5, PC}