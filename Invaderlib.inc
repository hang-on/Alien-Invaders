; Invaderlib.inc

.equ ONE_ROW 7
.equ RASTER_INTERRUPT_VALUE ONE_ROW
.equ SLICE_POINT_1 5
.equ SLICE_POINT_2 10
.equ SLICE_POINT_3 13
.equ SCROLL_VALUE_1 8
.equ SCROLL_VALUE_2 (-8)
.equ SCROLL_VALUE_3 0

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
  ; generate an include file formatted for this macro.

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
.ramsection "Invader Library Variables" slot 3
  RasterEffect.NextSlice db
  RasterEffect.Scroll db
  RasterEffect.TablePointer dw
.ends
; -----------------------------------------------------------------------------
.section "Raster Interrupt Handler" free
; -----------------------------------------------------------------------------
  HandleRasterInterrupt:
    in a,(V_COUNTER_PORT)
    ld b,a
    ld a,(RasterEffect.NextSlice)
    cp b
    call z,RasterEffect_CreateSlice
  ret

.ends

; -----------------------------------------------------------------------------
.section "Misc Development" free
; -----------------------------------------------------------------------------
  RasterEffect_CreateSlice:
    ld a,(RasterEffect.Scroll)
    ld b,HORIZONTAL_SCROLL_REGISTER
    call SetRegister
    call RasterEffect_PrepareNextSlice
  ret

  RasterEffect_PrepareNextSlice:
    ld hl,(RasterEffect.TablePointer)
    ld a,(hl)
    ld (RasterEffect.NextSlice),a
    inc hl
    ld a,(hl)
    ld (RasterEffect.Scroll),a
    inc hl
    ld (RasterEffect.TablePointer),hl
  ret

  RasterEffect.Frame:
    ld hl,RasterEffectTable
    ld (RasterEffect.TablePointer),hl
    call RasterEffect_PrepareNextSlice

    ld a,0
    ld b,HORIZONTAL_SCROLL_REGISTER
    call SetRegister
  ret

  RasterEffect.Initialize:
    ld a,RASTER_INTERRUPT_VALUE
    ld b,RASTER_INTERRUPT_REGISTER
    call SetRegister
  ret

  RasterEffectTable:
    .db ((ONE_ROW*SLICE_POINT_1)+SLICE_POINT_1-1), SCROLL_VALUE_1
    .db ((ONE_ROW*SLICE_POINT_2)+SLICE_POINT_2-1), SCROLL_VALUE_2
    .db ((ONE_ROW*SLICE_POINT_3)+SLICE_POINT_3-1), SCROLL_VALUE_3

.ends
