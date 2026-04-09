;=============================================================================
; constants.s
; INCLUDE-ONLY file – use with:  GET constants.s
;=============================================================================

;-----------------------------------------------------------------------------
; RCC
;-----------------------------------------------------------------------------
RCC_BASE            EQU     0x40023800
RCC_AHB1ENR         EQU     0x30
RCC_APB1ENR         EQU     0x40
RCC_APB2ENR         EQU     0x44

;-----------------------------------------------------------------------------
; GPIO – base addresses
;-----------------------------------------------------------------------------
GPIOA_BASE          EQU     0x40020000
GPIOB_BASE          EQU     0x40020400
GPIOC_BASE          EQU     0x40020800

;-----------------------------------------------------------------------------
; GPIO – register offsets
;-----------------------------------------------------------------------------
GPIO_MODER          EQU     0x00
GPIO_OTYPER         EQU     0x04
GPIO_OSPEEDR        EQU     0x08
GPIO_PUPDR          EQU     0x0C
GPIO_IDR            EQU     0x10
GPIO_ODR            EQU     0x14
GPIO_BSRR           EQU     0x18

;-----------------------------------------------------------------------------
; Bit masks
;-----------------------------------------------------------------------------
BIT0                EQU     0x00000001
BIT1                EQU     0x00000002
BIT2                EQU     0x00000004
BIT3                EQU     0x00000008
BIT4                EQU     0x00000010
BIT5                EQU     0x00000020
BIT6                EQU     0x00000040
BIT7                EQU     0x00000080
BIT8                EQU     0x00000100
BIT9                EQU     0x00000200
BIT10               EQU     0x00000400
BIT11               EQU     0x00000800
BIT12               EQU     0x00001000
BIT13               EQU     0x00002000
BIT14               EQU     0x00004000
BIT15               EQU     0x00008000

;-----------------------------------------------------------------------------
; TFT
;-----------------------------------------------------------------------------
TFT_DATA_MASK       EQU     0x000000FF

TFT_RS_PIN          EQU     2
TFT_WR_PIN          EQU     3
TFT_RD_PIN          EQU     4
TFT_CS_PIN          EQU     5
TFT_RST_PIN         EQU     12

TFT_D0              EQU     0       ; PB0
TFT_D1              EQU     1       ; PB1
TFT_D2              EQU     2       ; PB2
TFT_D3              EQU     3       ; PB3
TFT_D4              EQU     4       ; PB4
TFT_D5              EQU     5       ; PB5
TFT_D6              EQU     6       ; PB6
TFT_D7              EQU     7       ; PB7

;-----------------------------------------------------------------------------
; TFT / ILI9341 commands
;-----------------------------------------------------------------------------
ILI9341_SWRESET     EQU     0x01
ILI9341_SLPOUT      EQU     0x11
ILI9341_GAMSET      EQU     0x26
ILI9341_DISPON      EQU     0x29
ILI9341_CASET       EQU     0x2A
ILI9341_PASET       EQU     0x2B
ILI9341_RAMWR       EQU     0x2C
ILI9341_MADCTL      EQU     0x36
ILI9341_PIXFMT      EQU     0x3A
ILI9341_FRMCTR1     EQU     0xB1
ILI9341_DFUNCTR     EQU     0xB6
ILI9341_PWCTR1      EQU     0xC0
ILI9341_PWCTR2      EQU     0xC1
ILI9341_VMCTR1      EQU     0xC5
ILI9341_VMCTR2      EQU     0xC7

;-----------------------------------------------------------------------------
; ADC
;-----------------------------------------------------------------------------
SNS_BREATH_ADC      EQU     0           ; PA0 -> ADC1_IN0
SNS_SMOKE_ADC       EQU     1           ; PA1 -> ADC1_IN1

ADC1_BASE           EQU     0x40012000

