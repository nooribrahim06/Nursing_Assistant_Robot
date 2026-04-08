; =====================================================================
; FILE: tft_low.s
; DESCRIPTION:
;   Low-level TFT driver for ILI9341 using 8080 8-bit parallel interface.
;
;   Control pins  -> GPIOA
;       PA2  = RS
;       PA3  = WR
;       PA4  = RD
;       PA5  = CS
;       PA12 = RST
;
;   Data bus      -> GPIOB  (changed from GPIOC)
;       PB4..PB10 = D0..D6
;       PB12      = D7      (PB11 skipped — unavailable)
; =====================================================================

        AREA    TFT_LOW, CODE, READONLY
        THUMB

        EXPORT  TFT_Init
        EXPORT  TFT_Reset
        EXPORT  TFT_SendCommand
        EXPORT  TFT_SendData
        EXPORT  TFT_WriteData16
        EXPORT  TFT_SetAddressWindow

        IMPORT  GPIO_EnableClock
        IMPORT  GPIO_ConfigOutput

; ========================= GPIO BASE =========================
GPIOA_BASE      EQU     0x40020000
GPIOB_BASE      EQU     0x40020400
GPIOC_BASE      EQU     0x40020800

; ========================= GPIO OFFSETS ======================
GPIO_ODR        EQU     0x14
GPIO_BSRR       EQU     0x18

; ========================= TFT PIN CONSTANTS =================
TFT_RS_PIN      EQU     2
TFT_WR_PIN      EQU     3
TFT_RD_PIN      EQU     4
TFT_CS_PIN      EQU     5
TFT_RST_PIN     EQU     12

; Data bus: PB4..PB10 (D0..D6) + PB12 (D7) — PB11 skipped
;TFT_DATA_MASK   EQU     0x000017F0      ; bits 4-10 + bit 12

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
; TFT_GPIO_Init
; PURPOSE:
;   Configure every TFT pin as push-pull output.
;   MUST be called before TFT_Reset or any bus activity.
;
;   GPIOA (control pins):
;       PA2  = RS
;       PA3  = WR
;       PA4  = RD
;       PA5  = CS
;       PA12 = RST
;
;   GPIOB (data bus):                    <-- was GPIOC
;       PB4..PB10 = D0..D6
;       PB12      = D7  (PB11 skipped)
; =====================================================================
TFT_GPIO_Init FUNCTION
        PUSH    {R4, LR}

        ; --- ????? Clock ?? GPIOA ? GPIOB ---
        LDR     R0, =GPIOA_BASE
        BL      GPIO_EnableClock
        LDR     R0, =GPIOB_BASE
        BL      GPIO_EnableClock

        ; --- ????? ?????? ?????? (Control Pins) ?? GPIOA ---
        LDR     R0, =GPIOA_BASE
        MOV     R1, #TFT_RS_PIN
        BL      GPIO_ConfigOutput
        MOV     R1, #TFT_WR_PIN
        BL      GPIO_ConfigOutput
        MOV     R1, #TFT_RD_PIN
        BL      GPIO_ConfigOutput
        MOV     R1, #TFT_CS_PIN
        BL      GPIO_ConfigOutput
        MOV     R1, #TFT_RST_PIN
        BL      GPIO_ConfigOutput

        ; --- ????? ?????? ???????? (D0-D7) ?? GPIOB ---
        LDR     R0, =GPIOB_BASE
        MOV     R4, #0          ; ???? ?? PB0
ConfigDataLoop
        MOV     R1, R4
        BL      GPIO_ConfigOutput
        ADD     R4, R4, #1
        CMP     R4, #8          ; ??? PB7
        BNE     ConfigDataLoop

        POP     {R4, PC}
        ENDFUNC

