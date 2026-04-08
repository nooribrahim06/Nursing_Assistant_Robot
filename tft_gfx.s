;=============================================================================
; tft_gfx.s
; High-level TFT rendering layer
;
; Purpose:
;   - Implements the UI render functions called from ui_state.s
;   - Uses tft_low.s for low-level pixel / window writes
;   - Keeps older teammate naming alive through aliases where needed
;
; Notes:
;   - This version is compatibility-focused.
;   - Text drawing is stubbed for now so the project can build cleanly.
;   - The visible layout is simple but enough for flow testing.
;=============================================================================

        AREA    TFT_GFX, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

;-----------------------------------------------------------------------------
; Exports required by current ui_state.s
;-----------------------------------------------------------------------------
        EXPORT  TFT_Clear_Screen
        EXPORT  TFT_Render_Main_Menu
        EXPORT  TFT_Render_Sanitizing
        EXPORT  TFT_Render_Heart_Rate
        EXPORT  TFT_Render_Breathing
        EXPORT  TFT_Render_Motion
        EXPORT  TFT_Render_Med_Input
        EXPORT  TFT_Render_Med_Waiting
        EXPORT  TFT_Render_Med_Alert
        EXPORT  TFT_Render_Med_Dispense
        EXPORT  TFT_Render_Smoke_Alert
        EXPORT  TFT_Update_Smoke_Level

;-----------------------------------------------------------------------------
; Backward-compatible aliases for older teammate spellings
;-----------------------------------------------------------------------------
        EXPORT  TFT_Render_Med_Despense
        EXPORT  TFT_Render_Smoke_ALERT

;-----------------------------------------------------------------------------
; Helper exports
;-----------------------------------------------------------------------------
        EXPORT  TFT_Draw_Pixel
        EXPORT  TFT_Draw_Rect
        EXPORT  TFT_Fill_Rect
        EXPORT  TFT_Draw_String

;-----------------------------------------------------------------------------
; Imports from low-level TFT driver
;-----------------------------------------------------------------------------
        IMPORT  TFT_SetAddressWindow
        IMPORT  TFT_WriteData16

;=============================================================================
; Local constants
;=============================================================================
TFT_WIDTH           EQU     240
TFT_HEIGHT          EQU     320

HEADER_H            EQU     50
BOX_X               EQU     20
BOX_W               EQU     200
BOX_H               EQU     32

SMOKE_OUTER_X       EQU     20
SMOKE_OUTER_Y       EQU     285
SMOKE_OUTER_W       EQU     200
SMOKE_OUTER_H       EQU     18

SMOKE_INNER_X       EQU     21
SMOKE_INNER_Y       EQU     286
SMOKE_INNER_W       EQU     198
SMOKE_INNER_H       EQU     16

COLOR_BLACK         EQU     0x0000
COLOR_WHITE         EQU     0xFFFF
COLOR_RED           EQU     0xF800
COLOR_GREEN         EQU     0x07E0
COLOR_BLUE          EQU     0x001F
COLOR_YELLOW        EQU     0xFFE0
COLOR_CYAN          EQU     0x07FF
COLOR_ORANGE        EQU     0xFD20
COLOR_MAGENTA       EQU     0xF81F

;=============================================================================
; INTERNAL: TFT_Fill_Window_Color
; Fill the currently selected window with one repeated color.
; Input:
;   R0 = number of pixels
;   R1 = RGB565 color
;=============================================================================
TFT_Fill_Window_Color
        PUSH    {R4, R5, LR}

        MOV     R4, R0                  ; pixel count
        MOV     R5, R1                  ; fill color

Fill_Window_Loop
        CMP     R4, #0
        BEQ     Fill_Window_Done

        MOV     R0, R5
        BL      TFT_WriteData16

        SUBS    R4, R4, #1
        B       Fill_Window_Loop

Fill_Window_Done
        POP     {R4, R5, PC}

;=============================================================================
; FUNCTION: TFT_Draw_Pixel
; Input:
;   R0 = x
;   R1 = y
;   R2 = color
;=============================================================================
TFT_Draw_Pixel
        PUSH    {R4, LR}

        MOV     R4, R2                  ; preserve color
        MOV     R2, R0                  ; x1 = x0
        MOV     R3, R1                  ; y1 = y0
        BL      TFT_SetAddressWindow

        MOV     R0, R4
        BL      TFT_WriteData16

        POP     {R4, PC}

