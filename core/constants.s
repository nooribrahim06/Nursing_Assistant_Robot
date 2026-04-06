; =====================================================================
; FILE: constants.s
; DESCRIPTION: Global System Constants (Included in other .s files)
; =====================================================================
; ========================= TIMERS =========================
TIM3_BASE       EQU     0x40000400
TIM4_BASE       EQU     0x40000800

TIM_CR1         EQU     0x00
TIM_CCMR1       EQU     0x18
TIM_CCMR2       EQU     0x1C
TIM_CCER        EQU     0x20
TIM_PSC         EQU     0x28
TIM_ARR         EQU     0x2C
TIM_CCR1        EQU     0x34
TIM_CCR2        EQU     0x38
TIM_CCR3        EQU     0x3C
TIM_CCR4        EQU     0x40
; ========================= RCC =========================
RCC_BASE        EQU     0x40023800
RCC_AHB1ENR     EQU     0x30
RCC_APB1ENR     EQU     0x40
RCC_APB2ENR     EQU     0x44

; ========================= GPIO BASE =========================
GPIOA_BASE      EQU     0x40020000
GPIOB_BASE      EQU     0x40020400
GPIOC_BASE      EQU     0x40020800

; ========================= GPIO OFFSETS =========================
GPIO_MODER      EQU     0x00
GPIO_OTYPER     EQU     0x04
GPIO_OSPEEDR    EQU     0x08
GPIO_PUPDR      EQU     0x0C
GPIO_IDR        EQU     0x10
GPIO_ODR        EQU     0x14
GPIO_BSRR       EQU     0x18
GPIO_AFRL       EQU     0x20
GPIO_AFRH       EQU     0x24

; ========================= BIT MASKS =========================
BIT0    EQU     1
BIT1    EQU     2
BIT2    EQU     4
BIT3    EQU     8
BIT4    EQU     16
BIT5    EQU     32
BIT6    EQU     64
BIT7    EQU     128
BIT8    EQU     256
BIT9    EQU     512
BIT10   EQU     1024
BIT11   EQU     2048
BIT12   EQU     4096
BIT13   EQU     8192
BIT14   EQU     16384
BIT15   EQU     32768

; ========================= SERVOS =========================
ACT_SERVO_SAN   EQU     6
ACT_SERVO_MED   EQU     7

; ========================= MOTION =========================
MOT_IN1         EQU     8
MOT_IN2         EQU     9
MOT_IN3         EQU     10
MOT_IN4         EQU     11

MOT_ENA         EQU     8
MOT_ENB         EQU     9

; ========================= LINE TRACKER =========================
LINE_LEFT       EQU     0
LINE_CENTER     EQU     1
LINE_RIGHT      EQU     2

; ========================= SYSTEM STATES =========================
STATE_MAIN_MENU  EQU    0
STATE_SANITIZING EQU    1
STATE_HEART_RATE EQU    2
STATE_BREATHING  EQU    3
STATE_MED_TIMER  EQU    4
	END