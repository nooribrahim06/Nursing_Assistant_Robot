        AREA    BREATH_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

        EXPORT  BREATHE_Init
        EXPORT  BREATHE_Update

        IMPORT  ADC_Read
        IMPORT  g_breath_level

; ================= DATA =================
        AREA    BREATH_DATA, DATA, READWRITE
        ALIGN
breath_baseline     SPACE   4
breath_started      SPACE   4

        AREA    BREATH_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

; ================= INIT =================
BREATHE_Init
        PUSH    {R0-R3, LR}

        ; baseline/state reset
        LDR     R0, =breath_baseline
        MOVS    R1, #0
        STR     R1, [R0]

        LDR     R0, =breath_started
        STR     R1, [R0]

        LDR     R0, =g_breath_level
        STR     R1, [R0]

        ; ---- Enable GPIOC clock ----
        LDR     R0, =RCC_BASE
        LDR     R1, [R0, #RCC_AHB1ENR]
        ORR     R1, R1, #BIT2
        STR     R1, [R0, #RCC_AHB1ENR]

        ; ---- Configure PC14 as output ----
        LDR     R0, =GPIOC_BASE
        LDR     R1, [R0, #GPIO_MODER]
        LDR     R2, =(3 << (14 * 2))
        BIC     R1, R1, R2
        LDR     R2, =(1 << (14 * 2))
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_MODER]

        ; push-pull
        LDR     R1, [R0, #GPIO_OTYPER]
        LDR     R2, =(1 << 14)
        BIC     R1, R1, R2
        STR     R1, [R0, #GPIO_OTYPER]

        ; no pull-up/pull-down
        LDR     R1, [R0, #GPIO_PUPDR]
        LDR     R2, =(3 << (14 * 2))
        BIC     R1, R1, R2
        STR     R1, [R0, #GPIO_PUPDR]

        ; default OFF = HIGH
        LDR     R0, =GPIOC_BASE
        LDR     R1, =(1 << 14)
        STR     R1, [R0, #GPIO_BSRR]

        POP     {R0-R3, PC}

; ================= UPDATE =================
BREATHE_Update
        PUSH    {R1-R7, LR}

; ---------- IR LED ON ----------
        LDR     R0, =GPIOC_BASE
        LDR     R1, =(1 << (14 + 16))      ; RESET bit -> LOW = ON
        STR     R1, [R0, #GPIO_BSRR]

; delay
        MOVS    R2, #200
Delay1
        SUBS    R2, R2, #1
        BNE     Delay1

; read ON
        MOVS    R0, #SNS_BREATH_ADC
        BL      ADC_Read
        MOV     R6, R0

; ---------- IR LED OFF ----------
        LDR     R0, =GPIOC_BASE
        LDR     R1, =(1 << 14)             ; SET bit -> HIGH = OFF
        STR     R1, [R0, #GPIO_BSRR]

; delay
        MOVS    R2, #200
Delay2
        SUBS    R2, R2, #1
        BNE     Delay2

; read OFF
        MOVS    R0, #SNS_BREATH_ADC
        BL      ADC_Read
        MOV     R7, R0

; ---------- subtraction ----------
        SUB     R6, R6, R7

        CMP     R6, #0
        BGE     HaveSignal
        MOVS    R6, #0

HaveSignal
; ---------- SAME OLD LOGIC ----------
        LDR     R1, =breath_started
        LDR     R2, [R1]
        CMP     R2, #0
        BNE     HasBaseline

        LDR     R3, =breath_baseline
        STR     R6, [R3]

        MOVS    R2, #1
        STR     R2, [R1]

        LDR     R3, =g_breath_level
        MOVS    R2, #0
        STR     R2, [R3]

        POP     {R1-R7, PC}

HasBaseline
        LDR     R3, =breath_baseline
        LDR     R4, [R3]

        CMP     R6, R4
        BHS     Above

        SUB     R5, R4, R6
        LSRS    R2, R5, #4
        SUB     R4, R4, R2
        B       DoneBase

Above
        SUB     R5, R6, R4
        LSRS    R2, R5, #4
        ADD     R4, R4, R2

DoneBase
        STR     R4, [R3]

; scale
        LSLS    R5, R5, #3
        LDR     R2, =4095
        CMP     R5, R2
        BLS     Store
        MOV     R5, R2

Store
        LDR     R3, =g_breath_level
        STR     R5, [R3]

        POP     {R1-R7, PC}

        END