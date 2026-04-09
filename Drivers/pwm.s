; =====================================================================
; FILE: pwm.s
; DESCRIPTION: PWM Driver for Speed Control and Servo Actuation
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
;   TIM3 CH1/CH2 -> PA6 / PA7  (servos, 50 Hz)
;   TIM4 CH3/CH4 -> PB8 / PB9  (motor PWM)
; ---------------------------------------------------------------------
PWM_Init
        PUSH    {R4-R6, LR}

        ; Enable GPIOA + GPIOB clocks.
        LDR     R0, =RCC_BASE
        LDR     R1, [R0, #RCC_AHB1ENR]
        ORR     R1, R1, #0x03
        STR     R1, [R0, #RCC_AHB1ENR]

        ; Enable TIM3 + TIM4 clocks on APB1.
        LDR     R1, [R0, #RCC_APB1ENR]
        ORR     R1, R1, #0x06
        STR     R1, [R0, #RCC_APB1ENR]

        ; -------------------------------------------------------------
        ; PA6 / PA7 -> Alternate Function mode, AF2 (TIM3 CH1 / CH2)
        ; -------------------------------------------------------------
        LDR     R0, =GPIOA_BASE
        LDR     R1, [R0, #GPIO_MODER]
        LDR     R2, =0x0000F000
        BIC     R1, R1, R2
        LDR     R2, =0x0000A000
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_MODER]

        LDR     R1, [R0, #GPIO_AFRL]
        LDR     R2, =0xFF000000
        BIC     R1, R1, R2
        LDR     R2, =0x22000000
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_AFRL]

        ; -------------------------------------------------------------
        ; PB8 / PB9 -> Alternate Function mode, AF2 (TIM4 CH3 / CH4)
        ; -------------------------------------------------------------
       ; LDR     R0, =GPIOB_BASE
       ; LDR     R1, [R0, #GPIO_MODER]
        ;LDR     R2, =0x000F0000
        ;BIC     R1, R1, R2
        ;LDR     R2, =0x000A0000
        ;ORR     R1, R1, R2
        ;STR     R1, [R0, #GPIO_MODER]

        ;LDR     R1, [R0, #GPIO_AFRH]
        ;LDR     R2, =0x000000FF
        ;BIC     R1, R1, R2
        ;LDR     R2, =0x00000022
        ;ORR     R1, R1, R2
       ; STR     R1, [R0, #GPIO_AFRH]

        ; -------------------------------------------------------------
        ; TIM3 for servos
        ; 16 MHz / (15 + 1) = 1 MHz timer tick
        ; ARR = 20000 -> 20 ms period -> 50 Hz
        ; -------------------------------------------------------------
        LDR     R4, =TIM3_BASE
        MOVS    R0, #15
        STR     R0, [R4, #TIM_PSC]
        LDR     R0, =20000
        STR     R0, [R4, #TIM_ARR]

        ; PWM mode 1 on CH1 and CH2, preload enabled.
        LDR     R0, =0x6868
        STR     R0, [R4, #TIM_CCMR1]

        ; Enable CH1 and CH2 outputs.
        LDR     R0, =0x0011
        STR     R0, [R4, #TIM_CCER]

        ; Neutral startup pulse for both servos.
        LDR     R0, =1500
        STR     R0, [R4, #TIM_CCR1]
        STR     R0, [R4, #TIM_CCR2]

        ; Start TIM3.
        MOVS    R0, #1
        STR     R0, [R4, #TIM_CR1]

        ; -------------------------------------------------------------
        ; TIM4 for DC motor PWM
        ; 16 MHz / (15 + 1) = 1 MHz timer tick
        ; ARR = 1000 -> 1 kHz PWM
        ; -------------------------------------------------------------
       ; LDR     R4, =TIM4_BASE
       ; MOVS    R0, #15
        ;STR     R0, [R4, #TIM_PSC]
        ;LDR     R0, =1000
        ;STR     R0, [R4, #TIM_ARR]

        ; PWM mode 1 on CH3 and CH4, preload enabled.
        ;LDR     R0, =0x6868
        ;STR     R0, [R4, #TIM_CCMR2]

        ; Enable CH3 and CH4 outputs.
        ;LDR     R0, =0x1100
        ;STR     R0, [R4, #TIM_CCER]

        ; Start motors at 0 duty.
        ;MOVS    R0, #0
        ;STR     R0, [R4, #TIM_CCR3]
        ;STR     R0, [R4, #TIM_CCR4]

        ; Start TIM4.
        ;MOVS    R0, #1
        ;STR     R0, [R4, #TIM_CR1]

        POP     {R4-R6, PC}

; ---------------------------------------------------------------------
; PWM_Set_Motor_Speed
; Inputs:
;   R0 = right speed (TIM4 CH3 / PB8)
;   R1 = left  speed (TIM4 CH4 / PB9)
; ---------------------------------------------------------------------
PWM_Set_Motor_Speed
 ;       PUSH    {R4, LR}
  ;      LDR     R4, =TIM4_BASE
   ;     STR     R0, [R4, #TIM_CCR3]
    ;    STR     R1, [R4, #TIM_CCR4]
     ;   POP     {R4, PC}
		BX LR 
; ---------------------------------------------------------------------
; PWM_Set_Servo_Pos
; Inputs:
;   R0 = pulse width in microseconds (typically 1000..2000)
;   R1 = 0 -> sanitizing servo  (TIM3 CH1 / PA6)
;        1 -> medicine servo    (TIM3 CH2 / PA7)
; ---------------------------------------------------------------------
PWM_Set_Servo_Pos
        PUSH    {R4, LR}
        LDR     R4, =TIM3_BASE

        CMP     R1, #0
        BEQ     PWM_Set_Servo_SAN

        STR     R0, [R4, #TIM_CCR2]
        POP     {R4, PC}

PWM_Set_Servo_SAN
        STR     R0, [R4, #TIM_CCR1]
        POP     {R4, PC}

        END
