; =====================================================================
; FILE: tft_gfx.s
; DESCRIPTION:
;   High-level graphics and UI rendering layer for the TFT.
;
; THIS FILE IS RESPONSIBLE FOR:
;   1) Clear screen
;   2) Draw pixel
;   3) Fill rectangle
;   4) Draw rectangle border
;   5) Draw character
;   6) Draw string
;   7) Implement exact UI render function names required by ui_state.s
;   8) Implement smoke level partial update
;
; IMPORTANT RULE:
;   This file does NOT touch TFT pins directly.
;   It only uses the low-level API from tft_low.s.
; =====================================================================

        AREA    TFT_GFX, CODE, READONLY

        EXPORT  TFT_Clear_Screen
        EXPORT  TFT_Render_Main_Menu
        EXPORT  TFT_Render_Sanitizing
        EXPORT  TFT_Render_Heart_Rate
        EXPORT  TFT_Render_Breathing
        EXPORT  TFT_Render_Med_Input
        EXPORT  TFT_Render_Med_Alert
        EXPORT  TFT_Render_Med_Despense
        EXPORT  TFT_Render_Smoke_ALERT
        EXPORT  TFT_Update_Smoke_Level

        EXPORT  TFT_Draw_Pixel
        EXPORT  TFT_Draw_String
        EXPORT  TFT_Draw_Rect
        EXPORT  TFT_Fill_Rect

        IMPORT  TFT_SetAddressWindow
        IMPORT  TFT_WriteData16

; ========================= TFT SIZE =========================
TFT_WIDTH           EQU     240
TFT_HEIGHT          EQU     320

; ========================= COLORS RGB565 ====================
COLOR_BLACK         EQU     0x0000
COLOR_WHITE         EQU     0xFFFF
COLOR_RED           EQU     0xF800
COLOR_GREEN         EQU     0x07E0
COLOR_BLUE          EQU     0x001F
COLOR_YELLOW        EQU     0xFFE0
COLOR_CYAN          EQU     0x07FF
COLOR_ORANGE        EQU     0xFD20

; ========================= SMOKE BAR LAYOUT =================
SMOKE_BAR_X         EQU     20
SMOKE_BAR_Y         EQU     285
SMOKE_BAR_W         EQU     200
SMOKE_BAR_H         EQU     18

SMOKE_INNER_X       EQU     21
SMOKE_INNER_Y       EQU     286
SMOKE_INNER_W       EQU     198
SMOKE_INNER_H       EQU     16

; =====================================================================
; INTERNAL: TFT_Fill_Window_Color
; PURPOSE:
;   Fill the CURRENTLY selected TFT window with one solid color.
; INPUT:
;   R0 = number of pixels to write
;   R1 = RGB565 color
; =====================================================================
TFT_Fill_Window_Color:
        PUSH    {R4,R5,LR}
        MOV     R4, R0
        MOV     R5, R1
TFT_Fill_Window_Color_Loop:
        CMP     R4, #0
        BEQ     TFT_Fill_Window_Color_Done
        MOV     R0, R5
        BL      TFT_WriteData16
        SUBS    R4, R4, #1
        B       TFT_Fill_Window_Color_Loop
