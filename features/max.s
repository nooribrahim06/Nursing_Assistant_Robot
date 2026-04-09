; =====================================================================
; FILE: max30102.s
; DESCRIPTION:
;   MAX30102 init + Burst Read + Direct Raw to Display (Diagnostic Live)
; =====================================================================

        INCLUDE constants.s

        AREA    HR_DATA, DATA, READWRITE
        ALIGN
fifo_buf        SPACE   6           

        AREA    HR_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        IMPORT  I2C_Init
        IMPORT  I2C_WriteReg
        IMPORT  I2C_ReadReg
        IMPORT  I2C_Read6Bytes      
        IMPORT  g_hr_red_raw
        IMPORT  g_hr_ir_raw
        IMPORT  g_bpm
        IMPORT  g_spo2

        EXPORT  HR_Init
        EXPORT  HR_ReadFIFO

MAX30102_ADDR           EQU     0x57

; -------------------- Registers --------------------
REG_INT_STATUS1         EQU     0x00
REG_INT_STATUS2         EQU     0x01
REG_INT_ENABLE1         EQU     0x02
REG_INT_ENABLE2         EQU     0x03
REG_FIFO_WR_PTR         EQU     0x04
REG_OVF_COUNTER         EQU     0x05
REG_FIFO_RD_PTR         EQU     0x06
REG_FIFO_DATA           EQU     0x07
REG_FIFO_CFG            EQU     0x08
REG_MODE_CFG            EQU     0x09
REG_SPO2_CFG            EQU     0x0A
REG_LED1_PA             EQU     0x0C
REG_LED2_PA             EQU     0x0D

; -------------------- Mode / config --------------------
MODE_RESET              EQU     0x40
MODE_SPO2               EQU     0x03
SPO2_CFG_100SPS_18B     EQU     0x27
FIFO_CFG_DEFAULT        EQU     0x10    ; Rollover enabled
LED_PA_DEFAULT          EQU     0x24

RAW18_MASK              EQU     0x0003FFFF
FIFO_PTR_MASK           EQU     0x1F

; =====================================================================
; HR_Init
; =====================================================================
HR_Init
        PUSH    {R4-R7, LR}

        BL      I2C_Init

        MOVS    R4, #MAX30102_ADDR

        MOV     R0, R4
        MOVS    R1, #REG_MODE_CFG
        MOVS    R2, #MODE_RESET
        BL      I2C_WriteReg

HRI_WaitResetDone
        MOV     R0, R4
        MOVS    R1, #REG_MODE_CFG
        BL      I2C_ReadReg
        TST     R0, #MODE_RESET
        BNE     HRI_WaitResetDone

        MOV     R0, R4
        MOVS    R1, #REG_INT_ENABLE1
        MOVS    R2, #0
        BL      I2C_WriteReg

        MOV     R0, R4
        MOVS    R1, #REG_INT_ENABLE2
        MOVS    R2, #0
        BL      I2C_WriteReg

        MOV     R0, R4
        MOVS    R1, #REG_FIFO_WR_PTR
        MOVS    R2, #0
        BL      I2C_WriteReg

        MOV     R0, R4
        MOVS    R1, #REG_OVF_COUNTER
        MOVS    R2, #0
        BL      I2C_WriteReg

        MOV     R0, R4
        MOVS    R1, #REG_FIFO_RD_PTR
        MOVS    R2, #0
        BL      I2C_WriteReg

        MOV     R0, R4
        MOVS    R1, #REG_FIFO_CFG
        MOVS    R2, #FIFO_CFG_DEFAULT
        BL      I2C_WriteReg

        MOV     R0, R4
        MOVS    R1, #REG_SPO2_CFG
        MOVS    R2, #SPO2_CFG_100SPS_18B
        BL      I2C_WriteReg

        MOV     R0, R4
        MOVS    R1, #REG_LED1_PA
        MOVS    R2, #LED_PA_DEFAULT
        BL      I2C_WriteReg

        MOV     R0, R4
        MOVS    R1, #REG_LED2_PA
        MOVS    R2, #LED_PA_DEFAULT
        BL      I2C_WriteReg

        MOV     R0, R4
        MOVS    R1, #REG_MODE_CFG
        MOVS    R2, #MODE_SPO2
        BL      I2C_WriteReg

        LDR     R0, =g_hr_red_raw
        MOVS    R1, #0
        STR     R1, [R0]

        LDR     R0, =g_hr_ir_raw
        STR     R1, [R0]

        LDR     R0, =g_bpm
        STR     R1, [R0]

        LDR     R0, =g_spo2
        STR     R1, [R0]

        POP     {R4-R7, PC}

