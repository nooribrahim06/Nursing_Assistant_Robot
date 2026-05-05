;=============================================================================
; bluetooth_buffers.s
; Shared Bluetooth RAM and command flags
;
; Member 1 owns this file.
; Member 2 should IMPORT these globals from here.
;=============================================================================

        GET     constants.s

        AREA    BT_BUFFERS, DATA, READWRITE
        ALIGN

;-----------------------------------------------------------------------------
; Globals exposed to the motion layer
;-----------------------------------------------------------------------------
        EXPORT  g_bt_cmd_ready
        EXPORT  g_bt_motion_mode_request
        EXPORT  g_bt_motion_dir_request
        EXPORT  g_bt_last_rx_tick

g_bt_cmd_ready             DCD     0       ; 1 = new valid BT command parsed
g_bt_motion_mode_request   DCD     0       ; 1=LINE, 2=PHONE, 0=none
g_bt_motion_dir_request    DCD     0       ; 1=FWD,2=BACK,3=LEFT,4=RIGHT,5=STOP,0=none
g_bt_last_rx_tick          DCD     0       ; updated on every received byte

;-----------------------------------------------------------------------------
; Private Bluetooth buffers/state
;-----------------------------------------------------------------------------
        EXPORT  bt_rx_buffer
        EXPORT  bt_rx_index
        EXPORT  bt_tx_buffer
        EXPORT  bt_tx_len
        EXPORT  bt_tx_index
        EXPORT  bt_last_vitals_tick
        EXPORT  bt_last_alert_tick
        EXPORT  bt_alert_active
        EXPORT  bt_last_med_state
        EXPORT  bt_num_buffer

bt_rx_buffer               SPACE   BT_RX_BUFFER_SIZE
bt_rx_index                DCD     0

bt_tx_buffer               SPACE   BT_TX_BUFFER_SIZE
bt_tx_len                  DCD     0
bt_tx_index                DCD     0

bt_last_vitals_tick        DCD     0
bt_last_alert_tick         DCD     0
bt_alert_active            DCD     0
bt_last_med_state          DCD     0

bt_num_buffer              SPACE   BT_NUM_BUFFER_SIZE

        ALIGN
        END