TFT_Fill_Window_Color_Done:
        POP     {R4,R5,LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_Draw_Pixel
; PURPOSE:
;   Draw one pixel.
; INPUT:
;   R0 = x
;   R1 = y
;   R2 = color
; =====================================================================
TFT_Draw_Pixel:
        PUSH    {R4,LR}
        MOV     R4, R2
        MOV     R2, R0
        MOV     R3, R1
        BL      TFT_SetAddressWindow
        MOV     R0, R4
        BL      TFT_WriteData16
        POP     {R4,LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_Fill_Rect
; PURPOSE:
;   Fill a rectangular area with one color.
; INPUT:
;   R0 = x
;   R1 = y
;   R2 = width
;   R3 = height
;   R4 = color
; =====================================================================
TFT_Fill_Rect:
        PUSH    {R5,R6,R7,R8,LR}
        MOV     R5, R0
        MOV     R6, R1
        MOV     R7, R2
        MOV     R8, R3

        CMP     R7, #0
        BEQ     TFT_Fill_Rect_Done
        CMP     R8, #0
        BEQ     TFT_Fill_Rect_Done

        ADD     R2, R5, R7
        SUB     R2, R2, #1
        ADD     R3, R6, R8
        SUB     R3, R3, #1

        MOV     R0, R5
        MOV     R1, R6
        BL      TFT_SetAddressWindow

        MUL     R0, R7, R8
        MOV     R1, R4
        BL      TFT_Fill_Window_Color

TFT_Fill_Rect_Done:
        POP     {R5,R6,R7,R8,LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_Draw_Rect
; PURPOSE:
;   Draw border only for a rectangle.
; INPUT:
;   R0 = x
;   R1 = y
;   R2 = width
;   R3 = height
;   R4 = color
; =====================================================================
TFT_Draw_Rect:
        PUSH    {R5,R6,R7,R8,LR}
        MOV     R5, R0
        MOV     R6, R1
        MOV     R7, R2
        MOV     R8, R3

        ; Top
        MOV     R0, R5
        MOV     R1, R6
        MOV     R2, R7
        MOV     R3, #1
        BL      TFT_Fill_Rect

        ; Bottom
        MOV     R0, R5
        ADD     R1, R6, R8
        SUB     R1, R1, #1
        MOV     R2, R7
        MOV     R3, #1
        BL      TFT_Fill_Rect

        ; Left
        MOV     R0, R5
        MOV     R1, R6
        MOV     R2, #1
        MOV     R3, R8
        BL      TFT_Fill_Rect

        ; Right
        ADD     R0, R5, R7
        SUB     R0, R0, #1
        MOV     R1, R6
        MOV     R2, #1
        MOV     R3, R8
        BL      TFT_Fill_Rect

        POP     {R5,R6,R7,R8,LR}
        BX      LR

; =====================================================================
; INTERNAL: TFT_GetFontPtr
; PURPOSE:
;   Return pointer to the 5-byte bitmap of a supported character.
; INPUT:
;   R0 = ASCII char
; OUTPUT:
;   R0 = pointer to bitmap
; NOTE:
;   If char is unsupported, SPACE bitmap is returned.
; =====================================================================
TFT_GetFontPtr:
        PUSH    {R1,R2,R3,R4,LR}
        LDR     R1, =FONT_CHARSET
        LDR     R2, =FONT_BITMAPS
        MOV     R3, #0
TFT_GetFontPtr_Search:
        LDRB    R4, [R1, R3]
        CMP     R4, #0
        BEQ     TFT_GetFontPtr_NotFound
        CMP     R4, R0
        BEQ     TFT_GetFontPtr_Found
        ADD     R3, R3, #1
        B       TFT_GetFontPtr_Search
TFT_GetFontPtr_Found:
        ADD     R0, R3, R3, LSL #2      ; index * 5
        ADD     R0, R2, R0
        B       TFT_GetFontPtr_Exit
TFT_GetFontPtr_NotFound:
        LDR     R0, =FONT_BITMAPS
TFT_GetFontPtr_Exit:
        POP     {R1,R2,R3,R4,LR}
        BX      LR

; =====================================================================
; INTERNAL: TFT_Draw_Char
; PURPOSE:
;   Draw one 5x7 character plus one blank spacing column.
; INPUT:
;   R0 = x
;   R1 = y
;   R2 = ASCII char
;   R3 = foreground color
;   R4 = background color
; =====================================================================
TFT_Draw_Char:
        PUSH    {R5,R6,R7,R8,R9,R10,R11,R12,LR}

        MOV     R5, R0                  ; base x
        MOV     R6, R1                  ; base y
        MOV     R7, R3                  ; fg color
        MOV     R8, R4                  ; bg color

        MOV     R0, R2
        BL      TFT_GetFontPtr
        MOV     R9, R0                  ; bitmap pointer

        MOV     R10, #0                 ; column = 0..4

TFT_Draw_Char_Column_Loop:
        CMP     R10, #5
        BEQ     TFT_Draw_Char_Spacing

        LDRB    R11, [R9, R10]
        MOV     R12, #0                 ; row = 0..6

TFT_Draw_Char_Row_Loop:
        CMP     R12, #7
        BEQ     TFT_Draw_Char_Next_Column

        MOV     R3, #1
        LSL     R3, R3, R12
        TST     R11, R3
        BEQ     TFT_Draw_Char_DrawBG

        ; foreground pixel
        ADD     R0, R5, R10
        ADD     R1, R6, R12
        MOV     R2, R7
        BL      TFT_Draw_Pixel
        B       TFT_Draw_Char_Row_Advance

TFT_Draw_Char_DrawBG:
        ; background pixel
        ADD     R0, R5, R10
        ADD     R1, R6, R12
        MOV     R2, R8
        BL      TFT_Draw_Pixel

TFT_Draw_Char_Row_Advance:
        ADD     R12, R12, #1
        B       TFT_Draw_Char_Row_Loop

TFT_Draw_Char_Next_Column:
        ADD     R10, R10, #1
        B       TFT_Draw_Char_Column_Loop

TFT_Draw_Char_Spacing:
        MOV     R12, #0
TFT_Draw_Char_Spacing_Loop:
        CMP     R12, #7
        BEQ     TFT_Draw_Char_Done

        ADD     R0, R5, #5
        ADD     R1, R6, R12
        MOV     R2, R8
        BL      TFT_Draw_Pixel

        ADD     R12, R12, #1
        B       TFT_Draw_Char_Spacing_Loop

TFT_Draw_Char_Done:
        POP     {R5,R6,R7,R8,R9,R10,R11,R12,LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_Draw_String
; PURPOSE:
;   Draw a null-terminated string.
; INPUT:
;   R0 = x
;   R1 = y
;   R2 = string address
;   R3 = foreground color
;   R4 = background color
;
; NOTE:
;   R4 is preserved across the whole string so every character receives
;   the correct background color.
; =====================================================================
TFT_Draw_String:
        PUSH    {R4,R5,R6,R7,R8,LR}

        MOV     R5, R0                  ; current x
        MOV     R6, R1                  ; current y
        MOV     R7, R2                  ; string ptr
        MOV     R8, R3                  ; fg color

TFT_Draw_String_Loop:
        LDRB    R2, [R7], #1
        CMP     R2, #0
        BEQ     TFT_Draw_String_Done

        MOV     R0, R5
        MOV     R1, R6
        MOV     R3, R8
        BL      TFT_Draw_Char

        ADD     R5, R5, #6
        B       TFT_Draw_String_Loop

TFT_Draw_String_Done:
        POP     {R4,R5,R6,R7,R8,LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_Clear_Screen
; PURPOSE:
;   Fill whole screen with black.
; =====================================================================
TFT_Clear_Screen:
        PUSH    {R4,LR}
        MOV     R0, #0
        MOV     R1, #0
        MOV     R2, #TFT_WIDTH
        MOV     R3, #TFT_HEIGHT
        LDR     R4, =COLOR_BLACK
        BL      TFT_Fill_Rect
        POP     {R4,LR}
        BX      LR

; =====================================================================
; INTERNAL: TFT_Draw_Smoke_Frame
; PURPOSE:
;   Draw the static smoke label and smoke bar frame.
; =====================================================================
TFT_Draw_Smoke_Frame:
        PUSH    {R4,LR}

        MOV     R0, #20
        MOV     R1, #270
        LDR     R2, =TXT_SMOKE
        LDR     R3, =COLOR_WHITE
        LDR     R4, =COLOR_BLACK
        BL      TFT_Draw_String

        MOV     R0, #SMOKE_BAR_X
        MOV     R1, #SMOKE_BAR_Y
        MOV     R2, #SMOKE_BAR_W
        MOV     R3, #SMOKE_BAR_H
        LDR     R4, =COLOR_WHITE
        BL      TFT_Draw_Rect

        MOV     R0, #SMOKE_INNER_X
        MOV     R1, #SMOKE_INNER_Y
        MOV     R2, #SMOKE_INNER_W
        MOV     R3, #SMOKE_INNER_H
        LDR     R4, =COLOR_BLACK
        BL      TFT_Fill_Rect

        POP     {R4,LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_Update_Smoke_Level
; PURPOSE:
;   Update only the smoke bar content.
; INPUT:
;   R2 = smoke level value
; =====================================================================
TFT_Update_Smoke_Level:
        PUSH    {R4,R5,R6,LR}

        CMP     R2, #0
        BGE     TFT_Update_Smoke_ClampHigh
        MOV     R2, #0

TFT_Update_Smoke_ClampHigh:
        LDR     R4, =4095
        CMP     R2, R4
        MOVGT   R2, R4

        MOV     R4, #198
        MUL     R5, R2, R4
        LDR     R4, =4095
        UDIV    R5, R5, R4

        LDR     R6, =COLOR_GREEN
        CMP     R2, #1200
        BLT     TFT_Update_Smoke_ColorReady

        LDR     R6, =COLOR_YELLOW
        CMP     R2, #2600
        BLT     TFT_Update_Smoke_ColorReady

        LDR     R6, =COLOR_RED

TFT_Update_Smoke_ColorReady:
        MOV     R0, #SMOKE_INNER_X
        MOV     R1, #SMOKE_INNER_Y
        MOV     R2, #SMOKE_INNER_W
        MOV     R3, #SMOKE_INNER_H
        LDR     R4, =COLOR_BLACK
        BL      TFT_Fill_Rect

        CMP     R5, #0
        BEQ     TFT_Update_Smoke_Done

        MOV     R0, #SMOKE_INNER_X
        MOV     R1, #SMOKE_INNER_Y
        MOV     R2, R5
        MOV     R3, #SMOKE_INNER_H
        MOV     R4, R6
        BL      TFT_Fill_Rect

TFT_Update_Smoke_Done:
        POP     {R4,R5,R6,LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_Render_Main_Menu
; PURPOSE:
;   Draw main menu screen.
; =====================================================================
TFT_Render_Main_Menu:
        PUSH    {R4,LR}

        MOV     R0, #0
        MOV     R1, #0
        MOV     R2, #TFT_WIDTH
        MOV     R3, #32
        LDR     R4, =COLOR_BLUE
        BL      TFT_Fill_Rect

        MOV     R0, #72
        MOV     R1, #12
        LDR     R2, =TXT_MAIN_MENU
        LDR     R3, =COLOR_WHITE
        LDR     R4, =COLOR_BLUE
        BL      TFT_Draw_String

        MOV     R0, #20
        MOV     R1, #50
        MOV     R2, #200
        MOV     R3, #40
        LDR     R4, =COLOR_CYAN
        BL      TFT_Draw_Rect

        MOV     R0, #50
        MOV     R1, #64
        LDR     R2, =TXT_SANITIZING
        LDR     R3, =COLOR_WHITE
        LDR     R4, =COLOR_BLACK
        BL      TFT_Draw_String

        MOV     R0, #20
        MOV     R1, #100
        MOV     R2, #200
        MOV     R3, #40
        LDR     R4, =COLOR_RED
        BL      TFT_Draw_Rect

        MOV     R0, #55
        MOV     R1, #114
        LDR     R2, =TXT_HEART_RATE
        LDR     R3, =COLOR_WHITE
        LDR     R4, =COLOR_BLACK
        BL      TFT_Draw_String

        MOV     R0, #20
        MOV     R1, #150
        MOV     R2, #200
        MOV     R3, #40
        LDR     R4, =COLOR_GREEN
        BL      TFT_Draw_Rect

        MOV     R0, #58
        MOV     R1, #164
        LDR     R2, =TXT_BREATHING
        LDR     R3, =COLOR_WHITE
        LDR     R4, =COLOR_BLACK
        BL      TFT_Draw_String

        MOV     R0, #20
        MOV     R1, #200
        MOV     R2, #200
        MOV     R3, #40
        LDR     R4, =COLOR_YELLOW
        BL      TFT_Draw_Rect

        MOV     R0, #62
        MOV     R1, #214
        LDR     R2, =TXT_MED_INPUT
        LDR     R3, =COLOR_WHITE
        LDR     R4, =COLOR_BLACK
        BL      TFT_Draw_String

        BL      TFT_Draw_Smoke_Frame

        POP     {R4,LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_Render_Sanitizing
; PURPOSE:
;   Draw sanitizing screen.
; =====================================================================
TFT_Render_Sanitizing:
        PUSH    {R4,LR}
        MOV     R0, #0
        MOV     R1, #0
        MOV     R2, #TFT_WIDTH
        MOV     R3, #50
        LDR     R4, =COLOR_CYAN
        BL      TFT_Fill_Rect

        MOV     R0, #52
        MOV     R1, #20
        LDR     R2, =TXT_SANITIZING
        LDR     R3, =COLOR_BLACK
        LDR     R4, =COLOR_CYAN
        BL      TFT_Draw_String

        MOV     R0, #40
        MOV     R1, #120
        MOV     R2, #160
        MOV     R3, #80
        LDR     R4, =COLOR_CYAN
        BL      TFT_Draw_Rect

        MOV     R0, #70
        MOV     R1, #155
        LDR     R2, =TXT_ACTIVE
        LDR     R3, =COLOR_WHITE
        LDR     R4, =COLOR_BLACK
        BL      TFT_Draw_String

        POP     {R4,LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_Render_Heart_Rate
; PURPOSE:
;   Draw heart-rate screen.
; =====================================================================
TFT_Render_Heart_Rate:
        PUSH    {R4,LR}
        MOV     R0, #0
        MOV     R1, #0
        MOV     R2, #TFT_WIDTH
        MOV     R3, #50
        LDR     R4, =COLOR_RED
        BL      TFT_Fill_Rect

        MOV     R0, #48
        MOV     R1, #20
        LDR     R2, =TXT_HEART_RATE
        LDR     R3, =COLOR_WHITE
        LDR     R4, =COLOR_RED
        BL      TFT_Draw_String

        MOV     R0, #35
        MOV     R1, #110
        MOV     R2, #170
        MOV     R3, #100
        LDR     R4, =COLOR_RED
        BL      TFT_Draw_Rect

        MOV     R0, #82
        MOV     R1, #150
        LDR     R2, =TXT_BPM
        LDR     R3, =COLOR_WHITE
        LDR     R4, =COLOR_BLACK
        BL      TFT_Draw_String

        POP     {R4,LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_Render_Breathing
; PURPOSE:
;   Draw breathing screen.
; =====================================================================
TFT_Render_Breathing:
        PUSH    {R4,LR}
        MOV     R0, #0
        MOV     R1, #0
        MOV     R2, #TFT_WIDTH
        MOV     R3, #50
        LDR     R4, =COLOR_GREEN
        BL      TFT_Fill_Rect

        MOV     R0, #56
        MOV     R1, #20
        LDR     R2, =TXT_BREATHING
        LDR     R3, =COLOR_BLACK
        LDR     R4, =COLOR_GREEN
        BL      TFT_Draw_String

        MOV     R0, #20
        MOV     R1, #110
        MOV     R2, #200
        MOV     R3, #80
        LDR     R4, =COLOR_GREEN
        BL      TFT_Draw_Rect

        MOV     R0, #70
        MOV     R1, #145
        LDR     R2, =TXT_MONITOR
        LDR     R3, =COLOR_WHITE
        LDR     R4, =COLOR_BLACK
        BL      TFT_Draw_String

        POP     {R4,LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_Render_Med_Input
; PURPOSE:
;   Draw medicine input screen.
; =====================================================================
TFT_Render_Med_Input:
        PUSH    {R4,LR}
        MOV     R0, #0
        MOV     R1, #0
        MOV     R2, #TFT_WIDTH
        MOV     R3, #50
        LDR     R4, =COLOR_YELLOW
        BL      TFT_Fill_Rect

        MOV     R0, #56
        MOV     R1, #20
        LDR     R2, =TXT_MED_INPUT
        LDR     R3, =COLOR_BLACK
        LDR     R4, =COLOR_YELLOW
        BL      TFT_Draw_String

        MOV     R0, #25
        MOV     R1, #100
        MOV     R2, #190
        MOV     R3, #110
        LDR     R4, =COLOR_YELLOW
        BL      TFT_Draw_Rect

        MOV     R0, #45
        MOV     R1, #145
        LDR     R2, =TXT_ENTER_TIME
        LDR     R3, =COLOR_WHITE
        LDR     R4, =COLOR_BLACK
        BL      TFT_Draw_String

        POP     {R4,LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_Render_Med_Alert
; PURPOSE:
;   Draw medicine alert screen.
; =====================================================================
TFT_Render_Med_Alert:
        PUSH    {R4,LR}
        MOV     R0, #20
        MOV     R1, #60
        MOV     R2, #200
        MOV     R3, #160
        LDR     R4, =COLOR_RED
        BL      TFT_Draw_Rect

        MOV     R0, #72
        MOV     R1, #105
        LDR     R2, =TXT_MED_ALERT
        LDR     R3, =COLOR_RED
        LDR     R4, =COLOR_BLACK
        BL      TFT_Draw_String

        MOV     R0, #52
        MOV     R1, #140
        LDR     R2, =TXT_TIME_NOW
        LDR     R3, =COLOR_WHITE
        LDR     R4, =COLOR_BLACK
        BL      TFT_Draw_String

        POP     {R4,LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_Render_Med_Despense
; PURPOSE:
;   Draw medicine dispense screen.
; NOTE:
;   Name kept EXACTLY as required by ui_state.s
; =====================================================================
TFT_Render_Med_Despense:
        PUSH    {R4,LR}
        MOV     R0, #0
        MOV     R1, #0
        MOV     R2, #TFT_WIDTH
        MOV     R3, #50
        LDR     R4, =COLOR_ORANGE
        BL      TFT_Fill_Rect

        MOV     R0, #42
        MOV     R1, #20
        LDR     R2, =TXT_MED_DESPENSE
        LDR     R3, =COLOR_BLACK
        LDR     R4, =COLOR_ORANGE
        BL      TFT_Draw_String

        MOV     R0, #40
        MOV     R1, #110
        MOV     R2, #160
        MOV     R3, #90
        LDR     R4, =COLOR_ORANGE
        BL      TFT_Draw_Rect

        MOV     R0, #68
        MOV     R1, #150
        LDR     R2, =TXT_DISPENSE
        LDR     R3, =COLOR_WHITE
        LDR     R4, =COLOR_BLACK
        BL      TFT_Draw_String

        POP     {R4,LR}
        BX      LR

; =====================================================================
; FUNCTION: TFT_Render_Smoke_ALERT
; PURPOSE:
;   Draw smoke alert screen.
; =====================================================================
TFT_Render_Smoke_ALERT:
        PUSH    {R4,LR}
        MOV     R0, #0
        MOV     R1, #0
        MOV     R2, #TFT_WIDTH
        MOV     R3, #50
        LDR     R4, =COLOR_RED
        BL      TFT_Fill_Rect

        MOV     R0, #48
        MOV     R1, #20
        LDR     R2, =TXT_SMOKE_ALERT
        LDR     R3, =COLOR_WHITE
        LDR     R4, =COLOR_RED
        BL      TFT_Draw_String

        MOV     R0, #20
        MOV     R1, #90
        MOV     R2, #200
        MOV     R3, #110
        LDR     R4, =COLOR_RED
        BL      TFT_Draw_Rect

        MOV     R0, #78
        MOV     R1, #135
        LDR     R2, =TXT_DANGER
        LDR     R3, =COLOR_RED
        LDR     R4, =COLOR_BLACK
        BL      TFT_Draw_String

        BL      TFT_Draw_Smoke_Frame

        POP     {R4,LR}
        BX      LR

; =====================================================================
; SUPPORTED FONT CHARACTERS
; Only the characters actually needed by the UI text are included.
; =====================================================================
FONT_CHARSET
        DCB     ' '
        DCB     '-'
        DCB     ':'
        DCB     '0'
        DCB     '1'
        DCB     '2'
        DCB     '3'
        DCB     '4'
        DCB     '5'
        DCB     '6'
        DCB     '7'
        DCB     '8'
        DCB     '9'
        DCB     'A'
        DCB     'B'
        DCB     'C'
        DCB     'D'
        DCB     'E'
        DCB     'F'
        DCB     'G'
        DCB     'H'
        DCB     'I'
        DCB     'J'
        DCB     'K'
        DCB     'L'
        DCB     'M'
        DCB     'N'
        DCB     'O'
        DCB     'P'
        DCB     'Q'
        DCB     'R'
        DCB     'S'
        DCB     'T'
        DCB     'U'
        DCB     'V'
        DCB     'W'
        DCB     'X'
        DCB     'Y'
        DCB     'Z'
        DCB     0

; =====================================================================
; 5x7 FONT BITMAPS
; One entry = 5 bytes, same order as FONT_CHARSET.
; =====================================================================
FONT_BITMAPS
        ; ' '
        DCB 0x00,0x00,0x00,0x00,0x00
        ; '-'
        DCB 0x08,0x08,0x08,0x08,0x08
        ; ':'
        DCB 0x00,0x36,0x36,0x00,0x00

        ; '0'..'9'
        DCB 0x3E,0x51,0x49,0x45,0x3E
        DCB 0x00,0x42,0x7F,0x40,0x00
        DCB 0x42,0x61,0x51,0x49,0x46
        DCB 0x21,0x41,0x45,0x4B,0x31
        DCB 0x18,0x14,0x12,0x7F,0x10
        DCB 0x27,0x45,0x45,0x45,0x39
        DCB 0x3C,0x4A,0x49,0x49,0x30
        DCB 0x01,0x71,0x09,0x05,0x03
        DCB 0x36,0x49,0x49,0x49,0x36
        DCB 0x06,0x49,0x49,0x29,0x1E

        ; 'A'..'Z'
        DCB 0x7E,0x11,0x11,0x11,0x7E
        DCB 0x7F,0x49,0x49,0x49,0x36
        DCB 0x3E,0x41,0x41,0x41,0x22
        DCB 0x7F,0x41,0x41,0x22,0x1C
        DCB 0x7F,0x49,0x49,0x49,0x41
        DCB 0x7F,0x09,0x09,0x09,0x01
        DCB 0x3E,0x41,0x49,0x49,0x7A
        DCB 0x7F,0x08,0x08,0x08,0x7F
        DCB 0x00,0x41,0x7F,0x41,0x00
        DCB 0x20,0x40,0x41,0x3F,0x01
        DCB 0x7F,0x08,0x14,0x22,0x41
        DCB 0x7F,0x40,0x40,0x40,0x40
        DCB 0x7F,0x02,0x0C,0x02,0x7F
        DCB 0x7F,0x04,0x08,0x10,0x7F
        DCB 0x3E,0x41,0x41,0x41,0x3E
        DCB 0x7F,0x09,0x09,0x09,0x06
        DCB 0x3E,0x41,0x51,0x21,0x5E
        DCB 0x7F,0x09,0x19,0x29,0x46
        DCB 0x46,0x49,0x49,0x49,0x31
        DCB 0x01,0x01,0x7F,0x01,0x01
        DCB 0x3F,0x40,0x40,0x40,0x3F
        DCB 0x1F,0x20,0x40,0x20,0x1F
        DCB 0x3F,0x40,0x38,0x40,0x3F
        DCB 0x63,0x14,0x08,0x14,0x63
        DCB 0x07,0x08,0x70,0x08,0x07
        DCB 0x61,0x51,0x49,0x45,0x43

; =====================================================================
; UI TEXT STRINGS
; All uppercase because the compact font table supports uppercase only.
; =====================================================================
TXT_MAIN_MENU       DCB "MAIN MENU",0
TXT_SANITIZING      DCB "SANITIZING",0
TXT_HEART_RATE      DCB "HEART RATE",0
TXT_BREATHING       DCB "BREATHING",0
TXT_MED_INPUT       DCB "MED INPUT",0
TXT_MED_ALERT       DCB "MED ALERT",0
TXT_MED_DESPENSE    DCB "MED DESPENSE",0
TXT_SMOKE_ALERT     DCB "SMOKE ALERT",0
TXT_SMOKE           DCB "SMOKE",0
TXT_ACTIVE          DCB "ACTIVE",0
TXT_BPM             DCB "BPM",0
TXT_MONITOR         DCB "MONITOR",0
TXT_ENTER_TIME      DCB "ENTER TIME",0
TXT_TIME_NOW        DCB "TIME NOW",0
TXT_DISPENSE        DCB "DISPENSE",0
TXT_DANGER          DCB "DANGER",0

        END