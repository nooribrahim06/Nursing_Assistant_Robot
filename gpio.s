; =====================================================================
; FILE: gpio.s
; DESCRIPTION: GPIO driver for STM32F401RCT6
; LAYER: Low-Level Driver (Layer 3)
; =====================================================================

        AREA    GPIO_CODE, CODE, READONLY
        EXPORT  GPIO_EnableClock
        EXPORT  GPIO_ConfigOutput
        EXPORT  GPIO_ConfigInput
        EXPORT  GPIO_WritePin
        EXPORT  GPIO_ClearPin
        EXPORT  GPIO_ReadPin

        IMPORT  RCC_BASE
        IMPORT  RCC_AHB1ENR

        IMPORT  GPIOA_BASE
        IMPORT  GPIOB_BASE
        IMPORT  GPIOC_BASE

        IMPORT  GPIO_MODER
        IMPORT  GPIO_OTYPER
        IMPORT  GPIO_PUPDR
        IMPORT  GPIO_IDR
        IMPORT  GPIO_BSRR

; ============================================================
; GPIO_EnableClock
; Input:
;   R0 = GPIO base address
; ============================================================
GPIO_EnableClock
        PUSH    {R1, R2, LR}

        LDR     R1, =RCC_BASE
        ADD     R1, R1, #RCC_AHB1ENR

        ; Determine port index
        LDR     R2, =GPIOA_BASE
        CMP     R0, R2
        BEQ     EnableA

        LDR     R2, =GPIOB_BASE
        CMP     R0, R2
        BEQ     EnableB

        LDR     R2, =GPIOC_BASE
        CMP     R0, R2
        BEQ     EnableC

        B       EndEnable

EnableA
        LDR     R2, [R1]
        ORR     R2, R2, #(1 << 0)
        STR     R2, [R1]
        B       EndEnable

EnableB
        LDR     R2, [R1]
        ORR     R2, R2, #(1 << 1)
        STR     R2, [R1]
        B       EndEnable

EnableC
        LDR     R2, [R1]
        ORR     R2, R2, #(1 << 2)
        STR     R2, [R1]

EndEnable
        POP     {R1, R2, PC}

; ============================================================
; GPIO_ConfigOutput
; Input:
;   R0 = GPIO base
;   R1 = pin number (0–15)
; ============================================================
GPIO_ConfigOutput
        PUSH    {R2-R5, LR}

        ; MODER = 01
        LDR     R2, [R0, #GPIO_MODER]
        MOV     R3, #3
        LSL     R3, R3, R1, LSL #1      ; mask = 11 << (pin*2)
        BIC     R2, R2, R3

        MOV     R4, #1
        LSL     R4, R4, R1, LSL #1      ; value = 01 << (pin*2)
        ORR     R2, R2, R4
        STR     R2, [R0, #GPIO_MODER]

        ; OTYPER = push-pull (0)
        LDR     R2, [R0, #GPIO_OTYPER]
        MOV     R3, #1
        LSL     R3, R3, R1
        BIC     R2, R2, R3
        STR     R2, [R0, #GPIO_OTYPER]

        ; PUPDR = no pull
        LDR     R2, [R0, #GPIO_PUPDR]
        MOV     R3, #3
        LSL     R3, R3, R1, LSL #1
        BIC     R2, R2, R3
        STR     R2, [R0, #GPIO_PUPDR]

        POP     {R2-R5, PC}

; ============================================================
; GPIO_ConfigInput
; Input:
;   R0 = GPIO base
;   R1 = pin number
; ============================================================
GPIO_ConfigInput
        PUSH    {R2-R4, LR}

        ; MODER = 00
        LDR     R2, [R0, #GPIO_MODER]
        MOV     R3, #3
        LSL     R3, R3, R1, LSL #1
        BIC     R2, R2, R3
        STR     R2, [R0, #GPIO_MODER]

        ; PUPDR = no pull
        LDR     R2, [R0, #GPIO_PUPDR]
        MOV     R3, #3
        LSL     R3, R3, R1, LSL #1
        BIC     R2, R2, R3
        STR     R2, [R0, #GPIO_PUPDR]

        POP     {R2-R4, PC}

; ============================================================
; GPIO_WritePin (SET = HIGH)
; Input:
;   R0 = GPIO base
;   R1 = pin number
; ============================================================
GPIO_WritePin
        PUSH    {R2, LR}

        MOV     R2, #1
        LSL     R2, R2, R1
        STR     R2, [R0, #GPIO_BSRR]

        POP     {R2, PC}

; ============================================================
; GPIO_ClearPin (RESET = LOW)
; Input:
;   R0 = GPIO base
;   R1 = pin number
; ============================================================
GPIO_ClearPin
        PUSH    {R2, LR}

        MOV     R2, #1
        LSL     R2, R2, R1
        LSL     R2, R2, #16
        STR     R2, [R0, #GPIO_BSRR]

        POP     {R2, PC}

; ============================================================
; GPIO_ReadPin
; Input:
;   R0 = GPIO base
;   R1 = pin number
; Output:
;   R0 = 0 or 1
; ============================================================
GPIO_ReadPin
        PUSH    {R2, LR}

        LDR     R2, [R0, #GPIO_IDR]
        LSR     R2, R2, R1
        AND     R0, R2, #1

        POP     {R2, PC}

        END