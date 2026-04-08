;=============================================================================
; adc.s
; ADC1 driver – STM32F401RC
;
; Exports:
;   ADC_Init  – enable clocks, configure PA1 as analog, power ADC1 on
;   ADC_Read  – R0 = channel number in, R0 = 12-bit result out
;
; Hardware:
;   PA1  ->  ADC1_IN1  (MQ2 smoke sensor, SNS_SMOKE_ADC = 1)
;
; Fixes applied:
;   - PA1 MODER: BIC old bits before ORR to avoid partial state corruption
;   - CR1/CR2 BIC masks verified against reference manual
;   - SMPR2 mask corrected for channel 1 bits [5:3]
;   - SQR1 length mask corrected to bits [23:20]
;   - 12-bit result mask made register-safe via LDR
;=============================================================================

        AREA    ADC_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

        EXPORT  ADC_Init
        EXPORT  ADC_Read


;=============================================================================
; ADC_Init
;
; Steps:
;   1. Enable GPIOA clock  (AHB1ENR bit 0)
;   2. Enable ADC1 clock   (APB2ENR bit 8)
;   3. Set PA1 MODER = 11  (analog) – clear first, then set
;   4. CR1: 12-bit resolution (RES[25:24] = 00)
;   5. CR2: software trigger (EXTEN=00), right-align (ALIGN=0)
;   6. SMPR2: 84-cycle sample time on channel 1 (bits [5:3] = 101b)
;   7. SQR1: sequence length = 1 (L[23:20] = 0000)
;   8. Power ADC on (ADON) + stabilisation delay
;
; Clobbers: R0–R3
;=============================================================================
ADC_Init
        PUSH    {LR}

        ; ---- 1. Enable GPIOA clock (AHB1ENR bit 0 = GPIOAEN) ----
        LDR     R0, =RCC_BASE
        LDR     R1, [R0, #RCC_AHB1ENR]
        ORR     R1, R1, #BIT0
        STR     R1, [R0, #RCC_AHB1ENR]

        ; ---- 2. Enable ADC1 clock (APB2ENR bit 8 = ADC1EN) ----
        LDR     R1, [R0, #RCC_APB2ENR]
        ORR     R1, R1, #BIT8
        STR     R1, [R0, #RCC_APB2ENR]

        ; ---- 3. PA1 MODER[3:2] = 11 (analog) ----
        ; FIX: BIC bits [3:2] first so we start from a clean state,
        ;      then ORR 11b. Without BIC, a previous MODER value of 01
        ;      or 10 on PA1 would leave the pin in an incorrect mode.
        LDR     R0, =GPIOA_BASE
        LDR     R1, [R0, #GPIO_MODER]
        BIC     R1, R1, #0x0000000C    ; clear bits [3:2]
        ORR     R1, R1, #0x0000000C    ; set bits [3:2] = 11 (analog)
        STR     R1, [R0, #GPIO_MODER]

        ; ---- 4. CR1: 12-bit resolution (RES[25:24] = 00) ----
        LDR     R0, =ADC1_BASE
        LDR     R1, [R0, #ADC_CR1]
        BIC     R1, R1, #0x03000000    ; clear RES[25:24] -> 12-bit
        STR     R1, [R0, #ADC_CR1]

        ; ---- 5. CR2: software trigger + right-align ----
        ; EXTEN[29:28] = 00 -> software trigger (no external trigger)
        ; ALIGN bit 11  = 0  -> right-aligned result
        LDR     R1, [R0, #ADC_CR2]
        BIC     R1, R1, #0x30000000    ; clear EXTEN[29:28]
        BIC     R1, R1, #BIT11         ; clear ALIGN -> right-aligned
        STR     R1, [R0, #ADC_CR2]

        ; ---- 6. SMPR2: 84-cycle sample time for channel 1 ----
        ; Channel 1 sample time occupies bits [5:3] of SMPR2.
        ; Code 5 (101b) = 84 cycles. 101b << 3 = 0x28.
        LDR     R1, [R0, #ADC_SMPR2]
        BIC     R1, R1, #0x00000038    ; clear bits [5:3] for channel 1
        ORR     R1, R1, #0x00000028    ; set 101b -> 84 cycles
        STR     R1, [R0, #ADC_SMPR2]

        ; ---- 7. SQR1: sequence length = 1 (L[23:20] = 0000) ----
        LDR     R1, [R0, #ADC_SQR1]
        BIC     R1, R1, #0x00F00000    ; clear L[23:20] -> 1 conversion
        STR     R1, [R0, #ADC_SQR1]

        ; ---- 8. Power ADC on (CR2 ADON = bit 0) ----
        LDR     R1, [R0, #ADC_CR2]
        LDR     R2, =ADC_CR2_ADON
        ORR     R1, R1, R2
        STR     R1, [R0, #ADC_CR2]

        ; Stabilisation delay: ~few µs at 84 MHz.
        ; 1000 iterations is safe; reduce if boot time is critical.
        LDR     R2, =1000
ADC_StabDelay
        SUBS    R2, R2, #1
        BNE     ADC_StabDelay

        POP     {PC}


;=============================================================================
; ADC_Read
;
; In:  R0 = ADC channel number (e.g. SNS_SMOKE_ADC = 1)
; Out: R0 = 12-bit conversion result (0–4095)
;
; Steps:
;   1. Write channel into SQR3[4:0]
;   2. Clear EOC flag
;   3. Set SWSTART to begin conversion
;   4. Poll EOC until set
;   5. Read DR and mask to 12 bits
;
; Clobbers: R0 (return value), R1, R2 (saved/restored)
;=============================================================================
ADC_Read
        PUSH    {R1, R2, LR}

        LDR     R1, =ADC1_BASE

        ; ---- 1. Write channel number into SQR3 bits [4:0] ----
        LDR     R2, [R1, #ADC_SQR3]
        BIC     R2, R2, #0x0000001F    ; clear current first-sequence slot
        AND     R0, R0, #0x1F          ; safety mask: channel must be 0–18
        ORR     R2, R2, R0
        STR     R2, [R1, #ADC_SQR3]

        ; ---- 2. Clear EOC flag (write 0 to SR bit 1) ----
        LDR     R2, [R1, #ADC_SR]
        BIC     R2, R2, #ADC_SR_EOC
        STR     R2, [R1, #ADC_SR]

        ; ---- 3. Start conversion (SWSTART = CR2 bit 30) ----
        LDR     R2, [R1, #ADC_CR2]
        LDR     R0, =ADC_CR2_SWSTART
        ORR     R2, R2, R0
        STR     R2, [R1, #ADC_CR2]

        ; ---- 4. Poll until EOC is set ----
ADC_WaitEOC
        LDR     R2, [R1, #ADC_SR]
        TST     R2, #ADC_SR_EOC
        BEQ     ADC_WaitEOC

        ; ---- 5. Read result and mask to 12 bits ----
        ; DR is 16-bit wide on STM32F4 but sits in a 32-bit register;
        ; bits [15:12] are always 0 in right-aligned 12-bit mode,
        ; but we mask explicitly for safety.
        LDR     R0, [R1, #ADC_DR]
        LDR     R2, =0x00000FFF
        AND     R0, R0, R2             ; result in R0 = 0–4095

        POP     {R1, R2, PC}


        ALIGN
        END