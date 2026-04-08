;=============================================================================
; constants.s
; INCLUDE-ONLY file – use with:  GET constants.s
; No AREA or END directive in this file.
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
; GPIO – register offsets (from any GPIOx_BASE)
;-----------------------------------------------------------------------------
GPIO_MODER          EQU     0x00
GPIO_OTYPER         EQU     0x04
GPIO_OSPEEDR        EQU     0x08
GPIO_PUPDR          EQU     0x0C
GPIO_IDR            EQU     0x10
GPIO_ODR            EQU     0x14
GPIO_BSRR           EQU     0x18

;-----------------------------------------------------------------------------
; Bit-position masks
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
; TFT – control pin numbers (on their GPIO port)
; WARNING: TFT_RST_PIN = 12 shares the same pin number as LED_PIN (PB12).
;          If TFT is ever connected, move LED to a different pin or
;          move TFT_RST to a different port pin before enabling TFT_Init.
;-----------------------------------------------------------------------------
TFT_DATA_MASK   EQU   0x000000FF

TFT_RS_PIN          EQU     2
TFT_WR_PIN          EQU     3
TFT_RD_PIN          EQU     4
TFT_CS_PIN          EQU     5
TFT_RST_PIN         EQU     12          ; WARNING: conflicts with LED_PIN on PB12
; ================= TFT DATA BUS (GPIOB) =================
TFT_D0      EQU     0       ; PB0
TFT_D1      EQU     1       ; PB1
TFT_D2      EQU     2       ; PB2
TFT_D3      EQU     3       ; PB3
TFT_D4      EQU     4       ; PB4
TFT_D5      EQU     5       ; PB5
TFT_D6      EQU     6       ; PB6
TFT_D7      EQU     7       ; PB7
;-----------------------------------------------------------------------------
; TFT / ILI9341 command set
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
; ADC – sensor channel assignments
;-----------------------------------------------------------------------------
SNS_BREATH_ADC      EQU     0           ; PA0 – ADC1_IN0
SNS_SMOKE_ADC       EQU     1           ; PA1 – ADC1_IN1 (MQ2)

;-----------------------------------------------------------------------------
; ADC1 – peripheral base address
;-----------------------------------------------------------------------------
ADC1_BASE           EQU     0x40012000

;-----------------------------------------------------------------------------
; ADC1 – register offsets (from ADC1_BASE)
;-----------------------------------------------------------------------------
ADC_SR              EQU     0x00        ; Status register
ADC_CR1             EQU     0x04        ; Control register 1
ADC_CR2             EQU     0x08        ; Control register 2
ADC_SMPR2           EQU     0x10        ; Sample-time register (ch 0–9)
ADC_SQR1            EQU     0x2C        ; Sequence register 1 (length)
ADC_SQR3            EQU     0x34        ; Sequence register 3 (1st conv)
ADC_DR              EQU     0x4C        ; Data register

;-----------------------------------------------------------------------------
; ADC1 – control / status bits
;-----------------------------------------------------------------------------
ADC_CR2_ADON        EQU     0x00000001  ; ADC on/off
ADC_CR2_SWSTART     EQU     0x40000000  ; Software start conversion
ADC_SR_EOC          EQU     0x00000002  ; End-of-conversion flag

;-----------------------------------------------------------------------------
; LED – PB12, active high
; WARNING: same pin number as TFT_RST_PIN – see TFT note above
;-----------------------------------------------------------------------------
LED_PIN             EQU     12

;-----------------------------------------------------------------------------
; Servos
;-----------------------------------------------------------------------------
ACT_SERVO_SAN       EQU     6
ACT_SERVO_MED       EQU     7

;-----------------------------------------------------------------------------
; Buzzer
;-----------------------------------------------------------------------------
BUZZER_PIN          EQU     3

;-----------------------------------------------------------------------------
; Motor driver – direction and enable pins
;-----------------------------------------------------------------------------
MOT_IN1             EQU     8
MOT_IN2             EQU     9
MOT_IN3             EQU     10
MOT_IN4             EQU     11

MOT_ENA             EQU     8
MOT_ENB             EQU     9

MOTION_STOP         EQU     0

;-----------------------------------------------------------------------------
; I2C – pin numbers
;-----------------------------------------------------------------------------
I2C_SCL_PIN         EQU     6
I2C_SDA_PIN         EQU     7

;-----------------------------------------------------------------------------
; Line tracker – channel indices
;-----------------------------------------------------------------------------
LINE_LEFT           EQU     0
LINE_CENTER         EQU     1
LINE_RIGHT          EQU     2

;-----------------------------------------------------------------------------
; Keypad – row pins on GPIOA  (outputs, driven LOW one at a time)
;-----------------------------------------------------------------------------
KEY_ROW1            EQU     8           ; PA8
KEY_ROW2            EQU     9           ; PA9
KEY_ROW3            EQU     10          ; PA10
KEY_ROW4            EQU     11          ; PA11
 
;-----------------------------------------------------------------------------
; Keypad – column pins on GPIOB  (inputs with internal pull-up)
;-----------------------------------------------------------------------------
KEY_COL1            EQU     10          ; PB10
KEY_COL2            EQU     13          ; PB13
KEY_COL3            EQU     14          ; PB14
KEY_COL4            EQU     15          ; PB15
 
;-----------------------------------------------------------------------------
; Keypad – PUPDR pre-computed masks for KEY_COL1..KEY_COL4
; (PB10, PB13, PB14, PB15)
;
; PUPDR has 2 bits per pin:
;   PB10 -> bits [21:20]  clear = 0x00300000  pull-up (01) = 0x00100000
;   PB13 -> bits [27:26]  clear = 0x0C000000  pull-up (01) = 0x04000000
;   PB14 -> bits [29:28]  clear = 0x30000000  pull-up (01) = 0x10000000
;   PB15 -> bits [31:30]  clear = 0xC0000000  pull-up (01) = 0x40000000
;
; If KEY_COL pins change, update these two masks to match.
;-----------------------------------------------------------------------------
KP_PUPDR_CLEAR      EQU     0xCC300000
KP_PUPDR_SET        EQU     0x54100000
 
;-----------------------------------------------------------------------------
; Keypad – key codes
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
; Alarm flags (bits inside g_alarm_flags)
;-----------------------------------------------------------------------------
Smoke_Alert_Flag    EQU     0x00000001
Med_Alert_Flag      EQU     0x00000002

;-----------------------------------------------------------------------------
; System states (values for g_sys_state)
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