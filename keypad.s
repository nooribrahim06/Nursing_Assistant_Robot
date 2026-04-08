; =============================================================================
; FILE: keypad.s
; 4x4 Matrix Keypad Scanner
;
; ACTUAL WIRING:
;   Rows (outputs, driven LOW one at a time):
;       R1 -> PA8
;       R2 -> PA9
;       R3 -> PA10
;       R4 -> PA11
;
;   Columns (inputs with pull-up):
;       C1 -> PB8
;       C2 -> PB13
;       C3 -> PB14
;       C4 -> PB15
;
; KEY MAP:
;       C1  C2  C3  C4
; R1:   1   2   3   A
; R2:   4   5   6   B
; R3:   7   8   9   C
; R4:   *   0   #   D
; =============================================================================

        INCLUDE constants.s

        AREA    KEYPAD_CODE, CODE, READONLY
        THUMB

        EXPORT  Keypad_Init
        EXPORT  Keypad_Scan

        IMPORT  g_keycode

        IMPORT  GPIO_EnableClock
        IMPORT  GPIO_ConfigOutput
        IMPORT  GPIO_ConfigInput
        IMPORT  GPIO_WritePin
        IMPORT  GPIO_ClearPin

OFF_GPIO_PUPDR      EQU     0x0C
OFF_GPIO_IDR        EQU     0x10

