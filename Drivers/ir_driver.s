;=============================================================================
; ir_driver.s
; Robust NEC IR decode using falling-edge interrupt only
;
; PB10 -> EXTI10
; TIM2 -> 1 MHz free running timer
;
; Output:
;   g_ir_ready    = 1 when a key is decoded
;   g_ir_raw_code = NEC command byte only
;=============================================================================
        GET     constants.s

        AREA    IR_DATA, DATA, READWRITE
        ALIGN

        EXPORT  ir_last_fall
        EXPORT  ir_state
        EXPORT  ir_bit_count
        EXPORT  ir_temp_code

ir_last_fall    SPACE   4
ir_state        SPACE   4   ; 0=idle, 1=got first falling edge, 2=receiving bits
ir_bit_count    SPACE   4
ir_temp_code    SPACE   4

        AREA    IR_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        EXPORT  IR_Init
        EXPORT  EXTI15_10_IRQHandler

        IMPORT  g_ir_ready
        IMPORT  g_ir_raw_code

;-----------------------------------------------------------------------------
; IR_ResetDecoder
;-----------------------------------------------------------------------------
IR_ResetDecoder
        PUSH    {R0, R1, LR}

        MOVS    R1, #0

        LDR     R0, =ir_state
        STR     R1, [R0]

        LDR     R0, =ir_bit_count
        STR     R1, [R0]

        LDR     R0, =ir_temp_code
        STR     R1, [R0]

        LDR     R0, =ir_last_fall
        STR     R1, [R0]

        POP     {R0, R1, PC}

;-----------------------------------------------------------------------------
; IR_PublishIfValid
; R0 = full 32-bit NEC code
; Publishes command byte only into g_ir_raw_code
;-----------------------------------------------------------------------------
IR_PublishIfValid
        PUSH    {R1-R7, LR}

        MOV     R1, R0

        ; addr
        UXTB    R2, R1
        LSRS    R1, R1, #8

        ; ~addr
        UXTB    R3, R1
        ADDS    R4, R2, R3
        MOVS    R5, #0xFF
        CMP     R4, R5
        BNE     IR_Publish_End

        LSRS    R1, R1, #8

        ; cmd
        UXTB    R6, R1
        LSRS    R1, R1, #8

        ; ~cmd
        UXTB    R7, R1
        ADDS    R4, R6, R7
        CMP     R4, R5
        BNE     IR_Publish_End

        ; publish command byte only
        LDR     R1, =g_ir_raw_code
        STR     R6, [R1]

        MOVS    R0, #1
        LDR     R1, =g_ir_ready
        STR     R0, [R1]

IR_Publish_End
        POP     {R1-R7, PC}

