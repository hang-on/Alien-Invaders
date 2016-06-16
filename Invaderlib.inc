; Invaderlib.inc

.equ RASTER_INTERRUPT_VALUE 7

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
.ramsection "Invader Library Variables" slot 3

.ends
; -----------------------------------------------------------------------------
.section "Raster Interrupt Handler" free
; -----------------------------------------------------------------------------
  HandleRasterInterrupt:
    in a,(V_COUNTER_PORT)
    ld b,a
    call GetSlicePoint
    cp b
    ret nz
      ld a,8
      ld b,HORIZONTAL_SCROLL_REGISTER
      call SetRegister
  ret

.ends

.section "Development" free
  ResetScroll:
    ld a,0
    ld b,HORIZONTAL_SCROLL_REGISTER
    call SetRegister
  ret

  GetSlicePoint:
  ; Returns slicepoint in A.
    ld a,(RASTER_INTERRUPT_VALUE*2)+1
  ret
.ends