; =============================================================================
; Keypad_Init
; =============================================================================
Keypad_Init
        PUSH    {R4, LR}

        ; Enable GPIOA and GPIOB clocks
        LDR     R0, =GPIOA_BASE
        BL      GPIO_EnableClock
        LDR     R0, =GPIOB_BASE
        BL      GPIO_EnableClock

        ; ---------------- Rows: PA8, PA9, PA10, PA11 as outputs ----------------
        LDR     R0, =GPIOA_BASE
        MOVS    R1, #8
        BL      GPIO_ConfigOutput
        LDR     R0, =GPIOA_BASE
        MOVS    R1, #9
        BL      GPIO_ConfigOutput
        LDR     R0, =GPIOA_BASE
        MOVS    R1, #10
        BL      GPIO_ConfigOutput
        LDR     R0, =GPIOA_BASE
        MOVS    R1, #11
        BL      GPIO_ConfigOutput

        ; ---------------- Cols: PB8, PB13, PB14, PB15 as inputs ----------------
        LDR     R0, =GPIOB_BASE
        MOVS    R1, #8
        BL      GPIO_ConfigInput
        LDR     R0, =GPIOB_BASE
        MOVS    R1, #13
        BL      GPIO_ConfigInput
        LDR     R0, =GPIOB_BASE
        MOVS    R1, #14
        BL      GPIO_ConfigInput
        LDR     R0, =GPIOB_BASE
        MOVS    R1, #15
        BL      GPIO_ConfigInput

        ; ---------------- Enable pull-up on PB8, PB13, PB14, PB15 ----------------
        LDR     R4, =GPIOB_BASE
        LDR     R0, [R4, #OFF_GPIO_PUPDR]

        ; clear bits for PB8 / PB13 / PB14 / PB15
        LDR     R1, =0xFC030000
        BIC     R0, R0, R1

        ; set them to 01 (pull-up)
        LDR     R1, =0x54010000
        ORR     R0, R0, R1

        STR     R0, [R4, #OFF_GPIO_PUPDR]

        ; ---------------- Idle: all rows HIGH ----------------
        LDR     R0, =GPIOA_BASE
        MOVS    R1, #8
        BL      GPIO_WritePin
        LDR     R0, =GPIOA_BASE
        MOVS    R1, #9
        BL      GPIO_WritePin
        LDR     R0, =GPIOA_BASE
        MOVS    R1, #10
        BL      GPIO_WritePin
        LDR     R0, =GPIOA_BASE
        MOVS    R1, #11
        BL      GPIO_WritePin

        POP     {R4, PC}

; =============================================================================
; Keypad_Scan
; =============================================================================
Keypad_Scan
        PUSH    {R4-R7, LR}

        LDR     R4, =GPIOA_BASE      ; rows
        LDR     R5, =GPIOB_BASE      ; cols
        LDR     R6, =g_keycode

        ; default = no key
        MOVS    R0, #KEY_NONE
        STR     R0, [R6]

        ; ================= ROW 1 : PA8 =================
        BL      KP_AllRowsHigh
        MOV     R0, R4
        MOVS    R1, #8
        BL      GPIO_ClearPin
        BL      KP_Delay
        LDR     R7, [R5, #OFF_GPIO_IDR]

        TST     R7, #(1 << 8)
        BEQ     KP_Key1
        TST     R7, #(1 << 13)
        BEQ     KP_Key2
        TST     R7, #(1 << 14)
        BEQ     KP_Key3
        TST     R7, #(1 << 15)
        BEQ     KP_KeyA

        ; ================= ROW 2 : PA9 =================
        BL      KP_AllRowsHigh
        MOV     R0, R4
        MOVS    R1, #9
        BL      GPIO_ClearPin
        BL      KP_Delay
        LDR     R7, [R5, #OFF_GPIO_IDR]

        TST     R7, #(1 << 8)
        BEQ     KP_Key4
        TST     R7, #(1 << 13)
        BEQ     KP_Key5
        TST     R7, #(1 << 14)
        BEQ     KP_Key6
        TST     R7, #(1 << 15)
        BEQ     KP_KeyB

        ; ================= ROW 3 : PA10 =================
        BL      KP_AllRowsHigh
        MOV     R0, R4
        MOVS    R1, #10
        BL      GPIO_ClearPin
        BL      KP_Delay
        LDR     R7, [R5, #OFF_GPIO_IDR]

        TST     R7, #(1 << 8)
        BEQ     KP_Key7
        TST     R7, #(1 << 13)
        BEQ     KP_Key8
        TST     R7, #(1 << 14)
        BEQ     KP_Key9
        TST     R7, #(1 << 15)
        BEQ     KP_KeyC

        ; ================= ROW 4 : PA11 =================
        BL      KP_AllRowsHigh
        MOV     R0, R4
        MOVS    R1, #11
        BL      GPIO_ClearPin
        BL      KP_Delay
        LDR     R7, [R5, #OFF_GPIO_IDR]

        TST     R7, #(1 << 8)
        BEQ     KP_KeyStar
        TST     R7, #(1 << 13)
        BEQ     KP_Key0
        TST     R7, #(1 << 14)
        BEQ     KP_KeyHash
        TST     R7, #(1 << 15)
        BEQ     KP_KeyD

        B       KP_Scan_Done

KP_Key1
        MOVS    R0, #KEY_1
        B       KP_Store
KP_Key2
        MOVS    R0, #KEY_2
        B       KP_Store
KP_Key3
        MOVS    R0, #KEY_3
        B       KP_Store
KP_KeyA
        MOVS    R0, #KEY_A
        B       KP_Store

KP_Key4
        MOVS    R0, #KEY_4
        B       KP_Store
KP_Key5
        MOVS    R0, #KEY_5
        B       KP_Store
KP_Key6
        MOVS    R0, #KEY_6
        B       KP_Store
KP_KeyB
        MOVS    R0, #KEY_B
        B       KP_Store

KP_Key7
        MOVS    R0, #KEY_7
        B       KP_Store
KP_Key8
        MOVS    R0, #KEY_8
        B       KP_Store
KP_Key9
        MOVS    R0, #KEY_9
        B       KP_Store
KP_KeyC
        MOVS    R0, #KEY_C
        B       KP_Store

KP_KeyStar
        MOVS    R0, #KEY_STAR
        B       KP_Store
KP_Key0
        MOVS    R0, #KEY_0
        B       KP_Store
KP_KeyHash
        MOVS    R0, #KEY_HASH
        B       KP_Store
KP_KeyD
        MOVS    R0, #KEY_D
        B       KP_Store

KP_Store
        STR     R0, [R6]

KP_Scan_Done
        BL      KP_AllRowsHigh
        POP     {R4-R7, PC}

; =============================================================================
; KP_AllRowsHigh
; =============================================================================
KP_AllRowsHigh
        PUSH    {R0, R1, LR}
        LDR     R0, =GPIOA_BASE
        MOVS    R1, #8
        BL      GPIO_WritePin
        LDR     R0, =GPIOA_BASE
        MOVS    R1, #9
        BL      GPIO_WritePin
        LDR     R0, =GPIOA_BASE
        MOVS    R1, #10
        BL      GPIO_WritePin
        LDR     R0, =GPIOA_BASE
        MOVS    R1, #11
        BL      GPIO_WritePin
        POP     {R0, R1, PC}

; =============================================================================
; KP_Delay
; =============================================================================
KP_Delay
        PUSH    {R0, LR}
        MOVS    R0, #20
KP_Delay_Loop
        SUBS    R0, R0, #1
        BNE     KP_Delay_Loop
        POP     {R0, PC}

        ALIGN
        END