; =====================================================================
; FILE: i2c.s
; DESCRIPTION:
;   Blocking polling I2C1 driver for STM32F401, coded for PB8/PB9.
;   Added I2C_Read6Bytes for MAX30102 Burst Read compatibility.
; =====================================================================

        INCLUDE constants.s

        AREA    I2C_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        EXPORT  I2C_Init
        EXPORT  I2C_WriteReg
        EXPORT  I2C_ReadReg
        EXPORT  I2C_Read6Bytes

; -------------------- RCC / GPIO helpers --------------------
GPIO_AFRH               EQU     0x24

RCC_AHB1ENR_GPIOBEN     EQU     0x00000002
RCC_APB1ENR_I2C1EN      EQU     0x00200000

; -------------------- I2C1 registers ------------------------
I2C1_BASE               EQU     0x40005400

I2C_CR1                 EQU     0x00
I2C_CR2                 EQU     0x04
I2C_OAR1                EQU     0x08
I2C_DR                  EQU     0x10
I2C_SR1                 EQU     0x14
I2C_SR2                 EQU     0x18
I2C_CCR                 EQU     0x1C
I2C_TRISE               EQU     0x20

; -------------------- I2C bit defs --------------------------
I2C_CR1_PE              EQU     0x0001
I2C_CR1_START           EQU     0x0100
I2C_CR1_STOP            EQU     0x0200
I2C_CR1_ACK             EQU     0x0400

I2C_SR1_SB              EQU     0x0001
I2C_SR1_ADDR            EQU     0x0002
I2C_SR1_BTF             EQU     0x0004
I2C_SR1_RXNE            EQU     0x0040
I2C_SR1_TXE             EQU     0x0080

; -------------------- Fixed timing for APB1 = 42 MHz --------
I2C_CR2_FREQ_42MHZ      EQU     42
I2C_CCR_SM_100KHZ       EQU     210
I2C_TRISE_SM_42MHZ      EQU     43

; -------------------- GPIOB PB8/PB9 masks -------------------
PB8_PB9_MODE_MASK       EQU     0x000F0000
PB8_PB9_MODE_AF         EQU     0x000A0000

PB8_PB9_OT_MASK         EQU     0x00000300
PB8_PB9_OSPEED_MASK     EQU     0x000F0000
PB8_PB9_OSPEED_HIGH     EQU     0x000F0000

PB8_PB9_PUPD_MASK       EQU     0x000F0000
PB8_PB9_PUPD_PU         EQU     0x00050000

PB8_PB9_AFRH_MASK       EQU     0x000000FF
PB8_PB9_AFRH_AF4        EQU     0x00000044

