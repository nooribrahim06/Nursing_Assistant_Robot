;=============================================================================
; tft_low.s
; Low-level TFT driver for ILI9341 in 8080 8-bit parallel mode
;
; Responsibilities:
;   - hardware reset
;   - command/data write
;   - 8-bit bus write on PC4..PC11
;   - WR pulse generation
;   - 16-bit RGB565 data write
;   - address window setup
;   - basic display initialization
;
; Notes:
;   - Uses constants from constants.s via GET.
;   - Assumes GPIO clocks / modes are configured elsewhere.
;   - Fine for build/link testing even before full hardware setup exists.
;=============================================================================

        AREA    TFT_LOW, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

        EXPORT  TFT_Init
        EXPORT  TFT_Reset
        EXPORT  TFT_SendCommand
        EXPORT  TFT_SendData
        EXPORT  TFT_WriteData16
        EXPORT  TFT_SetAddressWindow

;-----------------------------------------------------------------------------
; ILI9341 commands used here
;-----------------------------------------------------------------------------
ILI9341_SWRESET     EQU     0x01
ILI9341_SLPOUT      EQU     0x11
ILI9341_GAMSET      EQU     0x26
ILI9341_DISPON      EQU     0x29
ILI9341_CASET       EQU     0x2A
ILI9341_PASET       EQU     0x2B
ILI9341_RAMWR       EQU     0x2C
ILI9341_MADCTL      EQU     0x36
ILI9341_PIXFMT      EQU     0x3A
ILI9341_FRMCTR1     EQU     0xB1
ILI9341_DFUNCTR     EQU     0xB6
ILI9341_PWCTR1      EQU     0xC0
ILI9341_PWCTR2      EQU     0xC1
ILI9341_VMCTR1      EQU     0xC5
ILI9341_VMCTR2      EQU     0xC7

