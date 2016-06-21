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
.ramsection "Raster Effect Variables" slot 3
  RasterEffect.NextSliceLine db
  RasterEffect.Scroll db
  RasterEffect.TablePointer dw
  RasterEffect.TableBaseAddress dw
.ends
; -----------------------------------------------------------------------------
.section "Raster Effect Functions" free
; -----------------------------------------------------------------------------
  RasterEffect.BeginNewFrame:
    ld hl,(RasterEffect.TableBaseAddress)
    ld (RasterEffect.TablePointer),hl
    call RasterEffect.PrepareNextSlice
    ld a,0
    ld b,HORIZONTAL_SCROLL_REGISTER
    call SetRegister
  ret

  RasterEffect.CreateSlice:
    ld a,(RasterEffect.Scroll)
    ld b,HORIZONTAL_SCROLL_REGISTER
    call SetRegister
    call RasterEffect.PrepareNextSlice
  ret

  RasterEffect.HandleRasterInterrupt:
    in a,(V_COUNTER_PORT)
    ld b,a
    ld a,(RasterEffect.NextSliceLine)
    cp b
    call z,RasterEffect.CreateSlice
  ret

  RasterEffect.Initialize:
    ld (RasterEffect.TableBaseAddress),hl
    ld a,RASTER_INTERRUPT_VALUE
    ld b,RASTER_INTERRUPT_REGISTER
    call SetRegister
  ret

  RasterEffect.PrepareNextSlice:
    ld hl,(RasterEffect.TablePointer)
    ld a,(hl)
    ld (RasterEffect.NextSliceLine),a
    inc hl
    ld a,(hl)
    ld (RasterEffect.Scroll),a
    inc hl
    ld (RasterEffect.TablePointer),hl
  ret

.ends
