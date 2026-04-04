AREA    CONSTANTS, DATA, READONLY

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

; ========================= Timer and GPIO Offsets =========================
TIM3_BASE       EQU     0x40000400
TIM4_BASE       EQU     0x40000800
TIM_CR1         EQU     0x00
TIM_PSC         EQU     0x28
TIM_ARR         EQU     0x2C
TIM_CCMR1       EQU     0x18
TIM_CCMR2       EQU     0x1C
TIM_CCER        EQU     0x20
TIM_CCR1        EQU     0x34
TIM_CCR2        EQU     0x38
TIM_CCR3        EQU     0x3C
TIM_CCR4        EQU     0x40

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

; ========================= TFT =========================
TFT_DATA_MASK   EQU     0x00000FF0

TFT_RS_PIN      EQU     2
TFT_WR_PIN      EQU     3
TFT_RD_PIN      EQU     4
TFT_CS_PIN      EQU     5
TFT_RST_PIN     EQU     12

; ========================= ADC SENSORS =========================
SNS_BREATH_ADC  EQU     0
SNS_SMOKE_ADC   EQU     1

; ========================= SERVOS =========================
ACT_SERVO_SAN   EQU     6
ACT_SERVO_MED   EQU     7

; ========================= BUZZER =========================
BUZZER_PIN      EQU     3

; ========================= MOTION =========================
MOT_IN1         EQU     8
MOT_IN2         EQU     9
MOT_IN3         EQU     10
MOT_IN4         EQU     11

MOT_ENA         EQU     8
MOT_ENB         EQU     9

; ========================= I2C =========================
I2C_SCL_PIN     EQU     6
I2C_SDA_PIN     EQU     7

; ========================= LINE TRACKER =========================
LINE_LEFT       EQU     0
LINE_CENTER     EQU     1
LINE_RIGHT      EQU     2

; ========================= KEYPAD =========================
KEY_ROW1        EQU     0
KEY_ROW2        EQU     1
KEY_ROW3        EQU     2
KEY_ROW4        EQU     10

KEY_COL1        EQU     12
KEY_COL2        EQU     13
KEY_COL3        EQU     14
KEY_COL4        EQU     15

; ========================= SYSTEM STATES =========================
STATE_MAIN_MENU EQU     0
STATE_SANITIZING EQU    1
STATE_HEART_RATE EQU    2
STATE_BREATHING  EQU    3
STATE_MED_TIMER  EQU    4

        END