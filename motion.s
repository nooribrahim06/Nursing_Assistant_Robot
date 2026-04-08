; =====================================================================
; FILE: motion.s
; DESCRIPTION: Full motion control logic with PWM and line tracking
; LAYER: Feature Module (Layer 2)
; =====================================================================

        AREA    MOTION_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

        EXPORT  MOT_Init
        EXPORT  MOT_Update

        IMPORT  GPIO_EnableClock
        IMPORT  GPIO_ConfigOutput
        IMPORT  GPIO_ConfigInput
        IMPORT  GPIO_WritePin
        IMPORT  GPIO_ClearPin
        IMPORT  GPIO_ReadPin
        IMPORT  PWM_Init
        IMPORT  PWM_Set_Motor_Speed
        IMPORT  g_motion_state

; ---------------------------------------------------------------------
; MOT_Init
; Initializes GPIOA/GPIOB/GPIOC clocks, motor direction pins,
; line tracker inputs, and PWM.
; ---------------------------------------------------------------------
MOT_Init
        PUSH    {LR}

        ; Enable clocks for required ports.
        LDR     R0, =GPIOA_BASE
        BL      GPIO_EnableClock
        LDR     R0, =GPIOB_BASE
        BL      GPIO_EnableClock
        LDR     R0, =GPIOC_BASE
        BL      GPIO_EnableClock

        ; Configure PA8..PA11 as motor direction outputs.
        LDR     R0, =GPIOA_BASE
        MOVS    R1, #MOT_IN1
        BL      GPIO_ConfigOutput
        MOVS    R1, #MOT_IN2
        BL      GPIO_ConfigOutput
        MOVS    R1, #MOT_IN3
        BL      GPIO_ConfigOutput
        MOVS    R1, #MOT_IN4
        BL      GPIO_ConfigOutput

        ; Configure PC0..PC2 as line tracker inputs.
        LDR     R0, =GPIOC_BASE
        MOVS    R1, #LINE_LEFT
        BL      GPIO_ConfigInput
        MOVS    R1, #LINE_CENTER
        BL      GPIO_ConfigInput
        MOVS    R1, #LINE_RIGHT
        BL      GPIO_ConfigInput

        ; Initialize PWM outputs.
        BL      PWM_Init

        POP     {PC}

; ---------------------------------------------------------------------
; MOT_Update
; Main line-following logic.
; ---------------------------------------------------------------------
MOT_Update
        PUSH    {R4-R6, LR}

        ; Read left sensor.
        LDR     R0, =GPIOC_BASE
        MOVS    R1, #LINE_LEFT
        BL      GPIO_ReadPin
        MOV     R4, R0

        ; Read center sensor.
        MOVS    R1, #LINE_CENTER
        BL      GPIO_ReadPin
        MOV     R5, R0

        ; Read right sensor.
        MOVS    R1, #LINE_RIGHT
        BL      GPIO_ReadPin
        MOV     R6, R0

        ; Priority: center, then left, then right, else stop.
        CMP     R5, #1
        BEQ     Action_Forward

        CMP     R4, #1
        BEQ     Action_Turn_Left

        CMP     R6, #1
        BEQ     Action_Turn_Right

        B       Action_Stop

Action_Forward
        BL      Set_Dir_Forward
        LDR     R2, =g_motion_state
        MOVS    R3, #1
        STR     R3, [R2]

        LDR     R0, =800
        LDR     R1, =800
        BL      PWM_Set_Motor_Speed
        B       End_Update

Action_Turn_Left
        BL      Set_Dir_Forward
        LDR     R2, =g_motion_state
        MOVS    R3, #2
        STR     R3, [R2]

        LDR     R0, =750
        LDR     R1, =250
        BL      PWM_Set_Motor_Speed
        B       End_Update

Action_Turn_Right
        BL      Set_Dir_Forward
        LDR     R2, =g_motion_state
        MOVS    R3, #3
        STR     R3, [R2]

        LDR     R0, =250
        LDR     R1, =750
        BL      PWM_Set_Motor_Speed
        B       End_Update

Action_Stop
        LDR     R2, =g_motion_state
        MOVS    R3, #0
        STR     R3, [R2]

        MOVS    R0, #0
        MOVS    R1, #0
        BL      PWM_Set_Motor_Speed

End_Update
        POP     {R4-R6, PC}

; ---------------------------------------------------------------------
; Set_Dir_Forward
; PA8=1, PA9=0, PA10=1, PA11=0
; ---------------------------------------------------------------------
Set_Dir_Forward
        PUSH    {LR}

        LDR     R0, =GPIOA_BASE
        MOVS    R1, #MOT_IN1
        BL      GPIO_WritePin
        MOVS    R1, #MOT_IN2
        BL      GPIO_ClearPin
        MOVS    R1, #MOT_IN3
        BL      GPIO_WritePin
        MOVS    R1, #MOT_IN4
        BL      GPIO_ClearPin

        POP     {PC}

        END
