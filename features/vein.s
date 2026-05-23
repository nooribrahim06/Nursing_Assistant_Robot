;=============================================================================
; vein.s
; Vein finder logic using IR sensor on PA7 (ADC CH7)
;=============================================================================
        GET     constants.s

        AREA    VEIN_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        EXPORT  VEIN_Init
        EXPORT  VEIN_Update
        EXPORT  VEIN_Reset_Calibration

        IMPORT  g_vein_raw
        IMPORT  g_vein_base
        IMPORT  g_vein_diff
        IMPORT  g_vein_calib_cnt
        IMPORT  g_ms_ticks
        IMPORT  GPIO_WritePin
        IMPORT  GPIO_ClearPin
        IMPORT  ADC_Read

VEIN_Init
        PUSH    {R4, LR}
        
        ; Config PA7 as Analog mode (Bits 14 & 15 = 11)
        ; Safe mask: Only touch bits 14-15 to avoid disturbing PA6 (bits 12-13)
        LDR     R0, =GPIOA_BASE
        LDR     R1, [R0, #GPIO_MODER]
        BIC     R1, R1, #(3 << 14)
        ORR     R1, R1, #(3 << 14)
        STR     R1, [R0, #GPIO_MODER]

        ; Disable Pull-up/Pull-down for PA7
        LDR     R1, [R0, #0x0C]      ; GPIO_PUPDR offset
        BIC     R1, R1, #(3 << 14)
        STR     R1, [R0, #0x0C]
        
        BL      VEIN_Reset_Calibration
        
        POP     {R4, PC}

VEIN_Reset_Calibration
        PUSH    {LR}
        
        LDR     R0, =g_vein_calib_cnt
        MOVS    R1, #0
        STR     R1, [R0]
        LDR     R0, =g_vein_base
        STR     R1, [R0]
        
        POP     {PC}

VEIN_Update
        PUSH    {R4-R7, LR}

        ; 1. Read PA7 eight times and average to kill noise
        MOVS    R4, #0               ; Accumulator = 0
        MOVS    R5, #8               ; 8 samples
V_ReadLoop
        MOVS    R0, #7               ; Channel 7
        BL      ADC_Read
        ADD     R4, R4, R0
        SUBS    R5, R5, #1
        BNE     V_ReadLoop

        LSRS    R1, R4, #3           ; R1 = average (divide by 8)

        LDR     R2, =g_vein_raw
        STR     R1, [R2]

        ; 2. Calibration phase: Average the first 128 readings for baseline
        LDR     R2, =g_vein_calib_cnt
        LDR     R3, [R2]
        CMP     R3, #128
        BHS     V_Active

        ; Accumulate averaged reads
        LDR     R4, =g_vein_base
        LDR     R5, [R4]
        ADD     R5, R5, R1
        STR     R5, [R4]

        ADDS    R3, R3, #1
        STR     R3, [R2]

        CMP     R3, #128
        BNE     V_TurnOffBuzzer

        ; Divide by 128 to get the average base
        LDR     R4, =g_vein_base
        LDR     R5, [R4]
        LSRS    R5, R5, #7
        STR     R5, [R4]
        B       V_TurnOffBuzzer

V_Active
        ; 3. Get Absolute Difference (Raw - Base)
        LDR     R4, =g_vein_base
        LDR     R5, [R4]
        SUBS    R1, R1, R5
        BPL     V_PosDiff
        RSBS    R1, R1, #0           ; If negative, make positive
V_PosDiff
        LDR     R4, =g_vein_diff
        STR     R1, [R4]

        ; 4. Dynamic Buzzer
        CMP     R1, #200
        BLO     V_TurnOffBuzzer

        ; Tiered beeping
        LDR     R4, =1000
        CMP     R1, R4
        BHS     V_TurnOnBuzzer       ; Peak: Solid tone
        LDR     R4, =700
        CMP     R1, R4
        BHS     V_BeepFast
        LDR     R4, =400
        CMP     R1, R4
        BHS     V_BeepMed
        B       V_BeepSlow

V_BeepFast
        MOVS    R3, #0x1F            ; ~32ms toggle mask
        B       V_ApplyBeep
V_BeepMed
        MOVS    R3, #0x3F            ; ~64ms toggle mask
        B       V_ApplyBeep
V_BeepSlow
        MOVS    R3, #0x7F            ; ~128ms toggle mask

V_ApplyBeep
        LDR     R2, =g_ms_ticks
        LDR     R2, [R2]
        TST     R2, R3
        BNE     V_TurnOffBuzzer

V_TurnOnBuzzer
        LDR     R0, =GPIOB_BASE
        MOVS    R1, #BUZZER_PIN
        BL      GPIO_WritePin
        B       V_Exit
 
V_TurnOffBuzzer
        LDR     R0, =GPIOB_BASE 
        MOVS    R1, #BUZZER_PIN
        BL      GPIO_ClearPin

V_Exit
        POP     {R4-R7, PC}
        ALIGN
        END
