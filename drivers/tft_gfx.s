;=============================================================================
; tft_gfx.s
; High-level TFT rendering layer
; Landscape 320x240 UI for SPI ILI9341
; Fixed:
;   - Visible UI text drawn at 2x
;   - Robo frame no longer flickers
;   - Main menu keeps only calm friendly expressions
;   - Robo appears on every screen
;   - Robo is red on alert pages
;=============================================================================

        GET     constants.s

        AREA    TFT_GFX, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

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
        EXPORT  TFT_Update_Breathing_Level
        EXPORT  TFT_Update_Heart_Values

        EXPORT  TFT_Render_Med_Despense
        EXPORT  TFT_Render_Smoke_ALERT

        EXPORT  TFT_Draw_Pixel
        EXPORT  TFT_Draw_Rect
        EXPORT  TFT_Fill_Rect
        EXPORT  TFT_Draw_String
        EXPORT  TFT_Draw_Number6

        IMPORT  g_ms_ticks
        IMPORT  g_sys_state
        IMPORT  g_bpm
        IMPORT  g_spo2
        IMPORT  g_med_timer
        IMPORT  TFT_SetAddressWindow
        IMPORT  TFT_WriteData16

TFT_WIDTH               EQU     320
TFT_HEIGHT              EQU     240
HEADER_H                EQU     32

COLOR_BLACK             EQU     0x0000
COLOR_WHITE             EQU     0xFFFF
COLOR_RED               EQU     0xF800
COLOR_GREEN             EQU     0x07E0
COLOR_BLUE              EQU     0x001F
COLOR_YELLOW            EQU     0xFFE0
COLOR_CYAN              EQU     0x07FF
COLOR_ORANGE            EQU     0xFD20
COLOR_MAGENTA           EQU     0xF81F
COLOR_GRAY              EQU     0x8410
COLOR_PANEL             EQU     0x1082
COLOR_DARKRED           EQU     0x8000
COLOR_DARKGREEN         EQU     0x0320
COLOR_DARKBLUE          EQU     0x0010

SMOKE_OUTER_X           EQU     60
SMOKE_OUTER_Y           EQU     214
SMOKE_OUTER_W           EQU     200
SMOKE_OUTER_H           EQU     14
SMOKE_INNER_X           EQU     61
SMOKE_INNER_Y           EQU     215
SMOKE_INNER_W           EQU     198
SMOKE_INNER_H           EQU     12
SMOKE_BAR_LABEL_X       EQU     130
SMOKE_BAR_LABEL_Y       EQU     194

BREATH_BOX_X            EQU     132
BREATH_BOX_Y            EQU     56
BREATH_BOX_W            EQU     172
BREATH_BOX_H            EQU     124
BREATH_PLOT_X           EQU     136
BREATH_PLOT_Y           EQU     60
BREATH_PLOT_W           EQU     164
BREATH_PLOT_H           EQU     116
BREATH_PLOT_W_LAST      EQU     163
BREATH_PLOT_H_LAST      EQU     115
BREATH_PLOT_BOTTOM      EQU     175
BREATH_MIDLINE_Y        EQU     117

HEART_BPM_X             EQU     48
HEART_BPM_Y             EQU     92
HEART_SPO2_X            EQU     48
HEART_SPO2_Y            EQU     156

MED_TIMER_X             EQU     95
MED_TIMER_Y             EQU     185

ROBO_X                  EQU     238
ROBO_Y                  EQU     8
ROBO_W                  EQU     64
ROBO_H                  EQU     16
ROBO_INNER_X            EQU     240
ROBO_INNER_Y            EQU     10
ROBO_INNER_W            EQU     60
ROBO_INNER_H            EQU     12

CHAR_ADVANCE            EQU     6
CHAR2X_ADVANCE          EQU     12

        AREA    TFT_GFX_DATA, DATA, READWRITE
        ALIGN
g_breath_plot_x         SPACE   4

        AREA    TFT_GFX, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN


;-----------------------------------------------------------------------------
; Low-level fill helper
;-----------------------------------------------------------------------------
TFT_Fill_Window_Color
        PUSH    {R4, R5, LR}

        MOV     R4, R0
        MOV     R5, R1

Fill_Window_Loop
        CMP     R4, #0
        BEQ     Fill_Window_Done

        MOV     R0, R5
        BL      TFT_WriteData16

        SUBS    R4, R4, #1
        B       Fill_Window_Loop

Fill_Window_Done
        POP     {R4, R5, PC}


;-----------------------------------------------------------------------------
; Pixel / rect primitives
;-----------------------------------------------------------------------------
TFT_Draw_Pixel
        PUSH    {R4, LR}

        MOV     R4, R2
        MOV     R2, R0
        MOV     R3, R1
        BL      TFT_SetAddressWindow

        MOV     R0, R4
        BL      TFT_WriteData16

        POP     {R4, PC}

TFT_Fill_Rect
        PUSH    {R5, R6, R7, R8, LR}

        MOV     R5, R0
        MOV     R6, R1
        MOV     R7, R2
        MOV     R8, R3

        CMP     R7, #0
        BEQ     TFT_Fill_Rect_Done

        CMP     R8, #0
        BEQ     TFT_Fill_Rect_Done

        ADD     R2, R5, R7
        SUBS    R2, R2, #1

        ADD     R3, R6, R8
        SUBS    R3, R3, #1

        MOV     R0, R5
        MOV     R1, R6
        BL      TFT_SetAddressWindow

        MUL     R0, R7, R8
        MOV     R1, R4
        BL      TFT_Fill_Window_Color

TFT_Fill_Rect_Done
        POP     {R5, R6, R7, R8, PC}

TFT_Draw_Rect
        PUSH    {R5, R6, R7, R8, LR}

        MOV     R5, R0
        MOV     R6, R1
        MOV     R7, R2
        MOV     R8, R3

        MOV     R0, R5
        MOV     R1, R6
        MOV     R2, R7
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        MOV     R0, R5
        ADD     R1, R6, R8
        SUBS    R1, R1, #1
        MOV     R2, R7
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        MOV     R0, R5
        MOV     R1, R6
        MOVS    R2, #1
        MOV     R3, R8
        BL      TFT_Fill_Rect

        ADD     R0, R5, R7
        SUBS    R0, R0, #1
        MOV     R1, R6
        MOVS    R2, #1
        MOV     R3, R8
        BL      TFT_Fill_Rect

        POP     {R5, R6, R7, R8, PC}

TFT_Draw_Panel
        PUSH    {R5-R8, LR}

        MOV     R5, R0
        MOV     R6, R1
        MOV     R7, R2
        MOV     R8, R3

        MOV     R0, R5
        MOV     R1, R6
        MOV     R2, R7
        MOV     R3, R8
        MOVW    R4, #COLOR_PANEL
        BL      TFT_Fill_Rect

        MOV     R0, R5
        MOV     R1, R6
        MOV     R2, R7
        MOV     R3, R8
        MOVW    R4, #COLOR_WHITE
        BL      TFT_Draw_Rect

        POP     {R5-R8, PC}

TFT_Draw_HeaderBand
        PUSH    {LR}

        MOVS    R0, #0
        MOVS    R1, #0
        MOVW    R2, #TFT_WIDTH
        MOVS    R3, #HEADER_H
        BL      TFT_Fill_Rect

        POP     {PC}

