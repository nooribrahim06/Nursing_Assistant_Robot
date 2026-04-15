; =====================================================================
; FILE: tft_low.s
; DESCRIPTION:
;   Low-level TFT driver for ILI9341 using SPI1 on STM32F401.
;
; FINAL TFT SPI MAP
;   PB0 -> TFT_CS
;   PB1 -> TFT_DC / RS
;   PB2 -> TFT_RST
;   PB3 -> SPI1_SCK   (AF5)
;   PB5 -> SPI1_MOSI  (AF5)
;   PB4 -> unused
;   MISO -> not used
;
; NOTES:
;   - Revised for better Proteus compatibility
;   - Uses normal 2-line SPI master mode
;   - Keeps CS low across command + parameter bytes in init/window setup
;   - Landscape mode uses MADCTL = 0x28
;     If your module is mirrored, try 0xE8 instead
; =====================================================================

        AREA    TFT_LOW, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        EXPORT  TFT_Init
        EXPORT  TFT_Reset
        EXPORT  TFT_SendCommand
        EXPORT  TFT_SendData
        EXPORT  TFT_WriteData16
        EXPORT  TFT_SetAddressWindow

RCC_BASE                EQU     0x40023800
RCC_AHB1ENR             EQU     0x30
RCC_APB2ENR             EQU     0x44

RCC_AHB1ENR_GPIOBEN     EQU     0x00000002
RCC_APB2ENR_SPI1EN      EQU     0x00001000

GPIOB_BASE              EQU     0x40020400
GPIO_MODER              EQU     0x00
GPIO_OTYPER             EQU     0x04
GPIO_OSPEEDR            EQU     0x08
GPIO_PUPDR              EQU     0x0C
GPIO_BSRR               EQU     0x18
GPIO_AFRL               EQU     0x20

SPI1_BASE               EQU     0x40013000
SPI_CR1                 EQU     0x00
SPI_SR                  EQU     0x08
SPI_DR                  EQU     0x0C

SPI_SR_TXE              EQU     0x02
SPI_SR_BSY              EQU     0x80

SPI1_CR1_VALUE          EQU     0x0000035C

ILI9341_SWRESET         EQU     0x01
ILI9341_SLPOUT          EQU     0x11
ILI9341_GAMSET          EQU     0x26
ILI9341_DISPON          EQU     0x29
ILI9341_CASET           EQU     0x2A
ILI9341_PASET           EQU     0x2B
ILI9341_RAMWR           EQU     0x2C
ILI9341_MADCTL          EQU     0x36
ILI9341_PIXFMT          EQU     0x3A
ILI9341_FRMCTR1         EQU     0xB1
ILI9341_DFUNCTR         EQU     0xB6
ILI9341_PWCTR1          EQU     0xC0
ILI9341_PWCTR2          EQU     0xC1
ILI9341_VMCTR1          EQU     0xC5
ILI9341_VMCTR2          EQU     0xC7

GPIOB_TFT_MODER_MASK    EQU     0x00000CFF
GPIOB_TFT_MODER_VALUE   EQU     0x00000895

GPIOB_TFT_OT_MASK       EQU     0x0000002F

GPIOB_TFT_OSPEED_MASK   EQU     0x00000CFF
GPIOB_TFT_OSPEED_VALUE  EQU     0x00000CFF

GPIOB_TFT_PUPDR_MASK    EQU     0x00000CFF

GPIOB_TFT_AFRL_MASK     EQU     0x00F0F000
GPIOB_TFT_AFRL_AF5      EQU     0x00505000

TFT_BSRR_IDLE_HIGH      EQU     0x00000007
TFT_BSRR_CS_HIGH        EQU     0x00000001
TFT_BSRR_CS_LOW         EQU     0x00010000
TFT_BSRR_DC_HIGH        EQU     0x00000002
TFT_BSRR_DC_LOW         EQU     0x00020000
TFT_BSRR_RST_HIGH       EQU     0x00000004
TFT_BSRR_RST_LOW        EQU     0x00040000

TFT_BSRR_CMD_MODE       EQU     0x00030000
TFT_BSRR_DATA_MODE      EQU     0x00010002

TFT_DELAY_RESET_SHORT   EQU     1000000
TFT_DELAY_RESET_LONG    EQU     2500000
TFT_DELAY_SWRESET       EQU     2500000
TFT_DELAY_SLPOUT        EQU     9000000
TFT_DELAY_POST_DISPON   EQU     2000000

TFT_Delay
TFT_Delay_Loop
        SUBS    R0, R0, #1
        BNE     TFT_Delay_Loop
        BX      LR

