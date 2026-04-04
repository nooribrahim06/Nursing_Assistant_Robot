; =====================================================================
; FILE: tft_low.s
; DESCRIPTION:
;   Low-level TFT driver for ILI9341 using 8080 8-bit parallel interface.
;
; RESPONSIBILITIES:
;   - Hardware reset
;   - Command write
;   - Data write
;   - 8-bit bus write on PC4..PC11
;   - WR pulse generation
;   - 16-bit RGB565 data write
;   - Address window setup
;   - Stronger ILI9341 init sequence
;
; ASSUMPTION:
;   GPIO pins were already configured as outputs elsewhere.
; =====================================================================

        AREA    TFT_LOW, CODE, READONLY

        EXPORT  TFT_Init
        EXPORT  TFT_Reset
        EXPORT  TFT_SendCommand
        EXPORT  TFT_SendData
        EXPORT  TFT_WriteData16
        EXPORT  TFT_SetAddressWindow

; ========================= GPIO BASE =========================
GPIOA_BASE      EQU     0x40020000
GPIOC_BASE      EQU     0x40020800

; ========================= GPIO OFFSETS ======================
GPIO_ODR        EQU     0x14
GPIO_BSRR       EQU     0x18

; ========================= TFT CONSTANTS =====================
TFT_DATA_MASK   EQU     0x00000FF0

TFT_RS_PIN      EQU     2
TFT_WR_PIN      EQU     3
TFT_RD_PIN      EQU     4
TFT_CS_PIN      EQU     5
TFT_RST_PIN     EQU     12

; ========================= ILI9341 COMMANDS ==================
ILI9341_SWRESET EQU     0x01
ILI9341_SLPOUT  EQU     0x11
ILI9341_GAMSET  EQU     0x26
ILI9341_DISPON  EQU     0x29
ILI9341_CASET   EQU     0x2A
ILI9341_PASET   EQU     0x2B
ILI9341_RAMWR   EQU     0x2C
ILI9341_MADCTL  EQU     0x36
ILI9341_PIXFMT  EQU     0x3A
ILI9341_FRMCTR1 EQU     0xB1
ILI9341_DFUNCTR EQU     0xB6
ILI9341_PWCTR1  EQU     0xC0
ILI9341_PWCTR2  EQU     0xC1
ILI9341_VMCTR1  EQU     0xC5
ILI9341_VMCTR2  EQU     0xC7

