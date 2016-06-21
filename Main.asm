.include "Base.inc"
.include "Invaderlib.inc"

; Definitions for raster effects
.equ ONE_ROW 7
.equ RASTER_INTERRUPT_VALUE ONE_ROW
.equ SLICE_POINT_1 5
.equ SLICE_POINT_2 10
.equ SLICE_POINT_3 13
.equ SCROLL_VALUE_1 8
.equ SCROLL_VALUE_2 (-8)
.equ SCROLL_VALUE_3 0


.bank 0 slot 0
.org $0038
; ---------------------------------------------------------------------------
.section "!VDP interrupt" force
; ---------------------------------------------------------------------------
  push af
  exx
    in a,CONTROL_PORT
    ld (VDPStatus),a
    bit 7,a
    jp nz,+
      call RasterEffect.HandleRasterInterrupt
    +:
  exx
  pop af
  ei
  reti

.ends

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
.ramsection "Main variables" slot 3
.ends
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Main" free
; -----------------------------------------------------------------------------
  SetupMain:

    LoadImage MockupAssets,MockupAssetsEnd

    ld a,RASTER_INTERRUPT_VALUE    
    call RasterEffect.Initialize

    ld a,FULL_SCROLL_SHOW_LEFT_COLUMN_KEEP_SPRITES_ENABLE_RASTER_INT
    ld b,0
    call SetRegister

    ld a,ENABLE_DISPLAY_ENABLE_FRAME_INTERRUPTS_NORMAL_SPRITES
    ld b,1
    call SetRegister
    ei
    call AwaitFrameInterrupt

  Main:
    call AwaitFrameInterrupt

    ld hl,BattleRasterEffectTable
    call RasterEffect.BeginNewFrame

    ; Non-vblank stuff below this line...
  jp Main
.ends


.bank 1 slot 1


.bank 2 slot 2
; -----------------------------------------------------------------------------
  .section "Data" free
; -----------------------------------------------------------------------------
  BattleRasterEffectTable:
    .db ((ONE_ROW*SLICE_POINT_1)+SLICE_POINT_1-1), SCROLL_VALUE_1
    .db ((ONE_ROW*SLICE_POINT_2)+SLICE_POINT_2-1), SCROLL_VALUE_2
    .db ((ONE_ROW*SLICE_POINT_3)+SLICE_POINT_3-1), SCROLL_VALUE_3


  MockupAssets:
    .include "MockupAssets.inc"
  MockupAssetsEnd:
  .ends
