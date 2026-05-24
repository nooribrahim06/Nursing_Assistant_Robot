;=============================================================================
; constants.s
; INCLUDE-ONLY file ? use with: GET constants.s
;=============================================================================

;-----------------------------------------------------------------------------
; RCC
;-----------------------------------------------------------------------------
RCC_BASE            EQU     0x40023800
RCC_AHB1ENR         EQU     0x30
RCC_APB1ENR         EQU     0x40
RCC_APB2ENR         EQU     0x44

;-----------------------------------------------------------------------------
; GPIO ? base addresses
;-----------------------------------------------------------------------------
GPIOA_BASE          EQU     0x40020000
GPIOB_BASE          EQU     0x40020400
GPIOC_BASE          EQU     0x40020800

;-----------------------------------------------------------------------------
; GPIO ? register offsets
;-----------------------------------------------------------------------------
GPIO_MODER          EQU     0x00
GPIO_OTYPER         EQU     0x04
GPIO_OSPEEDR        EQU     0x08
GPIO_PUPDR          EQU     0x0C
GPIO_IDR            EQU     0x10
GPIO_ODR            EQU     0x14
GPIO_BSRR           EQU     0x18
GPIO_AFRL           EQU     0x20
GPIO_AFRH           EQU     0x24

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
; TFT ? SPI ILI9341
;-----------------------------------------------------------------------------
TFT_CS_PIN          EQU     0
TFT_DC_PIN          EQU     1
TFT_RS_PIN          EQU     1
TFT_RST_PIN         EQU     2
TFT_SCK_PIN         EQU     3
TFT_MOSI_PIN        EQU     5

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
SNS_BREATH_ADC      EQU     0
SNS_SMOKE_ADC       EQU     1

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

; ADC Analog Watchdog
ADC_HTR             EQU     0x24
ADC_LTR             EQU     0x28
ADC_CR1_AWDEN       EQU     (1 << 23)
ADC_CR1_AWDSGL      EQU     (1 << 9)
ADC_CR1_AWDIE       EQU     (1 << 6)
ADC_SR_AWD          EQU     (1 << 0)

;-----------------------------------------------------------------------------
; Outputs
;-----------------------------------------------------------------------------
LED_PIN             EQU     12
ACT_SERVO_SAN       EQU     6
ACT_SERVO_MED       EQU     7
BUZZER_PIN          EQU     4
IR_LED_PORT         EQU     GPIOC_BASE
IR_LED_PIN          EQU     14

;-----------------------------------------------------------------------------
; Motor driver
;-----------------------------------------------------------------------------
MOT_IN1             EQU     8
MOT_IN2             EQU     9
MOT_IN3             EQU     10
MOT_IN4             EQU     11

MOT_ENA             EQU     6
MOT_ENB             EQU     7

MOTION_STOP         EQU     0

;-----------------------------------------------------------------------------
; I2C
;-----------------------------------------------------------------------------
I2C_SCL_PIN         EQU     8
I2C_SDA_PIN         EQU     9

;-----------------------------------------------------------------------------
; Line tracker
;-----------------------------------------------------------------------------
LINE_LEFT           EQU     12
LINE_CENTER         EQU     15
LINE_RIGHT          EQU     14
STATION_IR_PIN      EQU     13
Black_High          EQU     1
Black_Low           EQU     0	
;-----------------------------------------------------------------------------
; Alarm flags
;-----------------------------------------------------------------------------
Smoke_Alert_Flag        EQU     0x00000001
Med_Alert_Flag          EQU     0x00000002
SMOKE_IGNORE_ITERATIONS EQU     200
SMOKE_COOLDOWN_MS       EQU     5000    ; 5-second guaranteed cooldown after dismiss

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
STATE_TEMP          EQU     10
STATE_PPG_WAVE      EQU     11
STATE_VISION        EQU     12
STATE_VISION_RES    EQU     13
STATE_VEIN_FINDER   EQU     14
STATE_STRESS        EQU     16      ; Stress Level feature
STATE_MORE_MENU     EQU     17      ; Secondary menu page (Vision / Vein / Stress)