ADC_SR              EQU     0x00
ADC_CR1             EQU     0x04
ADC_CR2             EQU     0x08
ADC_SMPR2           EQU     0x10
ADC_SQR1            EQU     0x2C
ADC_SQR3            EQU     0x34
ADC_DR              EQU     0x4C

ADC_CR2_ADON        EQU     0x00000001
ADC_CR2_SWSTART     EQU     0x40000000
ADC_SR_EOC          EQU     0x00000002

;-----------------------------------------------------------------------------
; LED / outputs
;-----------------------------------------------------------------------------
LED_PIN             EQU     12
ACT_SERVO_SAN       EQU     6
ACT_SERVO_MED       EQU     7
BUZZER_PIN          EQU     3
IR_LED_PORT        EQU     GPIOC_BASE
IR_LED_PIN         EQU     14
;-----------------------------------------------------------------------------
; Motor driver
;-----------------------------------------------------------------------------
MOT_IN1             EQU     8
MOT_IN2             EQU     9
MOT_IN3             EQU     10
MOT_IN4             EQU     11

MOT_ENA             EQU     8
MOT_ENB             EQU     9

MOTION_STOP         EQU     0

;-----------------------------------------------------------------------------
; I2C
;-----------------------------------------------------------------------------
I2C_SCL_PIN         EQU     8
I2C_SDA_PIN         EQU     9

;-----------------------------------------------------------------------------
; Line tracker
;-----------------------------------------------------------------------------
LINE_LEFT           EQU     0
LINE_CENTER         EQU     1
LINE_RIGHT          EQU     2

;-----------------------------------------------------------------------------
; Keypad rows
;-----------------------------------------------------------------------------
KEY_ROW1            EQU     8           ; PA8
KEY_ROW2            EQU     9           ; PA9
KEY_ROW3            EQU     10          ; PA10
KEY_ROW4            EQU     11          ; PA11

;-----------------------------------------------------------------------------
; Keypad columns
; REAL WIRING:
;   C1 = PB13
;   C2 = PB14
;   C3 = PB15
;   C4 = PB10
;-----------------------------------------------------------------------------
KEY_COL1            EQU     13          ; PB13
KEY_COL2            EQU     14          ; PB14
KEY_COL3            EQU     15          ; PB15
KEY_COL4            EQU     10          ; PB10

;-----------------------------------------------------------------------------
; Keypad pull-up masks for PB10, PB13, PB14, PB15
;-----------------------------------------------------------------------------
KP_PUPDR_CLEAR      EQU     0xCC300000
KP_PUPDR_SET        EQU     0x54100000

;-----------------------------------------------------------------------------
; Keypad codes
;-----------------------------------------------------------------------------
KEY_NONE            EQU     0

KEY_1               EQU     1
KEY_2               EQU     2
KEY_3               EQU     3
KEY_A               EQU     4

KEY_4               EQU     5
KEY_5               EQU     6
KEY_6               EQU     7
KEY_B               EQU     8

KEY_7               EQU     9
KEY_8               EQU     10
KEY_9               EQU     11
KEY_C               EQU     12

KEY_STAR            EQU     13
KEY_0               EQU     14
KEY_HASH            EQU     15
KEY_D               EQU     16

;-----------------------------------------------------------------------------
; Alarm flags
;-----------------------------------------------------------------------------
Smoke_Alert_Flag    EQU     0x00000001
Med_Alert_Flag      EQU     0x00000002

;-----------------------------------------------------------------------------
; System states
;-----------------------------------------------------------------------------
STATE_MAIN_MENU     EQU     0
STATE_SANITIZING    EQU     1
STATE_HEART_RATE    EQU     2
STATE_BREATHING     EQU     3
STATE_MED_ALERT     EQU     4
STATE_MOTION        EQU     5
STATE_MED_INPUT     EQU     6
STATE_MED_DISPENSE  EQU     7
STATE_SMOKE_ALERT   EQU     8
STATE_MED_WAITING   EQU     9

STATE_INVALID       EQU     0xFFFFFFFF
	 END