TFT_Draw_Smoke_Bar_Frame
        PUSH    {LR}

        MOVW    R4, #COLOR_WHITE
        MOVS    R0, #SMOKE_OUTER_X
        MOVS    R1, #SMOKE_OUTER_Y
        MOVS    R2, #SMOKE_OUTER_W
        MOVS    R3, #SMOKE_OUTER_H
        BL      TFT_Draw_Rect

        MOVS    R0, #SMOKE_BAR_LABEL_X
        MOVS    R1, #SMOKE_BAR_LABEL_Y
        MOVW    R2, #:LOWER16:StrSmoke
        MOVT    R2, #:UPPER16:StrSmoke
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        POP     {PC}


;-----------------------------------------------------------------------------
; Robo helpers
;-----------------------------------------------------------------------------
TFT_Clear_Robo_Inner
        PUSH    {LR}

        MOVW    R4, #COLOR_BLACK
        MOVS    R0, #ROBO_INNER_X
        MOVS    R1, #ROBO_INNER_Y
        MOVS    R2, #ROBO_INNER_W
        MOVS    R3, #ROBO_INNER_H
        BL      TFT_Fill_Rect

        POP     {PC}

TFT_Draw_Robo_Frame_Normal
        PUSH    {LR}

        MOVW    R4, #COLOR_CYAN
        MOVS    R0, #ROBO_X
        MOVS    R1, #ROBO_Y
        MOVS    R2, #ROBO_W
        MOVS    R3, #ROBO_H
        BL      TFT_Draw_Rect

        POP     {PC}

TFT_Draw_Robo_Frame_Alert
        PUSH    {LR}

        MOVW    R4, #COLOR_RED
        MOVS    R0, #ROBO_X
        MOVS    R1, #ROBO_Y
        MOVS    R2, #ROBO_W
        MOVS    R3, #ROBO_H
        BL      TFT_Draw_Rect

        POP     {PC}

TFT_Draw_Robo_Face_Open
        PUSH    {LR}

        BL      TFT_Clear_Robo_Inner

        MOVW    R4, #COLOR_CYAN
        MOVS    R0, #252
        MOVS    R1, #13
        MOVS    R2, #10
        MOVS    R3, #4
        BL      TFT_Fill_Rect

        MOVW    R0, #276
        MOVS    R1, #13
        MOVS    R2, #10
        MOVS    R3, #4
        BL      TFT_Fill_Rect

        POP     {PC}

TFT_Draw_Robo_Face_Blink
        PUSH    {LR}

        BL      TFT_Clear_Robo_Inner

        MOVW    R4, #COLOR_CYAN
        MOVS    R0, #252
        MOVS    R1, #15
        MOVS    R2, #10
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        MOVW    R0, #276
        MOVS    R1, #15
        MOVS    R2, #10
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        POP     {PC}

TFT_Draw_Robo_Face_Happy
        PUSH    {LR}

        BL      TFT_Clear_Robo_Inner

        MOVW    R4, #COLOR_CYAN
        MOVS    R0, #252
        MOVS    R1, #15
        MOVS    R2, #3
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        MOVS    R0, #255
        MOVS    R1, #14
        MOVS    R2, #3
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        MOVS    R0, #258
        MOVS    R1, #15
        MOVS    R2, #3
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        MOVW    R0, #276
        MOVS    R1, #15
        MOVS    R2, #3
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        MOVW    R0, #279
        MOVS    R1, #14
        MOVS    R2, #3
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        MOVW    R0, #282
        MOVS    R1, #15
        MOVS    R2, #3
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        POP     {PC}

TFT_Draw_Robo_Face_Sleepy
        PUSH    {LR}

        BL      TFT_Clear_Robo_Inner

        MOVW    R4, #COLOR_CYAN
        MOVS    R0, #252
        MOVS    R1, #16
        MOVS    R2, #10
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        MOVW    R0, #276
        MOVS    R1, #16
        MOVS    R2, #10
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        POP     {PC}

TFT_Draw_Robo_Face_Worried
        PUSH    {LR}

        BL      TFT_Clear_Robo_Inner

        MOVW    R4, #COLOR_RED

        MOVS    R0, #252
        MOVS    R1, #13
        MOVS    R2, #4
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        MOVS    R0, #255
        MOVS    R1, #14
        MOVS    R2, #4
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        MOVW    R0, #276
        MOVS    R1, #14
        MOVS    R2, #4
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        MOVW    R0, #279
        MOVS    R1, #13
        MOVS    R2, #4
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        MOVW    R0, #262
        MOVS    R1, #18
        MOVS    R2, #8
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        POP     {PC}

;-----------------------------------------------------------------------------
; Main menu Robo animation
; Pattern:
;   blink
;   wait 500 ms
;   blink
;   wait 2000 ms
;   blink
;   happy eyes
;   repeat
;-----------------------------------------------------------------------------
TFT_Draw_Robo_MainMenuFace
        PUSH    {R4-R7, LR}

        ; g_ms_ticks is 1 ms tick
        MOVW    R0, #:LOWER16:g_ms_ticks
        MOVT    R0, #:UPPER16:g_ms_ticks
        LDR     R5, [R0]

        ; cycle length = 3500 ms
        ; reduce R5 modulo 3500
Robo_MM_ModLoop
        LDR     R6, =3500
        CMP     R5, R6
        BLO     Robo_MM_StateCheck
        SUB     R5, R5, R6
        B       Robo_MM_ModLoop

Robo_MM_StateCheck
        ; 0..119 ms   -> blink
        CMP     R5, #120
        BLO     Robo_MM_Blink1

        ; 120..619 ms -> open
        LDR     R6, =620
        CMP     R5, R6
        BLO     Robo_MM_Open1

        ; 620..739 ms -> blink
        LDR     R6, =740
        CMP     R5, R6
        BLO     Robo_MM_Blink2

        ; 740..2739 ms -> open
        LDR     R6, =2740
        CMP     R5, R6
        BLO     Robo_MM_Open2

        ; 2740..2859 ms -> blink
        LDR     R6, =2860
        CMP     R5, R6
        BLO     Robo_MM_Blink3

        ; 2860..3199 ms -> happy eyes
        LDR     R6, =3200
        CMP     R5, R6
        BLO     Robo_MM_Happy

        ; 3200..3499 ms -> open
        B       Robo_MM_Open3

Robo_MM_Blink1
        BL      TFT_Draw_Robo_Face_Blink
        B       Robo_MM_Done

Robo_MM_Open1
        BL      TFT_Draw_Robo_Face_Open
        B       Robo_MM_Done

Robo_MM_Blink2
        BL      TFT_Draw_Robo_Face_Blink
        B       Robo_MM_Done

Robo_MM_Open2
        BL      TFT_Draw_Robo_Face_Open
        B       Robo_MM_Done

Robo_MM_Blink3
        BL      TFT_Draw_Robo_Face_Blink
        B       Robo_MM_Done

Robo_MM_Happy
        BL      TFT_Draw_Robo_Face_Happy
        B       Robo_MM_Done

Robo_MM_Open3
        BL      TFT_Draw_Robo_Face_Open

Robo_MM_Done
        POP     {R4-R7, PC}


