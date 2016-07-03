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
  RasterEffectMetaTableIndex db
.ends
; -----------------------------------------------------------------------------
.section "Battle Loop" free
; -----------------------------------------------------------------------------
  SetupBattleLoop:
    ; Initialize variables:
    GetNextWord RasterEffectMetaTableIndex, BattleRasterEffectMetaTable, BattleRasterEffectMetaTableEnd
    ld (CurrentRasterEffectPtr),hl

    ld a,RASTER_INTERRUPT_VALUE
    call RasterEffect.Initialize

    ld a,ENEMY_MOVE_INTERVAL
    call Timer.Setup

    ; Initialize vdp (assume blanked screen and interrupts off):
    LoadImage MockupAssets,MockupAssetsEnd

    ld a,FULL_SCROLL_BLANK_LEFT_COLUMN_KEEP_SPRITES_ENABLE_RASTER_INT
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
      GetNextWord RasterEffectMetaTableIndex, BattleRasterEffectMetaTable, BattleRasterEffectMetaTableEnd
      ld (CurrentRasterEffectPtr),hl
    SkipEnemyMovement:

  jp BattleLoop
.ends

.bank 1 slot 1
  ; Stuff in bank 1 goes here...

.bank 2 slot 2
; -----------------------------------------------------------------------------
.section "Battle Raster Effect Data" free
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

  BattleRasterEffectTable1:
    MakeRasterEffectTable -12, ALIGN_SLICES
  BattleRasterEffectTable2:
    MakeRasterEffectTable -12, SKEW_SLICES
  BattleRasterEffectTable3:
    MakeRasterEffectTable -10, ALIGN_SLICES
  BattleRasterEffectTable4:
    MakeRasterEffectTable -10, SKEW_SLICES
  BattleRasterEffectTable5:
    MakeRasterEffectTable -8, ALIGN_SLICES
  BattleRasterEffectTable6:
    MakeRasterEffectTable -8, SKEW_SLICES
  BattleRasterEffectTable7:
    MakeRasterEffectTable -6, ALIGN_SLICES
  BattleRasterEffectTable8:
    MakeRasterEffectTable -6, SKEW_SLICES
  BattleRasterEffectTable9:
    MakeRasterEffectTable -4, ALIGN_SLICES
  BattleRasterEffectTable10:
    MakeRasterEffectTable -4, SKEW_SLICES
  BattleRasterEffectTable11:
    MakeRasterEffectTable -2, ALIGN_SLICES
  BattleRasterEffectTable12:
    MakeRasterEffectTable -2, SKEW_SLICES
  BattleRasterEffectTable13:
    MakeRasterEffectTable 0, ALIGN_SLICES
  BattleRasterEffectTable14:
    MakeRasterEffectTable 0, SKEW_SLICES
  BattleRasterEffectTable15:
    MakeRasterEffectTable 2, ALIGN_SLICES
  BattleRasterEffectTable16:
    MakeRasterEffectTable 2, SKEW_SLICES

  BattleRasterEffectTable17:
    MakeRasterEffectTable 4, ALIGN_SLICES
  BattleRasterEffectTable18:
    MakeRasterEffectTable 4, SKEW_SLICES
  BattleRasterEffectTable19:
    MakeRasterEffectTable 6, ALIGN_SLICES
  BattleRasterEffectTable20:
    MakeRasterEffectTable 6, SKEW_SLICES
  BattleRasterEffectTable21:
    MakeRasterEffectTable 8, ALIGN_SLICES
  BattleRasterEffectTable22:
    MakeRasterEffectTable 8, SKEW_SLICES
  BattleRasterEffectTable23:
    MakeRasterEffectTable 10, ALIGN_SLICES
  BattleRasterEffectTable24:
    MakeRasterEffectTable 10, SKEW_SLICES
  BattleRasterEffectTable25:
    MakeRasterEffectTable 12, ALIGN_SLICES
  BattleRasterEffectTable26:
    MakeRasterEffectTable 12, SKEW_SLICES


  BattleRasterEffectTable27:
    MakeRasterEffectTable 10, ALIGN_SLICES
  BattleRasterEffectTable28:
    MakeRasterEffectTable 10, SKEW_SLICES
  BattleRasterEffectTable29:
    MakeRasterEffectTable 12, ALIGN_SLICES
  BattleRasterEffectTable30:
    MakeRasterEffectTable 12, SKEW_SLICES
  BattleRasterEffectTable31:
    MakeRasterEffectTable 14, ALIGN_SLICES
  BattleRasterEffectTable32:
    MakeRasterEffectTable 14, SKEW_SLICES


  BattleRasterEffectMetaTable:
    ; A table of pointers to Battle Raster Effects which create the illusion
    ; of a moving alien army.
    .dw BattleRasterEffectTable1, BattleRasterEffectTable2,
    .dw BattleRasterEffectTable3, BattleRasterEffectTable4,
    .dw BattleRasterEffectTable5, BattleRasterEffectTable6,
    .dw BattleRasterEffectTable7, BattleRasterEffectTable8,
    .dw BattleRasterEffectTable9, BattleRasterEffectTable10,
    .dw BattleRasterEffectTable11, BattleRasterEffectTable12,
    .dw BattleRasterEffectTable13, BattleRasterEffectTable14,
    .dw BattleRasterEffectTable15, BattleRasterEffectTable16,

    .dw BattleRasterEffectTable17, BattleRasterEffectTable18,
    .dw BattleRasterEffectTable19, BattleRasterEffectTable20,
    .dw BattleRasterEffectTable21, BattleRasterEffectTable22,
    .dw BattleRasterEffectTable23, BattleRasterEffectTable24,

    ;.dw BattleRasterEffectTable25, BattleRasterEffectTable26,
    ;.dw BattleRasterEffectTable27, BattleRasterEffectTable28,
    ;.dw BattleRasterEffectTable29, BattleRasterEffectTable30,
    ;.dw BattleRasterEffectTable31, BattleRasterEffectTable32,

  BattleRasterEffectMetaTableEnd:

.ends

; -----------------------------------------------------------------------------
.section "Mockup Assets" free
; -----------------------------------------------------------------------------
  MockupAssets:
    .include "MockupAssets.inc"
  MockupAssetsEnd:
.ends
