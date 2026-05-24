; =====================================================================
; FILE: motion.s
; DESCRIPTION:
; Default (Line-Tracking): Uses 3 line tracking sensors to follow a marked path.
; Phone Override: Activating this via Bluetooth bypasses the sensors to allow manual control of the robot's direction.
; =====================================================================

        AREA    MOTION_DATA, DATA, READWRITE
        ALIGN

Last_Turn               DCD     0       ; 0=Straight, 1=Left, 2=Right ;Variables to save the Last state before losing the line for Line Saver

        AREA    MOTION_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s
        GET     motion_constants.s
        

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
        IMPORT  HCSR04_Read

        IMPORT  g_ms_ticks
        IMPORT  g_last_ultra_tick
        IMPORT  g_last_ultra_dist

        IMPORT  g_station_detected

; ---------------------------------------------------------------------
; Local motion-control values
; ---------------------------------------------------------------------



; ---------------------------------------------------------------------
; MOT_Init
; ---------------------------------------------------------------------
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

        ; LEFT   -> PB12
        ; CENTER -> PB15
        ; RIGHT  -> PB14
        
        LDR     R0, =GPIOB_BASE
        MOV     R1, #LINE_LEFT
        BL      GPIO_ConfigInput

        LDR     R0, =GPIOB_BASE
        MOV     R1, #LINE_CENTER
        BL      GPIO_ConfigInput

        LDR     R0, =GPIOB_BASE
        MOV     R1, #LINE_RIGHT
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
; If phone override is active: execute latest phone direction.
; Otherwise: run the line tracker logic.
; =====================================================================
MOT_Update
        PUSH    {R3-R7, LR}

        ; 1. Unified Safety Check (Runs in both LINE and PHONE modes)
        LDR     R0, =g_ms_ticks
        LDR     R1, [R0]
        LDR     R0, =g_last_ultra_tick
        LDR     R2, [R0]
        SUBS    R3, R1, R2
        CMP     R3, #50             ; 20Hz update
        BLO     MOT_CheckMode       ; Skip read if not time yet, but still check mode
        
        STR     R1, [R0]
        BL      HCSR04_Read
        LDR     R1, =g_last_ultra_dist
        STR     R0, [R1]

MOT_CheckMode
        ; 2. Obstacle Safety Stop
        LDR     R0, =g_last_ultra_dist
        LDR     R0, [R0]
        CMP     R0, #15
        BHS     MOT_CheckStation
        BL      MOT_StopNow         ; Stop in any mode if an obstacle is detected
        B       MOT_Update_Exit

        ; ---- IR STATION CHECK ----
MOT_CheckStation
        LDR     R0, =g_station_detected
        LDR     R0, [R0]
        CMP     R0, #0
        BEQ     MOT_ModeDispatch
        BL      MOT_StopNow         ; Station detected -> PB13 Outputs High -> full stop
        B       MOT_Update_Exit

MOT_ModeDispatch
        ; 3. Mode Selection
        LDR     R0, =g_motion_mode
        LDR     R1, [R0]
        CMP     R1, #MOTION_MODE_PHONE
        BEQ     MOT_RunPhoneTask

        ; 4. Default: Line Tracking
        B       MOT_DefaultFlow

MOT_RunPhoneTask
        BL      MotionBT_Task
        B       MOT_Update_Exit


; -------------------------------------------------------------
; Line Tracker Logic (Default)
; -------------------------------------------------------------
MOT_DefaultFlow
        ; 1. LEFT SENSOR
        LDR     R0, =GPIOB_BASE
        MOV     R1, #LINE_LEFT
        BL      GPIO_ReadPin
        LSL     R4, R0, #2

        ; 2. CENTER SENSOR
        LDR     R0, =GPIOB_BASE
        MOV     R1, #LINE_CENTER
        BL      GPIO_ReadPin
        LSL     R5, R0, #1

        ; 3. RIGHT SENSOR
        LDR     R0, =GPIOB_BASE
        MOV     R1, #LINE_RIGHT
        BL      GPIO_ReadPin
        MOV     R6, R0

        ; 4. Combine sensor mask
        ORR     R7, R4, R5
        ORR     R7, R7, R6
		
	MOV     R0, #Black_High ; Note: If Sensor Outputs Low when detecting a black line change to Black_Low
	CMP     R0 , #1
	BEQ     Decision_Maker
        EOR     R7, R7, #7 
	B       Decision_Maker		
; -------------------------------------------------------------
; Decision Tree
; -------------------------------------------------------------
Decision_Maker
        CMP     R7, #0x02               ; Center only (010)
        BEQ     Action_Straight

        CMP     R7, #0x05               ; Left + Right (101)
        BEQ     Action_Straight

        CMP     R7, #0x04               ; Left only (100)
        BEQ     Action_Arc_Left

        CMP     R7, #0x06               ; Left + Center (110)
        BEQ     Action_Arc_Left

        CMP     R7, #0x01               ; Right only (001)
        BEQ     Action_Arc_Right

        CMP     R7, #0x03               ; Right + Center (011)
        BEQ     Action_Arc_Right

        CMP     R7, #0x07               ; 3 Ones (Black Bar) -> Stop at the intersection
        BEQ     Action_Search

        CMP     R7, #0x00               ; 3 Zeros (Lost Line) -> Jump to Line Saver
        BEQ     Rescue_Lost_Line

        B       Action_Search


; =====================================================================
; MEMORY RESCUE LOGIC
; =====================================================================
Rescue_Lost_Line
        LDR     R2, =Last_Turn
        LDR     R3, [R2]

        CMP     R3, #1    ; If the Last Thing before the Sensor read before Losing the Line was go Left
        BEQ     Action_Pivot_Left

        CMP     R3, #2    ; If the Last Thing before the Sensor read before Losing the Line was go Right
        BEQ     Action_Pivot_Right

        B       Action_Straight  ;If Not Left nor Right, then go straight ahead


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
; =====================================================================
MOT_StopNow
Motion_Stop
        PUSH    {R3, LR}                

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
; DIRECTION SETTERS
; =====================================================================

; ---------------------------------------------------------------------
; Both motors forward
; ---------------------------------------------------------------------
Set_Dir_Forward
Motion_Forward
        PUSH    {R3, LR}               

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
        PUSH    {R3, LR}                

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
        PUSH    {R3, LR}                

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
        PUSH    {R3, LR}                

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
        