; =====================================================================
; INTERNAL: TFT_PinHighA
; PURPOSE:
;   Set one control pin on port A HIGH using BSRR.
; INPUT:
;   R0 = pin number
; =====================================================================
TFT_PinHighA:
        PUSH    {R1,R2,LR}
        LDR     R1, =GPIOA_BASE
        MOV     R2, #1
        LSL     R2, R2, R0
        STR     R2, [R1, #GPIO_BSRR]
        POP     {R1,R2,LR}
        BX      LR

; =====================================================================
; INTERNAL: TFT_PinLowA
; PURPOSE:
;   Set one control pin on port A LOW using BSRR.
; INPUT:
;   R0 = pin number
; =====================================================================
TFT_PinLowA:
        PUSH    {R1,R2,LR}
        LDR     R1, =GPIOA_BASE
        MOV     R2, #1
        LSL     R2, R2, R0
        LSL     R2, R2, #16
        STR     R2, [R1, #GPIO_BSRR]
        POP     {R1,R2,LR}
        BX      LR

; =====================================================================
; INTERNAL: TFT_Delay_Short
; PURPOSE:
;   Small timing gap used around WR pulse.
; =====================================================================
TFT_Delay_Short:
        PUSH    {R0,LR}
        MOV     R0, #40
TFT_Delay_Short_Loop:
        SUBS    R0, R0, #1
        BNE     TFT_Delay_Short_Loop
        POP     {R0,LR}
        BX      LR

; =====================================================================
; INTERNAL: TFT_Delay_Long
; PURPOSE:
;   Longer delay used after reset and sleep-out.
; =====================================================================
TFT_Delay_Long:
        PUSH    {R0,LR}
        LDR     R0, =120000
TFT_Delay_Long_Loop:
        SUBS    R0, R0, #1
        BNE     TFT_Delay_Long_Loop
        POP     {R0,LR}
        BX      LR

; =====================================================================
; INTERNAL: TFT_WriteBusByte
; PURPOSE:
;   Put one 8-bit value on PC4..PC11.
; INPUT:
;   R0 = byte to output
; =====================================================================
TFT_WriteBusByte:
        PUSH    {R1,R2,R3,LR}
        LDR     R1, =GPIOC_BASE
        LDR     R2, [R1, #GPIO_ODR]
        LDR     R3, =TFT_DATA_MASK
        BIC     R2, R2, R3
        AND     R0, R0, #0xFF
        ORR     R2, R2, R0, LSL #4
        STR     R2, [R1, #GPIO_ODR]
        POP     {R1,R2,R3,LR}
        BX      LR

; =====================================================================
; INTERNAL: TFT_PulseWR
; PURPOSE:
;   Generate one WR pulse so the TFT latches the byte.
; =====================================================================
TFT_PulseWR:
        PUSH    {LR}
        MOV     R0, #TFT_WR_PIN
        BL      TFT_PinLowA
        BL      TFT_Delay_Short
        MOV     R0, #TFT_WR_PIN
        BL      TFT_PinHighA
        BL      TFT_Delay_Short
        POP     {LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_SendCommand
; PURPOSE:
;   Send one command byte.
; INPUT:
;   R0 = command byte
; =====================================================================
TFT_SendCommand:
        PUSH    {R1,LR}
        MOV     R1, R0
        MOV     R0, #TFT_RS_PIN
        BL      TFT_PinLowA
        MOV     R0, #TFT_CS_PIN
        BL      TFT_PinLowA
        MOV     R0, R1
        BL      TFT_WriteBusByte
        BL      TFT_PulseWR
        MOV     R0, #TFT_CS_PIN
        BL      TFT_PinHighA
        POP     {R1,LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_SendData
; PURPOSE:
;   Send one data byte.
; INPUT:
;   R0 = data byte
; =====================================================================
TFT_SendData:
        PUSH    {R1,LR}
        MOV     R1, R0
        MOV     R0, #TFT_RS_PIN
        BL      TFT_PinHighA
        MOV     R0, #TFT_CS_PIN
        BL      TFT_PinLowA
        MOV     R0, R1
        BL      TFT_WriteBusByte
        BL      TFT_PulseWR
        MOV     R0, #TFT_CS_PIN
        BL      TFT_PinHighA
        POP     {R1,LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_WriteData16
; PURPOSE:
;   Send one 16-bit RGB565 value as two bytes.
; INPUT:
;   R0 = 16-bit value
; =====================================================================
TFT_WriteData16:
        PUSH    {R4,LR}
        MOV     R4, R0
        MOV     R0, R4, LSR #8
        BL      TFT_SendData
        AND     R0, R4, #0xFF
        BL      TFT_SendData
        POP     {R4,LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_SetAddressWindow
; PURPOSE:
;   Define the rectangular region where upcoming pixel data will go.
; INPUT:
;   R0 = x0
;   R1 = y0
;   R2 = x1
;   R3 = y1
; =====================================================================
TFT_SetAddressWindow:
        PUSH    {R4,R5,R6,R7,LR}
        MOV     R4, R0
        MOV     R5, R1
        MOV     R6, R2
        MOV     R7, R3

        MOV     R0, #ILI9341_CASET
        BL      TFT_SendCommand
        MOV     R0, R4, LSR #8
        BL      TFT_SendData
        AND     R0, R4, #0xFF
        BL      TFT_SendData
        MOV     R0, R6, LSR #8
        BL      TFT_SendData
        AND     R0, R6, #0xFF
        BL      TFT_SendData

        MOV     R0, #ILI9341_PASET
        BL      TFT_SendCommand
        MOV     R0, R5, LSR #8
        BL      TFT_SendData
        AND     R0, R5, #0xFF
        BL      TFT_SendData
        MOV     R0, R7, LSR #8
        BL      TFT_SendData
        AND     R0, R7, #0xFF
        BL      TFT_SendData

        MOV     R0, #ILI9341_RAMWR
        BL      TFT_SendCommand

        POP     {R4,R5,R6,R7,LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_Reset
; PURPOSE:
;   Hardware reset using RST pin.
; =====================================================================
TFT_Reset:
        PUSH    {LR}

        MOV     R0, #TFT_CS_PIN
        BL      TFT_PinHighA
        MOV     R0, #TFT_RD_PIN
        BL      TFT_PinHighA
        MOV     R0, #TFT_WR_PIN
        BL      TFT_PinHighA
        MOV     R0, #TFT_RS_PIN
        BL      TFT_PinHighA

        MOV     R0, #TFT_RST_PIN
        BL      TFT_PinHighA
        BL      TFT_Delay_Long

        MOV     R0, #TFT_RST_PIN
        BL      TFT_PinLowA
        BL      TFT_Delay_Long

        MOV     R0, #TFT_RST_PIN
        BL      TFT_PinHighA
        BL      TFT_Delay_Long

        POP     {LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_Init
; PURPOSE:
;   Stronger ILI9341 init sequence than the minimal one.
;   Still clean and not bloated.
; =====================================================================
TFT_Init:
        PUSH    {LR}

        BL      TFT_Reset

        MOV     R0, #ILI9341_SWRESET
        BL      TFT_SendCommand
        BL      TFT_Delay_Long

        MOV     R0, #ILI9341_SLPOUT
        BL      TFT_SendCommand
        BL      TFT_Delay_Long

        ; Frame rate control
        MOV     R0, #ILI9341_FRMCTR1
        BL      TFT_SendCommand
        MOV     R0, #0x00
        BL      TFT_SendData
        MOV     R0, #0x18
        BL      TFT_SendData

        ; Display function control
        MOV     R0, #ILI9341_DFUNCTR
        BL      TFT_SendCommand
        MOV     R0, #0x08
        BL      TFT_SendData
        MOV     R0, #0x82
        BL      TFT_SendData
        MOV     R0, #0x27
        BL      TFT_SendData

        ; Power control
        MOV     R0, #ILI9341_PWCTR1
        BL      TFT_SendCommand
        MOV     R0, #0x23
        BL      TFT_SendData

        MOV     R0, #ILI9341_PWCTR2
        BL      TFT_SendCommand
        MOV     R0, #0x10
        BL      TFT_SendData

        ; VCOM control
        MOV     R0, #ILI9341_VMCTR1
        BL      TFT_SendCommand
        MOV     R0, #0x3E
        BL      TFT_SendData
        MOV     R0, #0x28
        BL      TFT_SendData

        MOV     R0, #ILI9341_VMCTR2
        BL      TFT_SendCommand
        MOV     R0, #0x86
        BL      TFT_SendData

        ; Gamma curve
        MOV     R0, #ILI9341_GAMSET
        BL      TFT_SendCommand
        MOV     R0, #0x01
        BL      TFT_SendData

        ; Portrait orientation
        MOV     R0, #ILI9341_MADCTL
        BL      TFT_SendCommand
        MOV     R0, #0x48
        BL      TFT_SendData

        ; 16-bit RGB565
        MOV     R0, #ILI9341_PIXFMT
        BL      TFT_SendCommand
        MOV     R0, #0x55
        BL      TFT_SendData

        MOV     R0, #ILI9341_DISPON
        BL      TFT_SendCommand
        BL      TFT_Delay_Long

        POP     {LR}
        BX      LR

        END