;=============================================================================
; FUNCTION: TFT_Fill_Rect
; Input:
;   R0 = x
;   R1 = y
;   R2 = width
;   R3 = height
;   R4 = color
;=============================================================================
TFT_Fill_Rect
        PUSH    {R5, R6, R7, R8, LR}

        MOV     R5, R0                  ; x
        MOV     R6, R1                  ; y
        MOV     R7, R2                  ; w
        MOV     R8, R3                  ; h

        CMP     R7, #0
        BEQ     TFT_Fill_Rect_Done
        CMP     R8, #0
        BEQ     TFT_Fill_Rect_Done

        ADD     R2, R5, R7              ; x1 = x + w - 1
        SUBS    R2, R2, #1

        ADD     R3, R6, R8              ; y1 = y + h - 1
        SUBS    R3, R3, #1

        MOV     R0, R5
        MOV     R1, R6
        BL      TFT_SetAddressWindow

        MUL    R0, R7, R8              ; total pixels
        MOV     R1, R4
        BL      TFT_Fill_Window_Color

TFT_Fill_Rect_Done
        POP     {R5, R6, R7, R8, PC}

;=============================================================================
; FUNCTION: TFT_Draw_Rect
; Draw a rectangle border.
; Input:
;   R0 = x
;   R1 = y
;   R2 = width
;   R3 = height
;   R4 = color
;=============================================================================
TFT_Draw_Rect
        PUSH    {R5, R6, R7, R8, LR}

        MOV     R5, R0
        MOV     R6, R1
        MOV     R7, R2
        MOV     R8, R3

        ; top line
        MOV     R0, R5
        MOV     R1, R6
        MOV     R2, R7
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        ; bottom line
        MOV     R0, R5
        ADD     R1, R6, R8
        SUBS    R1, R1, #1
        MOV     R2, R7
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        ; left line
        MOV     R0, R5
        MOV     R1, R6
        MOVS    R2, #1
        MOV     R3, R8
        BL      TFT_Fill_Rect

        ; right line
        ADD     R0, R5, R7
        SUBS    R0, R0, #1
        MOV     R1, R6
        MOVS    R2, #1
        MOV     R3, R8
        BL      TFT_Fill_Rect

        POP     {R5, R6, R7, R8, PC}

;=============================================================================
; FUNCTION: TFT_Draw_String
; Temporary stub so UI and graphics link cleanly even before text engine is done.
;=============================================================================
TFT_Draw_String
        BX      LR

;=============================================================================
; INTERNAL: TFT_Draw_Header
; Draws a colored top header band.
; Input:
;   R4 = header color
;=============================================================================
TFT_Draw_Header
        PUSH    {LR}

        MOVS    R0, #0
        MOVS    R1, #0
        LDR     R2, =TFT_WIDTH
        MOVS    R3, #HEADER_H
        BL      TFT_Fill_Rect

        POP     {PC}

;=============================================================================
; INTERNAL: TFT_Draw_Main_Menu_Boxes
; Draw the menu panel boxes for visible structure.
;=============================================================================
TFT_Draw_Main_Menu_Boxes
        PUSH    {R4, LR}

        LDR     R4, =COLOR_WHITE

        MOVS    R0, #BOX_X
        MOVS    R1, #70
        MOVS    R2, #BOX_W
        MOVS    R3, #BOX_H
        BL      TFT_Draw_Rect

        MOVS    R0, #BOX_X
        MOVS    R1, #110
        MOVS    R2, #BOX_W
        MOVS    R3, #BOX_H
        BL      TFT_Draw_Rect

        MOVS    R0, #BOX_X
        MOVS    R1, #150
        MOVS    R2, #BOX_W
        MOVS    R3, #BOX_H
        BL      TFT_Draw_Rect

        MOVS    R0, #BOX_X
        MOVS    R1, #190
        MOVS    R2, #BOX_W
        MOVS    R3, #BOX_H
        BL      TFT_Draw_Rect

        MOVS    R0, #BOX_X
        LDR     R1, =230
        MOVS    R2, #BOX_W
        MOVS    R3, #BOX_H
        BL      TFT_Draw_Rect

        POP     {R4, PC}