; =====================================================================
; I2C_Init
; =====================================================================
I2C_Init
        PUSH    {R4, LR}

        LDR     R0, =RCC_BASE
        LDR     R1, [R0, #RCC_AHB1ENR]
        LDR     R2, =RCC_AHB1ENR_GPIOBEN
        ORR     R1, R1, R2
        STR     R1, [R0, #RCC_AHB1ENR]

        LDR     R1, [R0, #RCC_APB1ENR]
        LDR     R2, =RCC_APB1ENR_I2C1EN
        ORR     R1, R1, R2
        STR     R1, [R0, #RCC_APB1ENR]

        LDR     R0, =GPIOB_BASE
        LDR     R1, [R0, #GPIO_MODER]
        LDR     R2, =PB8_PB9_MODE_MASK
        BIC     R1, R1, R2
        LDR     R2, =PB8_PB9_MODE_AF
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_MODER]

        LDR     R1, [R0, #GPIO_OTYPER]
        LDR     R2, =PB8_PB9_OT_MASK
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_OTYPER]

        LDR     R1, [R0, #GPIO_OSPEEDR]
        LDR     R2, =PB8_PB9_OSPEED_MASK
        BIC     R1, R1, R2
        LDR     R2, =PB8_PB9_OSPEED_HIGH
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_OSPEEDR]

        LDR     R1, [R0, #GPIO_PUPDR]
        LDR     R2, =PB8_PB9_PUPD_MASK
        BIC     R1, R1, R2
        LDR     R2, =PB8_PB9_PUPD_PU
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_PUPDR]

        LDR     R1, [R0, #GPIO_AFRH]
        LDR     R2, =PB8_PB9_AFRH_MASK
        BIC     R1, R1, R2
        LDR     R2, =PB8_PB9_AFRH_AF4
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_AFRH]

        LDR     R4, =I2C1_BASE
        MOVS    R1, #0
        STR     R1, [R4, #I2C_CR1]

        MOVS    R1, #I2C_CR2_FREQ_42MHZ
        STR     R1, [R4, #I2C_CR2]

        LDR     R1, =0x00004000
        STR     R1, [R4, #I2C_OAR1]

        LDR     R1, =I2C_CCR_SM_100KHZ
        STR     R1, [R4, #I2C_CCR]

        MOVS    R1, #I2C_TRISE_SM_42MHZ
        STR     R1, [R4, #I2C_TRISE]

        LDR     R1, =I2C_CR1_PE + I2C_CR1_ACK
        STR     R1, [R4, #I2C_CR1]

        POP     {R4, PC}

; =====================================================================
; I2C_WriteReg
; =====================================================================
I2C_WriteReg
        PUSH    {R4-R7, LR}

        MOV     R4, R0
        MOV     R5, R1
        MOV     R6, R2
        LDR     R7, =I2C1_BASE

        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_START
        STR     R1, [R7, #I2C_CR1]

IW_WaitSB
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_SB
        BEQ     IW_WaitSB

        LSL     R0, R4, #1
        STR     R0, [R7, #I2C_DR]

IW_WaitADDR
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_ADDR
        BEQ     IW_WaitADDR

        LDR     R1, [R7, #I2C_SR1]
        LDR     R1, [R7, #I2C_SR2]

IW_WaitTXE_Reg
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_TXE
        BEQ     IW_WaitTXE_Reg

        STR     R5, [R7, #I2C_DR]

IW_WaitTXE_Data
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_TXE
        BEQ     IW_WaitTXE_Data

        STR     R6, [R7, #I2C_DR]

IW_WaitBTF
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_BTF
        BEQ     IW_WaitBTF

        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_STOP
        STR     R1, [R7, #I2C_CR1]

        MOVS    R0, #0
        POP     {R4-R7, PC}

; =====================================================================
; I2C_ReadReg
; =====================================================================
I2C_ReadReg
        PUSH    {R4-R7, LR}

        MOV     R4, R0
        MOV     R5, R1
        LDR     R7, =I2C1_BASE

        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_ACK
        STR     R1, [R7, #I2C_CR1]

        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_START
        STR     R1, [R7, #I2C_CR1]

IR_WaitSB1
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_SB
        BEQ     IR_WaitSB1

        LSL     R0, R4, #1
        STR     R0, [R7, #I2C_DR]

IR_WaitADDR1
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_ADDR
        BEQ     IR_WaitADDR1

        LDR     R1, [R7, #I2C_SR1]
        LDR     R1, [R7, #I2C_SR2]

IR_WaitTXE
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_TXE
        BEQ     IR_WaitTXE

        STR     R5, [R7, #I2C_DR]

IR_WaitBTF1
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_BTF
        BEQ     IR_WaitBTF1

        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_START
        STR     R1, [R7, #I2C_CR1]

IR_WaitSB2
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_SB
        BEQ     IR_WaitSB2

        LSL     R0, R4, #1
        ORR     R0, R0, #1
        STR     R0, [R7, #I2C_DR]

IR_WaitADDR2
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_ADDR
        BEQ     IR_WaitADDR2

        LDR     R1, [R7, #I2C_CR1]
        BIC     R1, R1, #I2C_CR1_ACK
        STR     R1, [R7, #I2C_CR1]

        LDR     R1, [R7, #I2C_SR1]
        LDR     R1, [R7, #I2C_SR2]

        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_STOP
        STR     R1, [R7, #I2C_CR1]

IR_WaitRXNE
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_RXNE
        BEQ     IR_WaitRXNE

        LDR     R0, [R7, #I2C_DR]

        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_ACK
        STR     R1, [R7, #I2C_CR1]

        POP     {R4-R7, PC}


; =====================================================================
; I2C_Read6Bytes
; Inputs:
;   R0 = 7-bit device address
;   R1 = register address
;   R2 = pointer to 6-byte buffer in RAM
; =====================================================================
I2C_Read6Bytes
        PUSH    {R4-R7, LR}

        MOV     R4, R0
        MOV     R5, R1
        MOV     R6, R2
        LDR     R7, =I2C1_BASE

        ; Enable ACK
        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_ACK
        STR     R1, [R7, #I2C_CR1]

        ; START 1
        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_START
        STR     R1, [R7, #I2C_CR1]
IR6_WaitSB1
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_SB
        BEQ     IR6_WaitSB1

        ; Address + Write
        LSL     R0, R4, #1
        STR     R0, [R7, #I2C_DR]
IR6_WaitADDR1
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_ADDR
        BEQ     IR6_WaitADDR1
        LDR     R1, [R7, #I2C_SR1]
        LDR     R1, [R7, #I2C_SR2]

        ; Register Address
IR6_WaitTXE
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_TXE
        BEQ     IR6_WaitTXE
        STR     R5, [R7, #I2C_DR]

IR6_WaitBTF1
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_BTF
        BEQ     IR6_WaitBTF1

        ; Repeated START
        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_START
        STR     R1, [R7, #I2C_CR1]
IR6_WaitSB2
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_SB
        BEQ     IR6_WaitSB2

        ; Address + Read
        LSL     R0, R4, #1
        ORR     R0, R0, #1
        STR     R0, [R7, #I2C_DR]
IR6_WaitADDR2
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_ADDR
        BEQ     IR6_WaitADDR2
        LDR     R1, [R7, #I2C_SR1]
        LDR     R1, [R7, #I2C_SR2]

        ; Byte 0
IR6_WaitRXNE0
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_RXNE
        BEQ     IR6_WaitRXNE0
        LDR     R0, [R7, #I2C_DR]
        STRB    R0, [R6, #0]

        ; Byte 1
IR6_WaitRXNE1
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_RXNE
        BEQ     IR6_WaitRXNE1
        LDR     R0, [R7, #I2C_DR]
        STRB    R0, [R6, #1]

        ; Byte 2
IR6_WaitRXNE2
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_RXNE
        BEQ     IR6_WaitRXNE2
        LDR     R0, [R7, #I2C_DR]
        STRB    R0, [R6, #2]

        ; Byte 3
IR6_WaitRXNE3
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_RXNE
        BEQ     IR6_WaitRXNE3
        LDR     R0, [R7, #I2C_DR]
        STRB    R0, [R6, #3]

        ; Byte 4
IR6_WaitRXNE4
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_RXNE
        BEQ     IR6_WaitRXNE4
        
        ; Clear ACK and Generate STOP before reading the 5th byte (Byte 4)
        LDR     R1, [R7, #I2C_CR1]
        BIC     R1, R1, #I2C_CR1_ACK
        STR     R1, [R7, #I2C_CR1]
        
        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_STOP
        STR     R1, [R7, #I2C_CR1]

        LDR     R0, [R7, #I2C_DR]
        STRB    R0, [R6, #4]

        ; Byte 5 (Final Byte)
IR6_WaitRXNE5
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, #I2C_SR1_RXNE
        BEQ     IR6_WaitRXNE5
        LDR     R0, [R7, #I2C_DR]
        STRB    R0, [R6, #5]

        ; Restore ACK
        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_ACK
        STR     R1, [R7, #I2C_CR1]

        POP     {R4-R7, PC}

        END