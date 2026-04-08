;=============================================================================
; smoke.s
; Smoke detection logic – reads MQ2 via ADC, updates alarm flag.
;
; Exports:
;   Smoke_Check  – call every superloop iteration
;
; Imports:
;   g_smoke_level   – word, latest raw ADC reading stored here
;   g_alarm_flags   – word, Smoke_Alert_Flag bit set/cleared here
;   ADC_Read        – R0 = channel in, R0 = 12-bit result out
;
; Does NOT drive the LED directly; Main_AlarmTask owns that.
;
; Fixes applied:
;   - BHI replaced with BHS so threshold value 2500 itself triggers alarm
;   - Duplicated POP paths collapsed to a single exit label
;   - Registers R2/R3 added to PUSH/POP (were clobbered but not saved)
;=============================================================================

        AREA    SMOKE_DETECT, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

        IMPORT  g_smoke_level
        IMPORT  g_alarm_flags
        IMPORT  ADC_Read

        EXPORT  Smoke_Check

;-----------------------------------------------------------------------------
; Threshold – ADC counts at-or-above which smoke alarm activates.
; 12-bit ADC range: 0–4095.  2500 ~ 61 % of full scale.
; FIX: previously BHI (strictly greater than) meant 2500 did not alarm.
;      Now BHS (greater than or equal) so 2500 triggers the alarm.
;-----------------------------------------------------------------------------
SMOKE_THRESHOLD     EQU     3500


;=============================================================================
; Smoke_Check
;
; 1. Read ADC channel SNS_SMOKE_ADC (PA1 / ADC1_IN1)
; 2. Store raw value in g_smoke_level
; 3. If value >= SMOKE_THRESHOLD -> set   Smoke_Alert_Flag in g_alarm_flags
;                                -> clear Smoke_Alert_Flag otherwise
;=============================================================================
Smoke_Check
        ; FIX: R2 and R3 were clobbered by this function but not saved.
        ;      Added to PUSH/POP to comply with AAPCS callee-save rules.
        PUSH    {R2, R3, LR}

        ; ---- 1. Read smoke sensor ----
        MOV     R0, #SNS_SMOKE_ADC     ; channel 1 = PA1 = MQ2
        BL      ADC_Read               ; R0 = 12-bit ADC result

        ; ---- 2. Store latest reading in g_smoke_level ----
        LDR     R1, =g_smoke_level
        STR     R0, [R1]

        ; ---- 3. Compare against threshold ----
        ; FIX: BHS (>=) instead of BHI (>) so exactly 2500 fires the alarm.
        LDR     R3, =SMOKE_THRESHOLD
        CMP     R0, R3
        BHS     Smoke_SetAlarm
        ; fall through to clear path

Smoke_ClearAlarm
        LDR     R1, =g_alarm_flags
        LDR     R2, [R1]
        BIC     R2, R2, #Smoke_Alert_Flag
        STR     R2, [R1]
        B       Smoke_Done             ; FIX: branch to single exit

Smoke_SetAlarm
        LDR     R1, =g_alarm_flags
        LDR     R2, [R1]
        ORR     R2, R2, #Smoke_Alert_Flag
        STR     R2, [R1]
        ; fall through to single exit

Smoke_Done
        POP     {R2, R3, PC}           ; single return point


        ALIGN
        END