;=============================================================================
; INTERNAL: TFT_PinHighA
; Set one GPIOA control pin high through BSRR.
; Input:
;   R0 = pin number
;=============================================================================
TFT_PinHighA
        PUSH    {R1, R2, LR}

        LDR     R1, =GPIOA_BASE
        MOVS    R2, #1
        LSLS    R2, R2, R0
        STR     R2, [R1, #GPIO_BSRR]

        POP     {R1, R2, PC}

;=============================================================================
; INTERNAL: TFT_PinLowA
; Set one GPIOA control pin low through upper-half BSRR.
; Input:
;   R0 = pin number
;=============================================================================
TFT_PinLowA
        PUSH    {R1, R2, LR}

        LDR     R1, =GPIOA_BASE
        MOVS    R2, #1
        LSLS    R2, R2, R0
        LSLS    R2, R2, #16
        STR     R2, [R1, #GPIO_BSRR]

        POP     {R1, R2, PC}

;=============================================================================
; INTERNAL: TFT_Delay_Short
; Small timing delay around WR pulses.
;=============================================================================
TFT_Delay_Short
        PUSH    {R0, LR}

        MOVS    R0, #40
TFT_Delay_Short_Loop
        SUBS    R0, R0, #1
        BNE     TFT_Delay_Short_Loop

        POP     {R0, PC}

;=============================================================================
; INTERNAL: TFT_Delay_Long
; Longer timing delay used after reset and sleep-out.
;=============================================================================
TFT_Delay_Long
        PUSH    {R0, LR}

        LDR     R0, =120000
TFT_Delay_Long_Loop
        SUBS    R0, R0, #1
        BNE     TFT_Delay_Long_Loop

        POP     {R0, PC}

;=============================================================================
; INTERNAL: TFT_WriteBusByte
; Drive one 8-bit value onto PC4..PC11.
; Input:
;   R0 = byte value
;=============================================================================
TFT_WriteBusByte
        PUSH    {R1, R2, R3, LR}

        LDR     R1, =GPIOC_BASE
        LDR     R2, [R1, #GPIO_ODR]      ; keep non-bus bits unchanged
        LDR     R3, =TFT_DATA_MASK
        BICS    R2, R2, R3               ; clear PC4..PC11
        UXTB    R0, R0
        ORR     R2, R2, R0, LSL #4       ; map D0..D7 -> PC4..PC11
        STR     R2, [R1, #GPIO_ODR]

        POP     {R1, R2, R3, PC}

;=============================================================================
; INTERNAL: TFT_PulseWR
; Generate one write pulse so the TFT latches the bus value.
;=============================================================================
TFT_PulseWR
        PUSH    {LR}

        MOVS    R0, #TFT_WR_PIN
        BL      TFT_PinLowA
        BL      TFT_Delay_Short

        MOVS    R0, #TFT_WR_PIN
        BL      TFT_PinHighA
        BL      TFT_Delay_Short

        POP     {PC}

;=============================================================================
; FUNCTION: TFT_SendCommand
; Input:
;   R0 = command byte
;=============================================================================
TFT_SendCommand
        PUSH    {R1, LR}

        MOV     R1, R0

        MOVS    R0, #TFT_RS_PIN
        BL      TFT_PinLowA              ; RS=0 for command

        MOVS    R0, #TFT_CS_PIN
        BL      TFT_PinLowA              ; select TFT

        MOV     R0, R1
        BL      TFT_WriteBusByte
        BL      TFT_PulseWR

        MOVS    R0, #TFT_CS_PIN
        BL      TFT_PinHighA             ; deselect TFT

        POP     {R1, PC}

;=============================================================================
; FUNCTION: TFT_SendData
; Input:
;   R0 = data byte
;=============================================================================
TFT_SendData
        PUSH    {R1, LR}

        MOV     R1, R0

        MOVS    R0, #TFT_RS_PIN
        BL      TFT_PinHighA             ; RS=1 for data

        MOVS    R0, #TFT_CS_PIN
        BL      TFT_PinLowA              ; select TFT

        MOV     R0, R1
        BL      TFT_WriteBusByte
        BL      TFT_PulseWR

        MOVS    R0, #TFT_CS_PIN
        BL      TFT_PinHighA             ; deselect TFT

        POP     {R1, PC}

;=============================================================================
; FUNCTION: TFT_WriteData16
; Input:
;   R0 = 16-bit RGB565 value
;=============================================================================
TFT_WriteData16
        PUSH    {R4, LR}

        MOV     R4, R0

        LSRS    R0, R4, #8               ; high byte first
        BL      TFT_SendData

        UXTB    R0, R4                   ; low byte second
        BL      TFT_SendData

        POP     {R4, PC}

;=============================================================================
; FUNCTION: TFT_SetAddressWindow
; Input:
;   R0 = x0
;   R1 = y0
;   R2 = x1
;   R3 = y1
;=============================================================================
TFT_SetAddressWindow
        PUSH    {R4, R5, R6, R7, LR}

        MOV     R4, R0
        MOV     R5, R1
        MOV     R6, R2
        MOV     R7, R3

        ; Column address set
        MOVS    R0, #ILI9341_CASET
        BL      TFT_SendCommand

        LSRS    R0, R4, #8
        BL      TFT_SendData
        UXTB    R0, R4
        BL      TFT_SendData

        LSRS    R0, R6, #8
        BL      TFT_SendData
        UXTB    R0, R6
        BL      TFT_SendData

        ; Page address set
        MOVS    R0, #ILI9341_PASET
        BL      TFT_SendCommand

        LSRS    R0, R5, #8
        BL      TFT_SendData
        UXTB    R0, R5
        BL      TFT_SendData

        LSRS    R0, R7, #8
        BL      TFT_SendData
        UXTB    R0, R7
        BL      TFT_SendData

        ; RAM write command
        MOVS    R0, #ILI9341_RAMWR
        BL      TFT_SendCommand

        POP     {R4, R5, R6, R7, PC}

;=============================================================================
; FUNCTION: TFT_Reset
; Hardware reset sequence.
;=============================================================================
TFT_Reset
        PUSH    {LR}

        ; Put idle control lines high
        MOVS    R0, #TFT_CS_PIN
        BL      TFT_PinHighA

        MOVS    R0, #TFT_RD_PIN
        BL      TFT_PinHighA

        MOVS    R0, #TFT_WR_PIN
        BL      TFT_PinHighA

        MOVS    R0, #TFT_RS_PIN
        BL      TFT_PinHighA

        ; Reset pulse
        MOVS    R0, #TFT_RST_PIN
        BL      TFT_PinHighA
        BL      TFT_Delay_Long

        MOVS    R0, #TFT_RST_PIN
        BL      TFT_PinLowA
        BL      TFT_Delay_Long

        MOVS    R0, #TFT_RST_PIN
        BL      TFT_PinHighA
        BL      TFT_Delay_Long

        POP     {PC}

;=============================================================================
; FUNCTION: TFT_Init
; Basic initialization sequence for ILI9341.
;=============================================================================
TFT_Init
        PUSH    {LR}

        BL      TFT_Reset

        ; software reset
        MOVS    R0, #ILI9341_SWRESET
        BL      TFT_SendCommand
        BL      TFT_Delay_Long

        ; exit sleep
        MOVS    R0, #ILI9341_SLPOUT
        BL      TFT_SendCommand
        BL      TFT_Delay_Long

        ; power control 1
        MOVS    R0, #ILI9341_PWCTR1
        BL      TFT_SendCommand
        MOVS    R0, #0x23
        BL      TFT_SendData

        ; power control 2
        MOVS    R0, #ILI9341_PWCTR2
        BL      TFT_SendCommand
        MOVS    R0, #0x10
        BL      TFT_SendData

        ; VCOM control 1
        MOVS    R0, #ILI9341_VMCTR1
        BL      TFT_SendCommand
        MOVS    R0, #0x3E
        BL      TFT_SendData
        MOVS    R0, #0x28
        BL      TFT_SendData

        ; VCOM control 2
        MOVS    R0, #ILI9341_VMCTR2
        BL      TFT_SendCommand
        MOVS    R0, #0x86
        BL      TFT_SendData

        ; memory access control
        MOVS    R0, #ILI9341_MADCTL
        BL      TFT_SendCommand
        MOVS    R0, #0x48
        BL      TFT_SendData

        ; RGB565 pixel format
        MOVS    R0, #ILI9341_PIXFMT
        BL      TFT_SendCommand
        MOVS    R0, #0x55
        BL      TFT_SendData

        ; frame rate
        MOVS    R0, #ILI9341_FRMCTR1
        BL      TFT_SendCommand
        MOVS    R0, #0x00
        BL      TFT_SendData
        MOVS    R0, #0x18
        BL      TFT_SendData

        ; display function control
        MOVS    R0, #ILI9341_DFUNCTR
        BL      TFT_SendCommand
        MOVS    R0, #0x08
        BL      TFT_SendData
        MOVS    R0, #0x82
        BL      TFT_SendData
        MOVS    R0, #0x27
        BL      TFT_SendData

        ; gamma set
        MOVS    R0, #ILI9341_GAMSET
        BL      TFT_SendCommand
        MOVS    R0, #0x01
        BL      TFT_SendData

        ; display on
        MOVS    R0, #ILI9341_DISPON
        BL      TFT_SendCommand
        BL      TFT_Delay_Long

        POP     {PC}

        LTORG
        END