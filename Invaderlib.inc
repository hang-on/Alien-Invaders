; Invaderlib.inc

; -----------------------------------------------------------------------------
.macro LoadImage
; -----------------------------------------------------------------------------
  ; This macro makes it easy to load an image. Call the macro like this:
  ; LoadImage MockupAssets,MockupAssetsEnd
  ; Include format:
  ;    MockupAssets:
  ;      .include "MockupAssets.inc"
  ;    MockupAssetsEnd:
  ; Drop a 256x192 indexed color image on \Tools\MakeAssets.bat to quickly
  ; generate and include file formatted for this macro.

  ; Assume 16 colors (bmp2tile's -fullpalette option).
  ld a,0
  ld b,16
  ld hl,\1
  call LoadCRam

  ; Assume 256x192 full screen image.
  ld bc,NAME_TABLE_SIZE
  ld de,NAME_TABLE_START
  ld hl,\1+16
  call LoadVRam

  ; Amount of tiles can vary.
  ld bc,\2-(\1+16+NAME_TABLE_SIZE)
  ld de,0
  ld hl,\1+16+NAME_TABLE_SIZE
  call LoadVRam
.endm

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
.ramsection "Raster Interrupt Variables" slot 3
  ScrollZoneTablePointer dw
.ends
; -----------------------------------------------------------------------------
.section "Raster Interrupt" free
; -----------------------------------------------------------------------------
  CreateNewScrollZone:
    ld hl,(ScrollZoneTablePointer)
    ld a,(hl)
    ld b,HORIZONTAL_SCROLL_REGISTER
    call SetRegister
    inc hl
    ld a,(hl)
    ld b,10
    call SetRegister
    inc hl
    ld (ScrollZoneTablePointer),hl
  ret

  ResetScrollZones:
    ld hl,ScrollZoneTable
    ld (ScrollZoneTablePointer),hl
    call CreateNewScrollZone
  ret

  ScrollZoneTable:
    ; This table creates the following scroll zones:
    ; scanlines : scroll
    ; 00-37     : 0
    ; 38-75     : 10
    ; 76-97     : -6
    ; 98+       : 0
    .db 0, 38,   ; Table format: [h.scroll], [scanlines]
    .db 10, 22
    .db -6, $ff
    .db 0

  NewScrollZoneTable:
    .db 38, 0, 10
    .db 22, -6, 0
    .db $ff

.ends
