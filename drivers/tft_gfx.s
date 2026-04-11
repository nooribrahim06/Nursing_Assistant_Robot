;=============================================================================
; tft_gfx.s
; High-level TFT rendering layer
;=============================================================================

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
        IMPORT  g_hr_red_raw
        IMPORT  g_hr_ir_raw
        IMPORT  g_bpm
        IMPORT  g_spo2
        IMPORT  TFT_SetAddressWindow
        IMPORT  TFT_WriteData16
	    IMPORT  g_med_timer
			

TFT_WIDTH           EQU     240
TFT_HEIGHT          EQU     320

HEADER_H            EQU     40

COLOR_BLACK         EQU     0x0000
COLOR_WHITE         EQU     0xFFFF
COLOR_RED           EQU     0xF800
COLOR_GREEN         EQU     0x07E0
COLOR_BLUE          EQU     0x001F
COLOR_YELLOW        EQU     0xFFE0
COLOR_CYAN          EQU     0x07FF
COLOR_ORANGE        EQU     0xFD20
COLOR_MAGENTA       EQU     0xF81F

SMOKE_OUTER_X       EQU     20
SMOKE_OUTER_Y       EQU     285
SMOKE_OUTER_W       EQU     200
SMOKE_OUTER_H       EQU     18

SMOKE_INNER_X       EQU     21
SMOKE_INNER_Y       EQU     286
SMOKE_INNER_W       EQU     198
SMOKE_INNER_H       EQU     16

BREATH_BOX_X        EQU     15
BREATH_BOX_Y        EQU     85
BREATH_BOX_W        EQU     210
BREATH_BOX_H        EQU     160

BREATH_WAVE_X       EQU     20
BREATH_WAVE_Y       EQU     120
BREATH_WAVE_W       EQU     200
BREATH_WAVE_H       EQU     100

CHAR_ADVANCE        EQU     6

        AREA    TFT_GFX_DATA, DATA, READWRITE
        ALIGN
g_breath_plot_x     SPACE   4

        AREA    TFT_GFX, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

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

GFX_GetGlyphPtr
        PUSH    {R1-R3, LR}

        CMP     R0, #' '
        BEQ     Glyph_Space_Label

        CMP     R0, #'0'
        BLO     Check_Colon
        CMP     R0, #'9'
        BHI     Check_Colon
        SUB     R1, R0, #'0'
        LDR     R0, =FontDigits
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
        LDR     R0, =FontUpper
        MOVS    R2, #5
        MUL     R1, R2, R1
        ADD     R0, R0, R1
        POP     {R1-R3, PC}

Glyph_Space_Label
        LDR     R0, =GlyphSpace
        POP     {R1-R3, PC}

Glyph_Colon_Label
        LDR     R0, =GlyphColon
        POP     {R1-R3, PC}

Glyph_Dash_Label
        LDR     R0, =GlyphDash
        POP     {R1-R3, PC}

Glyph_Slash_Label
        LDR     R0, =GlyphSlash
        POP     {R1-R3, PC}

Glyph_Percent_Label
        LDR     R0, =GlyphPercent
        POP     {R1-R3, PC}

GFX_Draw_Char
        PUSH    {R4-R11, LR}

        MOV     R8, R0
        MOV     R9, R1
        MOV     R10, R3

        MOV     R0, R2
        BL      GFX_GetGlyphPtr
        MOV     R11, R0

        MOVS    R4, #0

Char_Col_Loop
        CMP     R4, #5
        BEQ     Char_Done

        LDRB    R5, [R11, R4]
        MOVS    R6, #0

Char_Row_Loop
        CMP     R6, #7
        BEQ     Next_Col

        MOVS    R7, #1
        LSLS    R7, R7, R6
        TST     R5, R7
        BEQ     Skip_Pixel

        ADD     R0, R8, R4
        ADD     R1, R9, R6
        MOV     R2, R10
        BL      TFT_Draw_Pixel

Skip_Pixel
        ADDS    R6, R6, #1
        B       Char_Row_Loop