;-----------------------------------------------------------------------------
; Heart icon and warning triangle
;-----------------------------------------------------------------------------
TFT_Draw_Heart_Icon
        PUSH    {R4-R7, LR}

        MOVW    R0, #:LOWER16:g_ms_ticks
        MOVT    R0, #:UPPER16:g_ms_ticks
        LDR     R5, [R0]
        MOVW    R6, #0x01FF
        AND     R5, R5, R6

        MOVW    R4, #COLOR_BLACK
        MOVS    R0, #212
        MOVS    R1, #72
        MOVS    R2, #84
        MOVS    R3, #84
        BL      TFT_Fill_Rect

        CMP     R5, #48
        BLO     Heart_Large
        CMP     R5, #96
        BLO     Heart_Small
        CMP     R5, #136
        BLO     Heart_Large

Heart_Small
        MOVW    R4, #COLOR_DARKRED
        MOVS    R0, #228
        MOVS    R1, #88
        MOVS    R2, #16
        MOVS    R3, #12
        BL      TFT_Fill_Rect

        MOVS    R0, #250
        MOVS    R1, #88
        MOVS    R2, #16
        MOVS    R3, #12
        BL      TFT_Fill_Rect

        MOVS    R0, #232
        MOVS    R1, #98
        MOVS    R2, #30
        MOVS    R3, #10
        BL      TFT_Fill_Rect

        MOVS    R0, #238
        MOVS    R1, #108
        MOVS    R2, #18
        MOVS    R3, #10
        BL      TFT_Fill_Rect

        MOVS    R0, #244
        MOVS    R1, #118
        MOVS    R2, #6
        MOVS    R3, #6
        BL      TFT_Fill_Rect
        B       Heart_Done

Heart_Large
        MOVW    R4, #COLOR_RED
        MOVS    R0, #224
        MOVS    R1, #84
        MOVS    R2, #18
        MOVS    R3, #14
        BL      TFT_Fill_Rect

        MOVS    R0, #246
        MOVS    R1, #84
        MOVS    R2, #18
        MOVS    R3, #14
        BL      TFT_Fill_Rect

        MOVS    R0, #228
        MOVS    R1, #96
        MOVS    R2, #34
        MOVS    R3, #12
        BL      TFT_Fill_Rect

        MOVS    R0, #234
        MOVS    R1, #108
        MOVS    R2, #22
        MOVS    R3, #10
        BL      TFT_Fill_Rect

        MOVS    R0, #242
        MOVS    R1, #118
        MOVS    R2, #6
        MOVS    R3, #6
        BL      TFT_Fill_Rect

Heart_Done
        POP     {R4-R7, PC}

TFT_Draw_Warning_Triangle
        PUSH    {R4-R8, LR}

        MOVW    R0, #:LOWER16:g_ms_ticks
        MOVT    R0, #:UPPER16:g_ms_ticks
        LDR     R8, [R0]
        MOVW    R6, #0x01FF
        AND     R8, R8, R6

        MOVW    R4, #COLOR_BLACK
        MOVS    R0, #90
        MOVS    R1, #52
        MOVS    R2, #140
        MOVS    R3, #100
        BL      TFT_Fill_Rect

        CMP     R8, #200
        BLO     Triangle_On
        B       Triangle_Off

Triangle_On
        MOVW    R4, #COLOR_RED
        MOVS    R5, #0

Triangle_Row_Loop
        CMP     R5, #56
        BEQ     Triangle_Exclaim

        MOVS    R0, #160
        SUB     R0, R0, R5
        MOVS    R1, #62
        ADD     R1, R1, R5
        LSLS    R2, R5, #1
        ADDS    R2, R2, #1
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        ADDS    R5, R5, #2
        B       Triangle_Row_Loop

Triangle_Exclaim
        MOVW    R4, #COLOR_WHITE
        MOVS    R0, #158
        MOVS    R1, #92
        MOVS    R2, #4
        MOVS    R3, #22
        BL      TFT_Fill_Rect

        MOVS    R0, #158
        MOVS    R1, #120
        MOVS    R2, #4
        MOVS    R3, #4
        BL      TFT_Fill_Rect
        B       Triangle_Done

Triangle_Off
        MOVW    R4, #COLOR_DARKRED
        MOVS    R0, #128
        MOVS    R1, #80
        MOVS    R2, #64
        MOVS    R3, #44
        BL      TFT_Draw_Rect

Triangle_Done
        POP     {R4-R8, PC}

;-----------------------------------------------------------------------------
; Medical cross icon
;-----------------------------------------------------------------------------
TFT_Draw_Med_Cross
        PUSH    {LR}

        MOVW    R4, #COLOR_RED

        ; vertical bar
        MOVW    R0, #268
        MOVS    R1, #78
        MOVS    R2, #8
        MOVS    R3, #24
        BL      TFT_Fill_Rect

        ; horizontal bar
        MOVW    R0, #260
        MOVS    R1, #86
        MOVS    R2, #24
        MOVS    R3, #8
        BL      TFT_Fill_Rect

        POP     {PC}
;-----------------------------------------------------------------------------
; Font lookup and character drawing
;-----------------------------------------------------------------------------
GFX_GetGlyphPtr
        PUSH    {R1-R3, LR}

        CMP     R0, #' '
        BEQ     Glyph_Space_Label

        CMP     R0, #'0'
        BLO     Check_Colon
        CMP     R0, #'9'
        BHI     Check_Colon
        SUB     R1, R0, #'0'
        MOVW    R0, #:LOWER16:FontDigits
        MOVT    R0, #:UPPER16:FontDigits
        MOVS    R2, #5
        MUL     R1, R2, R1
        ADD     R0, R0, R1
        POP     {R1-R3, PC}

Check_Colon
        CMP     R0, #':'
        BEQ     Glyph_Colon_Label
        CMP     R0, #'-'
        BEQ     Glyph_Dash_Label
        CMP     R0, #'/'
        BEQ     Glyph_Slash_Label
        CMP     R0, #'%'
        BEQ     Glyph_Percent_Label

        CMP     R0, #'a'
        BLO     Check_Upper
        CMP     R0, #'z'
        BHI     Check_Upper
        SUB     R0, R0, #32

Check_Upper
        CMP     R0, #'A'
        BLO     Glyph_Space_Label
        CMP     R0, #'Z'
        BHI     Glyph_Space_Label
        SUB     R1, R0, #'A'
        MOVW    R0, #:LOWER16:FontUpper
        MOVT    R0, #:UPPER16:FontUpper
        MOVS    R2, #5
        MUL     R1, R2, R1
        ADD     R0, R0, R1
        POP     {R1-R3, PC}

Glyph_Space_Label
        MOVW    R0, #:LOWER16:GlyphSpace
        MOVT    R0, #:UPPER16:GlyphSpace
        POP     {R1-R3, PC}

Glyph_Colon_Label
        MOVW    R0, #:LOWER16:GlyphColon
        MOVT    R0, #:UPPER16:GlyphColon
        POP     {R1-R3, PC}

Glyph_Dash_Label
        MOVW    R0, #:LOWER16:GlyphDash
        MOVT    R0, #:UPPER16:GlyphDash
        POP     {R1-R3, PC}

Glyph_Slash_Label
        MOVW    R0, #:LOWER16:GlyphSlash
        MOVT    R0, #:UPPER16:GlyphSlash
        POP     {R1-R3, PC}

Glyph_Percent_Label
        MOVW    R0, #:LOWER16:GlyphPercent
        MOVT    R0, #:UPPER16:GlyphPercent
        POP     {R1-R3, PC}

