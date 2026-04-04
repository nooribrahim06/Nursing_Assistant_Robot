; =====================================================================
; FILE: pwm.s
; DESCRIPTION: PWM Driver for Speed Control and Servo Actuation
; LAYER: Low-Level Driver (Layer 3)
; =====================================================================

        AREA    PWM_CODE, CODE, READONLY
        GET     core\constants.inc
        EXPORT  PWM_Init
        EXPORT  PWM_Set_Motor_Speed
        EXPORT  PWM_Set_Servo_Pos

; ========================= Timer and GPIO Offsets =========================
GPIO_AFRL       EQU     0x20
GPIO_AFRH       EQU     0x24
TIM3_BASE       EQU     0x40000400
TIM4_BASE       EQU     0x40000800
TIM_CR1         EQU     0x00
TIM_PSC         EQU     0x28
TIM_ARR         EQU     0x2C
TIM_CCMR1       EQU     0x18
TIM_CCMR2       EQU     0x1C
TIM_CCER        EQU     0x20
TIM_CCR1        EQU     0x34
TIM_CCR2        EQU     0x38
TIM_CCR3        EQU     0x3C
TIM_CCR4        EQU     0x40
; ---------------------------------------------------------------------
; PWM_Init: Initialize timers and pins to Alternate Function (AF)
; ---------------------------------------------------------------------
PWM_Init
        PUSH    {R4-R6, LR}

        ; 0. Enable clock for TIM3 and TIM4 in APB1ENR register
        LDR     R0, =RCC_BASE
        LDR     R1, [R0, #RCC_APB1ENR]
        ORR     R1, R1, #0x06       ; Enable Bit 1 (TIM3) and Bit 2 (TIM4)
        STR     R1, [R0, #RCC_APB1ENR]

        ; 1. Set PA6, PA7 to AF (Alternate Function) mode for servos
        LDR     R0, =GPIOA_BASE
        LDR     R1, [R0, #GPIO_MODER]
        LDR     R2, =0x0000F000
        BIC     R1, R1, R2
        LDR     R2, =0x0000A000     ; Mode 10 (AF)
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_MODER]

        ; Select AF2 (0x02) for pins PA6 and PA7 in AFRL register
        LDR     R1, [R0, #GPIO_AFRL]
        LDR     R2, =0xFF000000
        BIC     R1, R1, R2
        LDR     R2, =0x22000000     ; Set AF2 function for pins 6 and 7
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_AFRL]

        ; 2. Set PB8, PB9 to AF mode for motor speed control
        LDR     R0, =GPIOB_BASE
        LDR     R1, [R0, #GPIO_MODER]
        LDR     R2, =0x000F0000
        BIC     R1, R1, R2
        LDR     R2, =0x000A0000     ; Mode 10 (AF)
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_MODER]

        ; Select AF2 (0x02) for pins PB8 and PB9 in AFRH register
        LDR     R1, [R0, #GPIO_AFRH]
        LDR     R2, =0x000000FF
        BIC     R1, R1, R2
        LDR     R2, =0x00000022     ; Set AF2 function for pins 8 and 9
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_AFRH]

        ; --- Configure Timer 3 for servos (50Hz frequency) ---
        LDR     R4, =TIM3_BASE
        ; Assuming 16MHz clock
        ; PSC = 15 (to get 1MHz) -> ARR = 20000 (to get 50Hz or 20ms period)
        MOV     R0, #15
        STR     R0, [R4, #TIM_PSC]
        LDR     R0, =20000
        STR     R0, [R4, #TIM_ARR]
        
        ; Enable PWM Mode 1 in CCMR1 for PA6 (CH1) and PA7 (CH2)
        LDR     R0, =0x6868
        STR     R0, [R4, #TIM_CCMR1]
        
        ; Enable outputs in CCER for CH1 and CH2
        LDR     R0, =0x0011
        STR     R0, [R4, #TIM_CCER]
        
        ; Start Timer 3
        LDR     R0, =0x01
        STR     R0, [R4, #TIM_CR1]

        ; --- Configure Timer 4 for DC motors (High frequency 1kHz) ---
        LDR     R4, =TIM4_BASE
        MOV     R0, #15             ; PSC = 15 (to get 1MHz)
        STR     R0, [R4, #TIM_PSC]
        LDR     R0, =1000           ; ARR = 1000 (for 1kHz frequency)
        STR     R0, [R4, #TIM_ARR]
        
        ; Enable PWM Mode 1 in CCMR2 for PB8 (CH3) and PB9 (CH4)
        LDR     R0, =0x6868
        STR     R0, [R4, #TIM_CCMR2]
        
        ; Enable outputs in CCER for CH3 and CH4
        LDR     R0, =0x1100
        STR     R0, [R4, #TIM_CCER]
        
        ; Start Timer 4
        LDR     R0, =0x01
        STR     R0, [R4, #TIM_CR1]

        POP     {R4-R6, PC}

; ---------------------------------------------------------------------
; PWM_Set_Motor_Speed: Update DC motor speeds
; Inputs: R0 = Right Speed (0-1000), R1 = Left Speed (0-1000)
; ---------------------------------------------------------------------
PWM_Set_Motor_Speed
        PUSH    {R4, LR}
        LDR     R4, =TIM4_BASE
        STR     R0, [R4, #TIM_CCR3] ; Update PB8 speed (Right) 
        STR     R1, [R4, #TIM_CCR4] ; Update PB9 speed (Left) 
        POP     {R4, PC}

; ---------------------------------------------------------------------
; PWM_Set_Servo_Pos: Update servo angle/position
; Inputs: R0 = Pulse Width (Value for CCR), R1 = 0 (SAN) or 1 (MED)
; ---------------------------------------------------------------------
PWM_Set_Servo_Pos
        PUSH    {R4, LR}
        LDR     R4, =TIM3_BASE      ; Servos are connected to TIM3
        CMP     R1, #0
        STREQ   R0, [R4, #TIM_CCR1] ; Update PA6 (Sanitizing) 
        STRNE   R0, [R4, #TIM_CCR2] ; Update PA7 (Medicine) 
        POP     {R4,PC}
