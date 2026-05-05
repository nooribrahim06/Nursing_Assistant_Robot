        INCLUDE constants.s

        AREA    I2C_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        EXPORT  I2C_Init
        EXPORT  I2C_WriteReg
        EXPORT  I2C_ReadReg
        EXPORT  I2C_Read6Bytes

I2C1_BASE               EQU     0x40005400

I2C_CR1                 EQU     0x00
I2C_CR2                 EQU     0x04
I2C_OAR1                EQU     0x08
I2C_DR                  EQU     0x10
I2C_SR1                 EQU     0x14
I2C_SR2                 EQU     0x18
I2C_CCR                 EQU     0x1C
I2C_TRISE               EQU     0x20

I2C_CR1_PE              EQU     0x0001
I2C_CR1_START           EQU     0x0100
I2C_CR1_STOP            EQU     0x0200
I2C_CR1_ACK             EQU     0x0400
I2C_CR1_SWRST           EQU     0x8000

I2C_SR1_SB_BIT          EQU     0x0001
I2C_SR1_ADDR_BIT        EQU     0x0002
I2C_SR1_BTF_BIT         EQU     0x0004
I2C_SR1_RXNE_BIT        EQU     0x0040
I2C_SR1_TXE_BIT         EQU     0x0080

I2C_CR2_FREQ_42MHZ      EQU     42
I2C_CCR_SM_100KHZ       EQU     210
I2C_TRISE_SM_42MHZ      EQU     43

PB8_PB9_MODE_MASK       EQU     0x000F0000
PB8_PB9_MODE_AF         EQU     0x000A0000
PB8_PB9_OT_MASK         EQU     0x00000300
PB8_PB9_OSPEED_MASK     EQU     0x000F0000
PB8_PB9_OSPEED_HIGH     EQU     0x000F0000
PB8_PB9_PUPD_MASK       EQU     0x000F0000
PB8_PB9_PUPD_PU         EQU     0x00050000
PB8_PB9_AFRH_MASK       EQU     0x000000FF
PB8_PB9_AFRH_AF4        EQU     0x00000044

I2C_TIMEOUT             EQU     60000

; =====================================================================
; I2C_WaitSR1_Set
; IN:  R7 = I2C base, R0 = SR1 mask
; OUT: R0 = 0 success, 1 timeout
; Uses R1,R2 only
; =====================================================================
I2C_WaitSR1_Set
        PUSH    {R1, R2, LR}
        LDR     R2, =I2C_TIMEOUT
