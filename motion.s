; =====================================================================
; FILE: motion.s (Touched)
; DESCRIPTION:
;   Default motion flow + temporary PHONE override for Bluetooth app
;
; DEFAULT:
;   Runs the existing line-tracker motion exactly like before.
;
; PHONE OVERRIDE:
;   Bluetooth parser will call exported MOT_SetPhone... functions.
;   While g_motion_state = MOTION_PHONE, MOT_Update ignores sensors
;   and executes the latest phone direction.
;
; IMPORTANT:
;   - No new UI state is required.
;   - MODE=LINE from app means return to DEFAULT normal flow.
;   - Direction commands are ignored unless PHONE override is active.
; =====================================================================

        AREA    MOTION_DATA, DATA, READWRITE
        ALIGN

Last_Turn               DCD     0       ; 0=Straight, 1=Left, 2=Right

        AREA    MOTION_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s
        

; ---------------------------------------------------------------------
; Public functions used by main.s
; ---------------------------------------------------------------------
        EXPORT  MOT_Init
        EXPORT  MOT_Update
        EXPORT  MOT_StopNow

; ---------------------------------------------------------------------
; Public functions used by bluetooth.s skeleton
; ---------------------------------------------------------------------
        EXPORT  Motion_Forward
        EXPORT  Motion_Backward
        EXPORT  Motion_Left
        EXPORT  Motion_Right
        EXPORT  Motion_Stop

; ---------------------------------------------------------------------
; Imports
; ---------------------------------------------------------------------
        IMPORT  GPIO_EnableClock
        IMPORT  GPIO_ConfigOutput
        IMPORT  GPIO_ConfigInput
        IMPORT  GPIO_WritePin
        IMPORT  GPIO_ClearPin
        IMPORT  GPIO_ReadPin
        IMPORT  PWM_Init
        IMPORT  PWM_Set_Motor_Speed

        IMPORT  g_motion_mode
        IMPORT  MotionBT_Task

; ---------------------------------------------------------------------
; Local motion-control values
; ---------------------------------------------------------------------



; =====================================================================
; MOT_Init
; =====================================================================
MOT_Init
        PUSH    {R0-R2, LR}

        ; Enable needed GPIO clocks
        LDR     R0, =GPIOA_BASE
        BL      GPIO_EnableClock

        LDR     R0, =GPIOB_BASE
        BL      GPIO_EnableClock

        LDR     R0, =GPIOC_BASE
        BL      GPIO_EnableClock

        ; Motor direction pins: PA8, PA9, PA10, PA11
        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN1
        BL      GPIO_ConfigOutput

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN2
        BL      GPIO_ConfigOutput

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN3
        BL      GPIO_ConfigOutput

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN4
        BL      GPIO_ConfigOutput

        ; Existing line sensor pins kept exactly as current file:
        ; LEFT   -> PB12
        ; CENTER -> PB15
        ; RIGHT  -> PB14
        LDR     R0, =GPIOB_BASE
        MOV     R1, #12
        BL      GPIO_ConfigInput

        LDR     R0, =GPIOB_BASE
        MOV     R1, #15
        BL      GPIO_ConfigInput

        LDR     R0, =GPIOB_BASE
        MOV     R1, #14
        BL      GPIO_ConfigInput

        ; Keep old behavior: PWM init here
        BL      PWM_Init

        LDR     R0, =Last_Turn
        MOVS    R1, #0
        STR     R1, [R0]

        BL      MOT_StopNow

        POP     {R0-R2, PC}


; =====================================================================
; MOT_Update
;
; Called repeatedly from main loop.
;
; If PHONE override is active:
;   execute latest phone direction.
;
; Else:
;   run original/default line tracker flow.
; =====================================================================
MOT_Update
        PUSH    {R3-R7, LR}             ; R3 pushed to ensure 8-byte stack alignment

        LDR     R0, =g_motion_mode
        LDR     R1, [R0]

        CMP     R1, #MOTION_MODE_PHONE
        BNE     MOT_DefaultFlow

        BL      MotionBT_Task
        B       MOT_Update_Exit


; =====================================================================
; DEFAULT FLOW
; This is the old/current line-tracker logic kept as-is.
; =====================================================================
MOT_DefaultFlow
        ; 1. LEFT SENSOR PB12 -> Bit 2
        LDR     R0, =GPIOB_BASE
        MOV     R1, #12
        BL      GPIO_ReadPin
        LSL     R4, R0, #2

        ; 2. CENTER SENSOR PB15 -> Bit 1
        LDR     R0, =GPIOB_BASE
        MOV     R1, #15
        BL      GPIO_ReadPin
        LSL     R5, R0, #1

        ; 3. RIGHT SENSOR PB14 -> Bit 0
        LDR     R0, =GPIOB_BASE
        MOV     R1, #14
        BL      GPIO_ReadPin
        MOV     R6, R0

        ; 4. Combine sensor mask
        ORR     R7, R4, R5
        ORR     R7, R7, R6

        ; -------------------------------------------------------------
        ; Existing decision tree
        ; -------------------------------------------------------------
        CMP     R7, #0x02               ; Center only
        BEQ     Action_Straight

        CMP     R7, #0x05               ; Left + Right
        BEQ     Action_Straight

        CMP     R7, #0x04               ; Left only
        BEQ     Action_Arc_Left

        CMP     R7, #0x06               ; Left + Center
        BEQ     Action_Arc_Left

        CMP     R7, #0x01               ; Right only
        BEQ     Action_Arc_Right

        CMP     R7, #0x03               ; Right + Center
        BEQ     Action_Arc_Right

        CMP     R7, #0x07               ; All sensors
        BEQ     Rescue_Lost_Line

        CMP     R7, #0x00               ; No sensors
        BEQ     Action_Search

        B       Action_Search


