; =====================================================================
; bluetooth.s (Touched for faster reporting)
; HC-05 Bluetooth communication layer on STM32F401RC USART2
;
; FIXED:
;   - Added LTORG blocks between functions to prevent:
;     A1284E: Literal pool too distant, use LTORG to assemble it within 4KB
;
; Role of this file:
;   - Configure USART2 on PA2/PA3 at 9600 8N1
;   - Receive commands without blocking
;   - Parse only the agreed phone motion commands
;   - Set request flags for motion layer
;   - Periodically queue and transmit structured packets
;
; This file does NOT control motors and does NOT change UI state.
;=============================================================================

        GET     constants.s
        ;GET     bluetooth_constants.s

        AREA    BT_RODATA, DATA, READONLY
        ALIGN

BT_TEXT_CMD_MODE_PHONE  DCB "PHONE",0
BT_TEXT_CMD_MODE_LINE   DCB "LINE",0
BT_TEXT_ACK_PREFIX      DCB "ACK=",0
BT_TEXT_CMD_DIR_FWD     DCB "FWD",0
BT_TEXT_CMD_DIR_BACK    DCB "BACK",0
BT_TEXT_CMD_DIR_LEFT    DCB "LEFT",0
BT_TEXT_CMD_DIR_RIGHT   DCB "RIGHT",0
BT_TEXT_CMD_DIR_STOP    DCB "STOP",0
BT_TEXT_CMD_OFF         DCB "OFF",0
BT_TEXT_CMD_MED         DCB "MED",0
BT_TEXT_CMD_SMOKE       DCB "SMOKE",0

BT_TX_VITALS_1          DCB "TYPE=VITALS,PATIENT=001,BPM=",0
BT_TX_SPO2              DCB ",SPO2=",0
BT_TX_BREATH            DCB ",BREATH=",0
BT_TX_SMOKE             DCB ",SMOKE=",0
BT_TX_MED               DCB ",MED=",0
BT_TX_ALERT_FIELD       DCB ",ALERT=",0
BT_TX_NONE              DCB "NONE",0
BT_TX_SMOKE_DETECTED    DCB "SMOKE_DETECTED",0
BT_TX_MED_ALERT         DCB "MED_ALERT",0
BT_TX_BOTH_ALERTS       DCB "SMOKE_AND_MED",0

BT_TX_ALERT_1           DCB "TYPE=ALERT,PATIENT=001,ALERT=SMOKE_DETECTED,SMOKE=",0
BT_TX_MED_EVENT         DCB "TYPE=MED_EVENT,PATIENT=001,MED_ID=MED01,STATUS=DISPENSED",13,10,0

BT_TX_DEBUG_1           DCB "TYPE=DEBUG,PATIENT=001,SMOKE_RAW=",0
BT_TX_DEBUG_BREATH      DCB ",BREATH_RAW=",0
BT_TX_DEBUG_STATE       DCB ",STATE=",0
BT_TX_DEBUG_LINE_L      DCB ",LINE_L=",0
BT_TX_DEBUG_LINE_C      DCB ",LINE_C=",0
BT_TX_DEBUG_LINE_R      DCB ",LINE_R=",0
BT_TX_CRLF              DCB 13,10,0

        AREA    BT_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

;-----------------------------------------------------------------------------
; Public API
;-----------------------------------------------------------------------------
        EXPORT  BT_Init
        EXPORT  BT_RxTask
        EXPORT  BT_PeriodicTask

; Compatibility with the old skeleton name
        EXPORT  BT_Update

; Optional/debug exports
        EXPORT  BT_ParseLine
        EXPORT  BT_ClearBuffer
        EXPORT  BT_SendVitalsNow
        EXPORT  BT_SendDebugNow
        EXPORT  BT_SendMedDispensed
        EXPORT  BT_TxTask
        EXPORT  BT_QueueACK

;-----------------------------------------------------------------------------
; Shared project globals
;-----------------------------------------------------------------------------
        IMPORT  g_ms_ticks
        IMPORT  g_bpm
        IMPORT  g_spo2
        IMPORT  g_breath_level
        IMPORT  g_smoke_level
        IMPORT  g_med_timer
        IMPORT  g_alarm_flags
        IMPORT  g_sys_state

; Optional pin debug only. No motor control is done here.
        IMPORT  GPIO_ReadPin

