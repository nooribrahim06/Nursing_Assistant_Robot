; =====================================================================
; FILE: medicine.s
; Positional medicine servo on PA6
;
; BEHAVIOR:
; - timer is entered in MINUTES
; - when timer ends -> MED ALERT
; - when user presses OK -> servo rotates one step (0 -> 90 -> 180 -> 0)
; - servo HOLDS the new position automatically via PWM
; - it does NOT return to old position
;
; IMPORTANT:
; This is for a POSITIONAL SERVO.
; 0 degrees ~ 500 us
; 90 degrees ~ 1500 us
; 180 degrees ~ 2500 us
;
; HARDWARE:
; - Medicine positional servo signal -> PA6 / TIM3_CH1
; - PWM_Set_Servo_Pos uses servo id 0 for PA6
; =====================================================================

        INCLUDE constants.s

        AREA    MED_DATA, DATA, READWRITE
        ALIGN

med_input_val           SPACE   4
med_seconds             SPACE   4
med_last_key            SPACE   4
med_active              SPACE   4
med_servo_pos_index     SPACE   4       ; 0=500us, 1=1500us, 2=2500us

        AREA    MED_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        IMPORT  g_sys_state
        IMPORT  g_keycode
        IMPORT  g_alarm_flags
        IMPORT  g_med_wait_ui
        IMPORT  g_ms_ticks
        IMPORT  g_last_med_tick
        IMPORT  g_med_timer
        IMPORT  PWM_Set_Servo_Pos
        IMPORT  g_pre_med_state
        IMPORT  GPIO_WritePin
        IMPORT  GPIO_ClearPin

        EXPORT  MED_Init
        EXPORT  MED_BackgroundTask
        EXPORT  MED_StartFromDisplayedMinutes
        EXPORT  Main_State_MedInput
        EXPORT  Main_State_MedWaiting
        EXPORT  Main_State_MedDispense

; ---------------------------------------------------------------------
; MED_Init
; initialize variables and set servo to 0 degrees
; ---------------------------------------------------------------------
MED_Init
        PUSH    {LR}

        MOVS    R1, #0

        LDR     R0, =med_input_val
        STR     R1, [R0]

        LDR     R0, =med_seconds
        STR     R1, [R0]

        LDR     R0, =med_last_key
        STR     R1, [R0]

        LDR     R0, =med_active
        STR     R1, [R0]

        LDR     R0, =med_servo_pos_index
        STR     R1, [R0]

        ; Set positional servo to 0 degrees (500 us)
        LDR     R0, =500
        MOVS    R1, #0
        BL      PWM_Set_Servo_Pos

        POP     {PC}

; ---------------------------------------------------------------------
; Used by UI layer:
; g_med_timer contains MINUTES entered by user
; This converts to seconds and starts the medicine countdown
; ---------------------------------------------------------------------
MED_StartFromDisplayedMinutes
        PUSH    {R4-R7, LR}

        LDR     R4, =g_med_timer
        LDR     R5, [R4]
        CMP     R5, #0
        BEQ     MSDM_Exit

        ; clear stale med alert flag
        LDR     R4, =g_alarm_flags
        LDR     R6, [R4]
        BIC     R6, R6, #Med_Alert_Flag
        STR     R6, [R4]

        ; convert minutes -> seconds
        MOVS    R6, #60
        MUL     R5, R5, R6

        LDR     R4, =med_seconds
        STR     R5, [R4]

        ; keep private mirror aligned
        LDR     R4, =g_med_timer
        LDR     R5, [R4]
        LDR     R4, =med_input_val
        STR     R5, [R4]

        ; mark active
        LDR     R4, =med_active
        MOVS    R5, #1
        STR     R5, [R4]

        ; store current tick as last second boundary
        LDR     R4, =g_ms_ticks
        LDR     R5, [R4]
        LDR     R4, =g_last_med_tick
        STR     R5, [R4]

        ; short waiting screen for 1 second
        LDR     R4, =g_ms_ticks
        LDR     R5, [R4]
        LDR     R0, =1000
        ADDS    R5, R5, R0
        LDR     R4, =g_med_wait_ui
        STR     R5, [R4]

        ; go to waiting screen
        LDR     R4, =g_sys_state
        MOVS    R5, #STATE_MED_WAITING
        STR     R5, [R4]

MSDM_Exit
        POP     {R4-R7, PC}

