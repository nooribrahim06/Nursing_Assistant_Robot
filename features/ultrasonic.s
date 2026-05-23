 ; =====================================================================
; FILE: ultrasonic.s
; HC-SR04 Ultrasonic Sensor Driver for STM32F401
; 
; TRIG PIN: PA12 (Output)
; ECHO PIN: PA15 (Input)
; TIMER: TIM5 (32-bit timer, configured for 1 microsecond ticks)
; =====================================================================

        AREA    ULTRASONIC_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        GET     constants.s

        EXPORT  HCSR04_Init
        EXPORT  HCSR04_Read



; =====================================================================
; HCSR04_Init
; Sets up PA12 (Trig), PA15 (Echo), and turns on TIM5 as a 1us stopwatch
; =====================================================================
HCSR04_Init
        PUSH    {R4-R5, LR}

        ; 1. Enable GPIOA Clock
        LDR     R0, =RCC_BASE
        LDR     R1, [R0, #RCC_AHB1ENR]
        ORR     R1, R1, #0x01           ; GPIOA EN
        STR     R1, [R0, #RCC_AHB1ENR]

        ; 2. Enable TIM5 Clock (APB1)
        LDR     R1, [R0, #RCC_APB1ENR]
        ORR     R1, R1, #0x08           ; TIM5 EN (Bit 3)
        STR     R1, [R0, #RCC_APB1ENR]

        ; 3. Configure PA12 (TRIG) as Output, PA15 (ECHO) as Input
        LDR     R0, =GPIOA_BASE
        LDR     R1, [R0, #GPIO_MODER]
        LDR     R2, =0xC3000000         ; Mask out bits 31:30 (PA15) and 25:24 (PA12)
        BIC     R1, R1, R2
        LDR     R2, =0x01000000         ; Set PA12 to 01 (Output). PA15 stays 00 (Input)
        ORR     R1, R1, R2              
        STR     R1, [R0, #GPIO_MODER]

        ; 4. Ensure PA12 TRIG starts LOW
        LDR     R1, [R0, #GPIO_ODR]
        LDR     R2, =0x1000             ; Bit 12 Mask
        BIC     R1, R1, R2         
        STR     R1, [R0, #GPIO_ODR]

        ; 5. Configure TIM5 for 1 microsecond ticks (Assuming 16MHz clock)
        LDR     R4, =TIM5_BASE
        
        MOVS    R1, #15                 ; Prescaler: 16MHz / (15+1) = 1MHz (1us tick)
        STR     R1, [R4, #TIM_PSC]

        LDR     R1, =0xFFFFFFFF         ; Auto-Reload Register (Max 32-bit value)
        STR     R1, [R4, #TIM_ARR]

        MOVS    R1, #1                  ; Generate Update Event to load prescaler
        STR     R1, [R4, #TIM_EGR]

        MOVS    R1, #1                  ; Enable Timer (CEN bit)
        STR     R1, [R4, #TIM_CR1]

        POP     {R4-R5, PC}


; =====================================================================
; HCSR04_Read
; Triggers the sensor, measures the echo, and calculates distance.
; Returns: Distance in cm in R0. (Returns 999 if error/timeout).
; =====================================================================
HCSR04_Read
        PUSH    {R4-R7, LR}
        
        LDR     R4, =GPIOA_BASE
        LDR     R5, =TIM5_BASE

        ; 1. Send 10us TRIG Pulse (PA12 HIGH)
        LDR     R1, [R4, #GPIO_ODR]
        LDR     R2, =0x1000             ; Bit 12 Mask
        ORR     R1, R1, R2
        STR     R1, [R4, #GPIO_ODR]

        ; Delay ~10+ microseconds
        MOVS    R2, #100
Trig_Wait
        SUBS    R2, R2, #1
        BNE     Trig_Wait

        ; Set TRIG Low (PA12 LOW)
        LDR     R1, [R4, #GPIO_ODR]
        LDR     R2, =0x1000             ; Bit 12 Mask
        BIC     R1, R1, R2
        STR     R1, [R4, #GPIO_ODR]

        ; 2. Wait for ECHO (PA15) to go HIGH
        LDR     R6, =10000              ; Wait up to ~3ms for sensor to respond
        LDR     R2, =0x8000             ; Bit 15 Mask
Wait_Echo_High
        SUBS    R6, R6, #1
        BEQ     Echo_Timeout            ; If counter hits 0, exit to prevent freezing
        LDR     R1, [R4, #GPIO_IDR]
        TST     R1, R2                  ; Check PA15
        BEQ     Wait_Echo_High

        ; 3. Echo is HIGH! Reset the timer to 0 to start stopwatch
        MOVS    R1, #0
        STR     R1, [R5, #TIM_CNT]

        ; 4. Wait for ECHO (PA15) to go LOW
        LDR     R6, =0x00020000         ; Increased timeout (approx 2ms)
Wait_Echo_Low
        SUBS    R6, R6, #1
        BEQ     Echo_Timeout
        LDR     R1, [R4, #GPIO_IDR]
        TST     R1, R2                  ; Check PA15
        BNE     Wait_Echo_Low           ; Keep looping while PA15 is HIGH

        ; 5. Read the Timer Value (Stopwatch time in microseconds)
        LDR     R7, [R5, #TIM_CNT]

        ; 6. Calculate Distance: Distance(cm) = Time(us) / 58
        MOVS    R1, #58
        UDIV    R0, R7, R1              ; Unsigned Divide: R0 = R7 / 58

        B       Read_Done

Echo_Timeout
        LDR     R0, =999                ; Return 999 to indicate "No Object" or Error

Read_Done
        POP     {R4-R7, PC}

        ALIGN
        END
