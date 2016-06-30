.include "Base.inc"
.include "Invaderlib.inc"

; Definitions for raster effects
.equ ONE_ROW 7
.equ RASTER_INTERRUPT_VALUE ONE_ROW
.equ SLICE_POINT_1 5
.equ SLICE_POINT_2 10
.equ SLICE_POINT_3 13

.equ META_TABLE_SIZE (BattleRasterEffectMetaTableEnd-BattleRasterEffectMetaTable)/2


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
  MetaTableIndex db
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

    ; FIXME: Should be set timer func.
    ld a,127
    ld (Timer),a


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
    cp 0
    jp nz,++

    ld a,(MetaTableIndex)
    inc a
    cp 2
    jp nz,+
      xor a
    +:
    ld (MetaTableIndex),a
    add a,a
    ld h,0
    ld l,a
    ld de,BattleRasterEffectMetaTable
    add hl,de
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    ld (NextRasterEffectTable),hl
    ld a,127
    ld (Timer),a
    ++:
  jp Main
.ends


.bank 1 slot 1


.bank 2 slot 2
; -----------------------------------------------------------------------------
  .section "Data" free
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
    MakeRasterEffectTable 4, SKEW_SLICES
  BattleRasterEffectTable2:
    MakeRasterEffectTable 4, ALIGN_SLICES

  MockupAssets:
    .include "MockupAssets.inc"
  MockupAssetsEnd:
  .ends

.section "Meta table" align 256
  BattleRasterEffectMetaTable:
    .dw BattleRasterEffectTable1, BattleRasterEffectTable2
  BattleRasterEffectMetaTableEnd:
.ends
