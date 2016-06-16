; Invaderlib.inc

.equ ONE_ROW 7
.equ RASTER_INTERRUPT_VALUE ONE_ROW
.equ SLICE_POINT_1 5
.equ SLICE_POINT_2 8
.equ SCROLL_VALUE 8

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

.ends
; -----------------------------------------------------------------------------
.section "Raster Interrupt Handler" free
; -----------------------------------------------------------------------------
  HandleRasterInterrupt:
    in a,(V_COUNTER_PORT)
    ld b,a
    call GetSlicePoint                    ; Return slicepoint in A.
    cp b
    ret nz
      call GetScrollValue                 ; Return scroll value in A.
      ld b,HORIZONTAL_SCROLL_REGISTER
      call SetRegister
  ret

.ends

; -----------------------------------------------------------------------------
.section "Misc Development" free
; -----------------------------------------------------------------------------
  ResetScroll:
    ld a,0
    ld b,HORIZONTAL_SCROLL_REGISTER
    call SetRegister
  ret


  GetSlicePoint:
  ; Returns slicepoint in A.
    ld hl,SlicePointTable
    ld a,(hl)
  ret

  SlicePointTable:
    .db ((ONE_ROW*SLICE_POINT_1)+SLICE_POINT_1-1)
    .db ((ONE_ROW*SLICE_POINT_2)+SLICE_POINT_2-1)

  GetScrollValue:
    ld hl,ScrollValueTable
    ld a,(hl)
  ret

  ScrollValueTable:
    .db SCROLL_VALUE

.ends