; =====================================================================
; MEMORY RESCUE LOGIC
; =====================================================================
Rescue_Lost_Line
        LDR     R2, =Last_Turn
        LDR     R3, [R2]

        CMP     R3, #1
        BEQ     Action_Pivot_Right

        CMP     R3, #2
        BEQ     Action_Pivot_Left

        B       Action_Straight


; =====================================================================
; DEFAULT MOVEMENT BLOCKS
; =====================================================================
Action_Straight
        LDR     R2, =Last_Turn
        MOV     R3, #0
        STR     R3, [R2]

        BL      Set_Dir_Forward

        LDR     R0, =340
        LDR     R1, =340
        BL      PWM_Set_Motor_Speed

        B       MOT_Update_Exit


Action_Arc_Left
        LDR     R2, =Last_Turn
        MOV     R3, #1
        STR     R3, [R2]

        BL      Set_Dir_Forward

        LDR     R0, =480
        LDR     R1, =280
        BL      PWM_Set_Motor_Speed

        B       MOT_Update_Exit


Action_Arc_Right
        LDR     R2, =Last_Turn
        MOV     R3, #2
        STR     R3, [R2]

        BL      Set_Dir_Forward

        LDR     R0, =290
        LDR     R1, =480
        BL      PWM_Set_Motor_Speed

        B       MOT_Update_Exit


Action_Pivot_Left
        BL      Set_Dir_Spin_Left

        LDR     R0, =280
        LDR     R1, =280
        BL      PWM_Set_Motor_Speed

        B       MOT_Update_Exit


Action_Pivot_Right
        BL      Set_Dir_Spin_Right

        LDR     R0, =280
        LDR     R1, =280
        BL      PWM_Set_Motor_Speed

        B       MOT_Update_Exit


Action_Search
        BL      MOT_StopNow
        B       MOT_Update_Exit


MOT_Update_Exit
        POP     {R3-R7, PC}


; =====================================================================
; MOT_StopNow
; Stops both motors immediately.
; Clears direction pins and sets PWM to zero.
; =====================================================================
MOT_StopNow
Motion_Stop
        PUSH    {R3, LR}                ; PUSH R3 to maintain 8-byte stack alignment

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN1
        BL      GPIO_ClearPin

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN2
        BL      GPIO_ClearPin

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN3
        BL      GPIO_ClearPin

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN4
        BL      GPIO_ClearPin

        MOVS    R0, #0
        MOVS    R1, #0
        BL      PWM_Set_Motor_Speed

        POP     {R3, PC}





; =====================================================================
; Direction Helpers
; =====================================================================

; ---------------------------------------------------------------------
; Both motors forward
; ---------------------------------------------------------------------
Set_Dir_Forward
Motion_Forward
        PUSH    {R3, LR}                ; PUSH R3 to maintain 8-byte stack alignment

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN1
        BL      GPIO_WritePin

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN2
        BL      GPIO_ClearPin

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN3
        BL      GPIO_WritePin

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN4
        BL      GPIO_ClearPin

        POP     {R3, PC}


; ---------------------------------------------------------------------
; Both motors backward
; ---------------------------------------------------------------------
Set_Dir_Backward
Motion_Backward
        PUSH    {R3, LR}                ; PUSH R3 to maintain 8-byte stack alignment

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN1
        BL      GPIO_ClearPin

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN2
        BL      GPIO_WritePin

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN3
        BL      GPIO_ClearPin

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN4
        BL      GPIO_WritePin

        POP     {R3, PC}


; ---------------------------------------------------------------------
; Tank spin left:
; right motor forward, left motor backward
; ---------------------------------------------------------------------
Set_Dir_Spin_Left
Motion_Left
        PUSH    {R3, LR}                ; PUSH R3 to maintain 8-byte stack alignment

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN1
        BL      GPIO_WritePin

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN2
        BL      GPIO_ClearPin

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN3
        BL      GPIO_ClearPin

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN4
        BL      GPIO_WritePin

        POP     {R3, PC}


; ---------------------------------------------------------------------
; Tank spin right:
; right motor backward, left motor forward
; ---------------------------------------------------------------------
Set_Dir_Spin_Right
Motion_Right
        PUSH    {R3, LR}                ; PUSH R3 to maintain 8-byte stack alignment

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN1
        BL      GPIO_ClearPin

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN2
        BL      GPIO_WritePin

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN3
        BL      GPIO_WritePin

        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN4
        BL      GPIO_ClearPin

        POP     {R3, PC}


        ALIGN
        END