;=============================================================================
; INTERNAL: TFT_Draw_Smoke_Frame
; Draw outer smoke frame and clear inner area.
;=============================================================================
TFT_Draw_Smoke_Frame
        PUSH    {R4, LR}

        ; outer border
        LDR     R4, =COLOR_WHITE
        MOVS    R0, #SMOKE_OUTER_X
        LDR     R1, =SMOKE_OUTER_Y
        MOVS    R2, #SMOKE_OUTER_W
        MOVS    R3, #SMOKE_OUTER_H
        BL      TFT_Draw_Rect

        ; inner background
        LDR     R4, =COLOR_BLACK
        MOVS    R0, #SMOKE_INNER_X
        LDR     R1, =SMOKE_INNER_Y
        MOVS    R2, #SMOKE_INNER_W
        MOVS    R3, #SMOKE_INNER_H
        BL      TFT_Fill_Rect

        POP     {R4, PC}

;=============================================================================
; FUNCTION: TFT_Clear_Screen
;=============================================================================
TFT_Clear_Screen
        PUSH    {R4, LR}

        LDR     R4, =COLOR_BLACK
        MOVS    R0, #0
        MOVS    R1, #0
        LDR     R2, =TFT_WIDTH
        LDR     R3, =TFT_HEIGHT
        BL      TFT_Fill_Rect

        POP     {R4, PC}

;=============================================================================
; FUNCTION: TFT_Render_Main_Menu
;=============================================================================
TFT_Render_Main_Menu
        PUSH    {R4, LR}

        LDR     R4, =COLOR_BLUE
        BL      TFT_Draw_Header

        BL      TFT_Draw_Main_Menu_Boxes
        BL      TFT_Draw_Smoke_Frame

        POP     {R4, PC}

;=============================================================================
; FUNCTION: TFT_Render_Sanitizing
;=============================================================================
TFT_Render_Sanitizing
        PUSH    {R4, LR}

        LDR     R4, =COLOR_GREEN
        BL      TFT_Draw_Header

        LDR     R4, =COLOR_GREEN
        MOVS    R0, #40
        LDR     R1, =110
        LDR     R2, =160
        LDR     R3, =90
        BL      TFT_Draw_Rect

        POP     {R4, PC}

;=============================================================================
; FUNCTION: TFT_Render_Heart_Rate
;=============================================================================
TFT_Render_Heart_Rate
        PUSH    {R4, LR}

        LDR     R4, =COLOR_RED
        BL      TFT_Draw_Header

        LDR     R4, =COLOR_RED
        MOVS    R0, #25
        LDR     R1, =90
        LDR     R2, =190
        LDR     R3, =110
        BL      TFT_Draw_Rect

        POP     {R4, PC}

;=============================================================================
; FUNCTION: TFT_Render_Breathing
;=============================================================================
TFT_Render_Breathing
        PUSH    {R4, LR}

        LDR     R4, =COLOR_CYAN
        BL      TFT_Draw_Header

        LDR     R4, =COLOR_CYAN
        MOVS    R0, #25
        LDR     R1, =90
        LDR     R2, =190
        LDR     R3, =110
        BL      TFT_Draw_Rect

        POP     {R4, PC}

;=============================================================================
; FUNCTION: TFT_Render_Motion
; Added to satisfy current ui_state.s with minimal change.
;=============================================================================
TFT_Render_Motion
        PUSH    {R4, LR}

        LDR     R4, =COLOR_MAGENTA
        BL      TFT_Draw_Header

        LDR     R4, =COLOR_MAGENTA
        MOVS    R0, #30
        LDR     R1, =110
        LDR     R2, =180
        LDR     R3, =90
        BL      TFT_Draw_Rect

        POP     {R4, PC}

;=============================================================================
; FUNCTION: TFT_Render_Med_Input
;=============================================================================
TFT_Render_Med_Input
        PUSH    {R4, LR}

        LDR     R4, =COLOR_YELLOW
        BL      TFT_Draw_Header

        LDR     R4, =COLOR_YELLOW
        MOVS    R0, #25
        LDR     R1, =100
        LDR     R2, =190
        LDR     R3, =110
        BL      TFT_Draw_Rect

        POP     {R4, PC}

