; =====================================================================
; FILE: motion.s
; DESCRIPTION: Full motion control logic with PWM and Line Tracking
; LAYER: Feature Module (Layer 2)
; =====================================================================

        AREA    MOTION_CODE, CODE, READONLY
        GET     core\constants.inc
        EXPORT  MOT_Init
        EXPORT  MOT_Update
        
        ; Import low-level drivers
        IMPORT  GPIO_EnableClock
        IMPORT  GPIO_ConfigOutput
        IMPORT  GPIO_ConfigInput
        IMPORT  GPIO_WritePin
        IMPORT  GPIO_ClearPin
        IMPORT  GPIO_ReadPin
        IMPORT  PWM_Init
        IMPORT  PWM_Set_Motor_Speed
        
        ; Import global variables
        IMPORT  g_motion_state

; ---------------------------------------------------------------------
; Subroutine: MOT_Init
; Purpose: Initialize Clocks, GPIOs, and PWM for Motion
; ---------------------------------------------------------------------
MOT_Init
        PUSH    {LR}
        
        ; 1. Enable clocks for required ports (mandatory before configuration) 
        LDR     R0, =GPIOA_BASE
        BL      GPIO_EnableClock
        LDR     R0, =GPIOB_BASE
        BL      GPIO_EnableClock
        LDR     R0, =GPIOC_BASE
        BL      GPIO_EnableClock
        
        ; 2. Configure motor direction pins (PA8-PA11) as outputs
        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN1
        BL      GPIO_ConfigOutput
        MOV     R1, #MOT_IN2
        BL      GPIO_ConfigOutput
        MOV     R1, #MOT_IN3
        BL      GPIO_ConfigOutput
        MOV     R1, #MOT_IN4
        BL      GPIO_ConfigOutput
        
        ; 3. Configure line tracking sensor pins (PC0-PC2) as inputs
        LDR     R0, =GPIOC_BASE
        MOV     R1, #LINE_LEFT
        BL      GPIO_ConfigInput
        MOV     R1, #LINE_CENTER
        BL      GPIO_ConfigInput
        MOV     R1, #LINE_RIGHT
        BL      GPIO_ConfigInput
        
        ; 4. Initialize PWM for speed control
        BL      PWM_Init 
        
        POP     {PC}

; ---------------------------------------------------------------------
; Subroutine: MOT_Update
; Purpose: Main logic loop for line following
; ---------------------------------------------------------------------
MOT_Update
        PUSH    {R4-R6, LR}     ; Save protected registers

        ; Read the state of the three sensors
        LDR     R0, =GPIOC_BASE
        MOV     R1, #LINE_LEFT
        BL      GPIO_ReadPin
        MOV     R4, R0          ; R4 = Left sensor state

        MOV     R1, #LINE_CENTER
        BL      GPIO_ReadPin
        MOV     R5, R0          ; R5 = Center sensor state

        MOV     R1, #LINE_RIGHT
        BL      GPIO_ReadPin
        MOV     R6, R0          ; R6 = Right sensor state

        ; Decision-making logic based on sensor readings
        CMP     R5, #1          ; Is the line in the center?
        BEQ     Action_Forward

        CMP     R4, #1          ; Is the line to the left?
        BEQ     Action_Turn_Left

        CMP     R6, #1          ; Is the line to the right?
        BEQ     Action_Turn_Right

        B       Action_Stop     ; No line detected (lost)

Action_Forward
        BL      Set_Dir_Forward ; Set direction pins for forward motion
        LDR     R2, =g_motion_state
        MOV     R3, #1          ; State code: 1 = Forward
        STR     R3, [R2]
        
        MOV     R0, #800        ; Right motor speed 80% 
        MOV     R1, #800        ; Left motor speed 80%
        BL      PWM_Set_Motor_Speed
        B       End_Update

Action_Turn_Left
        BL      Set_Dir_Forward
        LDR     R2, =g_motion_state
        MOV     R3, #2          ; State code: 2 = Turning Left
        STR     R3, [R2]
        
        MOV     R0, #750        ; Push from the right to turn left
        MOV     R1, #250        ; Reduce left motor speed
        BL      PWM_Set_Motor_Speed
        B       End_Update

Action_Turn_Right
        BL      Set_Dir_Forward
        LDR     R2, =g_motion_state
        MOV     R3, #3          ; State code: 3 = Turning Right
        STR     R3, [R2]
        
        MOV     R0, #250        ; Reduce right motor speed
        MOV     R1, #750        ; Push from the left to turn right
        BL      PWM_Set_Motor_Speed
        B       End_Update

Action_Stop
        LDR     R2, =g_motion_state
        MOV     R3, #0          ; State code: 0 = Stopped
        STR     R3, [R2]
        
        MOV     R0, #0          ; Stop speed completely (0%)
        MOV     R1, #0
        BL      PWM_Set_Motor_Speed
        B       End_Update

End_Update
        POP     {R4-R6, PC}     ; Restore registers and return

; ---------------------------------------------------------------------
; Helper: Set_Dir_Forward
; Purpose: Configure PA8-PA11 for forward movement
; ---------------------------------------------------------------------
Set_Dir_Forward
        PUSH    {LR}
        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN1
        BL      GPIO_WritePin   ; IN1 = High
        MOV     R1, #MOT_IN2
        BL      GPIO_ClearPin   ; IN2 = Low
        MOV     R1, #MOT_IN3
        BL      GPIO_WritePin   ; IN3 = High
        MOV     R1, #MOT_IN4
        BL      GPIO_ClearPin   ; IN4 = Low
        POP     {PC}

        END
