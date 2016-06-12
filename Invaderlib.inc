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
  RasterTablePointer dw
.ends
; -----------------------------------------------------------------------------
.section "Raster Interrupt" free
; -----------------------------------------------------------------------------
  HandleRasterInterrupt:
    ld hl,(RasterTablePointer)
    ld a,(hl)
    ld b,HORIZONTAL_SCROLL_REGISTER
    call SetRegister
    inc hl
    ld a,(hl)
    ld b,10
    call SetRegister
    inc hl
    ld (RasterTablePointer),hl
  ret

  ResetRasterizer:
    ld hl,RasterTable
    ld (RasterTablePointer),hl
    call HandleRasterInterrupt ; FIXME: Not nice with fake int - naming!!
  ret

  RasterTable:
    .db 0, 38  ; Format: [h.scroll], [scanlines]
    .db 10, 22
    .db -6, $ff
    .db 0


.ends