; ---------------------------------------------------------------------
; Background countdown task
; ---------------------------------------------------------------------
MED_BackgroundTask
        PUSH    {R4-R7, LR}

        LDR     R4, =med_active
        LDR     R5, [R4]
        CMP     R5, #0
        BEQ     MBG_Exit

        LDR     R4, =g_ms_ticks
        LDR     R5, [R4]

        LDR     R4, =g_last_med_tick
        LDR     R6, [R4]

        SUBS    R7, R5, R6
        LDR     R0, =1000
        CMP     R7, R0
        BLO     MBG_Exit

        ; advance one second boundary
        STR     R5, [R4]

        LDR     R4, =med_seconds
        LDR     R6, [R4]
        CMP     R6, #0
        BEQ     MBG_Finished

        SUBS    R6, R6, #1
        STR     R6, [R4]
        CMP     R6, #0
        BNE     MBG_Exit

MBG_Finished
        MOVS    R5, #0

        LDR     R4, =med_active
        STR     R5, [R4]

        LDR     R4, =g_alarm_flags
        LDR     R6, [R4]
        ORR     R6, R6, #Med_Alert_Flag
        STR     R6, [R4]

        ; Save current state before med alert
        LDR     R4, =g_sys_state
        LDR     R6, [R4]
        CMP     R6, #STATE_MED_ALERT
        BEQ     MBG_SkipSave
        LDR     R0, =g_pre_med_state
        STR     R6, [R0]
MBG_SkipSave
        MOVS    R6, #STATE_MED_ALERT
        STR     R6, [R4]

MBG_Exit
        POP     {R4-R7, PC}

; ---------------------------------------------------------------------
; Legacy keypad path kept intact
; ---------------------------------------------------------------------
Main_State_MedInput
        PUSH    {R4-R7, LR}

        LDR     R4, =g_keycode
        LDR     R5, [R4]

        CMP     R5, #KEY_NONE
        BNE     MSI_Check

        LDR     R6, =med_last_key
        MOVS    R7, #0
        STR     R7, [R6]
        B       MSI_Exit

MSI_Check
        LDR     R6, =med_last_key
        LDR     R7, [R6]
        CMP     R5, R7
        BEQ     MSI_Exit
        STR     R5, [R6]

        CMP     R5, #KEY_A
        BEQ     MSI_Confirm

        CMP     R5, #KEY_B
        BEQ     MSI_Clear

        CMP     R5, #KEY_C
        BEQ     MSI_Back

        MOV     R0, R5
        BL      Key_To_Num
        CMP     R0, #0xFF
        BEQ     MSI_Exit

        LDR     R6, =med_input_val
        LDR     R7, [R6]
        MOVS    R1, #10
        MUL     R7, R7, R1
        ADDS    R7, R7, R0
        STR     R7, [R6]
        B       MSI_Exit

MSI_Clear
        LDR     R6, =med_input_val
        MOVS    R7, #0
        STR     R7, [R6]
        B       MSI_Exit

MSI_Back
        LDR     R6, =g_sys_state
        MOVS    R7, #STATE_MAIN_MENU
        STR     R7, [R6]
        B       MSI_Exit

MSI_Confirm
        LDR     R6, =med_input_val
        LDR     R7, [R6]
        CMP     R7, #0
        BEQ     MSI_Exit

        MOVS    R1, #60
        MUL     R7, R7, R1

        LDR     R6, =med_seconds
        STR     R7, [R6]

        LDR     R6, =g_ms_ticks
        LDR     R7, [R6]

        LDR     R6, =g_last_med_tick
        STR     R7, [R6]

        LDR     R6, =med_active
        MOVS    R7, #1
        STR     R7, [R6]

        LDR     R6, =g_ms_ticks
        LDR     R7, [R6]
        LDR     R0, =1000
        ADDS    R7, R7, R0

        LDR     R6, =g_med_wait_ui
        STR     R7, [R6]

        ; Set the return-to state so MED_WAITING goes back to main menu
        LDR     R6, =g_pre_med_state
        MOVS    R7, #STATE_MAIN_MENU
        STR     R7, [R6]

        LDR     R6, =g_sys_state
        MOVS    R7, #STATE_MED_WAITING
        STR     R7, [R6]

        LDR     R6, =med_input_val
        MOVS    R7, #0
        STR     R7, [R6]

MSI_Exit
        POP     {R4-R7, PC}

