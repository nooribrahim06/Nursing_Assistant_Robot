; =====================================================================
; FILE: motion.s
; DESCRIPTION: Full motion control logic with PWM and Line Tracking
; LAYER: Feature Module (Layer 2)
; =====================================================================
        	INCLUDE constants.s
        
        AREA    MOTION_CODE, CODE, READONLY
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
; Purpose: Main logic loop for line following (Embedded Legacy Logic)
; ---------------------------------------------------------------------
; ---------------------------------------------------------------------
; Subroutine: MOT_Update
; Purpose: Main logic loop for line following (Embedded Legacy Logic)
; ---------------------------------------------------------------------
MOT_Update
        PUSH    {R4-R7, LR}     ; Save protected registers

        ; 1. Read Left Sensor (PC0) and shift it to Bit 2 (100)
        LDR     R0, =GPIOC_BASE
        MOV     R1, #LINE_LEFT
        BL      GPIO_ReadPin
        LSL     R4, R0, #2      

        ; 2. Read Center Sensor (PC1) and shift it to Bit 1 (010)
        LDR     R0, =GPIOC_BASE     ; <--- THE VISION FIX
        MOV     R1, #LINE_CENTER
        BL      GPIO_ReadPin
        LSL     R5, R0, #1      

        ; 3. Read Right Sensor (PC2) at Bit 0 (001)
        LDR     R0, =GPIOC_BASE     ; <--- THE VISION FIX
        MOV     R1, #LINE_RIGHT
        BL      GPIO_ReadPin
        MOV     R6, R0          

        ; 4. Combine them into a single 3-bit mask in R7
        ORR     R7, R4, R5
        ORR     R7, R7, R6
        
        ; 5. Invert the bits (Active-Low to Active-High)
        EOR     R7, R7, #0x07

        ; ==========================================
        ; The 8-State Legacy Decision Tree
        ; ==========================================
        CMP     R7, #0x02       ; STRAIGHT_FORWARD (010)
        BEQ     Action_Straight

        CMP     R7, #0x07       ; SEARCH_STRAIGHT (111)
        BEQ     Action_Search

        CMP     R7, #0x06       ; SLIGHT_LEFT (110)
        BEQ     Action_Slight_Left 

        CMP     R7, #0x04       ; SHARP_LEFT (100)
        BEQ     Action_Sharp_Left

        CMP     R7, #0x03       ; SLIGHT_RIGHT (011)
        BEQ     Action_Slight_Right 

        CMP     R7, #0x01       ; SHARP_RIGHT (001)
        BEQ     Action_Sharp_Right

        CMP     R7, #0x05       ; SEARCH_RIGHT (101)
        BEQ     Action_Sharp_Right

        CMP     R7, #0x00       ; SEARCH (000 - Lost Line)
        BEQ     Action_Search

        B       Action_Search   ; Fallback safety

; ==========================================
; Movement Execution (Using the new PWM Driver)
; Recall: R0 = Right Speed, R1 = Left Speed
; ==========================================
Action_Straight
        BL      Set_Dir_Forward
        MOV     R0, #383        ; Right = QUARTER_SPEED
        MOV     R1, #383        ; Left = QUARTER_SPEED
        BL      PWM_Set_Motor_Speed
        B       End_Update

Action_Slight_Left
        BL      Set_Dir_Forward
        MOV     R0, #499        ; Right = HALF_SPEED
        MOV     R1, #383        ; Left = QUARTER_SPEED 
        BL      PWM_Set_Motor_Speed
        B       End_Update

Action_Sharp_Left
        BL      Set_Dir_Forward
        MOV     R0, #499        ; Right = HALF_SPEED
        MOV     R1, #124        ; Left = EIGHTH_SPEED
        BL      PWM_Set_Motor_Speed
        B       End_Update

Action_Slight_Right
        BL      Set_Dir_Forward
        MOV     R0, #383        ; Right = QUARTER_SPEED
        MOV     R1, #499        ; Left = HALF_SPEED
        BL      PWM_Set_Motor_Speed
        B       End_Update

Action_Sharp_Right
        BL      Set_Dir_Forward
        MOV     R0, #124        ; Right = EIGHTH_SPEED
        MOV     R1, #499        ; Left = HALF_SPEED
        BL      PWM_Set_Motor_Speed
        B       End_Update

Action_Search
        ; ACTIVE BRAKING: Lock the H-Bridge to kill inertia
        LDR     R0, =GPIOA_BASE
        MOV     R1, #MOT_IN1
        BL      GPIO_WritePin     ; IN1 = HIGH
        MOV     R1, #MOT_IN2
        BL      GPIO_WritePin     ; IN2 = HIGH
        MOV     R1, #MOT_IN3
        BL      GPIO_WritePin     ; IN3 = HIGH
        MOV     R1, #MOT_IN4
        BL      GPIO_WritePin     ; IN4 = HIGH
        
        MOV     R0, #1000         ; PWM = 100% to engage the lock
        MOV     R1, #1000
        BL      PWM_Set_Motor_Speed
        B       End_Update

End_Update
        POP     {R4-R7, PC}     ; Restore registers and return

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
