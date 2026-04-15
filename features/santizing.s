;=============================================================================
; sanitizing.s
; Minimal sanitizing module so main.s links correctly
;=============================================================================

        AREA    SAN_CODE, CODE, READONLY
        THUMB
        PRESERVE8
        ALIGN

        EXPORT  SAN_Init
        EXPORT  SAN_Update

SAN_Init
        BX      LR

SAN_Update
        BX      LR

        ALIGN
        END