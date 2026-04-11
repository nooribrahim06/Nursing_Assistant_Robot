; =====================================================================
; FILE: medicine.s
; =====================================================================
        INCLUDE constants.s

        AREA    MED_DATA, DATA, READWRITE
        ALIGN
med_input_val       SPACE   4
med_seconds         SPACE   4
med_last_key        SPACE   4
med_active          SPACE   4

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
        IMPORT  PWM_Set_Servo_Pos

        EXPORT  MED_Init
        EXPORT  MED_BackgroundTask
        EXPORT  Main_State_MedInput
        EXPORT  Main_State_MedWaiting
        EXPORT  Main_State_MedDispense

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
        POP     {PC}

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
        LDR     R4, =g_sys_state
        MOVS    R6, #4 ; STATE_MED_ALERT
        STR     R6, [R4] 
MBG_Exit
        POP     {R4-R7, PC}

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
        MOVS    R7, #0 ; STATE_MAIN_MENU
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

        LDR     R6, =g_sys_state
        MOVS    R7, #9 ; STATE_MED_WAITING
        STR     R7, [R6]

        LDR     R6, =med_input_val
        MOVS    R7, #0
        STR     R7, [R6]
MSI_Exit
        POP     {R4-R7, PC}

Main_State_MedWaiting
        PUSH    {R4-R6, LR}
        LDR     R4, =g_ms_ticks
        LDR     R5, [R4]
        LDR     R4, =g_med_wait_ui
        LDR     R6, [R4]
        CMP     R5, R6 
        BLO     MSW_Exit
        LDR     R4, =g_sys_state
        MOVS    R5, #0 
        STR     R5, [R4]
MSW_Exit
        POP     {R4-R6, PC}

Main_State_MedDispense
        PUSH    {R4-R6, LR}
        LDR     R0, =2000
        MOVS    R1, #1
        BL      PWM_Set_Servo_Pos
        LDR     R4, =300000
MSD_Delay1
        SUBS    R4, R4, #1
        BNE     MSD_Delay1
        LDR     R0, =1500
        MOVS    R1, #1
        BL      PWM_Set_Servo_Pos
        LDR     R4, =g_alarm_flags
        LDR     R5, [R4]
        BIC     R5, R5, #Med_Alert_Flag
        STR     R5, [R4]
        LDR     R4, =med_seconds
        MOVS    R5, #0
        STR     R5, [R4]
        LDR     R4, =med_active
        STR     R5, [R4]
        LDR     R4, =g_sys_state
        MOVS    R5, #0
        STR     R5, [R4]
        POP     {R4-R6, PC}

Key_To_Num
        CMP     R0, #KEY_0
        BNE     K_1
        MOVS    R0, #0
        BX      LR
K_1     CMP     R0, #KEY_1
        BNE     K_2
        MOVS    R0, #1
        BX      LR
K_2     CMP     R0, #KEY_2
        BNE     K_3
        MOVS    R0, #2
        BX      LR
K_3     CMP     R0, #KEY_3
        BNE     K_4
        MOVS    R0, #3
        BX      LR
K_4     CMP     R0, #KEY_4
        BNE     K_5
        MOVS    R0, #4
        BX      LR
K_5     CMP     R0, #KEY_5
        BNE     K_6
        MOVS    R0, #5
        BX      LR
K_6     CMP     R0, #KEY_6
        BNE     K_7
        MOVS    R0, #6
        BX      LR
K_7     CMP     R0, #KEY_7
        BNE     K_8
        MOVS    R0, #7
        BX      LR
K_8     CMP     R0, #KEY_8
        BNE     K_9
        MOVS    R0, #8
        BX      LR
K_9     CMP     R0, #KEY_9
        BNE     K_Err
        MOVS    R0, #9
        BX      LR
K_Err
        MOVS    R0, #0xFF
        BX      LR

        END