TFT_GPIO_SPI_Init
        PUSH    {R1-R3, LR}

        LDR     R0, =RCC_BASE
        LDR     R1, [R0, #RCC_AHB1ENR]
        LDR     R2, =RCC_AHB1ENR_GPIOBEN
        ORR     R1, R1, R2
        STR     R1, [R0, #RCC_AHB1ENR]

        LDR     R0, =GPIOB_BASE

        LDR     R1, [R0, #GPIO_MODER]
        LDR     R2, =GPIOB_TFT_MODER_MASK
        BIC     R1, R1, R2
        LDR     R2, =GPIOB_TFT_MODER_VALUE
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_MODER]

        LDR     R1, [R0, #GPIO_OTYPER]
        LDR     R2, =GPIOB_TFT_OT_MASK
        BIC     R1, R1, R2
        STR     R1, [R0, #GPIO_OTYPER]

        LDR     R1, [R0, #GPIO_OSPEEDR]
        LDR     R2, =GPIOB_TFT_OSPEED_MASK
        BIC     R1, R1, R2
        LDR     R2, =GPIOB_TFT_OSPEED_VALUE
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_OSPEEDR]

        LDR     R1, [R0, #GPIO_PUPDR]
        LDR     R2, =GPIOB_TFT_PUPDR_MASK
        BIC     R1, R1, R2
        STR     R1, [R0, #GPIO_PUPDR]

        LDR     R1, [R0, #GPIO_AFRL]
        LDR     R2, =GPIOB_TFT_AFRL_MASK
        BIC     R1, R1, R2
        LDR     R2, =GPIOB_TFT_AFRL_AF5
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_AFRL]

        LDR     R1, =TFT_BSRR_IDLE_HIGH
        STR     R1, [R0, #GPIO_BSRR]

        LDR     R0, =RCC_BASE
        LDR     R1, [R0, #RCC_APB2ENR]
        LDR     R2, =RCC_APB2ENR_SPI1EN
        ORR     R1, R1, R2
        STR     R1, [R0, #RCC_APB2ENR]

        LDR     R0, =SPI1_BASE
        MOVS    R1, #0
        STR     R1, [R0, #SPI_CR1]

        LDR     R1, =SPI1_CR1_VALUE
        STR     R1, [R0, #SPI_CR1]

        POP     {R1-R3, PC}

SPI_SendByte
        LDR     R1, =SPI1_BASE

SPI_WaitTXE_1
        LDR     R2, [R1, #SPI_SR]
        TST     R2, #SPI_SR_TXE
        BEQ     SPI_WaitTXE_1

        STRB    R0, [R1, #SPI_DR]

SPI_WaitTXE_2
        LDR     R2, [R1, #SPI_SR]
        TST     R2, #SPI_SR_TXE
        BEQ     SPI_WaitTXE_2

SPI_WaitBSY
        LDR     R2, [R1, #SPI_SR]
        TST     R2, #SPI_SR_BSY
        BNE     SPI_WaitBSY

        BX      LR

TFT_BeginCommand
        LDR     R1, =GPIOB_BASE
        LDR     R0, =TFT_BSRR_CMD_MODE
        STR     R0, [R1, #GPIO_BSRR]
        BX      LR

TFT_SwitchToData
        LDR     R1, =GPIOB_BASE
        LDR     R0, =TFT_BSRR_DC_HIGH
        STR     R0, [R1, #GPIO_BSRR]
        BX      LR

TFT_EndTransaction
        LDR     R1, =GPIOB_BASE
        LDR     R0, =TFT_BSRR_CS_HIGH
        STR     R0, [R1, #GPIO_BSRR]
        BX      LR

TFT_Reset
        PUSH    {R1, LR}

        LDR     R1, =GPIOB_BASE

        LDR     R0, =TFT_BSRR_RST_HIGH
        STR     R0, [R1, #GPIO_BSRR]
        LDR     R0, =TFT_DELAY_RESET_SHORT
        BL      TFT_Delay

        LDR     R0, =TFT_BSRR_RST_LOW
        STR     R0, [R1, #GPIO_BSRR]
        LDR     R0, =TFT_DELAY_RESET_SHORT
        BL      TFT_Delay

        LDR     R0, =TFT_BSRR_RST_HIGH
        STR     R0, [R1, #GPIO_BSRR]
        LDR     R0, =TFT_DELAY_RESET_LONG
        BL      TFT_Delay

        POP     {R1, PC}

TFT_SendCommand
        PUSH    {R4, LR}
        MOV     R4, R0

        BL      TFT_BeginCommand
        MOV     R0, R4
        BL      SPI_SendByte
        BL      TFT_EndTransaction

        POP     {R4, PC}

TFT_SendData
        PUSH    {R4, R5, LR}

        MOV     R4, R0
        LDR     R5, =GPIOB_BASE
        LDR     R0, =TFT_BSRR_DATA_MODE
        STR     R0, [R5, #GPIO_BSRR]

        MOV     R0, R4
        BL      SPI_SendByte
        BL      TFT_EndTransaction

        POP     {R4, R5, PC}

TFT_WriteData16
        PUSH    {R4, R5, LR}

        MOV     R4, R0
        LDR     R5, =GPIOB_BASE

        LDR     R0, =TFT_BSRR_DATA_MODE
        STR     R0, [R5, #GPIO_BSRR]

        LSRS    R0, R4, #8
        BL      SPI_SendByte

        AND     R0, R4, #0xFF
        BL      SPI_SendByte

        BL      TFT_EndTransaction

        POP     {R4, R5, PC}

TFT_SetAddressWindow
        PUSH    {R4-R7, LR}

        MOV     R4, R0
        MOV     R5, R1
        MOV     R6, R2
        MOV     R7, R3

        BL      TFT_BeginCommand
        MOVS    R0, #ILI9341_CASET
        BL      SPI_SendByte
        BL      TFT_SwitchToData
        LSRS    R0, R4, #8
        BL      SPI_SendByte
        AND     R0, R4, #0xFF
        BL      SPI_SendByte
        LSRS    R0, R6, #8
        BL      SPI_SendByte
        AND     R0, R6, #0xFF
        BL      SPI_SendByte
        BL      TFT_EndTransaction

        BL      TFT_BeginCommand
        MOVS    R0, #ILI9341_PASET
        BL      SPI_SendByte
        BL      TFT_SwitchToData
        LSRS    R0, R5, #8
        BL      SPI_SendByte
        AND     R0, R5, #0xFF
        BL      SPI_SendByte
        LSRS    R0, R7, #8
        BL      SPI_SendByte
        AND     R0, R7, #0xFF
        BL      SPI_SendByte
        BL      TFT_EndTransaction

        BL      TFT_BeginCommand
        MOVS    R0, #ILI9341_RAMWR
        BL      SPI_SendByte
        BL      TFT_EndTransaction

        POP     {R4-R7, PC}

TFT_WriteReg1
        PUSH    {R4, R5, LR}
        MOV     R4, R0
        MOV     R5, R1

        BL      TFT_BeginCommand
        MOV     R0, R4
        BL      SPI_SendByte
        BL      TFT_SwitchToData
        MOV     R0, R5
        BL      SPI_SendByte
        BL      TFT_EndTransaction

        POP     {R4, R5, PC}

TFT_WriteReg2
        PUSH    {R4-R6, LR}
        MOV     R4, R0
        MOV     R5, R1
        MOV     R6, R2

        BL      TFT_BeginCommand
        MOV     R0, R4
        BL      SPI_SendByte
        BL      TFT_SwitchToData
        MOV     R0, R5
        BL      SPI_SendByte
        MOV     R0, R6
        BL      SPI_SendByte
        BL      TFT_EndTransaction

        POP     {R4-R6, PC}

TFT_WriteReg3
        PUSH    {R4-R7, LR}
        MOV     R4, R0
        MOV     R5, R1
        MOV     R6, R2
        MOV     R7, R3

        BL      TFT_BeginCommand
        MOV     R0, R4
        BL      SPI_SendByte
        BL      TFT_SwitchToData
        MOV     R0, R5
        BL      SPI_SendByte
        MOV     R0, R6
        BL      SPI_SendByte
        MOV     R0, R7
        BL      SPI_SendByte
        BL      TFT_EndTransaction

        POP     {R4-R7, PC}

TFT_Init
        PUSH    {LR}

        BL      TFT_GPIO_SPI_Init
        BL      TFT_Reset

        MOVS    R0, #ILI9341_SWRESET
        BL      TFT_SendCommand
        LDR     R0, =TFT_DELAY_SWRESET
        BL      TFT_Delay

        MOVS    R0, #ILI9341_SLPOUT
        BL      TFT_SendCommand
        LDR     R0, =TFT_DELAY_SLPOUT
        BL      TFT_Delay

        MOVS    R0, #ILI9341_FRMCTR1
        MOVS    R1, #0x00
        MOVS    R2, #0x18
        BL      TFT_WriteReg2

        MOVS    R0, #ILI9341_DFUNCTR
        MOVS    R1, #0x08
        MOVS    R2, #0x82
        MOVS    R3, #0x27
        BL      TFT_WriteReg3

        MOVS    R0, #ILI9341_PWCTR1
        MOVS    R1, #0x23
        BL      TFT_WriteReg1

        MOVS    R0, #ILI9341_PWCTR2
        MOVS    R1, #0x10
        BL      TFT_WriteReg1

        MOVS    R0, #ILI9341_VMCTR1
        MOVS    R1, #0x3E
        MOVS    R2, #0x28
        BL      TFT_WriteReg2

        MOVS    R0, #ILI9341_VMCTR2
        MOVS    R1, #0x86
        BL      TFT_WriteReg1

        MOVS    R0, #ILI9341_GAMSET
        MOVS    R1, #0x01
        BL      TFT_WriteReg1

        MOVS    R0, #ILI9341_MADCTL
        MOVS    R1, #0x28
        BL      TFT_WriteReg1

        MOVS    R0, #ILI9341_PIXFMT
        MOVS    R1, #0x55
        BL      TFT_WriteReg1

        MOVS    R0, #ILI9341_DISPON
        BL      TFT_SendCommand
        LDR     R0, =TFT_DELAY_POST_DISPON
        BL      TFT_Delay

        POP     {PC}

        ALIGN
        END