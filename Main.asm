.include "Base.inc"
.include "Invaderlib.inc"

; Definitions for raster effects
.equ ONE_ROW 7
.equ RASTER_INTERRUPT_VALUE ONE_ROW

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
  Timer db
  NextRasterEffectTable dw
.ends
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Main" free
; -----------------------------------------------------------------------------
  SetupMain:

    LoadImage MockupAssets,MockupAssetsEnd

    ld hl,BattleRasterEffectTable1
    ld (NextRasterEffectTable),hl

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

    ld hl,(NextRasterEffectTable)
    call RasterEffect.BeginNewFrame

    ; Non-vblank stuff below this line...
    ld a,(Timer)
    dec a
    ld (Timer),a
    cp 127
    jp nc,+
      ld hl,BattleRasterEffectTable1
      ld (NextRasterEffectTable),hl
      jp ++
    +:
      ld hl,BattleRasterEffectTable2
      ld (NextRasterEffectTable),hl
      jp ++
    ++:
  jp Main
.ends


.bank 1 slot 1


.bank 2 slot 2
; -----------------------------------------------------------------------------
  .section "Data" free
; -----------------------------------------------------------------------------
.equ SLICE_POINT_1 5
.equ SLICE_POINT_2 10
.equ SLICE_POINT_3 13

.equ SHIELDS_ON 1
.equ SHIELDS_OFF 0


.macro MakeRasterEffectTable
  .if \1 != 0
    .db ((ONE_ROW*SLICE_POINT_1)+SLICE_POINT_1-1), \1
    .db ((ONE_ROW*SLICE_POINT_2)+SLICE_POINT_2-1), \1-16
    .db ((ONE_ROW*SLICE_POINT_3)+SLICE_POINT_3-1), 0
  .else
    .db ((ONE_ROW*SLICE_POINT_1)+SLICE_POINT_1-1), 0
    .db ((ONE_ROW*SLICE_POINT_2)+SLICE_POINT_2-1), 0
    .db ((ONE_ROW*SLICE_POINT_3)+SLICE_POINT_3-1), 0
  .endif
.endm

  BattleRasterEffectTable1:
    MakeRasterEffectTable 12
  BattleRasterEffectTable2:
    MakeRasterEffectTable 4
  MockupAssets:
    .include "MockupAssets.inc"
  MockupAssetsEnd:
  .ends
