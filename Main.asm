.include "Base.inc"
.include "Invaderlib.inc"

; Definitions for raster effects
.equ ONE_ROW 7
.equ RASTER_INTERRUPT_VALUE ONE_ROW
.equ SLICE_POINT_1 5
.equ SLICE_POINT_2 10
.equ SLICE_POINT_3 13

.equ ENEMY_MOVE_INTERVAL 75           ; How many frames between each move?

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

.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Main" free
; -----------------------------------------------------------------------------
  SetupMain:
    jp Main

  Main:
    jp SetupBattleLoop
.ends

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
.ramsection "Battle loop variables" slot 3
  CurrentRasterEffectPtr dw
  BattleRasterEffectMetaTableIndex db
.ends
; -----------------------------------------------------------------------------
.section "Battle Loop" free
; -----------------------------------------------------------------------------
  SetupBattleLoop:
    ; Initialize variables:
    GetNextWord BattleRasterEffectMetaTableIndex, BattleRasterEffectMetaTable, BattleRasterEffectMetaTableEnd
    ld (CurrentRasterEffectPtr),hl

    ld a,RASTER_INTERRUPT_VALUE
    call RasterEffect.Initialize

    ld a,ENEMY_MOVE_INTERVAL
    call Timer.Setup

    ; Initialize vdp (assume blanked screen and interrupts off):
    LoadImage MockupAssets,MockupAssetsEnd

    ld a,FULL_SCROLL_SHOW_LEFT_COLUMN_KEEP_SPRITES_ENABLE_RASTER_INT
    ld b,0
    call SetRegister

    ld a,ENABLE_DISPLAY_ENABLE_FRAME_INTERRUPTS_NORMAL_SPRITES
    ld b,1
    call SetRegister
    ei
    call AwaitFrameInterrupt
    jp BattleLoop

  BattleLoop:
    call AwaitFrameInterrupt

    ld hl,(CurrentRasterEffectPtr)
    call RasterEffect.BeginNewFrame

    ; Non-vblank stuff below this line...

    call Timer.Countdown
    call Timer.IsDone
    jp nc,SkipEnemyMovement
      ld a,ENEMY_MOVE_INTERVAL
      call Timer.Setup
      GetNextWord BattleRasterEffectMetaTableIndex, BattleRasterEffectMetaTable, BattleRasterEffectMetaTableEnd
      ld (CurrentRasterEffectPtr),hl
    SkipEnemyMovement:

  jp BattleLoop
.ends

.bank 1 slot 1
  ; Stuff in bank 1 goes here...

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
    .dw BattleRasterEffectTable1, BattleRasterEffectTable2,
  BattleRasterEffectMetaTableEnd:

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
