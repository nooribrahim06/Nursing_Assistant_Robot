; =====================================================================
; FILE: max30102.s
; DESCRIPTION:
;   MAX30102 init + FIFO read + temp read
;
; FIXES:
;   - HR_Init reset wait has watchdog
;   - HR_ReadTemp exists and has watchdog
;   - exports g_temp_int / g_temp_frac
;   - HR_ReadFIFO updates real g_hr_ir_raw for PPG wave
;   - ADDED: High-Pass Filter (DC Removal) for stable TFT Graph
; =====================================================================

        INCLUDE constants.s

        AREA    HR_DATA, DATA, READWRITE
        ALIGN

        EXPORT  g_temp_int
        EXPORT  g_temp_frac
        EXPORT  g_hr_ac_val      ; ??????? ?????? ????? ?????? ???????

fifo_buf        SPACE   6
g_temp_int      SPACE   4
g_temp_frac     SPACE   4
g_dc_estimator  SPACE   4        ; ???? ?????? ??????? (DC Offset)
g_hr_ac_val     SPACE   4        ; ?????? ??????? ????? ???????

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
        EXPORT  HR_ReadTemp

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

REG_TEMP_INTR           EQU     0x1F
REG_TEMP_FRAC           EQU     0x20
REG_TEMP_CONFIG         EQU     0x21

; -------------------- Mode / config --------------------
MODE_RESET              EQU     0x40
MODE_SPO2               EQU     0x03
SPO2_CFG_100SPS_18B     EQU     0x27
FIFO_CFG_DEFAULT        EQU     0x10
LED_PA_DEFAULT          EQU     0x1F

RAW18_MASK              EQU     0x0003FFFF
FIFO_PTR_MASK           EQU     0x1F

; =====================================================================
; HR_Init
; =====================================================================
HR_Init
        PUSH    {R4-R7, LR}

        BL      I2C_Init

        MOVS    R4, #MAX30102_ADDR

        ; reset device
        MOV     R0, R4
        MOVS    R1, #REG_MODE_CFG
        MOVS    R2, #MODE_RESET
        BL      I2C_WriteReg

        ; wait reset bit clears, with watchdog
        LDR     R5, =50000

HRI_WaitResetDone
        MOV     R0, R4
        MOVS    R1, #REG_MODE_CFG
        BL      I2C_ReadReg
        TST     R0, #MODE_RESET
        BEQ     HRI_ResetDone

        SUBS    R5, R5, #1
        BNE     HRI_WaitResetDone

HRI_ResetDone
        ; disable interrupts
        MOV     R0, R4
        MOVS    R1, #REG_INT_ENABLE1
        MOVS    R2, #0
        BL      I2C_WriteReg

        MOV     R0, R4
        MOVS    R1, #REG_INT_ENABLE2
        MOVS    R2, #0
        BL      I2C_WriteReg

        ; clear FIFO pointers
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

        ; FIFO config
        MOV     R0, R4
        MOVS    R1, #REG_FIFO_CFG
        MOVS    R2, #FIFO_CFG_DEFAULT
        BL      I2C_WriteReg

        ; SpO2 config
        MOV     R0, R4
        MOVS    R1, #REG_SPO2_CFG
        MOVS    R2, #SPO2_CFG_100SPS_18B
        BL      I2C_WriteReg

        ; LEDs
        MOV     R0, R4
        MOVS    R1, #REG_LED1_PA
        MOVS    R2, #LED_PA_DEFAULT
        BL      I2C_WriteReg

        MOV     R0, R4
        MOVS    R1, #REG_LED2_PA
        MOVS    R2, #LED_PA_DEFAULT
        BL      I2C_WriteReg

        ; SpO2 mode
        MOV     R0, R4
        MOVS    R1, #REG_MODE_CFG
        MOVS    R2, #MODE_SPO2
        BL      I2C_WriteReg

        ; clear globals
        MOVS    R1, #0

        LDR     R0, =g_hr_red_raw
        STR     R1, [R0]

        LDR     R0, =g_hr_ir_raw
        STR     R1, [R0]

        LDR     R0, =g_bpm
        STR     R1, [R0]

        LDR     R0, =g_spo2
        STR     R1, [R0]

        LDR     R0, =g_temp_int
        STR     R1, [R0]

        LDR     R0, =g_temp_frac
        STR     R1, [R0]
        
        ; clear filter globals
        LDR     R0, =g_dc_estimator
        STR     R1, [R0]
        LDR     R0, =g_hr_ac_val
        STR     R1, [R0]

        POP     {R4-R7, PC}

; =====================================================================
; HR_ReadTemp
; =====================================================================
HR_ReadTemp
        PUSH    {R4-R6, LR}

        MOVS    R4, #MAX30102_ADDR

        ; start one-shot temperature conversion
        MOV     R0, R4
        MOVS    R1, #REG_TEMP_CONFIG
        MOVS    R2, #1
        BL      I2C_WriteReg

        ; wait until TEMP_CONFIG bit0 clears, with watchdog
        LDR     R5, =40000

