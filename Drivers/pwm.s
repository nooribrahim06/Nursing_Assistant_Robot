; =====================================================================
; FILE: pwm.s
; DESCRIPTION: Unified PWM Driver for DC Motor Speed and Servo Actuation
; LAYER: Low-Level Driver (Layer 3)
; =====================================================================

        AREA    PWM_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

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
; PWM_Init
; Initializes:
;   TIM3 CH1/CH2 -> PA6 / PA7  (Servos, 50 Hz)
;   TIM4 CH1/CH2 -> PB6 / PB7  (DC Motors, 1 kHz)
; ---------------------------------------------------------------------
PWM_Init
        PUSH    {R4-R6, LR}

        ; 1. Enable Clocks for GPIOA (Bit 0) and GPIOB (Bit 1) on AHB1
        LDR     R0, =RCC_BASE
        LDR     R1, [R0, #RCC_AHB1ENR]
        ORR     R1, R1, #0x03
        STR     R1, [R0, #RCC_AHB1ENR]

        ; 2. Enable Clocks for TIM3 (Bit 1) and TIM4 (Bit 2) on APB1
        LDR     R1, [R0, #RCC_APB1ENR]
        ORR     R1, R1, #0x06
        STR     R1, [R0, #RCC_APB1ENR]

        ; -------------------------------------------------------------
        ; Configure PA6 / PA7 for Alternate Function (TIM3 CH1/CH2)
        ; -------------------------------------------------------------
        LDR     R0, =GPIOA_BASE
        
        ; Set MODER to AF (10) for PA6 and PA7
        LDR     R1, [R0, #GPIO_MODER]
        LDR     R2, =0x0000F000
        BIC     R1, R1, R2
        LDR     R2, =0x0000A000
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_MODER]

        ; Set AFRL to AF2 (0x02) for PA6 and PA7
        LDR     R1, [R0, #GPIO_AFRL]
        LDR     R2, =0xFF000000
        BIC     R1, R1, R2
        LDR     R2, =0x22000000
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_AFRL]

        ; -------------------------------------------------------------
        ; Configure PB6 / PB7 for Alternate Function (TIM4 CH1/CH2)
        ; -------------------------------------------------------------
        LDR     R0, =GPIOB_BASE

        ; Set MODER to AF (10) for PB6 and PB7
        LDR     R1, [R0, #GPIO_MODER]
        LDR     R2, =0x0000F000
        BIC     R1, R1, R2
        LDR     R2, =0x0000A000
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_MODER]

        ; Set AFRL to AF2 (0x02) for PB6 and PB7
        LDR     R1, [R0, #GPIO_AFRL]
        LDR     R2, =0xFF000000
        BIC     R1, R1, R2
        LDR     R2, =0x22000000
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_AFRL]

        ; -------------------------------------------------------------
        ; Setup TIM3 (Servos @ 50Hz)
        ; 16 MHz / (15 + 1) = 1 MHz tick. ARR = 20000 (20ms period)
        ; -------------------------------------------------------------
        LDR     R4, =TIM3_BASE
        MOVS    R0, #15
        STR     R0, [R4, #TIM_PSC]
        LDR     R0, =20000
        STR     R0, [R4, #TIM_ARR]

        ; Enable PWM Mode 1 on CH1/CH2
        LDR     R0, =0x6868
        STR     R0, [R4, #TIM_CCMR1]

        ; Enable Output pins
        LDR     R0, =0x0011
        STR     R0, [R4, #TIM_CCER]

        ; Safe Startup: Neutral position (1500us) for both servos
        LDR     R0, =1500
        STR     R0, [R4, #TIM_CCR1]
        STR     R0, [R4, #TIM_CCR2]

        ; Start TIM3
        MOVS    R0, #1
        STR     R0, [R4, #TIM_CR1]

        ; -------------------------------------------------------------
        ; Setup TIM4 (DC Motors @ 1kHz)
        ; 16 MHz / (15 + 1) = 1 MHz tick. ARR = 1000 (1ms period)
        ; -------------------------------------------------------------
        LDR     R4, =TIM4_BASE
        MOVS    R0, #15
        STR     R0, [R4, #TIM_PSC]
        LDR     R0, =1000
        STR     R0, [R4, #TIM_ARR]

        ; Enable PWM Mode 1 on CH1/CH2
        LDR     R0, =0x6868
        STR     R0, [R4, #TIM_CCMR1]

        ; Enable Output pins
        LDR     R0, =0x0011
        STR     R0, [R4, #TIM_CCER]

        ; Safe Startup: Motors strictly at 0% Duty Cycle
        MOVS    R0, #0
        STR     R0, [R4, #TIM_CCR1]
        STR     R0, [R4, #TIM_CCR2]

        ; Start TIM4
        MOVS    R0, #1
        STR     R0, [R4, #TIM_CR1]

        POP     {R4-R6, PC}

; ---------------------------------------------------------------------
; PWM_Set_Motor_Speed
; Inputs:
;   R0 = Right Motor Speed (0-1000) -> TIM4 CH1 (PB6)
;   R1 = Left Motor Speed  (0-1000) -> TIM4 CH2 (PB7)
; ---------------------------------------------------------------------
PWM_Set_Motor_Speed
        PUSH    {R4, LR}
        LDR     R4, =TIM4_BASE
        STR     R0, [R4, #TIM_CCR1]
        STR     R1, [R4, #TIM_CCR2]
        POP     {R4, PC}

; ---------------------------------------------------------------------
; PWM_Set_Servo_Pos
; Inputs:
;   R0 = Pulse Width in microseconds (e.g., 1000 to 2000)
;   R1 = Servo ID (0 = Sanitizing PA6, 1 = Medicine PA7)
; ---------------------------------------------------------------------
PWM_Set_Servo_Pos
        PUSH    {R4, LR}
        LDR     R4, =TIM3_BASE

        CMP     R1, #0
        BEQ     PWM_Set_Servo_SAN

        ; If R1 != 0, write to Medicine Servo (CH2)
        STR     R0, [R4, #TIM_CCR2]
        POP     {R4, PC}

PWM_Set_Servo_SAN
        ; If R1 == 0, write to Sanitizer Servo (CH1)
        STR     R0, [R4, #TIM_CCR1]
        POP     {R4, PC}

        END