Next_Col
        ADDS    R4, R4, #1
        B       Char_Col_Loop

Char_Done
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

TFT_Draw_Number3
        PUSH    {R4-R9, LR}

        MOV     R4, R0
        MOV     R5, R1
        MOV     R6, R2
        MOV     R7, R3

        LDR     R0, =999
        CMP     R6, R0
        BLS     Num3_ClampDone
        MOV     R6, R0

Num3_ClampDone
        MOVS    R8, #0
Num3_Hundreds
        CMP     R6, #100
        BLO     Num3_HundredsDone
        SUBS    R6, R6, #100
        ADDS    R8, R8, #1
        B       Num3_Hundreds

Num3_HundredsDone
        MOVS    R9, #0
Num3_Tens
        CMP     R6, #10
        BLO     Num3_TensDone
        SUBS    R6, R6, #10
        ADDS    R9, R9, #1
        B       Num3_Tens

Num3_TensDone
        MOV     R0, R4
        MOV     R1, R5
        ADDS    R2, R8, #'0'
        MOV     R3, R7
        BL      GFX_Draw_Char

        MOV     R0, R4
        ADDS    R0, R0, #CHAR_ADVANCE
        MOV     R1, R5
        ADDS    R2, R9, #'0'
        MOV     R3, R7
        BL      GFX_Draw_Char

        MOV     R0, R4
        ADDS    R0, R0, #(CHAR_ADVANCE * 2)
        MOV     R1, R5
        ADDS    R2, R6, #'0'
        MOV     R3, R7
        BL      GFX_Draw_Char

        POP     {R4-R9, PC}

TFT_Draw_Number6
        PUSH    {R4-R11, LR}

        MOV     R4, R0
        MOV     R5, R1
        MOV     R6, R2
        MOV     R7, R3

        LDR     R0, =262143
        CMP     R6, R0
        BLS     Num6_ClampDone
        MOV     R6, R0

Num6_ClampDone
        MOVS    R8, #0
Num6_D1
        LDR     R0, =100000
        CMP     R6, R0
        BLO     Num6_D1Done
        SUB     R6, R6, R0
        ADDS    R8, R8, #1
        B       Num6_D1
Num6_D1Done

        MOVS    R9, #0
Num6_D2
        LDR     R0, =10000
        CMP     R6, R0
        BLO     Num6_D2Done
        SUB     R6, R6, R0
        ADDS    R9, R9, #1
        B       Num6_D2
Num6_D2Done

        MOVS    R10, #0
Num6_D3
        LDR     R0, =1000
        CMP     R6, R0
        BLO     Num6_D3Done
        SUB     R6, R6, R0
        ADDS    R10, R10, #1
        B       Num6_D3
Num6_D3Done

        MOVS    R11, #0
Num6_D4
        MOVS    R0, #100
        CMP     R6, R0
        BLO     Num6_D4Done
        SUBS    R6, R6, #100
        ADDS    R11, R11, #1
        B       Num6_D4
Num6_D4Done

        MOVS    R12, #0
Num6_D5
        MOVS    R0, #10
        CMP     R6, R0
        BLO     Num6_D5Done
        SUBS    R6, R6, #10
        ADDS    R12, R12, #1
        B       Num6_D5
Num6_D5Done

        MOV     R0, R4
        MOV     R1, R5
        ADDS    R2, R8, #'0'
        MOV     R3, R7
        BL      GFX_Draw_Char

        MOV     R0, R4
        ADDS    R0, R0, #6
        MOV     R1, R5
        ADDS    R2, R9, #'0'
        MOV     R3, R7
        BL      GFX_Draw_Char

        MOV     R0, R4
        ADDS    R0, R0, #12
        MOV     R1, R5
        ADDS    R2, R10, #'0'
        MOV     R3, R7
        BL      GFX_Draw_Char

        MOV     R0, R4
        ADDS    R0, R0, #18
        MOV     R1, R5
        ADDS    R2, R11, #'0'
        MOV     R3, R7
        BL      GFX_Draw_Char

        MOV     R0, R4
        ADDS    R0, R0, #24
        MOV     R1, R5
        ADDS    R2, R12, #'0'
        MOV     R3, R7
        BL      GFX_Draw_Char

        MOV     R0, R4
        ADDS    R0, R0, #30
        MOV     R1, R5
        ADDS    R2, R6, #'0'
        MOV     R3, R7
        BL      GFX_Draw_Char

        POP     {R4-R11, PC}