; ---------------------------------------------------------------------
; MED_WAITING state
; ---------------------------------------------------------------------
Main_State_MedWaiting
        PUSH    {R4-R6, LR}

        LDR     R4, =g_ms_ticks
        LDR     R5, [R4]

        LDR     R4, =g_med_wait_ui
        LDR     R6, [R4]

        CMP     R5, R6
        BLO     MSW_Exit

        LDR     R4, =g_pre_med_state
        LDR     R5, [R4]
        LDR     R4, =g_sys_state
        STR     R5, [R4]

MSW_Exit
        POP     {R4-R6, PC}

; ---------------------------------------------------------------------
; MED_DISPENSE state
;
; Called once when user confirms medicine taken.
; Advances positional servo to next 90-degree step.
; ---------------------------------------------------------------------
Main_State_MedDispense
        PUSH    {R4-R7, LR}

        ; Read current position index
        LDR     R4, =med_servo_pos_index
        LDR     R5, [R4]

        ; Advance index: 0 -> 1 -> 2 -> 0
        ADDS    R5, R5, #1
        CMP     R5, #3
        BNE     MSD_SetPulse
        MOVS    R5, #0

MSD_SetPulse
        ; Save new index
        STR     R5, [R4]

        ; Convert index to pulse
        CMP     R5, #0
        BEQ     MSD_Pos0
        CMP     R5, #1
        BEQ     MSD_Pos1
        
        ; Must be 2 (180 degrees -> 2500 us)
        LDR     R0, =2500
        B       MSD_Apply

MSD_Pos0
        ; 0 degrees -> 500 us
        LDR     R0, =500
        B       MSD_Apply

MSD_Pos1
        ; 90 degrees -> 1500 us
        LDR     R0, =1500

MSD_Apply
        MOVS    R1, #0
        BL      PWM_Set_Servo_Pos

        ; Beep to confirm dispense
        LDR     R0, =GPIOB_BASE
        MOVS    R1, #BUZZER_PIN
        BL      GPIO_WritePin
        
        ; Short delay for beep
        LDR     R2, =200000
MSD_BeepLoop
        SUBS    R2, R2, #1
        BNE     MSD_BeepLoop

        LDR     R0, =GPIOB_BASE
        MOVS    R1, #BUZZER_PIN
        BL      GPIO_ClearPin

        ; Clear medicine alert
        LDR     R4, =g_alarm_flags
        LDR     R6, [R4]
        BIC     R6, R6, #Med_Alert_Flag
        STR     R6, [R4]

        ; Clear medicine timing state variables
        MOVS    R5, #0
        
        LDR     R4, =med_seconds
        STR     R5, [R4]
        
        LDR     R4, =med_active
        STR     R5, [R4]
        
        LDR     R4, =g_med_timer
        STR     R5, [R4]
        
        LDR     R4, =med_input_val
        STR     R5, [R4]

        ; Wait about 1 second so the user sees the "Dispensing" screen
        ; and the servo has time to finish moving.
        LDR     R2, =8000000         ; Approx 1s at 16MHz (3-4 cycles per loop)
MSD_FinalDelay
        SUBS    R2, R2, #1
        BNE     MSD_FinalDelay

        ; Return to previous state
        LDR     R4, =g_pre_med_state
        LDR     R5, [R4]
        LDR     R4, =g_sys_state
        STR     R5, [R4]

        POP     {R4-R7, PC}

; ---------------------------------------------------------------------
; Key_To_Num
; ---------------------------------------------------------------------
Key_To_Num
        CMP     R0, #KEY_0
        BNE     K_1
        MOVS    R0, #0
        BX      LR

K_1
        CMP     R0, #KEY_1
        BNE     K_2
        MOVS    R0, #1
        BX      LR

K_2
        CMP     R0, #KEY_2
        BNE     K_3
        MOVS    R0, #2
        BX      LR

K_3
        CMP     R0, #KEY_3
        BNE     K_4
        MOVS    R0, #3
        BX      LR

K_4
        CMP     R0, #KEY_4
        BNE     K_5
        MOVS    R0, #4
        BX      LR

K_5
        CMP     R0, #KEY_5
        BNE     K_6
        MOVS    R0, #5
        BX      LR

K_6
        CMP     R0, #KEY_6
        BNE     K_7
        MOVS    R0, #6
        BX      LR

K_7
        CMP     R0, #KEY_7
        BNE     K_8
        MOVS    R0, #7
        BX      LR

K_8
        CMP     R0, #KEY_8
        BNE     K_9
        MOVS    R0, #8
        BX      LR

K_9
        CMP     R0, #KEY_9
        BNE     K_Err
        MOVS    R0, #9
        BX      LR

K_Err
        MOVS    R0, #0xFF
        BX      LR

        END