; =====================================================================
; HR_ReadFIFO
; =====================================================================
HR_ReadFIFO
        PUSH    {R4-R7, LR}

        MOVS    R4, #MAX30102_ADDR

        MOV     R0, R4
        MOVS    R1, #REG_FIFO_WR_PTR
        BL      I2C_ReadReg
        AND     R6, R0, #FIFO_PTR_MASK

        MOV     R0, R4
        MOVS    R1, #REG_FIFO_RD_PTR
        BL      I2C_ReadReg
        AND     R7, R0, #FIFO_PTR_MASK

        CMP     R6, R7
        BEQ     HRF_Exit

        MOV     R0, R4
        MOVS    R1, #REG_FIFO_DATA
        LDR     R2, =fifo_buf
        BL      I2C_Read6Bytes

        ; ==========================================================
        ; Construct RED sample (bytes 0, 1, 2)
        ; ==========================================================
        LDR     R7, =fifo_buf
        
        LDRB    R5, [R7, #0]
        LSL     R5, R5, #16
        
        LDRB    R0, [R7, #1]
        LSL     R0, R0, #8
        ORR     R5, R5, R0
        
        LDRB    R0, [R7, #2]
        ORR     R5, R5, R0

        LDR     R0, =RAW18_MASK
        AND     R5, R5, R0
        
        LDR     R0, =g_hr_red_raw
        STR     R5, [R0]

        ; ==========================================================
        ; Construct IR sample (bytes 3, 4, 5)
        ; ==========================================================
        LDRB    R6, [R7, #3]
        LSL     R6, R6, #16
        
        LDRB    R0, [R7, #4]
        LSL     R0, R0, #8
        ORR     R6, R6, R0
        
        LDRB    R0, [R7, #5]
        ORR     R6, R6, R0

        LDR     R0, =RAW18_MASK
        AND     R6, R6, R0
        
        LDR     R0, =g_hr_ir_raw
        STR     R6, [R0]

                ; ==========================================================
        ; DIRECT DISPLAY VARIABLES
        ; Keep BPM diagnostic from RED raw
        ; Fix SpO2 so it becomes percentage-like and stays 70..100
        ; ==========================================================

        ; BPM diagnostic (leave as before)
        LSRS    R1, R5, #10
        LDR     R2, =0xFF
        AND     R1, R1, R2
        LDR     R0, =g_bpm
        STR     R1, [R0]

        ; SpO2 approximate percentage from RED/IR ratio
        CMP     R6, #0
        BEQ     HRF_Spo2_Zero

        MOV     R1, R5
        LSLS    R1, R1, #8          ; ratio_q8 numerator = RED * 256
        UDIV    R1, R1, R6          ; ratio_q8 = (RED / IR) * 256

        MOVS    R2, #25
        MUL     R1, R1, R2
        LSRS    R1, R1, #8          ; (25 * ratio_q8) / 256

        LDR     R2, =110
        CMP     R1, R2
        BHI     HRF_Spo2_Zero

        SUBS    R1, R2, R1          ; spo2 ˜ 110 - 25*(RED/IR)

        CMP     R1, #70
        BHS     HRF_Spo2_ClampHigh
        MOVS    R1, #70

HRF_Spo2_ClampHigh
        CMP     R1, #100
        BLS     HRF_Spo2_Store
        MOVS    R1, #100

HRF_Spo2_Store
        LDR     R0, =g_spo2
        STR     R1, [R0]
        B       HRF_Exit

HRF_Spo2_Zero
        MOVS    R1, #0
        LDR     R0, =g_spo2
        STR     R1, [R0]

HRF_Exit
        POP     {R4-R7, PC}

        END