STATE_INVALID       EQU     0xFFFFFFFF

;-----------------------------------------------------------------------------
; SysTick
;-----------------------------------------------------------------------------
SYST_CSR            EQU     0xE000E010
SYST_RVR            EQU     0xE000E014
SYST_CVR            EQU     0xE000E018

SYST_ENABLE         EQU     0x00000001
SYST_TICKINT        EQU     0x00000002
SYST_CLKSRC         EQU     0x00000004

;-----------------------------------------------------------------------------
; Generic key codes used by UI / medicine logic
;-----------------------------------------------------------------------------
KEY_NONE            EQU     0
KEY_0               EQU     1
KEY_1               EQU     2
KEY_2               EQU     3
KEY_3               EQU     4
KEY_4               EQU     5
KEY_5               EQU     6
KEY_6               EQU     7
KEY_7               EQU     8
KEY_8               EQU     9
KEY_9               EQU     10
KEY_A               EQU     11
KEY_B               EQU     12
KEY_C               EQU     13
KEY_D               EQU     14
KEY_UP              EQU     15
KEY_DOWN            EQU     16
KEY_LEFT            EQU     17
KEY_RIGHT           EQU     18

;-----------------------------------------------------------------------------
; IR pin map
; PB10 -> IR receiver
;-----------------------------------------------------------------------------
IR_GPIO_PORT        EQU     GPIOB_BASE
IR_PIN              EQU     10

;-----------------------------------------------------------------------------
; IR command bytes only
;-----------------------------------------------------------------------------
IR_CODE_0           EQU     0x19      ; decimal 25
IR_CODE_1           EQU     0x45      ; decimal 69
IR_CODE_2           EQU     0x46      ; decimal 70
IR_CODE_3           EQU     0x47      ; decimal 71
IR_CODE_4           EQU     0x44      ; decimal 68
IR_CODE_5           EQU     0x40      ; decimal 64
IR_CODE_6           EQU     0x43      ; decimal 67
IR_CODE_7           EQU     0x07      ; decimal 7
IR_CODE_8           EQU     0x15      ; decimal 21
IR_CODE_9           EQU     0x09      ; decimal 9

IR_CODE_OK          EQU     0x1C      ; decimal 28 / OK
IR_CODE_CLR         EQU     0x16      ; decimal 22 / *
IR_CODE_BACK        EQU     0x0D      ; decimal 13 / #
IR_CODE_EXIT        EQU     0x02      ; decimal 2 / Down

IR_CODE_UP          EQU     0x18      ; optional
IR_CODE_LEFT        EQU     0x08      ; optional
IR_CODE_RIGHT       EQU     0x5A      ; optional
IR_CODE_DOWN        EQU     0x02      ; decimal 2

;-----------------------------------------------------------------------------
; SYSCFG / EXTI / NVIC for IR interrupt
;-----------------------------------------------------------------------------
SYSCFG_BASE         EQU     0x40013800
SYSCFG_EXTICR1      EQU     0x08
SYSCFG_EXTICR2      EQU     0x0C
SYSCFG_EXTICR3      EQU     0x10
SYSCFG_EXTICR4      EQU     0x14

EXTI_BASE           EQU     0x40013C00
EXTI_IMR            EQU     0x00
EXTI_EMR            EQU     0x04
EXTI_RTSR           EQU     0x08
EXTI_FTSR           EQU     0x0C
EXTI_SWIER          EQU     0x10
EXTI_PR             EQU     0x14

NVIC_ISER0          EQU     0xE000E100
NVIC_ISER1          EQU     0xE000E104

;-----------------------------------------------------------------------------
; TIM2 for 1 us IR timing
;-----------------------------------------------------------------------------
TIM2_BASE           EQU     0x40000000
TIM5_BASE           EQU     0x40000C00
TIM_CR1             EQU     0x00
TIM_CNT             EQU     0x24
TIM_PSC             EQU     0x28
TIM_ARR             EQU     0x2C
TIM_EGR             EQU     0x14