GFX_Draw_Char
        PUSH    {R4-R11, LR}

        MOV     R8, R0
        MOV     R9, R1
        MOV     R10, R3

        MOV     R0, R2
        BL      GFX_GetGlyphPtr
        MOV     R11, R0

        MOVS    R5, #0

Char_Col_Loop
        CMP     R5, #5
        BEQ     Char_Done

        LDRB    R6, [R11, R5]
        MOVS    R7, #0

Char_Row_Loop
        CMP     R7, #7
        BEQ     Next_Col

        MOVS    R0, #1
        LSLS    R0, R0, R7
        TST     R6, R0
        BEQ     Skip_Pixel

        ADD     R0, R8, R5
        ADD     R1, R9, R7
        MOV     R2, R10
        BL      TFT_Draw_Pixel

Skip_Pixel
        ADDS    R7, R7, #1
        B       Char_Row_Loop

Next_Col
        ADDS    R5, R5, #1
        B       Char_Col_Loop

Char_Done
        POP     {R4-R11, PC}

GFX_Draw_Char2x
        PUSH    {R4-R11, LR}

        MOV     R8, R0
        MOV     R9, R1
        MOV     R10, R3

        MOV     R0, R2
        BL      GFX_GetGlyphPtr
        MOV     R11, R0

        MOVS    R5, #0

Char2_Col_Loop
        CMP     R5, #5
        BEQ     Char2_Done

        LDRB    R6, [R11, R5]
        MOVS    R7, #0

Char2_Row_Loop
        CMP     R7, #7
        BEQ     Char2_Next_Col

        MOVS    R0, #1
        LSLS    R0, R0, R7
        TST     R6, R0
        BEQ     Char2_Skip_Pixel

        MOV     R0, R5
        LSLS    R0, R0, #1
        ADD     R0, R0, R8

        MOV     R1, R7
        LSLS    R1, R1, #1
        ADD     R1, R1, R9

        MOVS    R2, #2
        MOVS    R3, #2
        MOV     R4, R10
        BL      TFT_Fill_Rect

Char2_Skip_Pixel
        ADDS    R7, R7, #1
        B       Char2_Row_Loop

Char2_Next_Col
        ADDS    R5, R5, #1
        B       Char2_Col_Loop

Char2_Done
        POP     {R4-R11, PC}

TFT_Draw_String
        PUSH    {R4-R8, LR}

        MOV     R4, R0
        MOV     R5, R1
        MOV     R6, R2
        MOV     R7, R3

Draw_String_Loop
        LDRB    R8, [R6], #1
        CMP     R8, #0
        BEQ     Draw_String_Done

        MOV     R0, R4
        MOV     R1, R5
        MOV     R2, R8
        MOV     R3, R7
        BL      GFX_Draw_Char

        ADDS    R4, R4, #CHAR_ADVANCE
        B       Draw_String_Loop

Draw_String_Done
        POP     {R4-R8, PC}

TFT_Draw_String2x
        PUSH    {R4-R8, LR}

        MOV     R4, R0
        MOV     R5, R1
        MOV     R6, R2
        MOV     R7, R3

Draw_String2x_Loop
        LDRB    R8, [R6], #1
        CMP     R8, #0
        BEQ     Draw_String2x_Done

        MOV     R0, R4
        MOV     R1, R5
        MOV     R2, R8
        MOV     R3, R7
        BL      GFX_Draw_Char2x

        ADDS    R4, R4, #CHAR2X_ADVANCE
        B       Draw_String2x_Loop

Draw_String2x_Done
        POP     {R4-R8, PC}

TFT_Draw_Number3_2x
        PUSH    {R4-R9, LR}

        MOV     R4, R0
        MOV     R5, R1
        MOV     R6, R2
        MOV     R7, R3

        MOVW    R0, #999
        CMP     R6, R0
        BLS     Num32_ClampDone
        MOV     R6, R0

Num32_ClampDone
        MOVS    R8, #0
Num32_Hundreds
        CMP     R6, #100
        BLO     Num32_HundredsDone
        SUBS    R6, R6, #100
        ADDS    R8, R8, #1
        B       Num32_Hundreds

Num32_HundredsDone
        MOVS    R9, #0
Num32_Tens
        CMP     R6, #10
        BLO     Num32_TensDone
        SUBS    R6, R6, #10
        ADDS    R9, R9, #1
        B       Num32_Tens

Num32_TensDone
        MOV     R0, R4
        MOV     R1, R5
        ADDS    R2, R8, #'0'
        MOV     R3, R7
        BL      GFX_Draw_Char2x

        MOV     R0, R4
        ADDS    R0, R0, #CHAR2X_ADVANCE
        MOV     R1, R5
        ADDS    R2, R9, #'0'
        MOV     R3, R7
        BL      GFX_Draw_Char2x

        MOV     R0, R4
        ADDS    R0, R0, #(CHAR2X_ADVANCE * 2)
        MOV     R1, R5
        ADDS    R2, R6, #'0'
        MOV     R3, R7
        BL      GFX_Draw_Char2x

        POP     {R4-R9, PC}

TFT_Draw_Number6
        PUSH    {R4-R11, LR}
        SUB     SP, SP, #28

        MOV     R4, R0
        MOV     R5, R1
        MOV     R6, R2
        MOV     R7, R3

        MOVW    R0, #16959
        MOVT    R0, #15
        CMP     R6, R0
        BLS     Num6_ClampDone
        MOV     R6, R0

Num6_ClampDone
        MOVS    R8, #0
Num6_L1
        MOVW    R0, #34464
        MOVT    R0, #1
        CMP     R6, R0
        BLO     Num6_L1_Done
        SUB     R6, R6, R0
        ADDS    R8, R8, #1
        B       Num6_L1
