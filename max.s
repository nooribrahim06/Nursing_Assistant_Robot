; =====================================================================
; FILE: max30102.s
; DESCRIPTION:
;   MAX30102 init + raw FIFO acquisition
;
; Notes:
;   - uses 7-bit I2C address 0x57
;   - stores raw 18-bit Red / IR values into globals
;   - does NOT calculate BPM/SpO2 here
; =====================================================================

        INCLUDE constants.s

        AREA    HR_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        IMPORT  I2C_Init
        IMPORT  I2C_WriteReg
        IMPORT  I2C_ReadReg
        IMPORT  g_hr_red_raw
        IMPORT  g_hr_ir_raw

        EXPORT  HR_Init
        EXPORT  HR_ReadFIFO

MAX30102_ADDR       EQU     0x57        ; 7-bit slave ID

REG_INT_STATUS1     EQU     0x00
REG_INT_STATUS2     EQU     0x01
REG_FIFO_WR_PTR     EQU     0x04
REG_OVF_COUNTER     EQU     0x05
REG_FIFO_RD_PTR     EQU     0x06
REG_FIFO_DATA       EQU     0x07
REG_FIFO_CFG        EQU     0x08
REG_MODE_CFG        EQU     0x09
REG_SPO2_CFG        EQU     0x0A
REG_LED1_PA         EQU     0x0C
REG_LED2_PA         EQU     0x0D

MODE_RESET          EQU     0x40
MODE_SPO2           EQU     0x03

; SpO2 config:
;   ADC range = 4096 nA  -> 01 << 5
;   sample rate = 100 sps -> 001 << 2
;   pulse width = 411 us / 18-bit -> 11
SPO2_CFG_100SPS_18B EQU     0x27

; Moderate starting LED current. Tune later if needed.
LED_PA_DEFAULT      EQU     0x24

RAW18_MASK          EQU     0x0003FFFF

; =====================================================================
; HR_Init
; Bring up I2C, reset MAX30102, clear FIFO, configure SpO2 mode.
; =====================================================================
HR_Init
        PUSH    {R4-R7, LR}

        BL      I2C_Init

        MOVS    R4, #MAX30102_ADDR

        ; ---- Soft reset ----
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

        ; ---- Clear any pending interrupt status / power-ready latch ----
        MOV     R0, R4
        MOVS    R1, #REG_INT_STATUS1
        BL      I2C_ReadReg

        MOV     R0, R4
        MOVS    R1, #REG_INT_STATUS2
        BL      I2C_ReadReg

        ; ---- Clear FIFO pointers/counters ----
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

        ; ---- FIFO config: no averaging, no rollover, almost-full field irrelevant for polling ----
        MOV     R0, R4
        MOVS    R1, #REG_FIFO_CFG
        MOVS    R2, #0x00
        BL      I2C_WriteReg

        ; ---- SpO2 config ----
        MOV     R0, R4
        MOVS    R1, #REG_SPO2_CFG
        MOVS    R2, #SPO2_CFG_100SPS_18B
        BL      I2C_WriteReg

        ; ---- LED amplitudes ----
        MOV     R0, R4
        MOVS    R1, #REG_LED1_PA
        MOVS    R2, #LED_PA_DEFAULT
        BL      I2C_WriteReg

        MOV     R0, R4
        MOVS    R1, #REG_LED2_PA
        MOVS    R2, #LED_PA_DEFAULT
        BL      I2C_WriteReg

        ; ---- Enter SpO2 mode (Red + IR) ----
        MOV     R0, R4
        MOVS    R1, #REG_MODE_CFG
        MOVS    R2, #MODE_SPO2
        BL      I2C_WriteReg

        POP     {R4-R7, PC}

; =====================================================================
; HR_ReadFIFO
; Poll one sample from FIFO if available.
;
; Output:
;   g_hr_red_raw = 18-bit Red sample
;   g_hr_ir_raw  = 18-bit IR sample
; =====================================================================
HR_ReadFIFO
        PUSH    {R4-R7, LR}

        MOVS    R4, #MAX30102_ADDR

        ; ---- Check if FIFO has unread sample(s) ----
        MOV     R0, R4
        MOVS    R1, #REG_FIFO_WR_PTR
        BL      I2C_ReadReg
        MOV     R6, R0                  ; write pointer

        MOV     R0, R4
        MOVS    R1, #REG_FIFO_RD_PTR
        BL      I2C_ReadReg
        MOV     R7, R0                  ; read pointer

        CMP     R6, R7
        BEQ     HRF_Exit                ; no new sample yet

        ; ==========================================================
        ; Read Red sample: 3 bytes
        ; ==========================================================
        MOV     R0, R4
        MOVS    R1, #REG_FIFO_DATA
        BL      I2C_ReadReg
        LSL     R5, R0, #16             ; Red byte 1

        MOV     R0, R4
        MOVS    R1, #REG_FIFO_DATA
        BL      I2C_ReadReg
        LSL     R0, R0, #8              ; Red byte 2
        ORR     R5, R5, R0

        MOV     R0, R4
        MOVS    R1, #REG_FIFO_DATA
        BL      I2C_ReadReg             ; Red byte 3
        ORR     R5, R5, R0

        LDR     R0, =RAW18_MASK
        AND     R5, R5, R0

        ; ==========================================================
        ; Read IR sample: 3 bytes
        ; ==========================================================
        MOV     R0, R4
        MOVS    R1, #REG_FIFO_DATA
        BL      I2C_ReadReg
        LSL     R6, R0, #16             ; IR byte 1

        MOV     R0, R4
        MOVS    R1, #REG_FIFO_DATA
        BL      I2C_ReadReg
        LSL     R0, R0, #8              ; IR byte 2
        ORR     R6, R6, R0

        MOV     R0, R4
        MOVS    R1, #REG_FIFO_DATA
        BL      I2C_ReadReg             ; IR byte 3
        ORR     R6, R6, R0

        LDR     R0, =RAW18_MASK
        AND     R6, R6, R0

        ; ---- Store globals ----
        LDR     R0, =g_hr_red_raw
        STR     R5, [R0]

        LDR     R0, =g_hr_ir_raw
        STR     R6, [R0]

HRF_Exit
        POP     {R4-R7, PC}

        END