; =====================================================================
; TFT_PinHighA / TFT_PinLowA
; =====================================================================
TFT_PinHighA FUNCTION
        PUSH    {R1, R2, LR}
        LDR     R1, =GPIOA_BASE
        MOVS    R2, #1
        LSLS    R2, R2, R0
        STR     R2, [R1, #GPIO_BSRR]
        POP     {R1, R2, LR}
        BX      LR
        ENDFUNC

TFT_PinLowA FUNCTION
        PUSH    {R1, R2, LR}
        LDR     R1, =GPIOA_BASE
        MOVS    R2, #1
        LSLS    R2, R2, R0
        LSLS    R2, R2, #16
        STR     R2, [R1, #GPIO_BSRR]
        POP     {R1, R2, LR}
        BX      LR
        ENDFUNC


; =====================================================================
; TFT_Delay_Short / TFT_Delay_Long
; =====================================================================
TFT_Delay_Short FUNCTION
        PUSH    {R0, LR}
        MOVS    R0, #40
TFT_Delay_Short_Loop
        SUBS    R0, R0, #1
        BNE     TFT_Delay_Short_Loop
        POP     {R0, LR}
        BX      LR
        ENDFUNC

TFT_Delay_Long FUNCTION
        PUSH    {R0, LR}
        LDR     R0, =120000
TFT_Delay_Long_Loop
        SUBS    R0, R0, #1
        BNE     TFT_Delay_Long_Loop
        POP     {R0, LR}
        BX      LR
        ENDFUNC


; =====================================================================
; TFT_WriteBusByte
; Put one byte on PB4..PB10 (D0..D6) and PB12 (D7).
; PB11 is skipped — bits 0-6 shift to GPIO bits 4-10 as before,
; bit 7 of the byte is placed separately at GPIO bit 12.
; INPUT: R0 = byte
; =====================================================================
TFT_WriteBusByte FUNCTION
        PUSH    {R1, R2, R3, LR}
        LDR     R1, =GPIOB_BASE
        
        ; ????? ?????? ??????? ?????
        LDR     R2, [R1, #GPIO_ODR]
        
        ; ??? ??? 8 ?? ??? (0-7) ?????? ??? ???? ???? ????????
        BIC     R2, R2, #0xFF
        
        ; ??? ?????? ?????? (R0) ?? ??? 8 ??
        AND     R3, R0, #0xFF
        ORR     R2, R2, R3
        
        ; ????? ?????? ???????? ?? ?????
        STR     R2, [R1, #GPIO_ODR]
        
        POP     {R1, R2, R3, LR}
        BX      LR
        ENDFUNC

; =====================================================================
; TFT_PulseWR
; =====================================================================
TFT_PulseWR FUNCTION
        PUSH    {R0, LR}             ; ????? ??? R0 ???? ?????? ???? ??????

        ; 1. ???? ?? ????? ??????? ?????? (Start Pulse)
        MOVS    R0, #TFT_WR_PIN
        BL      TFT_PinLowA
        
        ; 2. ????? ???? ??? ??????? ?????? ????? ??? ?????? ????? ??????
        BL      TFT_Delay_Short
        
        ; 3. ???? ??????? (End Pulse / Latch Data)
        MOVS    R0, #TFT_WR_PIN
        BL      TFT_PinHighA
        
        ; 4. ????? ????? ??? ????? ????? ??? ????? ????? ?????? ????? ?????
        BL      TFT_Delay_Short
        
        POP     {R0, PC}             ; ?????? ?????? ???????? PC
        ENDFUNC
; =====================================================================
; TFT_SendCommand
; =====================================================================
TFT_SendCommand FUNCTION
        PUSH    {R1, LR}
        MOV     R1, R0
        MOVS    R0, #TFT_RS_PIN
        BL      TFT_PinLowA
        MOVS    R0, #TFT_CS_PIN
        BL      TFT_PinLowA
        MOV     R0, R1
        BL      TFT_WriteBusByte
        BL      TFT_PulseWR
        MOVS    R0, #TFT_CS_PIN
        BL      TFT_PinHighA
        POP     {R1, LR}
        BX      LR
        ENDFUNC


; =====================================================================
; TFT_SendData
; =====================================================================
TFT_SendData FUNCTION
        PUSH    {R1, LR}
        MOV     R1, R0
        MOVS    R0, #TFT_RS_PIN
        BL      TFT_PinHighA
        MOVS    R0, #TFT_CS_PIN
        BL      TFT_PinLowA
        MOV     R0, R1
        BL      TFT_WriteBusByte
        BL      TFT_PulseWR
        MOVS    R0, #TFT_CS_PIN
        BL      TFT_PinHighA
        POP     {R1, LR}
        BX      LR
        ENDFUNC


; =====================================================================
; TFT_WriteData16
; INPUT: R0 = 16-bit RGB565
; =====================================================================
TFT_WriteData16 FUNCTION
        PUSH    {R4, LR}
        MOV     R4, R0
        LSRS    R0, R4, #8
        BL      TFT_SendData
        AND     R0, R4, #0xFF
        BL      TFT_SendData
        POP     {R4, LR}
        BX      LR
        ENDFUNC


; =====================================================================
; TFT_SetAddressWindow
; INPUT: R0=x0, R1=y0, R2=x1, R3=y1
; =====================================================================
TFT_SetAddressWindow FUNCTION
        PUSH    {R4, R5, R6, R7, LR}
        MOV     R4, R0
        MOV     R5, R1
        MOV     R6, R2
        MOV     R7, R3

        MOVS    R0, #ILI9341_CASET
        BL      TFT_SendCommand
        LSRS    R0, R4, #8
        BL      TFT_SendData
        AND     R0, R4, #0xFF
        BL      TFT_SendData
        LSRS    R0, R6, #8
        BL      TFT_SendData
        AND     R0, R6, #0xFF
        BL      TFT_SendData

        MOVS    R0, #ILI9341_PASET
        BL      TFT_SendCommand
        LSRS    R0, R5, #8
        BL      TFT_SendData
        AND     R0, R5, #0xFF
        BL      TFT_SendData
        LSRS    R0, R7, #8
        BL      TFT_SendData
        AND     R0, R7, #0xFF
        BL      TFT_SendData

        MOVS    R0, #ILI9341_RAMWR
        BL      TFT_SendCommand

        POP     {R4, R5, R6, R7, LR}
        BX      LR
        ENDFUNC


; =====================================================================
; TFT_Reset
; =====================================================================
TFT_Reset FUNCTION
        PUSH    {LR}

        ; Idle all control pins HIGH before toggling RST
        MOVS    R0, #TFT_CS_PIN
        BL      TFT_PinHighA
        MOVS    R0, #TFT_RD_PIN
        BL      TFT_PinHighA
        MOVS    R0, #TFT_WR_PIN
        BL      TFT_PinHighA
        MOVS    R0, #TFT_RS_PIN
        BL      TFT_PinHighA

        MOVS    R0, #TFT_RST_PIN
        BL      TFT_PinHighA
        BL      TFT_Delay_Long

        MOVS    R0, #TFT_RST_PIN
        BL      TFT_PinLowA
        BL      TFT_Delay_Long

        MOVS    R0, #TFT_RST_PIN
        BL      TFT_PinHighA
        BL      TFT_Delay_Long

        POP     {LR}
        BX      LR
        ENDFUNC


; =====================================================================
; TFT_Init
; PURPOSE:
;   Full ILI9341 bring-up.
;   Step 1: configure GPIO pins as outputs
;   Step 2: hardware reset
;   Step 3: ILI9341 register sequence
; =====================================================================
TFT_Init FUNCTION
        PUSH    {LR}

        BL      TFT_GPIO_Init

        BL      TFT_Reset

        MOVS    R0, #ILI9341_SWRESET
        BL      TFT_SendCommand
        BL      TFT_Delay_Long

        MOVS    R0, #ILI9341_SLPOUT
        BL      TFT_SendCommand
        BL      TFT_Delay_Long

        MOVS    R0, #ILI9341_FRMCTR1
        BL      TFT_SendCommand
        MOVS    R0, #0x00
        BL      TFT_SendData
        MOVS    R0, #0x18
        BL      TFT_SendData

        MOVS    R0, #ILI9341_DFUNCTR
        BL      TFT_SendCommand
        MOVS    R0, #0x08
        BL      TFT_SendData
        MOVS    R0, #0x82
        BL      TFT_SendData
        MOVS    R0, #0x27
        BL      TFT_SendData

        MOVS    R0, #ILI9341_PWCTR1
        BL      TFT_SendCommand
        MOVS    R0, #0x23
        BL      TFT_SendData

        MOVS    R0, #ILI9341_PWCTR2
        BL      TFT_SendCommand
        MOVS    R0, #0x10
        BL      TFT_SendData

        MOVS    R0, #ILI9341_VMCTR1
        BL      TFT_SendCommand
        MOVS    R0, #0x3E
        BL      TFT_SendData
        MOVS    R0, #0x28
        BL      TFT_SendData

        MOVS    R0, #ILI9341_VMCTR2
        BL      TFT_SendCommand
        MOVS    R0, #0x86
        BL      TFT_SendData

        MOVS    R0, #ILI9341_GAMSET
        BL      TFT_SendCommand
        MOVS    R0, #0x01
        BL      TFT_SendData

        MOVS    R0, #ILI9341_MADCTL
        BL      TFT_SendCommand
        MOVS    R0, #0x48
        BL      TFT_SendData

        MOVS    R0, #ILI9341_PIXFMT
        BL      TFT_SendCommand
        MOVS    R0, #0x55
        BL      TFT_SendData

        MOVS    R0, #ILI9341_DISPON
        BL      TFT_SendCommand
        BL      TFT_Delay_Long

        POP     {LR}
        BX      LR
        ENDFUNC

        END