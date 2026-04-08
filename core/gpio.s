;=============================================================================
; gpio.s
; General-purpose GPIO helpers – STM32F401RC
;=============================================================================

        AREA    GPIO_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

        EXPORT  GPIO_EnableClock
        EXPORT  GPIO_ConfigOutput
        EXPORT  GPIO_ConfigInput
        EXPORT  GPIO_WritePin
        EXPORT  GPIO_ClearPin
        EXPORT  GPIO_ReadPin

OFF_RCC_AHB1ENR     EQU     0x30
OFF_GPIO_MODER      EQU     0x00
OFF_GPIO_OTYPER     EQU     0x04
OFF_GPIO_PUPDR      EQU     0x0C
OFF_GPIO_IDR        EQU     0x10
OFF_GPIO_BSRR       EQU     0x18

GPIO_EnableClock
        PUSH    {R1, R2, R3, LR}

        LDR     R1, =RCC_BASE
        LDR     R2, [R1, #OFF_RCC_AHB1ENR]

        LDR     R3, =GPIOA_BASE
        CMP     R0, R3
        BEQ     GEC_EnableA

        LDR     R3, =GPIOB_BASE
        CMP     R0, R3
        BEQ     GEC_EnableB

        LDR     R3, =GPIOC_BASE
        CMP     R0, R3
        BEQ     GEC_EnableC

        B       GEC_Done

GEC_EnableA
        ORR     R2, R2, #BIT0
        B       GEC_Store

GEC_EnableB
        ORR     R2, R2, #BIT1
        B       GEC_Store

GEC_EnableC
        ORR     R2, R2, #BIT2

GEC_Store
        STR     R2, [R1, #OFF_RCC_AHB1ENR]

GEC_Done
        POP     {R1, R2, R3, PC}

GPIO_ConfigOutput
        PUSH    {R0,R2, R3, R4, LR}

        LDR     R2, [R0, #OFF_GPIO_MODER]
        MOV     R4, R1, LSL #1
        MOVS    R3, #3
        LSL     R3, R3, R4
        BIC     R2, R2, R3
        MOVS    R3, #1
        LSL     R3, R3, R4
        ORR     R2, R2, R3
        STR     R2, [R0, #OFF_GPIO_MODER]

        LDR     R2, [R0, #OFF_GPIO_OTYPER]
        MOVS    R3, #1
        LSL     R3, R3, R1
        BIC     R2, R2, R3
        STR     R2, [R0, #OFF_GPIO_OTYPER]

        LDR     R2, [R0, #OFF_GPIO_PUPDR]
        MOVS    R3, #3
        LSL     R3, R3, R4
        BIC     R2, R2, R3
        STR     R2, [R0, #OFF_GPIO_PUPDR]

        POP     {R0,R2, R3, R4, PC}

GPIO_ConfigInput
        PUSH    {R2, R3, R4, LR}

        LDR     R2, [R0, #OFF_GPIO_MODER]
        MOV     R4, R1, LSL #1
        MOVS    R3, #3
        LSL     R3, R3, R4
        BIC     R2, R2, R3
        STR     R2, [R0, #OFF_GPIO_MODER]

        LDR     R2, [R0, #OFF_GPIO_PUPDR]
        MOVS    R3, #3
        LSL     R3, R3, R4
        BIC     R2, R2, R3
        STR     R2, [R0, #OFF_GPIO_PUPDR]

        POP     {R2, R3, R4, PC}

GPIO_WritePin
        PUSH    {R2, LR}

        MOVS    R2, #1
        LSL     R2, R2, R1
        STR     R2, [R0, #OFF_GPIO_BSRR]

        POP     {R2, PC}

GPIO_ClearPin
        PUSH    {R2, LR}

        MOVS    R2, #1
        LSL     R2, R2, R1
        LSL     R2, R2, #16
        STR     R2, [R0, #OFF_GPIO_BSRR]

        POP     {R2, PC}

GPIO_ReadPin
        PUSH    {R2, LR}

        LDR     R2, [R0, #OFF_GPIO_IDR]
        LSR     R2, R2, R1
        AND     R0, R2, #1

        POP     {R2, PC}

        ALIGN
        END