TFT_Draw_Header
        PUSH    {LR}

        MOVS    R0, #0
        MOVS    R1, #0
        LDR     R2, =TFT_WIDTH
        MOVS    R3, #HEADER_H
        BL      TFT_Fill_Rect

        POP     {PC}

TFT_Clear_Screen
        PUSH    {R4, LR}

        LDR     R4, =COLOR_BLACK
        MOVS    R0, #0
        MOVS    R1, #0
        LDR     R2, =TFT_WIDTH
        LDR     R3, =TFT_HEIGHT
        BL      TFT_Fill_Rect

        POP     {R4, PC}

TFT_Render_Main_Menu
        PUSH    {R4, LR}

        LDR     R4, =COLOR_BLUE
        BL      TFT_Draw_Header

        MOVS    R0, #78
        MOVS    R1, #15
        LDR     R2, =StrMainMenu
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        LDR     R4, =COLOR_WHITE

        MOVS    R0, #20
        MOVS    R1, #60
        LDR     R2, =200
        MOVS    R3, #30
        BL      TFT_Draw_Rect

        MOVS    R0, #20
        MOVS    R1, #100
        LDR     R2, =200
        MOVS    R3, #30
        BL      TFT_Draw_Rect

        MOVS    R0, #20
        MOVS    R1, #140
        LDR     R2, =200
        MOVS    R3, #30
        BL      TFT_Draw_Rect

        MOVS    R0, #20
        MOVS    R1, #180
        LDR     R2, =200
        MOVS    R3, #30
        BL      TFT_Draw_Rect

        MOVS    R0, #30
        MOVS    R1, #72
        LDR     R2, =StrMenu1
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        MOVS    R0, #30
        MOVS    R1, #112
        LDR     R2, =StrMenu2
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        MOVS    R0, #30
        MOVS    R1, #152
        LDR     R2, =StrMenu3
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        MOVS    R0, #30
        MOVS    R1, #192
        LDR     R2, =StrMenu4
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        LDR     R4, =COLOR_WHITE
        MOVS    R0, #SMOKE_OUTER_X
        LDR     R1, =SMOKE_OUTER_Y
        MOVS    R2, #SMOKE_OUTER_W
        MOVS    R3, #SMOKE_OUTER_H
        BL      TFT_Draw_Rect

        MOVS    R0, #20
        LDR     R1, =270
        LDR     R2, =StrSmoke
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        POP     {R4, PC}

        LTORG

TFT_Render_Sanitizing
        PUSH    {R4, LR}

        LDR     R4, =COLOR_GREEN
        BL      TFT_Draw_Header

        MOVS    R0, #55
        MOVS    R1, #15
        LDR     R2, =StrSanHeader
        LDR     R3, =COLOR_BLACK
        BL      TFT_Draw_String

        LDR     R4, =COLOR_GREEN
        MOVS    R0, #30
        MOVS    R1, #90
        LDR     R2, =180
        LDR     R3, =80
        BL      TFT_Draw_Rect

        MOVS    R0, #55
        MOVS    R1, #120
        LDR     R2, =StrSanBody
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        MOVS    R0, #55
        MOVS    R1, #220
        LDR     R2, =StrExitD
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        POP     {R4, PC}