;=============================================================================
; FUNCTION: TFT_Render_Med_Waiting
; Added to satisfy current ui_state.s with minimal change.
;=============================================================================
TFT_Render_Med_Waiting
        PUSH    {R4, LR}

        LDR     R4, =COLOR_YELLOW
        BL      TFT_Draw_Header

        LDR     R4, =COLOR_WHITE
        MOVS    R0, #25
        LDR     R1, =100
        LDR     R2, =190
        LDR     R3, =110
        BL      TFT_Draw_Rect

        POP     {R4, PC}

;=============================================================================
; FUNCTION: TFT_Render_Med_Alert
;=============================================================================
TFT_Render_Med_Alert
        PUSH    {R4, LR}

        LDR     R4, =COLOR_ORANGE
        BL      TFT_Draw_Header

        LDR     R4, =COLOR_ORANGE
        MOVS    R0, #25
        LDR     R1, =100
        LDR     R2, =190
        LDR     R3, =110
        BL      TFT_Draw_Rect

        POP     {R4, PC}

;=============================================================================
; FUNCTION: TFT_Render_Med_Dispense
; Old teammate spelling kept as alias below.
;=============================================================================
TFT_Render_Med_Dispense
TFT_Render_Med_Despense
        PUSH    {R4, LR}

        LDR     R4, =COLOR_ORANGE
        BL      TFT_Draw_Header

        LDR     R4, =COLOR_WHITE
        MOVS    R0, #40
        LDR     R1, =110
        LDR     R2, =160
        LDR     R3, =90
        BL      TFT_Draw_Rect

        POP     {R4, PC}

;=============================================================================
; FUNCTION: TFT_Render_Smoke_Alert
; Old teammate casing kept as alias below.
;=============================================================================
TFT_Render_Smoke_Alert
TFT_Render_Smoke_ALERT
        PUSH    {R4, LR}

        LDR     R4, =COLOR_RED
        BL      TFT_Draw_Header

        LDR     R4, =COLOR_RED
        MOVS    R0, #20
        LDR     R1, =90
        LDR     R2, =200
        LDR     R3, =110
        BL      TFT_Draw_Rect

        BL      TFT_Draw_Smoke_Frame

        POP     {R4, PC}

;=============================================================================
; FUNCTION: TFT_Update_Smoke_Level
; Input:
;   R2 = smoke value
;
; Simple compatibility mapping:
;   visible width = min(198, smoke_value >> 4)
;=============================================================================
TFT_Update_Smoke_Level
        PUSH    {R4, R5, LR}

        MOV     R5, R2
        LSRS    R5, R5, #4             ; scale down to a visible bar width

        CMP     R5, #SMOKE_INNER_W
        BLS     Smoke_Clamp_Done
        MOVS    R5, #SMOKE_INNER_W

Smoke_Clamp_Done
        ; clear inner bar first
        LDR     R4, =COLOR_BLACK
        MOVS    R0, #SMOKE_INNER_X
        LDR     R1, =SMOKE_INNER_Y
        MOVS    R2, #SMOKE_INNER_W
        MOVS    R3, #SMOKE_INNER_H
        BL      TFT_Fill_Rect

        CMP     R5, #0
        BEQ     Smoke_Update_Done

        ; choose color by level
        CMP     R5, #66
        BLS     Smoke_Green

        CMP     R5, #132
        BLS     Smoke_Yellow

        LDR     R4, =COLOR_RED
        B       Smoke_Draw

Smoke_Green
        LDR     R4, =COLOR_GREEN
        B       Smoke_Draw

Smoke_Yellow
        LDR     R4, =COLOR_YELLOW

Smoke_Draw
        MOVS    R0, #SMOKE_INNER_X
        LDR     R1, =SMOKE_INNER_Y
        MOV     R2, R5
        MOVS    R3, #SMOKE_INNER_H
        BL      TFT_Fill_Rect

Smoke_Update_Done
        POP     {R4, R5, PC}

        LTORG
        END