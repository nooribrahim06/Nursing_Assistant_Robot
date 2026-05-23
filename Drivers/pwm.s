; =====================================================================
; FILE: pwm.s
; TIM3 CH1 -> PA6  Medicine servo
; TIM3 CH2 -> PA7  Sanitizing servo
; TIM4 CH1 -> PB6  Motor PWM
; TIM4 CH2 -> PB7  Motor PWM
; =====================================================================

        AREA    PWM_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

        EXPORT  PWM_Init
        EXPORT  PWM_Set_Motor_Speed
        EXPORT  PWM_Set_Servo_Pos

TIM3_BASE       EQU     0x40000400
TIM4_BASE       EQU     0x40000800

TIM_CCMR1       EQU     0x18
TIM_CCER        EQU     0x20
TIM_CCR1        EQU     0x34
TIM_CCR2        EQU     0x38
TIM_CR1_CEN     EQU     0x0001
TIM_CR1_ARPE    EQU     0x0080

PWM_Init
        PUSH    {R4-R7, LR}

        LDR     R0, =RCC_BASE
        LDR     R1, [R0, #RCC_AHB1ENR]
        ORR     R1, R1, #0x03
        STR     R1, [R0, #RCC_AHB1ENR]

        LDR     R1, [R0, #RCC_APB1ENR]
        ORR     R1, R1, #0x06
        STR     R1, [R0, #RCC_APB1ENR]

        ; PA6 only -> AF2 (TIM3 CH1, Medicine servo)
        ; PA7 is reserved for Vein sensor ADC - do NOT touch it here
        LDR     R0, =GPIOA_BASE

        LDR     R1, [R0, #GPIO_MODER]
        BIC     R1, R1, #0x00003000  ; Clear bits 12-13 (PA6 only)
        ORR     R1, R1, #0x00002000  ; AF mode for PA6 only
        STR     R1, [R0, #GPIO_MODER]

        LDR     R1, [R0, #GPIO_AFRL]
        LDR     R2, =0x0F000000      ; AFRL bits 24-27 (PA6 only)
        BIC     R1, R1, R2
        LDR     R2, =0x02000000      ; AF2 for PA6 only
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_AFRL]

        LDR     R1, [R0, #GPIO_PUPDR]
        BIC     R1, R1, #0x00003000  ; Clear pull for PA6 only
        STR     R1, [R0, #GPIO_PUPDR]

        ; PB6 / PB7 -> AF2 (TIM4 CH1 / CH2)
        LDR     R0, =GPIOB_BASE

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

        LDR     R1, [R0, #GPIO_PUPDR]
        LDR     R2, =0x0000F000
        BIC     R1, R1, R2
        STR     R1, [R0, #GPIO_PUPDR]

        ; TIM3 -> Servo PWM @ 50 Hz
        LDR     R4, =TIM3_BASE

        MOVS    R0, #15
        STR     R0, [R4, #TIM_PSC]

        LDR     R0, =19999
        STR     R0, [R4, #TIM_ARR]

        LDR     R0, =0x6868          ; PWM mode for both CH1 and CH2
        STR     R0, [R4, #TIM_CCMR1]

        LDR     R0, =0x0011          ; Enable both CH1 and CH2
        STR     R0, [R4, #TIM_CCER]

        LDR     R0, =1000
        STR     R0, [R4, #TIM_CCR1]

        MOVS    R0, #1
        STR     R0, [R4, #TIM_EGR]

        LDR     R0, =(TIM_CR1_ARPE + TIM_CR1_CEN)
        STR     R0, [R4, #TIM_CR1]

        ; TIM4 -> Motor PWM @ 1 kHz
        LDR     R4, =TIM4_BASE

        MOVS    R0, #15
        STR     R0, [R4, #TIM_PSC]

        LDR     R0, =999
        STR     R0, [R4, #TIM_ARR]

        LDR     R0, =0x6868
        STR     R0, [R4, #TIM_CCMR1]

        LDR     R0, =0x0011
        STR     R0, [R4, #TIM_CCER]

        MOVS    R0, #0
        STR     R0, [R4, #TIM_CCR1]
        STR     R0, [R4, #TIM_CCR2]

        MOVS    R0, #1
        STR     R0, [R4, #TIM_EGR]

        LDR     R0, =(TIM_CR1_ARPE + TIM_CR1_CEN)
        STR     R0, [R4, #TIM_CR1]

        POP     {R4-R7, PC}

PWM_Set_Motor_Speed
        PUSH    {R4-R7, LR}
        LDR     R4, =TIM4_BASE

        LDR     R5, =999
        CMP     R0, R5
        BLS     PMS_R0_OK
        MOV     R0, R5
PMS_R0_OK
        CMP     R1, R5
        BLS     PMS_R1_OK
        MOV     R1, R5
PMS_R1_OK
        STR     R0, [R4, #TIM_CCR1]
        STR     R1, [R4, #TIM_CCR2]

        POP     {R4-R7, PC}

PWM_Set_Servo_Pos
        PUSH    {R4-R6, LR}
        LDR     R4, =TIM3_BASE

        LDR     R5, =500
        CMP     R0, R5
        BHS     PSP_CheckHigh
        MOV     R0, R5

PSP_CheckHigh
        LDR     R5, =2500
        CMP     R0, R5
        BLS     PSP_Select
        MOV     R0, R5

PSP_Select
        CMP     R1, #0
        BEQ     PSP_MED

        STR     R0, [R4, #TIM_CCR2]
        POP     {R4-R6, PC}

PSP_MED
        STR     R0, [R4, #TIM_CCR1]
        POP     {R4-R6, PC}

        ALIGN
        END