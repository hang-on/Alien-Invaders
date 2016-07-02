.include "Base.inc"
.include "Invaderlib.inc"

; Definitions for raster effects
.equ ONE_ROW 7
.equ RASTER_INTERRUPT_VALUE ONE_ROW
.equ SLICE_POINT_1 5
.equ SLICE_POINT_2 10
.equ SLICE_POINT_3 13

.equ META_TABLE_MAX_INDEX 1
.equ ENEMY_MOVE_INTERVAL 75

.equ END_OF_TABLE $ffff

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
  NextRasterEffectTable dw
  MetaTableIndex db
  MetaTablePointer dw
.ends
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Main" free
; -----------------------------------------------------------------------------
  SetupMain:

    LoadImage MockupAssets,MockupAssetsEnd

    ld hl,BattleRasterEffectTable1
    ld (NextRasterEffectTable),hl
    ld hl,BattleRasterEffectMetaTable
    ld (MetaTablePointer),hl

    ld a,RASTER_INTERRUPT_VALUE
    call RasterEffect.Initialize

    ld a,ENEMY_MOVE_INTERVAL
    call Timer.Setup



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

    call Timer.Countdown
    call Timer.IsDone
    jp nc,SkipEnemyMovement
      ld a,ENEMY_MOVE_INTERVAL
      call Timer.Setup
      GetNextWord MetaTableIndex, META_TABLE_MAX_INDEX, BattleRasterEffectMetaTable
      ld (NextRasterEffectTable),hl
    SkipEnemyMovement:

  jp Main
.ends
.bank 1 slot 1


.bank 2 slot 2
; -----------------------------------------------------------------------------
.section "Battle Raster Effect Data" align 256
; -----------------------------------------------------------------------------
  .equ ALIGN_SLICES 1
  .equ SKEW_SLICES 0
  .macro MakeRasterEffectTable ARGS OFFSET, SLICE_MODE
    .if SLICE_MODE == SKEW_SLICES
      .db ((ONE_ROW*SLICE_POINT_1)+SLICE_POINT_1-1), OFFSET+8
      .db ((ONE_ROW*SLICE_POINT_2)+SLICE_POINT_2-1), OFFSET-8
      .db ((ONE_ROW*SLICE_POINT_3)+SLICE_POINT_3-1), 0
    .else
      .db ((ONE_ROW*SLICE_POINT_1)+SLICE_POINT_1-1), OFFSET
      .db ((ONE_ROW*SLICE_POINT_2)+SLICE_POINT_2-1), OFFSET
      .db ((ONE_ROW*SLICE_POINT_3)+SLICE_POINT_3-1), 0
    .endif
  .endm

  BattleRasterEffectMetaTable:
    .dw BattleRasterEffectTable2, BattleRasterEffectTable1, END_OF_TABLE

  BattleRasterEffectTable1:
    MakeRasterEffectTable 0, ALIGN_SLICES
  BattleRasterEffectTable2:
    MakeRasterEffectTable 0, SKEW_SLICES
.ends

; -----------------------------------------------------------------------------
.section "Mockup Assets" free
; -----------------------------------------------------------------------------
  MockupAssets:
    .include "MockupAssets.inc"
  MockupAssetsEnd:
.ends