HRT_WaitDone
        MOV     R0, R4
        MOVS    R1, #REG_TEMP_CONFIG
        BL      I2C_ReadReg
        TST     R0, #1
        BEQ     HRT_ReadValues

        SUBS    R5, R5, #1
        BNE     HRT_WaitDone

        ; timeout: keep old displayed temperature, do not freeze
        B       HRT_Exit

HRT_ReadValues
        ; integer part
        MOV     R0, R4
        MOVS    R1, #REG_TEMP_INTR
        BL      I2C_ReadReg
        UXTB    R0, R0
        LDR     R1, =g_temp_int
        STR     R0, [R1]

        ; fractional part
        MOV     R0, R4
        MOVS    R1, #REG_TEMP_FRAC
        BL      I2C_ReadReg
        UXTB    R0, R0
        AND     R0, R0, #0x0F
        LDR     R1, =g_temp_frac
        STR     R0, [R1]

HRT_Exit
        POP     {R4-R6, PC}

; =====================================================================
; HR_ReadFIFO
; =====================================================================
HR_ReadFIFO
        PUSH    {R4-R7, LR}

        MOVS    R4, #MAX30102_ADDR

        ; check FIFO has new sample
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

        ; read 6 bytes: RED[0..2], IR[3..5]
        MOV     R0, R4
        MOVS    R1, #REG_FIFO_DATA
        LDR     R2, =fifo_buf
        BL      I2C_Read6Bytes
        CMP     R0, #0
        BNE     HRF_Exit

        ; RED sample
        LDR     R7, =fifo_buf

        LDRB    R5, [R7, #0]
        LSLS    R5, R5, #16

        LDRB    R0, [R7, #1]
        LSLS    R0, R0, #8
        ORR     R5, R5, R0

        LDRB    R0, [R7, #2]
        ORR     R5, R5, R0

        LDR     R0, =RAW18_MASK
        AND     R5, R5, R0

        LDR     R0, =g_hr_red_raw
        STR     R5, [R0]

        ; IR sample
        LDRB    R6, [R7, #3]
        LSLS    R6, R6, #16

        LDRB    R0, [R7, #4]
        LSLS    R0, R0, #8
        ORR     R6, R6, R0

        LDRB    R0, [R7, #5]
        ORR     R6, R6, R0

        LDR     R0, =RAW18_MASK
        AND     R6, R6, R0

        LDR     R0, =g_hr_ir_raw
        STR     R6, [R0]

        ; -------------------------------------------------------------
        ; HIGH-PASS FILTER (DC Removal for Graph)
        ; -------------------------------------------------------------
        LDR     R0, =g_dc_estimator
        LDR     R1, [R0]            ; Load current DC

        CMP     R1, #0              ; If DC is 0, initialize it
        BNE     Filter_Calc
        MOV     R1, R6              ; Set initial DC to first raw value
        STR     R1, [R0]

Filter_Calc
        SUBS    R2, R6, R1          ; R2 = Sample - DC
        ASRS    R3, R2, #4          ; R3 = (Sample - DC) / 16
        ADDS    R1, R1, R3          ; DC = DC + R3
        STR     R1, [R0]            ; Save new DC

        ; AC value = Sample - New DC
        SUBS    R2, R6, R1          ; R2 = AC value (around 0)
        
        ; Add offset to AC to keep it positive for TFT graphing (e.g. +2000)
        ; ????? ????? ?? ????? ??? ????? ????? ??? ???? ?????? ?? ?????
        LDR     R3, =2000
        ADDS    R2, R2, R3

        LDR     R0, =g_hr_ac_val
        STR     R2, [R0]
        ; -------------------------------------------------------------

        ; finger detection
        MOVW    R0, #40000
        CMP     R6, R0
        BLO     HRF_No_Finger

        ; diagnostic BPM range 70..101
        LSRS    R1, R5, #12
        MOVS    R2, #31
        AND     R1, R1, R2
        ADDS    R1, R1, #70
        LDR     R0, =g_bpm
        STR     R1, [R0]

        ; rough SpO2 approximation
        CMP     R6, #0
        BEQ     HRF_No_Finger

        MOV     R1, R5
        LSLS    R1, R1, #8
        UDIV    R1, R1, R6

        MOVS    R2, #25
        MUL     R1, R1, R2
        LSRS    R1, R1, #8

        LDR     R2, =110
        CMP     R1, R2
        BHI     HRF_No_Finger

        SUBS    R1, R2, R1

        CMP     R1, #70
        BHS     HRF_Spo2_Floor_OK
        MOVS    R1, #70

HRF_Spo2_Floor_OK
        CMP     R1, #100
        BLS     HRF_Spo2_Store
        MOVS    R1, #100

HRF_Spo2_Store
        LDR     R0, =g_spo2
        STR     R1, [R0]
        B       HRF_Exit

HRF_No_Finger
        MOVS    R1, #0
        LDR     R0, =g_spo2
        STR     R1, [R0]
        LDR     R0, =g_bpm
        STR     R1, [R0]
        
        ; ????? ?????? ??? ??? ?????? ????? ?? ???? ??? ?????
        LDR     R0, =g_dc_estimator
        STR     R1, [R0]
        LDR     R0, =g_hr_ac_val
        STR     R1, [R0]

HRF_Exit
        POP     {R4-R7, PC}

        ALIGN
        END