TFT_Render_Heart_Rate
        PUSH    {R4, LR}

        LDR     R4, =COLOR_RED
        BL      TFT_Draw_Header

        MOVS    R0, #50
        MOVS    R1, #15
        LDR     R2, =StrHeartHeader
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        LDR     R4, =COLOR_RED
        MOVS    R0, #20
        MOVS    R1, #70
        LDR     R2, =200
        LDR     R3, =140
        BL      TFT_Draw_Rect

        MOVS    R0, #35
        MOVS    R1, #100
        LDR     R2, =StrBpmLabel
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        MOVS    R0, #35
        MOVS    R1, #150
        LDR     R2, =StrSpo2Label
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        LDR     R2, =g_bpm
        LDR     R2, [R2]

        LDR     R3, =g_spo2
        LDR     R3, [R3]

        BL      TFT_Update_Heart_Values

        MOVS    R0, #55
        MOVS    R1, #230
        LDR     R2, =StrExitD
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        POP     {R4, PC}

        LTORG

TFT_Render_Breathing
        PUSH    {R4, LR}

        LDR     R4, =COLOR_CYAN
        BL      TFT_Draw_Header

        MOVS    R0, #55
        MOVS    R1, #15
        LDR     R2, =StrBreathHeader
        LDR     R3, =COLOR_BLACK
        BL      TFT_Draw_String

        LDR     R4, =COLOR_CYAN
        MOVS    R0, #BREATH_BOX_X
        MOVS    R1, #BREATH_BOX_Y
        LDR     R2, =BREATH_BOX_W
        LDR     R3, =BREATH_BOX_H
        BL      TFT_Draw_Rect

        MOVS    R0, #25
        MOVS    R1, #95
        LDR     R2, =StrBreathBody1
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        MOVS    R0, #25
        MOVS    R1, #108
        LDR     R2, =StrBreathBody2
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        LDR     R4, =COLOR_WHITE
        MOVS    R0, #BREATH_WAVE_X
        MOVS    R1, #BREATH_WAVE_Y
        LDR     R2, =BREATH_WAVE_W
        LDR     R3, =BREATH_WAVE_H
        BL      TFT_Draw_Rect

        LDR     R4, =COLOR_BLACK
        MOVS    R0, #21
        MOVS    R1, #121
        LDR     R2, =198
        LDR     R3, =98
        BL      TFT_Fill_Rect

        LDR     R0, =g_breath_plot_x
        MOVS    R1, #0
        STR     R1, [R0]

        MOVS    R0, #55
        MOVS    R1, #260
        LDR     R2, =StrExitD
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        POP     {R4, PC}

TFT_Render_Motion
        PUSH    {R4, LR}

        LDR     R4, =COLOR_MAGENTA
        BL      TFT_Draw_Header

        MOVS    R0, #85
        MOVS    R1, #15
        LDR     R2, =StrMotion
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        LDR     R4, =COLOR_MAGENTA
        MOVS    R0, #30
        MOVS    R1, #110
        LDR     R2, =180
        MOVS    R3, #90
        BL      TFT_Draw_Rect

        POP     {R4, PC}

        LTORG

TFT_Render_Med_Input
        PUSH    {R4, LR}

        LDR     R4, =COLOR_YELLOW
        BL      TFT_Draw_Header

        MOVS    R0, #50
        MOVS    R1, #15
        LDR     R2, =StrMedInputHeader
        LDR     R3, =COLOR_BLACK
        BL      TFT_Draw_String

        LDR     R4, =COLOR_YELLOW
        MOVS    R0, #25
        MOVS    R1, #100
        LDR     R2, =190
        LDR     R3, =110
        BL      TFT_Draw_Rect

        MOVS    R0, #40
        MOVS    R1, #120
        LDR     R2, =StrMedInput1
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        MOVS    R0, #40
        MOVS    R1, #140
        LDR     R2, =StrMedInput2
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        MOVS    R0, #40
        MOVS    R1, #160
        LDR     R2, =StrMedInput3
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        ; ---- DEBUG LABEL ----
        MOVS    R0, #40
        MOVS    R1, #185
        LDR     R2, =StrTimerDbg
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        ; ---- DEBUG VALUE: g_med_timer ----
        LDR     R2, =g_med_timer
        LDR     R2, [R2]
        MOVS    R0, #95
        MOVS    R1, #185
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_Number6

        POP     {R4, PC}

