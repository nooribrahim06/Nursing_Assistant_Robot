; =====================================================================
; FILE: motion_constants.s
; DESCRIPTION: Shared constants for motion control and Bluetooth override
; =====================================================================



MOTION_MODE_LINE        EQU     1
MOTION_MODE_PHONE       EQU     2

PHONE_DIR_STOP          EQU     5
PHONE_DIR_FWD           EQU     1
PHONE_DIR_BACK          EQU     2
PHONE_DIR_LEFT          EQU     3
PHONE_DIR_RIGHT         EQU     4

PHONE_TIMEOUT_MS        EQU     2000

PHONE_SPEED             EQU     340
PHONE_TURN_FAST         EQU     480
PHONE_TURN_SLOW         EQU     280
PHONE_PIVOT_SPEED       EQU     300

        END
