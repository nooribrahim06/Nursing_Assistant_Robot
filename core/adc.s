;=============================================================================
; adc.s
; ADC1 driver for STM32F401RC
;
; Exports:
;   ADC_Init   - Enable clock, configure PA1 as analog, set up ADC1
;   ADC_Read   - Read channel passed in R0, return 12-bit result in R0
;
; Hardware assumptions:
;   PA1  -> ADC1_IN1  (MQ2 smoke sensor)
;   SNS_SMOKE_ADC EQU 1  (channel number, matches constants.s)
;=============================================================================

        AREA    ADC_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

        EXPORT  ADC_Init
        EXPORT  ADC_Read

;========================= ADC1 BASE & OFFSETS =========================
ADC1_BASE       EQU     0x40012000

; ADC per-channel registers (relative to ADC1_BASE)
ADC_SR          EQU     0x00        ; Status register
ADC_CR1         EQU     0x04        ; Control register 1
ADC_CR2         EQU     0x08        ; Control register 2
ADC_SMPR1       EQU     0x0C        ; Sample time register 1 (ch 10-18)
ADC_SMPR2       EQU     0x10        ; Sample time register 2 (ch 0-9)
ADC_SQR1        EQU     0x2C        ; Regular sequence register 1
ADC_SQR3        EQU     0x34        ; Regular sequence register 3 (1st conv)
ADC_DR          EQU     0x4C        ; Data register

; ADC common registers
ADC_CCR         EQU     0x40012300  ; Common control register (absolute)

; RCC_APB2ENR bit for ADC1
RCC_APB2ENR_ADC1EN  EQU     0x100   ; Bit 8

; ADC_CR2 bits
ADC_CR2_ADON    EQU     0x00000001  ; ADC on
ADC_CR2_SWSTART EQU     0x40000000  ; Start conversion

; ADC_SR bits
ADC_SR_EOC      EQU     0x00000002  ; End of conversion

; GPIO_MODER analog mode (11b) for pin 1 -> bits [3:2]
PA1_ANALOG_MASK EQU     0x0000000C  ; bits 3:2 = 11 -> analog

;=============================================================================
; ADC_Init
; - Enables GPIOA clock (for PA1 analog input)
; - Enables ADC1 clock
; - Sets PA1 MODER to analog (11)
; - Powers on ADC1 with 12-bit resolution, software trigger
; - Sets 84-cycle sample time on channel 1 (good for MQ2 impedance)
; Clobbers: R0-R3
;=============================================================================
ADC_Init
        PUSH    {LR}

        ;--- Enable GPIOA clock (AHB1ENR bit 0) ---
        LDR     R0, =RCC_BASE
        LDR     R1, [R0, #RCC_AHB1ENR]
        ORR     R1, R1, #BIT0           ; GPIOAEN
        STR     R1, [R0, #RCC_AHB1ENR]

        ;--- Enable ADC1 clock (APB2ENR bit 8) ---
        LDR     R1, [R0, #RCC_APB2ENR]
        LDR     R2, =RCC_APB2ENR_ADC1EN
        ORR     R1, R1, R2
        STR     R1, [R0, #RCC_APB2ENR]

        ;--- Configure PA1 as analog (MODER bits [3:2] = 11) ---
        LDR     R0, =GPIOA_BASE
        LDR     R1, [R0, #GPIO_MODER]
        LDR     R2, =PA1_ANALOG_MASK
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_MODER]

        ;--- Configure ADC1 ---
        LDR     R0, =ADC1_BASE

        ; CR1: 12-bit resolution (bits [25:24] = 00), no scan mode
        LDR     R1, [R0, #ADC_CR1]
        BIC     R1, R1, #0x03000000     ; clear RES bits -> 12-bit
        STR     R1, [R0, #ADC_CR1]

        ; CR2: software trigger (EXTEN=00), right-align, single conversion
        LDR     R1, [R0, #ADC_CR2]
        BIC     R1, R1, #0x30000000     ; clear EXTEN -> software trigger
        BIC     R1, R1, #BIT11          ; ALIGN=0 -> right-aligned
        STR     R1, [R0, #ADC_CR2]

        ; SMPR2: set 84 cycles for channel 1 (bits [5:3] = 101)
        ; 84-cycle sample time code = 5 (101b), shift left 3 bits for CH1
        LDR     R1, [R0, #ADC_SMPR2]
        BIC     R1, R1, #0x00000038     ; clear bits [5:3]
        ORR     R1, R1, #0x00000028     ; 101b << 3 = 0x28
        STR     R1, [R0, #ADC_SMPR2]

        ; SQR1: sequence length = 1 conversion (L bits [23:20] = 0000)
        LDR     R1, [R0, #ADC_SQR1]
        BIC     R1, R1, #0x00F00000
        STR     R1, [R0, #ADC_SQR1]

        ; SQR3: first (only) conversion = channel 1 (bits [4:0] = 00001)
        LDR     R1, [R0, #ADC_SQR3]
        BIC     R1, R1, #0x0000001F
        ORR     R1, R1, #0x00000001
        STR     R1, [R0, #ADC_SQR3]

        ; CR2: turn ADC on (ADON bit 0)
        LDR     R1, [R0, #ADC_CR2]
        LDR     R2, =ADC_CR2_ADON
        ORR     R1, R1, R2
        STR     R1, [R0, #ADC_CR2]

        ; Brief stabilisation delay (~few us at 84MHz)
        LDR     R2, =1000
ADC_InitDelay
        SUBS    R2, R2, #1
        BNE     ADC_InitDelay

        POP     {PC}

;=============================================================================
; ADC_Read
; In:  R0 = ADC channel number (use SNS_SMOKE_ADC = 1 for MQ2)
; Out: R0 = 12-bit conversion result (0-4095)
;
; Note: This implementation always reads channel 1 (PA1/MQ2).
;       When you add more sensors, extend SQR3 selection here using R0.
;=============================================================================
ADC_Read
        PUSH    {R1, R2, LR}

        LDR     R1, =ADC1_BASE

        ;--- Select channel in SQR3 bits [4:0] ---
        ; R0 holds the channel number passed by caller
        LDR     R2, [R1, #ADC_SQR3]
        BIC     R2, R2, #0x0000001F     ; clear current channel
        AND     R0, R0, #0x1F           ; mask channel to 5 bits (safety)
        ORR     R2, R2, R0
        STR     R2, [R1, #ADC_SQR3]

        ;--- Clear EOC flag ---
        LDR     R2, [R1, #ADC_SR]
        BIC     R2, R2, #ADC_SR_EOC
        STR     R2, [R1, #ADC_SR]

        ;--- Start conversion (SWSTART) ---
        LDR     R2, [R1, #ADC_CR2]
        LDR     R0, =ADC_CR2_SWSTART
        ORR     R2, R2, R0
        STR     R2, [R1, #ADC_CR2]

        ;--- Poll EOC ---
ADC_WaitEOC
        LDR     R2, [R1, #ADC_SR]
        TST     R2, #ADC_SR_EOC
        BEQ     ADC_WaitEOC

        ;--- Read result ---
        LDR     R0, [R1, #ADC_DR]       ; 12-bit result in R0
        AND     R0, R0, #0x0FFF         ; mask to 12 bits (safety)

        POP     {R1, R2, PC}

        ALIGN
        END