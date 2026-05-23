;=============================================================================
; sanitizing.s
; Final working pump code
; PA4 = sensor input  (active-low)
; PA5 = relay / pump output
;=============================================================================

        AREA    SAN_CODE, CODE, READONLY
        THUMB
        PRESERVE8 
        ALIGN

        GET     constants.s

        EXPORT  SAN_Init
        EXPORT  SAN_Update
        EXPORT  SAN_StopNow
        EXPORT  SAN_ResetSequence

;-----------------------------------------------------------------------------
; Local register offsets
;-----------------------------------------------------------------------------
OFF_RCC_AHB1ENR      EQU     0x30
OFF_GPIO_MODER       EQU     0x00
OFF_GPIO_IDR         EQU     0x10
OFF_GPIO_ODR         EQU     0x14

;-----------------------------------------------------------------------------
; SAN_Init
; Enable GPIOA clock
; PA4 = input
; PA5 = output
; Pump OFF at start
;-----------------------------------------------------------------------------
SAN_Init
        PUSH    {R0-R2, LR}

        ; Enable GPIOA clock
        LDR     R0, =RCC_BASE
        LDR     R1, [R0, #OFF_RCC_AHB1ENR]
        ORR     R1, R1, #BIT0
        STR     R1, [R0, #OFF_RCC_AHB1ENR]

        ; Configure PA4 input, PA5 output
        LDR     R0, =SAN_GPIO_PORT
        LDR     R1, [R0, #OFF_GPIO_MODER]

        ; Clear PA4 mode bits
        LDR     R2, =(3 << (SAN_SENSOR_PIN * 2))
        BIC     R1, R1, R2

        ; Clear PA5 mode bits
        LDR     R2, =(3 << (SAN_RELAY_PIN * 2))
        BIC     R1, R1, R2

        ; Set PA5 as output (01)
        LDR     R2, =(1 << (SAN_RELAY_PIN * 2))
        ORR     R1, R1, R2

        STR     R1, [R0, #OFF_GPIO_MODER]

        ; Pump OFF
        LDR     R1, [R0, #OFF_GPIO_ODR]
        LDR     R2, =(1 << SAN_RELAY_PIN)
        BIC     R1, R1, R2
        STR     R1, [R0, #OFF_GPIO_ODR]

        POP     {R0-R2, PC}

;-----------------------------------------------------------------------------
; SAN_StopNow
; Pump OFF immediately
;-----------------------------------------------------------------------------
SAN_StopNow
        PUSH    {R0-R2, LR}

        LDR     R0, =SAN_GPIO_PORT
        LDR     R1, [R0, #OFF_GPIO_ODR]
        LDR     R2, =(1 << SAN_RELAY_PIN)
        BIC     R1, R1, R2
        STR     R1, [R0, #OFF_GPIO_ODR]

        POP     {R0-R2, PC}

;-----------------------------------------------------------------------------
; SAN_ResetSequence
; Same as stop for this design
;-----------------------------------------------------------------------------
SAN_ResetSequence
        B       SAN_StopNow

;-----------------------------------------------------------------------------
; SAN_Update
; Read sensor on PA4
; If active-low detected => pump ON + delay
; Else pump OFF
;-----------------------------------------------------------------------------
SAN_Update
        PUSH    {R0-R2, LR}

        ; Read sensor input
        LDR     R0, =SAN_GPIO_PORT
        LDR     R1, [R0, #OFF_GPIO_IDR]
        TST     R1, #(1 << SAN_SENSOR_PIN)
        BEQ     SAN_PumpOn

        ; No hand => pump OFF
        LDR     R1, [R0, #OFF_GPIO_ODR]
        LDR     R2, =(1 << SAN_RELAY_PIN)
        BIC     R1, R1, R2
        STR     R1, [R0, #OFF_GPIO_ODR]
        B       SAN_Exit

SAN_PumpOn
        ; Pump ON
        LDR     R1, [R0, #OFF_GPIO_ODR]
        LDR     R2, =(1 << SAN_RELAY_PIN)
        ORR     R1, R1, R2
        STR     R1, [R0, #OFF_GPIO_ODR]

        ; Delay
        LDR     R2, =SAN_PUMP_DELAY
SAN_DelayLoop
        SUBS    R2, R2, #1
        BNE     SAN_DelayLoop

SAN_Exit
        POP     {R0-R2, PC}

        ALIGN
        END