;-----------------------------------------------------------------------------
; IR_Init
;-----------------------------------------------------------------------------
IR_Init
        PUSH    {R4-R7, LR}

        ; Enable GPIOB clock
        LDR     R0, =RCC_BASE
        LDR     R1, [R0, #RCC_AHB1ENR]
        ORR     R1, R1, #BIT1
        STR     R1, [R0, #RCC_AHB1ENR]

        ; Enable SYSCFG clock
        LDR     R1, [R0, #RCC_APB2ENR]
        LDR     R2, =0x00004000
        ORR     R1, R1, R2
        STR     R1, [R0, #RCC_APB2ENR]

        ; Enable TIM2 clock
        LDR     R1, [R0, #RCC_APB1ENR]
        ORR     R1, R1, #BIT0
        STR     R1, [R0, #RCC_APB1ENR]

        ; PB10 input mode
        LDR     R0, =GPIOB_BASE
        LDR     R1, [R0, #GPIO_MODER]
        LDR     R2, =0x00300000
        BIC     R1, R1, R2
        STR     R1, [R0, #GPIO_MODER]

        ; PB10 pull-up
        LDR     R1, [R0, #GPIO_PUPDR]
        LDR     R2, =0x00300000
        BIC     R1, R1, R2
        LDR     R2, =0x00100000
        ORR     R1, R1, R2
        STR     R1, [R0, #GPIO_PUPDR]

        ; TIM2 = 1 MHz
        LDR     R0, =TIM2_BASE
        MOVS    R1, #0
        STR     R1, [R0, #TIM_CR1]

        LDR     R1, =15
        STR     R1, [R0, #TIM_PSC]

        LDR     R1, =0xFFFFFFFF
        STR     R1, [R0, #TIM_ARR]

        MOVS    R1, #1
        STR     R1, [R0, #TIM_EGR]

        MOVS    R1, #0
        STR     R1, [R0, #TIM_CNT]

        MOVS    R1, #1
        STR     R1, [R0, #TIM_CR1]

        ; EXTI10 -> Port B
        LDR     R0, =SYSCFG_BASE
        LDR     R1, [R0, #SYSCFG_EXTICR3]
        LDR     R2, =0x00000F00
        BIC     R1, R1, R2
        LDR     R2, =0x00000100
        ORR     R1, R1, R2
        STR     R1, [R0, #SYSCFG_EXTICR3]

        ; EXTI mask
        LDR     R0, =EXTI_BASE

        LDR     R1, [R0, #EXTI_IMR]
        ORR     R1, R1, #BIT10
        STR     R1, [R0, #EXTI_IMR]

        ; falling edge only
        LDR     R1, [R0, #EXTI_FTSR]
        ORR     R1, R1, #BIT10
        STR     R1, [R0, #EXTI_FTSR]

        ; disable rising edge
        LDR     R1, [R0, #EXTI_RTSR]
        BIC     R1, R1, #BIT10
        STR     R1, [R0, #EXTI_RTSR]

        ; clear pending
        MOV     R1, #BIT10
        STR     R1, [R0, #EXTI_PR]

        ; init vars
        MOVS    R1, #0

        LDR     R0, =ir_last_fall
        STR     R1, [R0]

        LDR     R0, =ir_state
        STR     R1, [R0]

        LDR     R0, =ir_bit_count
        STR     R1, [R0]

        LDR     R0, =ir_temp_code
        STR     R1, [R0]

        LDR     R0, =g_ir_ready
        STR     R1, [R0]

        LDR     R0, =g_ir_raw_code
        STR     R1, [R0]

        ; NVIC enable EXTI15_10 IRQ (IRQ40 => ISER1 bit 8)
        LDR     R0, =NVIC_ISER1
        MOVS    R1, #1
        LSLS    R1, R1, #8
        STR     R1, [R0]

        POP     {R4-R7, PC}

;-----------------------------------------------------------------------------
; EXTI15_10_IRQHandler
; Falling-edge only decode
;-----------------------------------------------------------------------------
EXTI15_10_IRQHandler
        PUSH    {R0-R7, LR}

        ; check EXTI10 pending
        LDR     R0, =EXTI_BASE
        LDR     R1, [R0, #EXTI_PR]
        TST     R1, #BIT10
        BEQ.W   IR_IRQ_Exit

        ; clear pending
        MOV     R1, #BIT10
        STR     R1, [R0, #EXTI_PR]

        ; now = TIM2_CNT
        LDR     R0, =TIM2_BASE
        LDR     R6, [R0, #TIM_CNT]

        ; load previous falling time
        LDR     R0, =ir_last_fall
        LDR     R2, [R0]
        STR     R6, [R0]

        ; state
        LDR     R0, =ir_state
        LDR     R3, [R0]

        ; first falling edge after idle -> arm only
        CMP     R3, #0
        BNE     IR_NotFirstFall
        MOVS    R1, #1
        STR     R1, [R0]
        B.W     IR_IRQ_Exit

IR_NotFirstFall
        ; dt = now - previous falling
        SUB     R6, R6, R2

        ; state 1 = classify start frame
        CMP     R3, #1
        BNE     IR_CheckData

        ; Start frame ~= 13.5ms between falling edges
        LDR     R1, =12500
        CMP     R6, R1
        BLO     IR_State1_Bad

        LDR     R1, =14500
        CMP     R6, R1
        BHI     IR_State1_Bad

        ; valid leader
        MOVS    R1, #2
        STR     R1, [R0]

        MOVS    R1, #0
        LDR     R0, =ir_bit_count
        STR     R1, [R0]
        LDR     R0, =ir_temp_code
        STR     R1, [R0]
        B.W     IR_IRQ_Exit

IR_State1_Bad
        ; stay armed waiting for a fresh leader
        MOVS    R1, #1
        LDR     R0, =ir_state
        STR     R1, [R0]
        B.W     IR_IRQ_Exit

IR_CheckData
        ; only decode in state 2
        CMP     R3, #2
        BEQ     IR_DataBit
        B.W     IR_IRQ_Exit

IR_DataBit
        LDR     R0, =ir_bit_count
        LDR     R4, [R0]

        LDR     R1, =ir_temp_code
        LDR     R5, [R1]

        ; 0-bit ~= 1.12ms falling-to-falling
        LDR     R2, =900
        CMP     R6, R2
        BLO     IR_DataBad

        LDR     R2, =1400
        CMP     R6, R2
        BLS     IR_StoreZero

        ; 1-bit ~= 2.25ms falling-to-falling
        LDR     R2, =1800
        CMP     R6, R2
        BLO     IR_DataBad

        LDR     R2, =2800
        CMP     R6, R2
        BHI     IR_DataBad

        ; store bit=1, LSB first
        MOVS    R2, #1
        LSLS    R2, R2, R4
        ORRS    R5, R5, R2
        B       IR_AdvanceBit

IR_StoreZero
        ; do nothing, bit already 0
        NOP

IR_AdvanceBit
        STR     R5, [R1]
        ADDS    R4, R4, #1
        STR     R4, [R0]

        CMP     R4, #32
        BNE.W   IR_IRQ_Exit

        ; full NEC frame ready
        MOV     R0, R5
        BL      IR_PublishIfValid

        ; reset for next frame
        BL      IR_ResetDecoder
        B.W     IR_IRQ_Exit

IR_DataBad
        ; bad timing -> reset
        BL      IR_ResetDecoder
        B.W     IR_IRQ_Exit

IR_IRQ_Exit
        POP     {R0-R7, PC}

        ALIGN
        END