;=============================================================================
; adc.s
; ADC1 driver - STM32F401RC
;
; Exports:
;   ADC_Init  - enable clocks, configure PA0 and PA1 as analog, power ADC1 on
;   ADC_Read  - R0 = channel number in, R0 = 12-bit result out
;
; Hardware:
;   PA0  -> ADC1_IN0  (breathing sensor, SNS_BREATH_ADC = 0)
;   PA1  -> ADC1_IN1  (MQ2 smoke sensor, SNS_SMOKE_ADC  = 1)
;
; FIX:
;   - ADC_Read now has timeout in ADC_WaitEOC
;   - If ADC fails, returns 4095 instead of freezing forever
;   - 4095 is safer for smoke logic where clean air = high ADC
;=============================================================================

        AREA    ADC_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

        EXPORT  ADC_Init
        EXPORT  ADC_Read

ADC_TIMEOUT_COUNT       EQU     100000

;=============================================================================
; ADC_Init
;=============================================================================
ADC_Init
        PUSH    {LR}

        ; ---- 1. Enable GPIOA clock ----
        LDR     R0, =RCC_BASE
        LDR     R1, [R0, #RCC_AHB1ENR]
        ORR     R1, R1, #BIT0
        STR     R1, [R0, #RCC_AHB1ENR]

        ; ---- 2. Enable ADC1 clock ----
        LDR     R1, [R0, #RCC_APB2ENR]
        ORR     R1, R1, #BIT8
        STR     R1, [R0, #RCC_APB2ENR]

        ; ---- 3. PA0 and PA1 -> analog mode ----
        ; PA0 MODER[1:0] = 11
        ; PA1 MODER[3:2] = 11
        LDR     R0, =GPIOA_BASE
        LDR     R1, [R0, #GPIO_MODER]
        BIC     R1, R1, #0x0000000F
        ORR     R1, R1, #0x0000000F
        STR     R1, [R0, #GPIO_MODER]

        ; ---- 4. CR1: 12-bit resolution ----
        LDR     R0, =ADC1_BASE
        LDR     R1, [R0, #ADC_CR1]
        BIC     R1, R1, #0x03000000
        STR     R1, [R0, #ADC_CR1]

        ; ---- 5. CR2: software trigger + right-align ----
        LDR     R1, [R0, #ADC_CR2]
        BIC     R1, R1, #0x30000000
        BIC     R1, R1, #BIT11
        STR     R1, [R0, #ADC_CR2]

        ; ---- 6. SMPR2: 84 cycles for channel 0 and 1 ----
        ; ch0 bits [2:0] = 101
        ; ch1 bits [5:3] = 101
        LDR     R1, [R0, #ADC_SMPR2]
        BIC     R1, R1, #0x0000003F
        ORR     R1, R1, #0x0000002D
        STR     R1, [R0, #ADC_SMPR2]

        ; ---- 7. SQR1: sequence length = 1 ----
        LDR     R1, [R0, #ADC_SQR1]
        BIC     R1, R1, #0x00F00000
        STR     R1, [R0, #ADC_SQR1]

        ; ---- 8. Power ADC on ----
        LDR     R1, [R0, #ADC_CR2]
        LDR     R2, =ADC_CR2_ADON
        ORR     R1, R1, R2
        STR     R1, [R0, #ADC_CR2]

        ; Stabilization delay
        LDR     R2, =1000

ADC_StabDelay
        SUBS    R2, R2, #1
        BNE     ADC_StabDelay

        POP     {PC}


;=============================================================================
; ADC_Read
; IN:
;   R0 = ADC channel number
;
; OUT:
;   R0 = 12-bit ADC value
;
; Fail-safe:
;   If EOC never becomes ready, returns 4095 instead of freezing.
;=============================================================================
ADC_Read
        PUSH    {R1, R2, R3, LR}

        LDR     R1, =ADC1_BASE

        ; ---- 1. Select channel ----
        LDR     R2, [R1, #ADC_SQR3]
        BIC     R2, R2, #0x0000001F
        AND     R0, R0, #0x1F
        ORR     R2, R2, R0
        STR     R2, [R1, #ADC_SQR3]

        ; ---- 2. Clear EOC ----
        LDR     R2, [R1, #ADC_SR]
        BIC     R2, R2, #ADC_SR_EOC
        STR     R2, [R1, #ADC_SR]

        ; ---- 3. Start conversion ----
        LDR     R2, [R1, #ADC_CR2]
        LDR     R0, =ADC_CR2_SWSTART
        ORR     R2, R2, R0
        STR     R2, [R1, #ADC_CR2]

        ; ---- 4. Wait EOC with timeout ----
        LDR     R3, =ADC_TIMEOUT_COUNT

ADC_WaitEOC
        LDR     R2, [R1, #ADC_SR]
        TST     R2, #ADC_SR_EOC
        BNE     ADC_Read_Result

        SUBS    R3, R3, #1
        BNE     ADC_WaitEOC

        ; Timeout fail-safe:
        ; return max ADC value instead of hanging forever.
        LDR     R0, =0x00000FFF
        POP     {R1, R2, R3, PC}

ADC_Read_Result
        ; ---- 5. Read result ----
        LDR     R0, [R1, #ADC_DR]
        LDR     R2, =0x00000FFF
        AND     R0, R0, R2

        POP     {R1, R2, R3, PC}

        ALIGN
        END