;-----------------------------------------------------------------------------
; Sanitizing pump / hand sensor
;-----------------------------------------------------------------------------
SAN_GPIO_PORT        EQU     GPIOA_BASE
SAN_SENSOR_PIN       EQU     4
SAN_RELAY_PIN        EQU     5
SAN_PUMP_DELAY       EQU     200000
        END

;=============================================================================
; bluetooth_constants.s
; HC-05 / USART2 Bluetooth constants for STM32F401RC
;
; PA2 = USART2_TX -> HC-05 RX
; PA3 = USART2_RX <- HC-05 TX
; 9600 baud, 8 data bits, no parity, 1 stop bit
;=============================================================================

;-----------------------------------------------------------------------------
; USART2 peripheral
;---------------------------------------------- -------------------------------
BT_USART2_BASE          EQU     0x40004400

BT_USART_SR             EQU     0x00
BT_USART_DR             EQU     0x04
BT_USART_BRR            EQU     0x08
BT_USART_CR1            EQU     0x0C
BT_USART_CR2            EQU     0x10
BT_USART_CR3            EQU     0x14

BT_USART_SR_RXNE        EQU     0x00000020
BT_USART_SR_TXE         EQU     0x00000080

BT_USART_CR1_RE         EQU     0x00000004
BT_USART_CR1_TE         EQU     0x00000008
BT_USART_CR1_UE         EQU     0x00002000

; USART2 clock is RCC_APB1ENR bit 17
BT_RCC_USART2_EN        EQU     0x00020000

; 16 MHz / 9600 baud, OVER8 = 0 => BRR approx 0x0683
; If your project later changes APB1 clock, update this value only.
BT_USART2_BRR_9600      EQU     0x00000683

;-----------------------------------------------------------------------------
; GPIO pins / alternate function
;-----------------------------------------------------------------------------
BT_TX_PIN               EQU     2       ; PA2
BT_RX_PIN               EQU     3       ; PA3
BT_USART_AF             EQU     7       ; AF7 = USART2

; PA2/PA3 MODER mask and value for alternate function mode
BT_GPIOA_PA2_PA3_MODER_MASK EQU 0x000000F0
BT_GPIOA_PA2_PA3_MODER_AF   EQU 0x000000A0

; PA2/PA3 AFRL mask/value, AF7 on both pins
BT_GPIOA_PA2_PA3_AFRL_MASK  EQU 0x0000FF00
BT_GPIOA_PA2_PA3_AFRL_AF7   EQU 0x00007700

; Pull-up only on RX PA3. PA2 stays no-pull.
BT_GPIOA_PA2_PA3_PUPD_MASK  EQU 0x000000F0
BT_GPIOA_PA3_PULLUP         EQU 0x00000040

; Medium/high output speed for PA2/PA3
BT_GPIOA_PA2_PA3_SPEED_MASK EQU 0x000000F0
BT_GPIOA_PA2_PA3_SPEED_FAST EQU 0x000000A0

;-----------------------------------------------------------------------------
; RX/TX buffers
;-----------------------------------------------------------------------------
BT_RX_BUFFER_SIZE       EQU     80
BT_RX_LAST_INDEX        EQU     79
BT_TX_BUFFER_SIZE       EQU     192
BT_TX_LAST_INDEX        EQU     191
BT_NUM_BUFFER_SIZE      EQU     12

;-----------------------------------------------------------------------------
; ASCII
;-----------------------------------------------------------------------------
BT_ASCII_CR             EQU     13
BT_ASCII_LF             EQU     10
BT_ASCII_0              EQU     48

;-----------------------------------------------------------------------------
; Bluetooth command values shared with motion member
;-----------------------------------------------------------------------------
BT_CMD_NONE             EQU     0

BT_MODE_LINE            EQU     1
BT_MODE_PHONE           EQU     2

BT_DIR_FWD              EQU     1
BT_DIR_BACK             EQU     2
BT_DIR_LEFT             EQU     3
BT_DIR_RIGHT            EQU     4
BT_DIR_STOP             EQU     5

;-----------------------------------------------------------------------------
; Reporting
;-----------------------------------------------------------------------------
BT_REPORT_PERIOD_MS     EQU     250
BT_PATIENT_ID_TEXT      EQU     001

        END