I2C_WaitSR1_Loop
        LDR     R1, [R7, #I2C_SR1]
        TST     R1, R0
        BNE     I2C_WaitSR1_OK
        SUBS    R2, R2, #1
        BNE     I2C_WaitSR1_Loop
        MOVS    R0, #1
        POP     {R1, R2, PC}
I2C_WaitSR1_OK
        MOVS    R0, #0
        POP     {R1, R2, PC}

; =====================================================================
; I2C_ForceStop
; Leaves bus in a safe state after timeout.
; =====================================================================
I2C_ForceStop
        PUSH    {R0, R1, LR}
        LDR     R0, [R7, #I2C_CR1]
        ORR     R0, R0, #I2C_CR1_STOP
        ORR     R0, R0, #I2C_CR1_ACK
        STR     R0, [R7, #I2C_CR1]
        POP     {R0, R1, PC}

; =====================================================================
; I2C_Init
; =====================================================================
I2C_Init
        PUSH    {R4, LR}

        LDR     R0, =RCC_BASE
        LDR     R1, [R0, #RCC_AHB1ENR]
        ORR     R1, R1, #0x00000002
        STR     R1, [R0, #RCC_AHB1ENR]

        LDR     R1, [R0, #RCC_APB1ENR]
        LDR     R2, =0x00200000
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

        ; software reset clears a stuck I2C peripheral state
        LDR     R1, =I2C_CR1_SWRST
        STR     R1, [R4, #I2C_CR1]
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

        LDR     R1, =0x00000401
        STR     R1, [R4, #I2C_CR1]

        POP     {R4, PC}

; =====================================================================
; I2C_WriteReg
; R0=device addr, R1=reg, R2=data
; OUT R0=0 success, R0=1 timeout/fail
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

        MOVS    R0, #I2C_SR1_SB_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IW_Fail

        LSL     R0, R4, #1
        STR     R0, [R7, #I2C_DR]

        MOVS    R0, #I2C_SR1_ADDR_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IW_Fail

        LDR     R1, [R7, #I2C_SR1]
        LDR     R1, [R7, #I2C_SR2]

        MOVS    R0, #I2C_SR1_TXE_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IW_Fail
        STR     R5, [R7, #I2C_DR]

        MOVS    R0, #I2C_SR1_TXE_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IW_Fail
        STR     R6, [R7, #I2C_DR]

        MOVS    R0, #I2C_SR1_BTF_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IW_Fail

        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_STOP
        STR     R1, [R7, #I2C_CR1]

        MOVS    R0, #0
        POP     {R4-R7, PC}

IW_Fail
        BL      I2C_ForceStop
        MOVS    R0, #1
        POP     {R4-R7, PC}

; =====================================================================
; I2C_ReadReg
; R0=device addr, R1=reg -> R0=data, returns 0 if timeout
; =====================================================================
I2C_ReadReg
        PUSH    {R4-R7, LR}

        MOV     R4, R0
        MOV     R5, R1
        LDR     R7, =I2C1_BASE

        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_ACK
        ORR     R1, R1, #I2C_CR1_START
        STR     R1, [R7, #I2C_CR1]

        MOVS    R0, #I2C_SR1_SB_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR_Fail

        LSL     R0, R4, #1
        STR     R0, [R7, #I2C_DR]

        MOVS    R0, #I2C_SR1_ADDR_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR_Fail

        LDR     R1, [R7, #I2C_SR1]
        LDR     R1, [R7, #I2C_SR2]

        MOVS    R0, #I2C_SR1_TXE_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR_Fail
        STR     R5, [R7, #I2C_DR]

        MOVS    R0, #I2C_SR1_BTF_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR_Fail

        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_START
        STR     R1, [R7, #I2C_CR1]

        MOVS    R0, #I2C_SR1_SB_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR_Fail

        LSL     R0, R4, #1
        ORR     R0, R0, #1
        STR     R0, [R7, #I2C_DR]

        MOVS    R0, #I2C_SR1_ADDR_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR_Fail

        ; single byte read: ACK off before clearing ADDR, then STOP
        LDR     R1, [R7, #I2C_CR1]
        BIC     R1, R1, #I2C_CR1_ACK
        STR     R1, [R7, #I2C_CR1]

        LDR     R1, [R7, #I2C_SR1]
        LDR     R1, [R7, #I2C_SR2]

        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_STOP
        STR     R1, [R7, #I2C_CR1]

        MOVS    R0, #I2C_SR1_RXNE_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR_Fail

        LDR     R0, [R7, #I2C_DR]
        UXTB    R0, R0

        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_ACK
        STR     R1, [R7, #I2C_CR1]

        POP     {R4-R7, PC}

IR_Fail
        BL      I2C_ForceStop
        MOVS    R0, #0
        POP     {R4-R7, PC}

; =====================================================================
; I2C_Read6Bytes
; R0=device addr, R1=reg, R2=buffer ptr
; OUT R0=0 success, R0=1 timeout/fail
; =====================================================================
I2C_Read6Bytes
        PUSH    {R4-R7, LR}

        MOV     R4, R0
        MOV     R5, R1
        MOV     R6, R2
        LDR     R7, =I2C1_BASE

        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_ACK
        ORR     R1, R1, #I2C_CR1_START
        STR     R1, [R7, #I2C_CR1]

        MOVS    R0, #I2C_SR1_SB_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR6_Fail

        LSL     R0, R4, #1
        STR     R0, [R7, #I2C_DR]

        MOVS    R0, #I2C_SR1_ADDR_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR6_Fail
        LDR     R1, [R7, #I2C_SR1]
        LDR     R1, [R7, #I2C_SR2]

        MOVS    R0, #I2C_SR1_TXE_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR6_Fail
        STR     R5, [R7, #I2C_DR]

        MOVS    R0, #I2C_SR1_BTF_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR6_Fail

        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_START
        STR     R1, [R7, #I2C_CR1]

        MOVS    R0, #I2C_SR1_SB_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR6_Fail

        LSL     R0, R4, #1
        ORR     R0, R0, #1
        STR     R0, [R7, #I2C_DR]

        MOVS    R0, #I2C_SR1_ADDR_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR6_Fail
        LDR     R1, [R7, #I2C_SR1]
        LDR     R1, [R7, #I2C_SR2]

        ; bytes 0..3 with ACK
        MOVS    R0, #I2C_SR1_RXNE_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR6_Fail
        LDR     R0, [R7, #I2C_DR]
        STRB    R0, [R6, #0]

        MOVS    R0, #I2C_SR1_RXNE_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR6_Fail
        LDR     R0, [R7, #I2C_DR]
        STRB    R0, [R6, #1]

        MOVS    R0, #I2C_SR1_RXNE_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR6_Fail
        LDR     R0, [R7, #I2C_DR]
        STRB    R0, [R6, #2]

        MOVS    R0, #I2C_SR1_RXNE_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR6_Fail
        LDR     R0, [R7, #I2C_DR]
        STRB    R0, [R6, #3]

        ; byte 4: turn ACK off and request STOP before final byte
        MOVS    R0, #I2C_SR1_RXNE_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR6_Fail

        LDR     R1, [R7, #I2C_CR1]
        BIC     R1, R1, #I2C_CR1_ACK
        ORR     R1, R1, #I2C_CR1_STOP
        STR     R1, [R7, #I2C_CR1]

        LDR     R0, [R7, #I2C_DR]
        STRB    R0, [R6, #4]

        MOVS    R0, #I2C_SR1_RXNE_BIT
        BL      I2C_WaitSR1_Set
        CMP     R0, #0
        BNE     IR6_Fail
        LDR     R0, [R7, #I2C_DR]
        STRB    R0, [R6, #5]

        LDR     R1, [R7, #I2C_CR1]
        ORR     R1, R1, #I2C_CR1_ACK
        STR     R1, [R7, #I2C_CR1]

        MOVS    R0, #0
        POP     {R4-R7, PC}

IR6_Fail
        BL      I2C_ForceStop
        MOVS    R0, #1
        POP     {R4-R7, PC}

        END