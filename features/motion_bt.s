; =====================================================================
; FILE: motion_bt.s (Touched)
; DESCRIPTION: Bluetooth phone override logic for motion
; =====================================================================

        AREA    MOTION_BT_DATA, DATA, READWRITE
        ALIGN

        ; We keep a local copy of the direction so motors keep running
phone_dir       DCD     0

        AREA    MOTION_BT_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

        EXPORT  MotionBT_Init
        EXPORT  MotionBT_SetMode
        EXPORT  MotionBT_ApplyDirection
        EXPORT  MotionBT_Task

        IMPORT  g_sys_state
        IMPORT  g_motion_mode
        IMPORT  g_bt_cmd_ready
        IMPORT  g_bt_motion_mode_request
        IMPORT  g_bt_motion_dir_request
        IMPORT  g_bt_last_rx_tick
        IMPORT  g_ms_ticks

        IMPORT  Motion_Forward
        IMPORT  Motion_Backward
        IMPORT  Motion_Left
        IMPORT  Motion_Right
        IMPORT  Motion_Stop
        IMPORT  PWM_Set_Motor_Speed

; ---------------------------------------------------------------------
; MotionBT_Init
; ---------------------------------------------------------------------
MotionBT_Init
        PUSH    {R0, R1, LR}
        LDR     R0, =g_motion_mode
        MOVS    R1, #MOTION_MODE_LINE
        STR     R1, [R0]
        LDR     R0, =phone_dir
        MOVS    R1, #PHONE_DIR_STOP
        STR     R1, [R0]
        POP     {R0, R1, PC}

; ---------------------------------------------------------------------
; MotionBT_SetMode
; Called when a mode change command is received.
; R0 = Mode to set (MOTION_MODE_LINE or MOTION_MODE_PHONE)
; ---------------------------------------------------------------------
MotionBT_SetMode
        PUSH    {R0-R3, LR}
        
        ; Stop motors first
        BL      Motion_Stop

        ; Set g_motion_mode
        LDR     R1, =g_motion_mode
        STR     R0, [R1]

        ; If entering PHONE mode, FORCE the system UI state into MOTION!
        ; Without this, MOT_Update never runs if the robot is on the Main Menu.
        CMP     R0, #MOTION_MODE_PHONE
        BNE     MBSM_SkipUI

        LDR     R1, =g_sys_state
        LDR     R2, =STATE_MOTION
        STR     R2, [R1]

MBSM_SkipUI
        ; Clear phone dir locally to ensure we stop until next command
        LDR     R1, =phone_dir
        MOVS    R2, #PHONE_DIR_STOP
        STR     R2, [R1]

        ; Clear consumed Bluetooth request flag
        LDR     R1, =g_bt_motion_mode_request
        MOVS    R2, #0
        STR     R2, [R1]

        POP     {R0-R3, PC}

; ---------------------------------------------------------------------
; MotionBT_ApplyDirection
; Called when a direction command is received.
; R0 = Direction to apply (PHONE_DIR_FWD, etc.)
; ---------------------------------------------------------------------
MotionBT_ApplyDirection
        PUSH    {R0-R2, LR}

        ; Clear the BT request flag since we consume it
        LDR     R1, =g_bt_motion_dir_request
        MOVS    R2, #0
        STR     R2, [R1]

        ; IDIOT-PROOF WAKEUP: If we receive a direction command, force the robot
        ; completely into Phone Control mode, even if the app failed to send MODE=PHONE!
        LDR     R1, =g_motion_mode
        MOVS    R2, #MOTION_MODE_PHONE
        STR     R2, [R1]

        LDR     R1, =g_sys_state
        LDR     R2, =STATE_MOTION
        STR     R2, [R1]

        ; Save direction
        LDR     R1, =phone_dir
        STR     R0, [R1]

MBAD_Exit
        POP     {R0-R2, PC}

; ---------------------------------------------------------------------
; MotionBT_Task
; Called repeatedly from MOT_Update ONLY when g_motion_mode == PHONE.
; ---------------------------------------------------------------------
MotionBT_Task
        PUSH    {R3-R5, LR}

        ; Check timeout (g_ms_ticks - g_bt_last_rx_tick > PHONE_TIMEOUT_MS)
        LDR     R0, =g_ms_ticks
        LDR     R1, [R0]
        
        LDR     R0, =g_bt_last_rx_tick
        LDR     R2, [R0]

        SUBS    R3, R1, R2
        LDR     R4, =PHONE_TIMEOUT_MS
        CMP     R3, R4
        BLS     MBT_CheckDir

        ; Timeout occurred -> Stop motors but stay in phone mode
        LDR     R0, =phone_dir
        MOVS    R1, #PHONE_DIR_STOP
        STR     R1, [R0]

        BL      Motion_Stop
        B       MBT_Exit

MBT_CheckDir
        LDR     R0, =phone_dir
        LDR     R1, [R0]

        CMP     R1, #PHONE_DIR_FWD
        BEQ     MBT_Action_Forward

        CMP     R1, #PHONE_DIR_BACK
        BEQ     MBT_Action_Back

        CMP     R1, #PHONE_DIR_LEFT
        BEQ     MBT_Action_Left

        CMP     R1, #PHONE_DIR_RIGHT
        BEQ     MBT_Action_Right

        ; STOP or invalid
        BL      Motion_Stop
        B       MBT_Exit

MBT_Action_Forward
        BL      Motion_Forward
        LDR     R0, =PHONE_SPEED
        LDR     R1, =PHONE_SPEED
        BL      PWM_Set_Motor_Speed
        B       MBT_Exit

MBT_Action_Back
        BL      Motion_Backward
        LDR     R0, =PHONE_SPEED
        LDR     R1, =PHONE_SPEED
        BL      PWM_Set_Motor_Speed
        B       MBT_Exit

MBT_Action_Left
        BL      Motion_Forward
        LDR     R0, =PHONE_TURN_FAST
        LDR     R1, =PHONE_TURN_SLOW
        BL      PWM_Set_Motor_Speed
        B       MBT_Exit

MBT_Action_Right
        BL      Motion_Forward
        LDR     R0, =PHONE_TURN_SLOW
        LDR     R1, =PHONE_TURN_FAST
        BL      PWM_Set_Motor_Speed
        B       MBT_Exit

MBT_Exit
        POP     {R3-R5, PC}

        ALIGN
        END