;-----------------------------------------------------------------------------
; Bluetooth globals from bluetooth_buffers.s
;-----------------------------------------------------------------------------
        IMPORT  g_bt_cmd_ready
        IMPORT  g_bt_motion_mode_request
        IMPORT  g_bt_motion_dir_request
        IMPORT  g_sys_state
        IMPORT  g_alarm_flags
        IMPORT  g_smoke_ignore_counter
        IMPORT  g_bt_last_rx_tick

        IMPORT  bt_rx_buffer
        IMPORT  bt_rx_index
        IMPORT  bt_tx_buffer
        IMPORT  bt_tx_len
        IMPORT  bt_tx_index
        IMPORT  bt_last_vitals_tick
        IMPORT  bt_last_alert_tick
        IMPORT  bt_alert_active
        IMPORT  bt_last_med_state
        IMPORT  bt_num_buffer

;=============================================================================
; BT_Init
;=============================================================================
BT_Init
        PUSH    {R4-R7, LR}

        ; Clear public command flags
        MOVS    R1, #0
        LDR     R0, =g_bt_cmd_ready
        STR     R1, [R0]
        LDR     R0, =g_bt_motion_mode_request
        STR     R1, [R0]
        LDR     R0, =g_bt_motion_dir_request
        STR     R1, [R0]
        LDR     R0, =g_bt_last_rx_tick
        STR     R1, [R0]

        ; Clear private state
        LDR     R0, =bt_rx_index
        STR     R1, [R0]
        LDR     R0, =bt_tx_len
        STR     R1, [R0]
        LDR     R0, =bt_tx_index
        STR     R1, [R0]
        LDR     R0, =bt_last_vitals_tick
        STR     R1, [R0]
        LDR     R0, =bt_last_alert_tick
        STR     R1, [R0]
        LDR     R0, =bt_alert_active
        STR     R1, [R0]
        LDR     R0, =bt_last_med_state
        STR     R1, [R0]

        ; Enable GPIOA clock
        LDR     R4, =RCC_BASE
        LDR     R5, [R4, #RCC_AHB1ENR]
        ORR     R5, R5, #BIT0
        STR     R5, [R4, #RCC_AHB1ENR]

        ; Enable USART2 clock on APB1
        LDR     R5, [R4, #RCC_APB1ENR]
        LDR     R6, =BT_RCC_USART2_EN
        ORR     R5, R5, R6
        STR     R5, [R4, #RCC_APB1ENR]

        ; PA2/PA3 alternate function mode
        LDR     R4, =GPIOA_BASE
        LDR     R5, [R4, #GPIO_MODER]
        LDR     R6, =BT_GPIOA_PA2_PA3_MODER_MASK
        BIC     R5, R5, R6
        LDR     R6, =BT_GPIOA_PA2_PA3_MODER_AF
        ORR     R5, R5, R6
        STR     R5, [R4, #GPIO_MODER]

        ; PA2/PA3 AF7 for USART2
        LDR     R5, [R4, #GPIO_AFRL]
        LDR     R6, =BT_GPIOA_PA2_PA3_AFRL_MASK
        BIC     R5, R5, R6
        LDR     R6, =BT_GPIOA_PA2_PA3_AFRL_AF7
        ORR     R5, R5, R6
        STR     R5, [R4, #GPIO_AFRL]

        ; Pull-up on PA3 RX only
        LDR     R5, [R4, #GPIO_PUPDR]
        LDR     R6, =BT_GPIOA_PA2_PA3_PUPD_MASK
        BIC     R5, R5, R6
        LDR     R6, =BT_GPIOA_PA3_PULLUP
        ORR     R5, R5, R6
        STR     R5, [R4, #GPIO_PUPDR]

        ; Fast enough speed for USART pins
        LDR     R5, [R4, #GPIO_OSPEEDR]
        LDR     R6, =BT_GPIOA_PA2_PA3_SPEED_MASK
        BIC     R5, R5, R6
        LDR     R6, =BT_GPIOA_PA2_PA3_SPEED_FAST
        ORR     R5, R5, R6
        STR     R5, [R4, #GPIO_OSPEEDR]

        ; Configure USART2: 9600, 8N1, TX+RX enabled
        LDR     R4, =BT_USART2_BASE
        MOVS    R5, #0
        STR     R5, [R4, #BT_USART_CR1]
        STR     R5, [R4, #BT_USART_CR2]
        STR     R5, [R4, #BT_USART_CR3]

        LDR     R5, =BT_USART2_BRR_9600
        STR     R5, [R4, #BT_USART_BRR]

        LDR     R5, =(BT_USART_CR1_UE + BT_USART_CR1_TE + BT_USART_CR1_RE)
        STR     R5, [R4, #BT_USART_CR1]

        ; Clear stale DR if RXNE was already set
        LDR     R5, [R4, #BT_USART_SR]
        TST     R5, #BT_USART_SR_RXNE
        BEQ     BTI_Done
        LDR     R5, [R4, #BT_USART_DR]

BTI_Done
        POP     {R4-R7, PC}

        ALIGN
        LTORG

;=============================================================================
; BT_Update
; Old skeleton compatibility. Main can call BT_Update or BT_RxTask.
;=============================================================================
BT_Update
        B       BT_RxTask

        ALIGN
        LTORG

;=============================================================================
; BT_RxTask
; Non-blocking receiver. Reads at most one byte per call.
;=============================================================================
BT_RxTask
        PUSH    {R4-R7, LR}

BTRX_PollLoop
        LDR     R4, =BT_USART2_BASE
        LDR     R5, [R4, #BT_USART_SR]
        TST     R5, #BT_USART_SR_RXNE
        BEQ     BTRX_Exit

        ; Read byte. Reading DR clears RXNE.
        LDR     R6, [R4, #BT_USART_DR]
        AND     R6, R6, #0xFF

        ; Update last RX tick on every received byte
        LDR     R4, =g_ms_ticks
        LDR     R5, [R4]
        LDR     R4, =g_bt_last_rx_tick
        STR     R5, [R4]

        ; Ignore CR
        CMP     R6, #BT_ASCII_CR
        BEQ     BTRX_PollLoop

        ; LF ends the command line
        CMP     R6, #BT_ASCII_LF
        BEQ     BTRX_LineDone

        ; Normal character: append if room exists
        LDR     R4, =bt_rx_index
        LDR     R5, [R4]
        CMP     R5, #BT_RX_LAST_INDEX
        BHS     BTRX_Overflow

        LDR     R7, =bt_rx_buffer
        STRB    R6, [R7, R5]
        ADDS    R5, R5, #1
        STR     R5, [R4]
        B       BTRX_PollLoop

BTRX_LineDone
        LDR     R4, =bt_rx_index
        LDR     R5, [R4]
        CMP     R5, #0
        BEQ     BTRX_ClearOnly

        LDR     R7, =bt_rx_buffer
        MOVS    R6, #0
        STRB    R6, [R7, R5]
        BL      BT_ParseLine

BTRX_ClearOnly
        BL      BT_ClearBuffer
        B       BTRX_PollLoop

BTRX_Overflow
        ; Corrupted/too-long line: drop it safely.
        BL      BT_ClearBuffer

BTRX_Exit
        POP     {R4-R7, PC}

        ALIGN
        LTORG

;=============================================================================
; BT_ClearBuffer
; Clears RX build buffer only. It does NOT clear g_bt_cmd_ready.
; Motion layer clears g_bt_cmd_ready after consuming the request.
;=============================================================================
BT_ClearBuffer
        PUSH    {R0, R1, LR}
        MOVS    R1, #0
        LDR     R0, =bt_rx_index
        STR     R1, [R0]
        LDR     R0, =bt_rx_buffer
        STRB    R1, [R0]
        POP     {R0, R1, PC}

        ALIGN
        LTORG

;=============================================================================
; BT_Contains
; Returns 1 in R0 if substring in R1 is found anywhere inside string in R0.
;=============================================================================
BT_Contains
        PUSH    {R4-R7, LR}
        MOV     R4, R0          ; R4 = Buffer pointer
        MOV     R5, R1          ; R5 = Substring pointer

BTC_Loop
        LDRB    R6, [R4]
        CMP     R6, #0
        BEQ     BTC_NotFound

        MOV     R0, R4
        MOV     R1, R5
        BL      BT_StartsWith
        CMP     R0, #1
        BEQ     BTC_Found

        ADDS    R4, R4, #1
        B       BTC_Loop

BTC_Found
        MOVS    R0, #1
        POP     {R4-R7, PC}

BTC_NotFound
        MOVS    R0, #0
        POP     {R4-R7, PC}

;=============================================================================
; BT_StartsWith
; Returns 1 if R0 starts with R1
;=============================================================================
BT_StartsWith
        PUSH    {R4-R5, LR}
BTSW_Loop
        LDRB    R5, [R1], #1
        CMP     R5, #0
        BEQ     BTSW_Match
        LDRB    R4, [R0], #1
        CMP     R4, #0
        BEQ     BTSW_NoMatch
        CMP     R4, R5
        BNE     BTSW_NoMatch
        B       BTSW_Loop
BTSW_Match
        MOVS    R0, #1
        POP     {R4-R5, PC}
BTSW_NoMatch
        MOVS    R0, #0
        POP     {R4-R5, PC}

;=============================================================================
; BT_ParseLine
; Now uses ultra-robust SUBSTRING matching. Ignores all garbage formatting!
;=============================================================================
BT_ParseLine
        PUSH    {R4-R7, LR}

        ; 1. Check for FWD
        LDR     R0, =bt_rx_buffer
        LDR     R1, =BT_TEXT_CMD_DIR_FWD
        BL      BT_Contains
        CMP     R0, #1
        BEQ     BTP_DirFwd

        ; 2. Check for BACK
        LDR     R0, =bt_rx_buffer
        LDR     R1, =BT_TEXT_CMD_DIR_BACK
        BL      BT_Contains
        CMP     R0, #1
        BEQ     BTP_DirBack

        ; 3. Check for LEFT
        LDR     R0, =bt_rx_buffer
        LDR     R1, =BT_TEXT_CMD_DIR_LEFT
        BL      BT_Contains
        CMP     R0, #1
        BEQ     BTP_DirLeft

        ; 4. Check for RIGHT
        LDR     R0, =bt_rx_buffer
        LDR     R1, =BT_TEXT_CMD_DIR_RIGHT
        BL      BT_Contains
        CMP     R0, #1
        BEQ     BTP_DirRight

        ; 5. Check for STOP
        LDR     R0, =bt_rx_buffer
        LDR     R1, =BT_TEXT_CMD_DIR_STOP
        BL      BT_Contains
        CMP     R0, #1
        BEQ     BTP_DirStop

        ; 6. Check for MODE=PHONE
        LDR     R0, =bt_rx_buffer
        LDR     R1, =BT_TEXT_CMD_MODE_PHONE
        BL      BT_Contains
        CMP     R0, #1
        BEQ     BTP_ModePhone

        ; 7. Check for MODE=LINE
        LDR     R0, =bt_rx_buffer
        LDR     R1, =BT_TEXT_CMD_MODE_LINE
        BL      BT_Contains
        CMP     R0, #1
        BEQ     BTP_ModeLine

        ; 8. Check if it's an OFF command
        LDR     R0, =bt_rx_buffer
        LDR     R1, =BT_TEXT_CMD_OFF
        BL      BT_Contains
        CMP     R0, #1
        BNE     BTP_Exit

        ; It's an OFF command. Is it MED or SMOKE?
        LDR     R0, =bt_rx_buffer
        LDR     R1, =BT_TEXT_CMD_MED
        BL      BT_Contains
        CMP     R0, #1
        BEQ     BTP_MedOff

        LDR     R0, =bt_rx_buffer
        LDR     R1, =BT_TEXT_CMD_SMOKE
        BL      BT_Contains
        CMP     R0, #1
        BEQ     BTP_SmokeOff

        ; Unknown OFF command
        B       BTP_Exit

BTP_DirFwd
        MOVS    R0, #BT_DIR_FWD
        BL      BT_SetDirRequest
        BL      BT_QueueACK
        B       BTP_Exit

BTP_DirBack
        MOVS    R0, #BT_DIR_BACK
        BL      BT_SetDirRequest
        BL      BT_QueueACK
        B       BTP_Exit

BTP_DirLeft
        MOVS    R0, #BT_DIR_LEFT
        BL      BT_SetDirRequest
        BL      BT_QueueACK
        B       BTP_Exit

BTP_DirRight
        MOVS    R0, #BT_DIR_RIGHT
        BL      BT_SetDirRequest
        BL      BT_QueueACK
        B       BTP_Exit

BTP_DirStop
        MOVS    R0, #BT_DIR_STOP
        BL      BT_SetDirRequest
        BL      BT_QueueACK
        B       BTP_Exit

BTP_ModePhone
        MOVS    R0, #BT_MODE_PHONE
        BL      BT_SetModeRequest
        BL      BT_QueueACK
        B       BTP_Exit

BTP_ModeLine
        MOVS    R0, #BT_MODE_LINE
        BL      BT_SetModeRequest
        BL      BT_QueueACK
        B       BTP_Exit

BTP_MedOff
        BL      BT_Handle_MedAlertOff
        B       BTP_Exit

BTP_SmokeOff
        BL      BT_Handle_SmokeAlertOff
        B       BTP_Exit

BTP_Exit
        POP     {R4-R7, PC}

;=============================================================================
; BT_Handle_SmokeAlertOff
; Clears the smoke alert flag and forces UI back to main menu
;=============================================================================
BT_Handle_SmokeAlertOff
        PUSH    {R0-R2, LR}
        
        ; Clear Smoke_Alert_Flag (Bit 1)
        LDR     R0, =g_alarm_flags
        LDR     R1, [R0]
        BIC     R1, R1, #Smoke_Alert_Flag
        STR     R1, [R0]

        ; Reset Smoke Ignore Counter so it doesn't instantly retrigger
        LDR     R0, =g_smoke_ignore_counter
        LDR     R1, =SMOKE_IGNORE_ITERATIONS
        STR     R1, [R0]

        ; If currently on Smoke Alert screen, exit to Main Menu
        LDR     R0, =g_sys_state
        LDR     R1, [R0]
        CMP     R1, #STATE_SMOKE_ALERT
        BNE     BTSA_Exit
        MOVS    R2, #STATE_MAIN_MENU
        STR     R2, [R0]

BTSA_Exit
        POP     {R0-R2, PC}

        ALIGN
        LTORG

;=============================================================================
; BT_SetModeRequest
; R0 = mode request value
;=============================================================================
BT_SetModeRequest
        PUSH    {R1, R2, LR}
        LDR     R1, =g_bt_motion_mode_request
        STR     R0, [R1]
        MOVS    R2, #0
        LDR     R1, =g_bt_motion_dir_request
        STR     R2, [R1]
        MOVS    R2, #1
        LDR     R1, =g_bt_cmd_ready
        STR     R2, [R1]
        POP     {R1, R2, PC}

        ALIGN
        LTORG

;=============================================================================
; BT_SetDirRequest
; R0 = direction request value
;=============================================================================
BT_SetDirRequest
        PUSH    {R1, R2, LR}
        LDR     R1, =g_bt_motion_dir_request
        STR     R0, [R1]
        MOVS    R2, #0
        LDR     R1, =g_bt_motion_mode_request
        STR     R2, [R1]
        MOVS    R2, #1
        LDR     R1, =g_bt_cmd_ready
        STR     R2, [R1]
        POP     {R1, R2, PC}

        ALIGN
        LTORG

;=============================================================================
; BT_StrEq
; R0 = string A, R1 = string B. Returns R0=1 equal, R0=0 not equal.
;=============================================================================
BT_StrEq
        PUSH    {R2-R4, LR}
BTSE_Loop
        LDRB    R2, [R0], #1
        LDRB    R3, [R1], #1
        CMP     R2, R3
        BNE     BTSE_NotEqual
        CMP     R2, #0
        BNE     BTSE_Loop
        MOVS    R0, #1
        POP     {R2-R4, PC}

BTSE_NotEqual
        MOVS    R0, #0
        POP     {R2-R4, PC}

        ALIGN
        LTORG

;=============================================================================
; BT_Handle_MedAlertOff
; Clears Med_Alert_Flag and returns to main menu if currently in Med Alert state.
;=============================================================================
BT_Handle_MedAlertOff
        PUSH    {R4, R5, LR}

        ; Clear Med_Alert_Flag
        LDR     R4, =g_alarm_flags
        LDR     R5, [R4]
        LDR     R0, =Med_Alert_Flag
        BIC     R5, R5, R0
        STR     R5, [R4]

        ; If currently in STATE_MED_ALERT, go to STATE_MAIN_MENU
        LDR     R4, =g_sys_state
        LDR     R5, [R4]
        CMP     R5, #STATE_MED_ALERT
        BNE     BTHM_SkipState

        MOVS    R5, #STATE_MAIN_MENU
        STR     R5, [R4]

BTHM_SkipState
        POP     {R4, R5, PC}

        ALIGN
        LTORG

;=============================================================================
; BT_PeriodicTask
; Call every main loop. Never blocks.
;=============================================================================
BT_PeriodicTask
        PUSH    {R4-R7, LR}

        ; Always let pending TX progress first.
        BL      BT_TxTask

        ; If TX is busy, do not build a new packet now.
        BL      BT_TxIdle
        CMP     R0, #1
        BNE     BTPER_Exit

        ; Event packets have priority over periodic vitals.
        BL      BT_CheckMedEvent
        BL      BT_TxIdle
        CMP     R0, #1
        BNE     BTPER_SendOne

        BL      BT_CheckSmokeAlert
        BL      BT_TxIdle
        CMP     R0, #1
        BNE     BTPER_SendOne

        ; Vitals every 2000 ms
        LDR     R0, =g_ms_ticks
        LDR     R4, [R0]
        LDR     R0, =bt_last_vitals_tick
        LDR     R5, [R0]
        SUBS    R6, R4, R5
        LDR     R7, =BT_REPORT_PERIOD_MS
        CMP     R6, R7
        BLO     BTPER_Exit

        STR     R4, [R0]
        BL      BT_QueueVitals

BTPER_SendOne
        ; Try sending the first byte immediately if USART is ready.
        BL      BT_TxTask

BTPER_Exit
        POP     {R4-R7, PC}

        ALIGN
        LTORG

;=============================================================================
; BT_TxTask
; Hybrid Blocking TX. Sends the entire packet at once for maximum speed, 
; but constantly polls RX while waiting to prevent dropping motion commands!
;=============================================================================
BT_TxTask
        PUSH    {R4-R7, LR}

        LDR     R4, =bt_tx_len
        LDR     R5, [R4]
        CMP     R5, #0
        BEQ     BTTX_Exit

        LDR     R6, =bt_tx_index
        LDR     R7, [R6]

BTTX_Loop
        CMP     R7, R5
        BHS     BTTX_Clear

BTTX_WaitTXE
        ; 1. Keep the receiver alive! Check for incoming joystick commands
        BL      BT_RxTask

        ; 2. Check if the transmitter is ready for the next character
        LDR     R0, =BT_USART2_BASE
        LDR     R1, [R0, #BT_USART_SR]
        TST     R1, #BT_USART_SR_TXE
        BEQ     BTTX_WaitTXE

        ; 3. Send the character
        LDR     R1, =bt_tx_buffer
        LDRB    R2, [R1, R7]
        STR     R2, [R0, #BT_USART_DR]

        ADDS    R7, R7, #1
        B       BTTX_Loop

BTTX_Clear
        MOVS    R0, #0
        STR     R0, [R4]
        STR     R0, [R6]

BTTX_Exit
        POP     {R4-R7, PC}

        ALIGN
        LTORG

;=============================================================================
; BT_TxIdle
; Returns R0=1 if no queued TX packet, else R0=0.
;=============================================================================
BT_TxIdle
        PUSH    {R1, LR}
        LDR     R1, =bt_tx_len
        LDR     R0, [R1]
        CMP     R0, #0
        BEQ     BTTI_Yes
        MOVS    R0, #0
        POP     {R1, PC}

BTTI_Yes
        MOVS    R0, #1
        POP     {R1, PC}

        ALIGN
        LTORG

;=============================================================================
; BT_StartPacket
;=============================================================================
BT_StartPacket
        PUSH    {R0, R1, LR}
        MOVS    R1, #0
        LDR     R0, =bt_tx_len
        STR     R1, [R0]
        LDR     R0, =bt_tx_index
        STR     R1, [R0]
        LDR     R0, =bt_tx_buffer
        STRB    R1, [R0]
        POP     {R0, R1, PC}

        ALIGN
        LTORG

;=============================================================================
; BT_AppendChar
; R0 = character byte
;=============================================================================
BT_AppendChar
        PUSH    {R1-R4, LR}
        LDR     R1, =bt_tx_len
        LDR     R2, [R1]
        CMP     R2, #BT_TX_LAST_INDEX
        BHS     BTAC_Exit
        LDR     R3, =bt_tx_buffer
        STRB    R0, [R3, R2]
        ADDS    R2, R2, #1
        STR     R2, [R1]
        MOVS    R4, #0
        STRB    R4, [R3, R2]

BTAC_Exit
        POP     {R1-R4, PC}

        ALIGN
        LTORG

;=============================================================================
; BT_AppendString
; R0 = pointer to zero-terminated string
;=============================================================================
BT_AppendString
        PUSH    {R4, LR}
        MOV     R4, R0

BTAS_Loop
        LDRB    R0, [R4], #1
        CMP     R0, #0
        BEQ     BTAS_Exit
        BL      BT_AppendChar
        B       BTAS_Loop

BTAS_Exit
        POP     {R4, PC}

        ALIGN
        LTORG

;=============================================================================
; BT_AppendU32
; R0 = unsigned number to append as decimal
; Uses UDIV, valid on Cortex-M4 STM32F401.
;=============================================================================
BT_AppendU32
        PUSH    {R4-R6, LR}
        LDR     R4, =bt_num_buffer
        MOVS    R5, #0          ; char count

        ; If R0 == 0, special case
        CMP     R0, #0
        BNE     BTAU_NotZero
        MOVS    R1, #BT_ASCII_0
        STRB    R1, [R4]
        MOVS    R5, #1
        B       BTAU_DoneBuilding

BTAU_NotZero
        MOVS    R1, #10
BTAU_BuildLoop
        CMP     R0, #0
        BEQ     BTAU_DoneBuilding
        UDIV    R2, R0, R1      ; R2 = R0 / 10
        MLS     R3, R2, R1, R0  ; R3 = R0 - (R2 * 10) = remainder
        ADDS    R3, R3, #BT_ASCII_0
        STRB    R3, [R4, R5]
        ADDS    R5, R5, #1
        MOV     R0, R2
        B       BTAU_BuildLoop

BTAU_DoneBuilding
        ; Buffer now has digits in REVERSE order. Append them to TX buffer in correct order.
BTAU_CopyLoop
        CMP     R5, #0
        BEQ     BTAU_Exit
        SUBS    R5, R5, #1
        LDRB    R0, [R4, R5]
        BL      BT_AppendChar
        B       BTAU_CopyLoop

BTAU_Exit
        POP     {R4-R6, PC}

        ALIGN
        LTORG

;=============================================================================
; BT_QueueVitals
;=============================================================================
BT_QueueVitals
        PUSH    {LR}
        BL      BT_StartPacket
        LDR     R0, =BT_TX_VITALS_1
        BL      BT_AppendString
        LDR     R0, =g_bpm
        LDR     R0, [R0]
        BL      BT_AppendU32
        LDR     R0, =BT_TX_SPO2
        BL      BT_AppendString
        LDR     R0, =g_spo2
        LDR     R0, [R0]
        BL      BT_AppendU32
        LDR     R0, =BT_TX_BREATH
        BL      BT_AppendString
        LDR     R0, =g_breath_level
        LDR     R0, [R0]
        BL      BT_AppendU32
        LDR     R0, =BT_TX_SMOKE
        BL      BT_AppendString
        LDR     R0, =g_smoke_level
        LDR     R0, [R0]
        BL      BT_AppendU32
        LDR     R0, =BT_TX_MED
        BL      BT_AppendString
        LDR     R0, =g_med_timer
        LDR     R0, [R0]
        BL      BT_AppendU32
        
        ; Add alerts field
        LDR     R0, =BT_TX_ALERT_FIELD
        BL      BT_AppendString
        
        LDR     R1, =g_alarm_flags
        LDR     R1, [R1]
        
        ; Both
        LDR     R2, =(Smoke_Alert_Flag :OR: Med_Alert_Flag)
        ANDS    R2, R2, R1
        LDR     R3, =(Smoke_Alert_Flag :OR: Med_Alert_Flag)
        CMP     R2, R3
        BEQ     BTQV_Both
        
        ; Smoke only
        LDR     R2, =Smoke_Alert_Flag
        ANDS    R2, R2, R1
        CMP     R2, #Smoke_Alert_Flag
        BEQ     BTQV_Smoke
        
        ; Med only
        LDR     R2, =Med_Alert_Flag
        ANDS    R2, R2, R1
        CMP     R2, #Med_Alert_Flag
        BEQ     BTQV_Med
        
        ; None
        LDR     R0, =BT_TX_NONE
        BL      BT_AppendString
        B       BTQV_Final
        
BTQV_Both
        LDR     R0, =BT_TX_BOTH_ALERTS
        BL      BT_AppendString
        B       BTQV_Final
        
BTQV_Smoke
        LDR     R0, =BT_TX_SMOKE_DETECTED
        BL      BT_AppendString
        B       BTQV_Final
        
BTQV_Med
        LDR     R0, =BT_TX_MED_ALERT
        BL      BT_AppendString

BTQV_Final
        LDR     R0, =BT_TX_CRLF
        BL      BT_AppendString
        POP     {PC}

        ALIGN
        LTORG

;=============================================================================
; BT_CheckMedEvent
;=============================================================================
BT_CheckMedEvent
        PUSH    {R4, R5, LR}
        LDR     R0, =g_sys_state
        LDR     R1, [R0]
        LDR     R0, =bt_last_med_state
        LDR     R2, [R0]
        
        CMP     R1, R2
        BEQ     BTCME_Exit
        
        ; State changed. Was it from Dispense to Wait?
        CMP     R2, #STATE_MED_DISPENSE
        BNE     BTCME_Update
        CMP     R1, #STATE_MED_WAITING
        BEQ     BTCME_Queue
        CMP     R1, #STATE_MAIN_MENU
        BEQ     BTCME_Queue
        B       BTCME_Update

BTCME_Queue
        BL      BT_SendMedDispensed

BTCME_Update
        LDR     R0, =bt_last_med_state
        STR     R1, [R0]

BTCME_Exit
        POP     {R4, R5, PC}

        ALIGN
        LTORG

;=============================================================================
; BT_SendMedDispensed
;=============================================================================
BT_SendMedDispensed
        PUSH    {LR}
        BL      BT_StartPacket
        LDR     R0, =BT_TX_MED_EVENT
        BL      BT_AppendString
        POP     {PC}

        ALIGN
        LTORG

;=============================================================================
; BT_CheckSmokeAlert
;=============================================================================
BT_CheckSmokeAlert
        PUSH    {R4-R6, LR}
        LDR     R0, =g_alarm_flags
        LDR     R1, [R0]
        LDR     R2, =Smoke_Alert_Flag
        TST     R1, R2
        BEQ     BTCSA_Clear
        
        ; Alarm is set. Have we reported it recently?
        LDR     R3, =g_ms_ticks
        LDR     R4, [R3]
        LDR     R3, =bt_last_alert_tick
        LDR     R5, [R3]
        SUBS    R6, R4, R5
        LDR     R0, =5000       ; 5 seconds re-alert
        CMP     R6, R0
        BLO     BTCSA_Exit
        
        STR     R4, [R3]
        BL      BT_SendSmokeAlert
        B       BTCSA_Exit

BTCSA_Clear
        LDR     R3, =bt_last_alert_tick
        MOVS    R4, #0
        STR     R4, [R3]

BTCSA_Exit
        POP     {R4-R6, PC}

        ALIGN
        LTORG

;=============================================================================
; BT_SendSmokeAlert
;=============================================================================
BT_SendSmokeAlert
        PUSH    {LR}
        BL      BT_StartPacket
        LDR     R0, =BT_TX_ALERT_1
        BL      BT_AppendString
        LDR     R0, =g_smoke_level
        LDR     R0, [R0]
        BL      BT_AppendU32
        LDR     R0, =BT_TX_CRLF
        BL      BT_AppendString
        POP     {PC}

        ALIGN
        LTORG

;=============================================================================
; BT_SendVitalsNow
; (DEBUG / Force send)
;=============================================================================
BT_SendVitalsNow
        PUSH    {LR}
        BL      BT_QueueVitals
        BL      BT_TxTask
        POP     {PC}

;=============================================================================
; BT_SendDebugNow
; (DEBUG / Force send)
;=============================================================================
BT_SendDebugNow
        PUSH    {LR}
        BL      BT_StartPacket
        LDR     R0, =BT_TX_DEBUG_1
        BL      BT_AppendString
        
        LDR     R0, =g_smoke_level
        LDR     R0, [R0]
        BL      BT_AppendU32
        
        LDR     R0, =BT_TX_DEBUG_BREATH
        BL      BT_AppendString
        LDR     R0, =g_breath_level
        LDR     R0, [R0]
        BL      BT_AppendU32
        
        LDR     R0, =BT_TX_DEBUG_STATE
        BL      BT_AppendString
        LDR     R0, =g_sys_state
        LDR     R0, [R0]
        BL      BT_AppendU32

        LDR     R0, =BT_TX_CRLF
        BL      BT_AppendString
        BL      BT_TxTask
        POP     {PC}

;=============================================================================
; BT_QueueACK
; Sends "ACK=" + current rx_buffer + \n
;=============================================================================
BT_QueueACK
        PUSH    {LR}
        BL      BT_StartPacket
        LDR     R0, =BT_TEXT_ACK_PREFIX
        BL      BT_AppendString
        LDR     R0, =bt_rx_buffer
        BL      BT_AppendString
        LDR     R0, =BT_TX_CRLF
        BL      BT_AppendString
        BL      BT_TxTask               ; Send immediately
        POP     {PC}

        ALIGN
        END