TFT_Render_Med_Waiting
        PUSH    {R4, LR}

        LDR     R4, =COLOR_YELLOW
        BL      TFT_Draw_Header

        MOVS    R0, #75
        MOVS    R1, #15
        LDR     R2, =StrWaiting
        LDR     R3, =COLOR_BLACK
        BL      TFT_Draw_String

        POP     {R4, PC}

TFT_Render_Med_Alert
        PUSH    {R4, LR}

        LDR     R4, =COLOR_ORANGE
        BL      TFT_Draw_Header

        MOVS    R0, #55
        MOVS    R1, #15
        LDR     R2, =StrMedAlertHeader
        LDR     R3, =COLOR_BLACK
        BL      TFT_Draw_String

        LDR     R4, =COLOR_ORANGE
        MOVS    R0, #25
        MOVS    R1, #100
        LDR     R2, =190
        LDR     R3, =110
        BL      TFT_Draw_Rect

        MOVS    R0, #40
        MOVS    R1, #130
        LDR     R2, =StrMedAlertBody
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        POP     {R4, PC}

        LTORG

TFT_Render_Med_Dispense
TFT_Render_Med_Despense
        PUSH    {R4, LR}

        LDR     R4, =COLOR_ORANGE
        BL      TFT_Draw_Header

        MOVS    R0, #45
        MOVS    R1, #15
        LDR     R2, =StrDispense
        LDR     R3, =COLOR_BLACK
        BL      TFT_Draw_String

        POP     {R4, PC}

TFT_Render_Smoke_Alert
TFT_Render_Smoke_ALERT
        PUSH    {R4, LR}

        LDR     R4, =COLOR_RED
        BL      TFT_Draw_Header

        MOVS    R0, #50
        MOVS    R1, #15
        LDR     R2, =StrSmokeAlert
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        LDR     R4, =COLOR_RED
        MOVS    R0, #20
        MOVS    R1, #90
        LDR     R2, =200
        LDR     R3, =110
        BL      TFT_Draw_Rect

        MOVS    R0, #70
        MOVS    R1, #130
        LDR     R2, =StrSmokeDanger
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_String

        LDR     R4, =COLOR_WHITE
        MOVS    R0, #SMOKE_OUTER_X
        LDR     R1, =SMOKE_OUTER_Y
        MOVS    R2, #SMOKE_OUTER_W
        MOVS    R3, #SMOKE_OUTER_H
        BL      TFT_Draw_Rect

        POP     {R4, PC}

TFT_Update_Smoke_Level
        PUSH    {R4, R5, LR}

        MOV     R5, R2
        LSRS    R5, R5, #4

        CMP     R5, #198
        BLS     Smoke_Clamp_Done
        MOVS    R5, #198

Smoke_Clamp_Done
        LDR     R4, =COLOR_BLACK
        MOVS    R0, #SMOKE_INNER_X
        LDR     R1, =SMOKE_INNER_Y
        MOVS    R2, #SMOKE_INNER_W
        MOVS    R3, #SMOKE_INNER_H
        BL      TFT_Fill_Rect

        CMP     R5, #0
        BEQ     Smoke_Done

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

Smoke_Done
        POP     {R4, R5, PC}

TFT_Update_Heart_Values
        PUSH    {R4-R7, LR}

        MOV     R6, R2
        MOV     R7, R3

        LDR     R4, =COLOR_BLACK
        MOVS    R0, #85
        MOVS    R1, #120
        MOVS    R2, #40
        MOVS    R3, #8
        BL      TFT_Fill_Rect

        LDR     R4, =COLOR_BLACK
        MOVS    R0, #85
        MOVS    R1, #150
        MOVS    R2, #52
        MOVS    R3, #8
        BL      TFT_Fill_Rect

        MOVS    R0, #85
        MOVS    R1, #120
        MOV     R2, R6
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_Number3

        MOVS    R0, #85
        MOVS    R1, #150
        MOV     R2, R7
        LDR     R3, =COLOR_WHITE
        BL      TFT_Draw_Number3

        MOVS    R0, #103
        MOVS    R1, #150
        MOVS    R2, #'%'
        LDR     R3, =COLOR_WHITE
        BL      GFX_Draw_Char

        POP     {R4-R7, PC}