Num6_L1_Done
        STR     R8, [SP, #0]

        MOVS    R8, #0
Num6_L2
        MOVW    R0, #10000
        CMP     R6, R0
        BLO     Num6_L2_Done
        SUB     R6, R6, R0
        ADDS    R8, R8, #1
        B       Num6_L2
Num6_L2_Done
        STR     R8, [SP, #4]

        MOVS    R8, #0
Num6_L3
        MOVW    R0, #1000
        CMP     R6, R0
        BLO     Num6_L3_Done
        SUB     R6, R6, R0
        ADDS    R8, R8, #1
        B       Num6_L3
Num6_L3_Done
        STR     R8, [SP, #8]

        MOVS    R8, #0
Num6_L4
        MOVS    R0, #100
        CMP     R6, R0
        BLO     Num6_L4_Done
        SUBS    R6, R6, #100
        ADDS    R8, R8, #1
        B       Num6_L4
Num6_L4_Done
        STR     R8, [SP, #12]

        MOVS    R8, #0
Num6_L5
        MOVS    R0, #10
        CMP     R6, R0
        BLO     Num6_L5_Done
        SUBS    R6, R6, #10
        ADDS    R8, R8, #1
        B       Num6_L5
Num6_L5_Done
        STR     R8, [SP, #16]
        STR     R6, [SP, #20]

        MOV     R0, R4
        MOV     R1, R5
        LDR     R2, [SP, #0]
        ADDS    R2, R2, #'0'
        MOV     R3, R7
        BL      GFX_Draw_Char

        MOV     R0, R4
        ADDS    R0, R0, #6
        MOV     R1, R5
        LDR     R2, [SP, #4]
        ADDS    R2, R2, #'0'
        MOV     R3, R7
        BL      GFX_Draw_Char

        MOV     R0, R4
        ADDS    R0, R0, #12
        MOV     R1, R5
        LDR     R2, [SP, #8]
        ADDS    R2, R2, #'0'
        MOV     R3, R7
        BL      GFX_Draw_Char

        MOV     R0, R4
        ADDS    R0, R0, #18
        MOV     R1, R5
        LDR     R2, [SP, #12]
        ADDS    R2, R2, #'0'
        MOV     R3, R7
        BL      GFX_Draw_Char

        MOV     R0, R4
        ADDS    R0, R0, #24
        MOV     R1, R5
        LDR     R2, [SP, #16]
        ADDS    R2, R2, #'0'
        MOV     R3, R7
        BL      GFX_Draw_Char

        MOV     R0, R4
        ADDS    R0, R0, #30
        MOV     R1, R5
        LDR     R2, [SP, #20]
        ADDS    R2, R2, #'0'
        MOV     R3, R7
        BL      GFX_Draw_Char

        ADD     SP, SP, #28
        POP     {R4-R11, PC}


;-----------------------------------------------------------------------------
; Screen render functions
;-----------------------------------------------------------------------------
TFT_Clear_Screen
        PUSH    {R4, LR}

        MOVW    R4, #COLOR_BLACK
        MOVS    R0, #0
        MOVS    R1, #0
        MOVW    R2, #TFT_WIDTH
        MOVS    R3, #240
        BL      TFT_Fill_Rect

        POP     {R4, PC}

TFT_Render_Main_Menu
        PUSH    {R4, LR}

        MOVW    R4, #COLOR_DARKBLUE
        BL      TFT_Draw_HeaderBand

        MOVS    R0, #16
        MOVS    R1, #8
        MOVW    R2, #:LOWER16:StrMainMenu
        MOVT    R2, #:UPPER16:StrMainMenu
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        BL      TFT_Draw_Robo_Frame_Normal
        BL      TFT_Draw_Robo_MainMenuFace

        MOVS    R0, #16
        MOVS    R1, #52
        MOVS    R2, #136
        MOVS    R3, #36
        BL      TFT_Draw_Panel

        MOVS    R0, #168
        MOVS    R1, #52
        MOVS    R2, #136
        MOVS    R3, #36
        BL      TFT_Draw_Panel

        MOVS    R0, #16
        MOVS    R1, #98
        MOVS    R2, #136
        MOVS    R3, #36
        BL      TFT_Draw_Panel

        MOVS    R0, #168
        MOVS    R1, #98
        MOVS    R2, #136
        MOVS    R3, #36
        BL      TFT_Draw_Panel

        MOVS    R0, #22
        MOVS    R1, #62
        MOVW    R2, #:LOWER16:StrMenu1
        MOVT    R2, #:UPPER16:StrMenu1
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        MOVS    R0, #174
        MOVS    R1, #62
        MOVW    R2, #:LOWER16:StrMenu2
        MOVT    R2, #:UPPER16:StrMenu2
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        MOVS    R0, #22
        MOVS    R1, #108
        MOVW    R2, #:LOWER16:StrMenu3
        MOVT    R2, #:UPPER16:StrMenu3
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        MOVS    R0, #174
        MOVS    R1, #108
        MOVW    R2, #:LOWER16:StrMenu4
        MOVT    R2, #:UPPER16:StrMenu4
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        BL      TFT_Draw_Smoke_Bar_Frame

        POP     {R4, PC}

TFT_Render_Sanitizing
        PUSH    {R4, LR}

        MOVW    R4, #COLOR_DARKGREEN
        BL      TFT_Draw_HeaderBand

        MOVS    R0, #16
        MOVS    R1, #8
        MOVW    R2, #:LOWER16:StrSanHeader
        MOVT    R2, #:UPPER16:StrSanHeader
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        BL      TFT_Draw_Robo_Frame_Normal
        BL      TFT_Draw_Robo_Face_Happy

        MOVS    R0, #28
        MOVS    R1, #66
        MOVW    R2, #264
        MOVS    R3, #92
        BL      TFT_Draw_Panel

        MOVS    R0, #96
        MOVS    R1, #106
        MOVW    R2, #:LOWER16:StrSanBody
        MOVT    R2, #:UPPER16:StrSanBody
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        MOVS    R0, #110
        MOVS    R1, #176
        MOVW    R2, #:LOWER16:StrExitD
        MOVT    R2, #:UPPER16:StrExitD
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        POP     {R4, PC}

TFT_Render_Heart_Rate
        PUSH    {R4, LR}

        MOVW    R4, #COLOR_DARKRED
        BL      TFT_Draw_HeaderBand

        MOVS    R0, #16
        MOVS    R1, #8
        MOVW    R2, #:LOWER16:StrHeartHeader
        MOVT    R2, #:UPPER16:StrHeartHeader
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        BL      TFT_Draw_Robo_Frame_Normal
        BL      TFT_Draw_Robo_Face_Happy

        MOVS    R0, #16
        MOVS    R1, #56
        MOVS    R2, #178
        MOVS    R3, #128
        BL      TFT_Draw_Panel

        MOVS    R0, #206
        MOVS    R1, #56
        MOVS    R2, #98
        MOVS    R3, #128
        BL      TFT_Draw_Panel

        MOVS    R0, #30
        MOVS    R1, #68
        MOVW    R2, #:LOWER16:StrBpmLabel
        MOVT    R2, #:UPPER16:StrBpmLabel
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        MOVS    R0, #30
        MOVS    R1, #132
        MOVW    R2, #:LOWER16:StrSpo2Label
        MOVT    R2, #:UPPER16:StrSpo2Label
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        MOVW    R2, #:LOWER16:g_bpm
        MOVT    R2, #:UPPER16:g_bpm
        LDR     R2, [R2]

        MOVW    R3, #:LOWER16:g_spo2
        MOVT    R3, #:UPPER16:g_spo2
        LDR     R3, [R3]

        BL      TFT_Update_Heart_Values

        MOVS    R0, #110
        MOVS    R1, #192
        MOVW    R2, #:LOWER16:StrExitD
        MOVT    R2, #:UPPER16:StrExitD
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        POP     {R4, PC}

TFT_Render_Breathing
        PUSH    {R4, LR}

        MOVW    R4, #COLOR_DARKBLUE
        BL      TFT_Draw_HeaderBand

        MOVS    R0, #16
        MOVS    R1, #8
        MOVW    R2, #:LOWER16:StrBreathHeader
        MOVT    R2, #:UPPER16:StrBreathHeader
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        BL      TFT_Draw_Robo_Frame_Normal
        BL      TFT_Draw_Robo_Face_Sleepy

        MOVS    R0, #16
        MOVS    R1, #56
        MOVS    R2, #104
        MOVS    R3, #124
        BL      TFT_Draw_Panel

        MOVS    R0, #34
        MOVS    R1, #76
        MOVW    R2, #:LOWER16:StrBreathBody1
        MOVT    R2, #:UPPER16:StrBreathBody1
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        MOVS    R0, #28
        MOVS    R1, #104
        MOVW    R2, #:LOWER16:StrBreathBody2
        MOVT    R2, #:UPPER16:StrBreathBody2
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        MOVS    R0, #22
        MOVS    R1, #152
        MOVW    R2, #:LOWER16:StrExitD
        MOVT    R2, #:UPPER16:StrExitD
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        MOVS    R0, #BREATH_BOX_X
        MOVS    R1, #BREATH_BOX_Y
        MOVW    R2, #BREATH_BOX_W
        MOVW    R3, #BREATH_BOX_H
        BL      TFT_Draw_Panel

        MOVW    R4, #COLOR_BLACK
        MOVW    R0, #BREATH_PLOT_X
        MOVW    R1, #BREATH_PLOT_Y
        MOVW    R2, #BREATH_PLOT_W
        MOVW    R3, #BREATH_PLOT_H
        BL      TFT_Fill_Rect

        MOVW    R4, #COLOR_GRAY
        MOVW    R0, #BREATH_PLOT_X
        MOVW    R1, #BREATH_MIDLINE_Y
        MOVW    R2, #BREATH_PLOT_W
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        MOVW    R0, #:LOWER16:g_breath_plot_x
        MOVT    R0, #:UPPER16:g_breath_plot_x
        MOVS    R1, #0
        STR     R1, [R0]

        POP     {R4, PC}

TFT_Render_Motion
        PUSH    {R4, LR}

        MOVW    R4, #COLOR_MAGENTA
        BL      TFT_Draw_HeaderBand

        MOVS    R0, #16
        MOVS    R1, #8
        MOVW    R2, #:LOWER16:StrMotion
        MOVT    R2, #:UPPER16:StrMotion
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        BL      TFT_Draw_Robo_Frame_Normal
        BL      TFT_Draw_Robo_Face_Open

        MOVS    R0, #28
        MOVS    R1, #76
        MOVW    R2, #264
        MOVS    R3, #92
        BL      TFT_Draw_Panel

        MOVS    R0, #70
        MOVS    R1, #112
        MOVW    R2, #:LOWER16:StrMotionBody
        MOVT    R2, #:UPPER16:StrMotionBody
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        POP     {R4, PC}

TFT_Render_Med_Input
        PUSH    {R4, LR}

        MOVW    R4, #COLOR_DARKGREEN
        BL      TFT_Draw_HeaderBand

        MOVS    R0, #16
        MOVS    R1, #8
        MOVW    R2, #:LOWER16:StrMedInputHeader
        MOVT    R2, #:UPPER16:StrMedInputHeader
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        BL      TFT_Draw_Robo_Frame_Normal
        BL      TFT_Draw_Robo_Face_Open

        MOVS    R0, #16
        MOVS    R1, #56
        MOVW    R2, #288
        MOVS    R3, #128
        BL      TFT_Draw_Panel

        BL      TFT_Draw_Med_Cross

        MOVS    R0, #34
        MOVS    R1, #72
        MOVW    R2, #:LOWER16:StrMedInput1
        MOVT    R2, #:UPPER16:StrMedInput1
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        MOVS    R0, #34
        MOVS    R1, #96
        MOVW    R2, #:LOWER16:StrMedInput2
        MOVT    R2, #:UPPER16:StrMedInput2
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        MOVS    R0, #34
        MOVS    R1, #120
        MOVW    R2, #:LOWER16:StrMedInput3
        MOVT    R2, #:UPPER16:StrMedInput3
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        MOVS    R0, #34
        MOVS    R1, #154
        MOVW    R2, #:LOWER16:StrTimerDbg
        MOVT    R2, #:UPPER16:StrTimerDbg
        MOVW    R3, #COLOR_YELLOW
        BL      TFT_Draw_String2x

        MOVW    R2, #:LOWER16:g_med_timer
        MOVT    R2, #:UPPER16:g_med_timer
        LDR     R2, [R2]
        MOVS    R0, #MED_TIMER_X
        MOVS    R1, #MED_TIMER_Y
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_Number6

        POP     {R4, PC}

TFT_Render_Med_Waiting
        PUSH    {R4, LR}

        MOVW    R4, #COLOR_ORANGE
        BL      TFT_Draw_HeaderBand

        MOVS    R0, #16
        MOVS    R1, #8
        MOVW    R2, #:LOWER16:StrWaiting
        MOVT    R2, #:UPPER16:StrWaiting
        MOVW    R3, #COLOR_BLACK
        BL      TFT_Draw_String2x

        BL      TFT_Draw_Robo_Frame_Normal
        BL      TFT_Draw_Robo_Face_Sleepy

        MOVS    R0, #44
        MOVS    R1, #82
        MOVS    R2, #232
        MOVS    R3, #72
        BL      TFT_Draw_Panel

        MOVS    R0, #74
        MOVS    R1, #108
        MOVW    R2, #:LOWER16:StrWaitingBody
        MOVT    R2, #:UPPER16:StrWaitingBody
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        POP     {R4, PC}

TFT_Render_Med_Alert
        PUSH    {R4, LR}

        MOVW    R4, #COLOR_ORANGE
        BL      TFT_Draw_HeaderBand

        MOVS    R0, #16
        MOVS    R1, #8
        MOVW    R2, #:LOWER16:StrMedAlertHeader
        MOVT    R2, #:UPPER16:StrMedAlertHeader
        MOVW    R3, #COLOR_BLACK
        BL      TFT_Draw_String2x

        BL      TFT_Draw_Robo_Frame_Alert
        BL      TFT_Draw_Robo_Face_Worried

        MOVS    R0, #28
        MOVS    R1, #76
        MOVW    R2, #264
        MOVS    R3, #88
        BL      TFT_Draw_Panel

        MOVS    R0, #82
        MOVS    R1, #98
        MOVW    R2, #:LOWER16:StrMedAlertBody
        MOVT    R2, #:UPPER16:StrMedAlertBody
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        MOVS    R0, #64
        MOVS    R1, #126
        MOVW    R2, #:LOWER16:StrMedAlertKeys
        MOVT    R2, #:UPPER16:StrMedAlertKeys
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        POP     {R4, PC}

TFT_Render_Med_Dispense
TFT_Render_Med_Despense
        PUSH    {R4, LR}

        MOVW    R4, #COLOR_ORANGE
        BL      TFT_Draw_HeaderBand

        MOVS    R0, #16
        MOVS    R1, #8
        MOVW    R2, #:LOWER16:StrDispense
        MOVT    R2, #:UPPER16:StrDispense
        MOVW    R3, #COLOR_BLACK
        BL      TFT_Draw_String2x

        BL      TFT_Draw_Robo_Frame_Normal
        BL      TFT_Draw_Robo_Face_Happy

        MOVS    R0, #40
        MOVS    R1, #82
        MOVS    R2, #240
        MOVS    R3, #70
        BL      TFT_Draw_Panel

        MOVS    R0, #76
        MOVS    R1, #108
        MOVW    R2, #:LOWER16:StrDispenseBody
        MOVT    R2, #:UPPER16:StrDispenseBody
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        POP     {R4, PC}

;-----------------------------------------------------------------------------
; Smoke alert Robo
; Red angry Robo face for smoke alert
;-----------------------------------------------------------------------------
TFT_Draw_Robo_Smoke_Alert
        PUSH    {LR}

        ; outer Robo frame
        MOVW    R4, #COLOR_RED
        MOVW    R0, #238
        MOVS    R1, #8
        MOVS    R2, #64
        MOVS    R3, #16
        BL      TFT_Draw_Rect

        ; clear inside only
        MOVW    R4, #COLOR_BLACK
        MOVW    R0, #240
        MOVS    R1, #10
        MOVS    R2, #60
        MOVS    R3, #12
        BL      TFT_Fill_Rect

        ; left angry eye
        MOVW    R4, #COLOR_RED
        MOVW    R0, #252
        MOVS    R1, #13
        MOVS    R2, #4
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        MOVW    R0, #255
        MOVS    R1, #14
        MOVS    R2, #4
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        MOVW    R0, #258
        MOVS    R1, #15
        MOVS    R2, #4
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        ; right angry eye
        MOVW    R0, #276
        MOVS    R1, #15
        MOVS    R2, #4
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        MOVW    R0, #279
        MOVS    R1, #14
        MOVS    R2, #4
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        MOVW    R0, #282
        MOVS    R1, #13
        MOVS    R2, #4
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        ; angry mouth
        MOVW    R0, #262
        MOVS    R1, #18
        MOVS    R2, #10
        MOVS    R3, #1
        BL      TFT_Fill_Rect

        POP     {PC}


;-----------------------------------------------------------------------------
; No-smoking sign
; Box-style icon for smoke alert
;-----------------------------------------------------------------------------
TFT_Draw_NoSmoking_Sign
        PUSH    {R5, LR}

        ; clear sign area
        MOVW    R4, #COLOR_BLACK
        MOVS    R0, #78
        MOVS    R1, #82
        MOVS    R2, #120
        MOVS    R3, #86
        BL      TFT_Fill_Rect

        ; sign border
        MOVW    R4, #COLOR_WHITE
        MOVS    R0, #88
        MOVS    R1, #92
        MOVS    R2, #96
        MOVS    R3, #68
        BL      TFT_Draw_Rect

        ; cigarette body
        MOVW    R4, #COLOR_WHITE
        MOVS    R0, #108
        MOVS    R1, #122
        MOVS    R2, #34
        MOVS    R3, #6
        BL      TFT_Fill_Rect

        ; ember
        MOVW    R4, #COLOR_ORANGE
        MOVS    R0, #142
        MOVS    R1, #122
        MOVS    R2, #6
        MOVS    R3, #6
        BL      TFT_Fill_Rect

        ; smoke
        MOVW    R4, #COLOR_WHITE
        MOVS    R0, #110
        MOVS    R1, #110
        MOVS    R2, #4
        MOVS    R3, #4
        BL      TFT_Fill_Rect

        MOVS    R0, #118
        MOVS    R1, #104
        MOVS    R2, #4
        MOVS    R3, #4
        BL      TFT_Fill_Rect

        MOVS    R0, #126
        MOVS    R1, #110
        MOVS    R2, #4
        MOVS    R3, #4
        BL      TFT_Fill_Rect

        ; red slash
        MOVW    R4, #COLOR_RED
        MOVS    R5, #0

NoSmoke_Slash_Loop
        CMP     R5, #46
        BEQ     NoSmoke_Slash_Done

        MOVS    R0, #96
        ADD     R0, R0, R5
        MOVS    R1, #148
        SUB     R1, R1, R5
        MOVS    R2, #3
        MOVS    R3, #3
        BL      TFT_Fill_Rect

        ADDS    R5, R5, #1
        B       NoSmoke_Slash_Loop

NoSmoke_Slash_Done
        POP     {R5, PC}

TFT_Render_Smoke_Alert
TFT_Render_Smoke_ALERT
        PUSH    {R4, LR}

        MOVW    R4, #COLOR_RED
        BL      TFT_Draw_HeaderBand

        MOVS    R0, #16
        MOVS    R1, #8
        MOVW    R2, #:LOWER16:StrSmokeAlert
        MOVT    R2, #:UPPER16:StrSmokeAlert
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        BL      TFT_Draw_Robo_Smoke_Alert
        BL      TFT_Draw_NoSmoking_Sign

        MOVS    R0, #92
        MOVS    R1, #170
        MOVW    R2, #:LOWER16:StrSmokeDanger
        MOVT    R2, #:UPPER16:StrSmokeDanger
        MOVW    R3, #COLOR_WHITE
        BL      TFT_Draw_String2x

        BL      TFT_Draw_Smoke_Bar_Frame

        POP     {R4, PC}

;-----------------------------------------------------------------------------
; Partial update functions
;-----------------------------------------------------------------------------
TFT_Update_Smoke_Level
        PUSH    {R4-R7, LR}

        MOV     R5, R2
        LSRS    R5, R5, #4

        MOVS    R0, #SMOKE_INNER_W
        CMP     R5, R0
        BLS     Smoke_Clamp_Done
        MOV     R5, R0

Smoke_Clamp_Done
        MOVW    R4, #COLOR_BLACK
        MOVS    R0, #SMOKE_INNER_X
        MOVS    R1, #SMOKE_INNER_Y
        MOVS    R2, #SMOKE_INNER_W
        MOVS    R3, #SMOKE_INNER_H
        BL      TFT_Fill_Rect

        CMP     R5, #0
        BEQ     Smoke_Draw_Animation

        CMP     R5, #66
        BLS     Smoke_Green
        CMP     R5, #132
        BLS     Smoke_Yellow
        MOVW    R4, #COLOR_RED
        B       Smoke_Draw

Smoke_Green
        MOVW    R4, #COLOR_GREEN
        B       Smoke_Draw

Smoke_Yellow
        MOVW    R4, #COLOR_YELLOW

Smoke_Draw
        MOVS    R0, #SMOKE_INNER_X
        MOVS    R1, #SMOKE_INNER_Y
        MOV     R2, R5
        MOVS    R3, #SMOKE_INNER_H
        BL      TFT_Fill_Rect

Smoke_Draw_Animation
        MOVW    R0, #:LOWER16:g_sys_state
        MOVT    R0, #:UPPER16:g_sys_state
        LDR     R0, [R0]
        CMP     R0, #STATE_MAIN_MENU
        BEQ     Smoke_Update_Menu
        B       Smoke_Done

Smoke_Update_Menu
        BL      TFT_Draw_Robo_MainMenuFace

Smoke_Done
        POP     {R4-R7, PC}

TFT_Update_Heart_Values
        PUSH    {R4-R7, LR}

        MOV     R6, R2
        MOV     R7, R3

        MOVW    R4, #COLOR_BLACK
        MOVS    R0, #HEART_BPM_X
        MOVS    R1, #HEART_BPM_Y
        MOVS    R2, #44
        MOVS    R3, #16
        BL      TFT_Fill_Rect

        MOVS    R0, #HEART_SPO2_X
        MOVS    R1, #HEART_SPO2_Y
        MOVS    R2, #56
        MOVS    R3, #16
        BL      TFT_Fill_Rect

        MOVW    R3, #COLOR_WHITE
        MOVS    R0, #HEART_BPM_X
        MOVS    R1, #HEART_BPM_Y
        MOV     R2, R6
        BL      TFT_Draw_Number3_2x

        MOVW    R3, #COLOR_WHITE
        MOVS    R0, #HEART_SPO2_X
        MOVS    R1, #HEART_SPO2_Y
        MOV     R2, R7
        BL      TFT_Draw_Number3_2x

        MOVS    R0, #84
        MOVS    R1, #160
        MOVS    R2, #'%'
        MOVW    R3, #COLOR_WHITE
        BL      GFX_Draw_Char2x

        BL      TFT_Draw_Heart_Icon

        POP     {R4-R7, PC}

TFT_Update_Breathing_Level
        PUSH    {R4-R7, LR}

        MOV     R7, R2

        MOVW    R0, #:LOWER16:g_breath_plot_x
        MOVT    R0, #:UPPER16:g_breath_plot_x
        LDR     R5, [R0]

        MOVS    R0, #BREATH_PLOT_W_LAST
        CMP     R5, R0
        BLO     Breath_X_OK

        MOVS    R5, #0

        MOVW    R4, #COLOR_BLACK
        MOVW    R0, #BREATH_PLOT_X
        MOVW    R1, #BREATH_PLOT_Y
        MOVW    R2, #BREATH_PLOT_W
        MOVW    R3, #BREATH_PLOT_H
        BL      TFT_Fill_Rect

        MOVW    R4, #COLOR_GRAY
        MOVW    R0, #BREATH_PLOT_X
        MOVW    R1, #BREATH_MIDLINE_Y
        MOVW    R2, #BREATH_PLOT_W
        MOVS    R3, #1
        BL      TFT_Fill_Rect

Breath_X_OK
        MOVW    R4, #COLOR_BLACK
        MOVW    R0, #BREATH_PLOT_X
        ADD     R0, R0, R5
        MOVW    R1, #BREATH_PLOT_Y
        MOVS    R2, #1
        MOVW    R3, #BREATH_PLOT_H
        BL      TFT_Fill_Rect

        MOV     R6, R7
        LSRS    R6, R6, #5

        MOVS    R0, #BREATH_PLOT_H_LAST
        CMP     R6, R0
        BLS     Breath_Clamp_OK
        MOV     R6, R0

Breath_Clamp_OK
        MOVS    R1, #BREATH_PLOT_BOTTOM
        SUB     R1, R1, R6

        MOVW    R0, #BREATH_PLOT_X
        ADD     R0, R0, R5
        MOVW    R2, #COLOR_CYAN
        BL      TFT_Draw_Pixel

        ADDS    R1, R1, #1
        MOVW    R0, #BREATH_PLOT_X
        ADD     R0, R0, R5
        MOVW    R2, #COLOR_CYAN
        BL      TFT_Draw_Pixel

        ADDS    R5, R5, #1
        MOVW    R0, #:LOWER16:g_breath_plot_x
        MOVT    R0, #:UPPER16:g_breath_plot_x
        STR     R5, [R0]

        POP     {R4-R7, PC}


;-----------------------------------------------------------------------------
; Strings
;-----------------------------------------------------------------------------
StrMainMenu         DCB     "ROBO MENU",0
StrMenu1            DCB     "1 SANITIZE",0
StrMenu2            DCB     "2 HEART",0
StrMenu3            DCB     "3 BREATH",0
StrMenu4            DCB     "4 MEDICINE",0
StrSmoke            DCB     "SMOKE",0

StrSanHeader        DCB     "SANITIZE",0
StrSanBody          DCB     "SERVO ON",0

StrHeartHeader      DCB     "HEART RATE",0
StrBpmLabel         DCB     "BPM",0
StrSpo2Label        DCB     "SPO2",0

StrBreathHeader     DCB     "BREATH",0
StrBreathBody1      DCB     "LIVE",0
StrBreathBody2      DCB     "WAVE",0

StrMotion           DCB     "MOTION",0
StrMotionBody       DCB     "LINE TRACK",0

StrMedInputHeader   DCB     "MED INPUT",0
StrMedInput1        DCB     "A OK",0
StrMedInput2        DCB     "B CLR",0
StrMedInput3        DCB     "C BACK",0
StrTimerDbg         DCB     "TIMER",0

StrWaiting          DCB     "WAITING",0
StrWaitingBody      DCB     "MED TIMER",0

StrMedAlertHeader   DCB     "MED ALERT",0
StrMedAlertBody     DCB     "TIME NOW",0
StrMedAlertKeys     DCB     "A GO  C BACK",0

StrDispense         DCB     "DISPENSE",0
StrDispenseBody     DCB     "SERVO MOVE",0

StrSmokeAlert       DCB     "SMOKE ALERT",0
StrSmokeDanger      DCB     "DANGER",0

StrExitD            DCB     "D EXIT",0
        ALIGN


;-----------------------------------------------------------------------------
; 5x7 font
;-----------------------------------------------------------------------------
GlyphSpace          DCB     0x00,0x00,0x00,0x00,0x00
GlyphColon          DCB     0x00,0x36,0x36,0x00,0x00
GlyphDash           DCB     0x08,0x08,0x08,0x08,0x08
GlyphSlash          DCB     0x20,0x10,0x08,0x04,0x02
GlyphPercent        DCB     0x63,0x13,0x08,0x64,0x63

FontDigits
        DCB     0x3E,0x51,0x49,0x45,0x3E
        DCB     0x00,0x42,0x7F,0x40,0x00
        DCB     0x42,0x61,0x51,0x49,0x46
        DCB     0x21,0x41,0x45,0x4B,0x31
        DCB     0x18,0x14,0x12,0x7F,0x10
        DCB     0x27,0x45,0x45,0x45,0x39
        DCB     0x3C,0x4A,0x49,0x49,0x30
        DCB     0x01,0x71,0x09,0x05,0x03
        DCB     0x36,0x49,0x49,0x49,0x36
        DCB     0x06,0x49,0x49,0x29,0x1E

FontUpper
        DCB     0x7E,0x11,0x11,0x11,0x7E
        DCB     0x7F,0x49,0x49,0x49,0x36
        DCB     0x3E,0x41,0x41,0x41,0x22
        DCB     0x7F,0x41,0x41,0x22,0x1C
        DCB     0x7F,0x49,0x49,0x49,0x41
        DCB     0x7F,0x09,0x09,0x09,0x01
        DCB     0x3E,0x41,0x49,0x49,0x7A
        DCB     0x7F,0x08,0x08,0x08,0x7F
        DCB     0x00,0x41,0x7F,0x41,0x00
        DCB     0x20,0x40,0x41,0x3F,0x01
        DCB     0x7F,0x08,0x14,0x22,0x41
        DCB     0x7F,0x40,0x40,0x40,0x40
        DCB     0x7F,0x02,0x0C,0x02,0x7F
        DCB     0x7F,0x04,0x08,0x10,0x7F
        DCB     0x3E,0x41,0x41,0x41,0x3E
        DCB     0x7F,0x09,0x09,0x09,0x06
        DCB     0x3E,0x41,0x51,0x21,0x5E
        DCB     0x7F,0x09,0x19,0x29,0x46
        DCB     0x46,0x49,0x49,0x49,0x31
        DCB     0x01,0x01,0x7F,0x01,0x01
        DCB     0x3F,0x40,0x40,0x40,0x3F
        DCB     0x1F,0x20,0x40,0x20,0x1F
        DCB     0x7F,0x20,0x18,0x20,0x7F
        DCB     0x63,0x14,0x08,0x14,0x63
        DCB     0x03,0x04,0x78,0x04,0x03
        DCB     0x61,0x51,0x49,0x45,0x43

        END