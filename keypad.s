; =============================================================================
; FILE: keypad.s
; 4x4 Matrix Keypad Scanner
;
; All pin assignments come from constants.s – change wiring there, not here.
;
; Rows (outputs, driven LOW one at a time) -> GPIOA
;   PA8=ROW1  PA9=ROW2  PA10=ROW3  PA11=ROW4
;
; Columns (inputs, internal pull-up) -> GPIOB
;   PB10=COL1  PB13=COL2  PB14=COL3  PB15=COL4
;
; KEY MAP:
;       COL1  COL2  COL3  COL4
; ROW1:   1     2     3     A
; ROW2:   4     5     6     B
; ROW3:   7     8     9     C
; ROW4:   *     0     #     D
; =============================================================================

        GET     constants.s

        AREA    KEYPAD_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        EXPORT  Keypad_Init
        EXPORT  Keypad_Scan

        IMPORT  g_keycode

        IMPORT  GPIO_EnableClock
        IMPORT  GPIO_ConfigOutput
        IMPORT  GPIO_ConfigInput
        IMPORT  GPIO_WritePin
        IMPORT  GPIO_ClearPin

; =============================================================================
; Keypad_Init
; Configures row pins as outputs and column pins as inputs with pull-up.
; =============================================================================
Keypad_Init
        PUSH    {R4, LR}

        ; Enable clocks (safe to call even if already enabled by TFT_GPIO_Init)
        LDR     R0, =GPIOA_BASE
        BL      GPIO_EnableClock
        LDR     R0, =GPIOB_BASE
        BL      GPIO_EnableClock

        ; Rows as push-pull outputs
        LDR     R0, =GPIOA_BASE
        MOVS    R1, #KEY_ROW1
        BL      GPIO_ConfigOutput
        MOVS    R1, #KEY_ROW2
        BL      GPIO_ConfigOutput
        MOVS    R1, #KEY_ROW3
        BL      GPIO_ConfigOutput
        MOVS    R1, #KEY_ROW4
        BL      GPIO_ConfigOutput

        ; Columns as floating inputs (pull-up applied below)
        LDR     R0, =GPIOB_BASE
        MOVS    R1, #KEY_COL1
        BL      GPIO_ConfigInput
        MOVS    R1, #KEY_COL2
        BL      GPIO_ConfigInput
        MOVS    R1, #KEY_COL3
        BL      GPIO_ConfigInput
        MOVS    R1, #KEY_COL4
        BL      GPIO_ConfigInput

        ; Apply internal pull-up to column pins
        ; KP_PUPDR_CLEAR and KP_PUPDR_SET are pre-computed in constants.s
        ; for the current COL pin assignments.
        LDR     R4, =GPIOB_BASE
        LDR     R0, [R4, #GPIO_PUPDR]
        LDR     R1, =KP_PUPDR_CLEAR
        BIC     R0, R0, R1
        LDR     R1, =KP_PUPDR_SET
        ORR     R0, R0, R1
        STR     R0, [R4, #GPIO_PUPDR]

        ; Leave all rows HIGH (idle/deselect state)
        BL      KP_AllRowsHigh

        POP     {R4, PC}


; =============================================================================
; Keypad_Scan
; Scans all rows and writes the detected key code into g_keycode.
; Writes KEY_NONE when no key is pressed.
; =============================================================================
Keypad_Scan
        PUSH    {R4-R7, LR}

        LDR     R4, =GPIOA_BASE         ; row port
        LDR     R5, =GPIOB_BASE         ; col port
        LDR     R6, =g_keycode

        ; Assume no key pressed
        MOVS    R0, #KEY_NONE
        STR     R0, [R6]

        ; ---- ROW 1  (PA8) ----
        BL      KP_AllRowsHigh
        MOV     R0, R4
        MOVS    R1, #KEY_ROW1
        BL      GPIO_ClearPin
        BL      KP_Delay
        LDR     R7, [R5, #GPIO_IDR]
        TST     R7, #(1 << KEY_COL1)
        BEQ     KP_Set_Key1
        TST     R7, #(1 << KEY_COL2)
        BEQ     KP_Set_Key2
        TST     R7, #(1 << KEY_COL3)
        BEQ     KP_Set_Key3
        TST     R7, #(1 << KEY_COL4)
        BEQ     KP_Set_KeyA

        ; ---- ROW 2  (PA9) ----
        BL      KP_AllRowsHigh
        MOV     R0, R4
        MOVS    R1, #KEY_ROW2
        BL      GPIO_ClearPin
        BL      KP_Delay
        LDR     R7, [R5, #GPIO_IDR]
        TST     R7, #(1 << KEY_COL1)
        BEQ     KP_Set_Key4
        TST     R7, #(1 << KEY_COL2)
        BEQ     KP_Set_Key5
        TST     R7, #(1 << KEY_COL3)
        BEQ     KP_Set_Key6
        TST     R7, #(1 << KEY_COL4)
        BEQ     KP_Set_KeyB

        ; ---- ROW 3  (PA10) ----
        BL      KP_AllRowsHigh
        MOV     R0, R4
        MOVS    R1, #KEY_ROW3
        BL      GPIO_ClearPin
        BL      KP_Delay
        LDR     R7, [R5, #GPIO_IDR]
        TST     R7, #(1 << KEY_COL1)
        BEQ     KP_Set_Key7
        TST     R7, #(1 << KEY_COL2)
        BEQ     KP_Set_Key8
        TST     R7, #(1 << KEY_COL3)
        BEQ     KP_Set_Key9
        TST     R7, #(1 << KEY_COL4)
        BEQ     KP_Set_KeyC

        ; ---- ROW 4  (PA11) ----
        BL      KP_AllRowsHigh
        MOV     R0, R4
        MOVS    R1, #KEY_ROW4
        BL      GPIO_ClearPin
        BL      KP_Delay
        LDR     R7, [R5, #GPIO_IDR]
        TST     R7, #(1 << KEY_COL1)
        BEQ     KP_Set_KeyStar
        TST     R7, #(1 << KEY_COL2)
        BEQ     KP_Set_Key0
        TST     R7, #(1 << KEY_COL3)
        BEQ     KP_Set_KeyHash
        TST     R7, #(1 << KEY_COL4)
        BEQ     KP_Set_KeyD

        B       KP_Scan_Done

; --- Store targets: one per key, each loads the code then falls into KP_Store ---
KP_Set_Key1     MOVS    R0, #KEY_1      
                B       KP_Store
KP_Set_Key2     MOVS    R0, #KEY_2
                B       KP_Store
KP_Set_Key3     MOVS    R0, #KEY_3
                B       KP_Store
KP_Set_KeyA     MOVS    R0, #KEY_A
                B       KP_Store

KP_Set_Key4     MOVS    R0, #KEY_4
                B       KP_Store
KP_Set_Key5     MOVS    R0, #KEY_5
                B       KP_Store
KP_Set_Key6     MOVS    R0, #KEY_6
                B       KP_Store
KP_Set_KeyB     MOVS    R0, #KEY_B
                B       KP_Store

KP_Set_Key7     MOVS    R0, #KEY_7
                B       KP_Store
KP_Set_Key8     MOVS    R0, #KEY_8
                B       KP_Store
KP_Set_Key9     MOVS    R0, #KEY_9
                B       KP_Store
KP_Set_KeyC     MOVS    R0, #KEY_C
                B       KP_Store

KP_Set_KeyStar  MOVS    R0, #KEY_STAR
                B       KP_Store
KP_Set_Key0     MOVS    R0, #KEY_0
                B       KP_Store
KP_Set_KeyHash  MOVS    R0, #KEY_HASH
                B       KP_Store
KP_Set_KeyD     MOVS    R0, #KEY_D
                ; falls into KP_Store

KP_Store
        STR     R0, [R6]

KP_Scan_Done
        BL      KP_AllRowsHigh
        POP     {R4-R7, PC}


; =============================================================================
; KP_AllRowsHigh  –  drives all row pins HIGH (idle / deselect all)
; =============================================================================
KP_AllRowsHigh
        PUSH    {R0, R1, LR}
        LDR     R0, =GPIOA_BASE
        MOVS    R1, #KEY_ROW1
        BL      GPIO_WritePin
        MOVS    R1, #KEY_ROW2
        BL      GPIO_WritePin
        MOVS    R1, #KEY_ROW3
        BL      GPIO_WritePin
        MOVS    R1, #KEY_ROW4
        BL      GPIO_WritePin
        POP     {R0, R1, PC}


; =============================================================================
; KP_Delay  –  column settling delay after a row is driven LOW
; Increase the count if keys are misread due to slow pull-up rise time.
; =============================================================================
KP_Delay
        PUSH    {R0, LR}
        LDR     R0, =2000
KP_Delay_Loop
        SUBS    R0, R0, #1
        BNE     KP_Delay_Loop
        POP     {R0, PC}

        ALIGN
        END