TFT_Update_Breathing_Level
        PUSH    {R4-R7, LR}

        MOV     R7, R2

        LDR     R0, =g_breath_plot_x
        LDR     R5, [R0]

        CMP     R5, #198
        BLO     Breath_X_OK

        MOVS    R5, #0

        LDR     R4, =COLOR_BLACK
        MOVS    R0, #21
        MOVS    R1, #121
        LDR     R2, =198
        LDR     R3, =98
        BL      TFT_Fill_Rect

Breath_X_OK
        LDR     R4, =COLOR_BLACK
        MOVS    R0, #21
        ADD     R0, R0, R5
        MOVS    R1, #121
        MOVS    R2, #1
        LDR     R3, =98
        BL      TFT_Fill_Rect

        MOV     R6, R7
        LSRS    R6, R6, #5
        CMP     R6, #97
        BLS     Breath_Clamp_OK
        MOVS    R6, #97

Breath_Clamp_OK
        LDR     R1, =218
        SUB     R1, R1, R6

        MOVS    R0, #21
        ADD     R0, R0, R5
        LDR     R2, =COLOR_CYAN
        BL      TFT_Draw_Pixel

        ADDS    R1, R1, #1
        MOVS    R0, #21
        ADD     R0, R0, R5
        LDR     R2, =COLOR_CYAN
        BL      TFT_Draw_Pixel

        ADDS    R5, R5, #1
        LDR     R0, =g_breath_plot_x
        STR     R5, [R0]

        POP     {R4-R7, PC}

        LTORG

StrMainMenu         DCB "MAIN MENU",0
StrMenu1            DCB "1 SANITIZING",0
StrMenu2            DCB "2 HEART RATE",0
StrMenu3            DCB "3 BREATHING",0
StrMenu4            DCB "4 MED INPUT",0
StrSmoke            DCB "SMOKE",0

StrSanHeader        DCB "SANITIZING",0
StrSanBody          DCB "SERVO ACTIVE",0

StrHeartHeader      DCB "HEART RATE",0
StrHeartBody1       DCB "PLACE FINGER",0
StrHeartBody2       DCB "SENSOR READY",0
StrBpmLabel         DCB "BPM",0
StrSpo2Label        DCB "SPO2",0

StrBreathHeader     DCB "BREATHING",0
StrBreathBody1      DCB "WAVEFORM MODE",0
StrBreathBody2      DCB "SIGNAL ON PA0",0

StrMotion           DCB "MOTION",0

StrMedInputHeader   DCB "MED INPUT",0
StrMedInput1        DCB "A CONFIRM",0
StrMedInput2        DCB "B CLEAR",0
StrMedInput3        DCB "C BACK",0

StrWaiting          DCB "WAITING",0
StrMedAlertHeader   DCB "MED ALERT",0
StrMedAlertBody     DCB "A OK  C BACK",0
StrDispense         DCB "DISPENSING",0

StrSmokeAlert       DCB "SMOKE ALERT",0
StrSmokeDanger      DCB "DANGER",0

StrExitD            DCB "D EXIT",0
StrTimerDbg         DCB "TIMER",0
        ALIGN

GlyphSpace          DCB 0x00,0x00,0x00,0x00,0x00
GlyphColon          DCB 0x00,0x36,0x36,0x00,0x00
GlyphDash           DCB 0x08,0x08,0x08,0x08,0x08
GlyphSlash          DCB 0x20,0x10,0x08,0x04,0x02
GlyphPercent        DCB 0x63,0x13,0x08,0x64,0x63

FontDigits
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

FontUpper
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
        DCB 0x7F,0x20,0x18,0x20,0x7F
        DCB 0x63,0x14,0x08,0x14,0x63
        DCB 0x03,0x04,0x78,0x04,0x03
        DCB 0x61,0x51,0x49,0x45,0x43

        END