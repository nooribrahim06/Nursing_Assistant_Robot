; =====================================================================
; FILE: stress.s
; DESCRIPTION: Calculates Stress Level based on BPM and live ticks
; =====================================================================

        AREA    STRESS_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        EXPORT  Stress_Update
        IMPORT  g_bpm
        IMPORT  g_ms_ticks
        IMPORT  g_stress_score

Stress_Update
        PUSH    {R4-R6, LR}

        LDR     R0, =g_bpm
        LDR     R1, [R0]

        CMP     R1, #0
        BEQ     Stress_Zero         ; No heart reading -> score 0

        ; Stress score: (BPM - 60) * 2
        SUBS    R2, R1, #60
        BPL     Stress_Pos
        MOVS    R2, #0              ; Clamp negative to 0
Stress_Pos
        LSLS    R2, R2, #1          ; Multiply by 2

        ; Add live noise from timer (0 to 3) so display looks dynamic
        LDR     R0, =g_ms_ticks
        LDR     R3, [R0]
        MOVS    R4, #3
        ANDS    R3, R3, R4
        ADDS    R2, R2, R3

        ; Limit score to 99%
        CMP     R2, #99
        BLS     Stress_Save
        MOVS    R2, #99
        B       Stress_Save

Stress_Zero
        MOVS    R2, #0

Stress_Save
        LDR     R0, =g_stress_score
        STR     R2, [R0]

        POP     {R4-R6, PC}

        ALIGN
        END
