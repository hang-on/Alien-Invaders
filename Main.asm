.include "Base.inc"
.include "Invaderlib.inc"
; Definitions for raster effects
.equ ONE_ROW 7
.equ RASTER_INTERRUPT_VALUE ONE_ROW
.equ SLICE_POINT_1 5
.equ SLICE_POINT_2 10
.equ SLICE_POINT_3 13
.equ RASTER_TIMER_INTERVAL 45           ; How many frames between each move?
; -----------------------------------------------------------------------------
.macro MATCH_WORDS ARGS _VARIABLE, _VALUE
; -----------------------------------------------------------------------------
  or a              ; Clear carry so it does not interfere with sbc below.
  ld hl,_VARIABLE
  ld a,(hl)
  inc hl
  ld h,(hl)
  ld l,a
  ld de,_VALUE
  sbc hl,de
  scf
  jp z,+
    or a
  +:
.endm
; -----------------------------------------------------------------------------
.macro LOAD_IMAGE
; -----------------------------------------------------------------------------
  ; This macro makes it easy to load an image. Call the macro like this:
  ; LOAD_IMAGE MockupAssets,MockupAssetsEnd
  ; Include format:
  ;    MockupAssets:
  ;      .include "MockupAssets.inc"
  ;    MockupAssetsEnd:
  ; Drop a 256x192 indexed color image on \Tools\MakeAssets.bat to quickly
  ; generate an include file formatted for this macro.
  ;
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
  Raster.Pointer dw
  Raster.Timer db
.ends
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Main" free
; -----------------------------------------------------------------------------
  SetupMain:
    ; Initialize the raster effect:
    ld hl,RasterTablesStart
    ld (Raster.Pointer),hl
    ld a,RASTER_INTERRUPT_VALUE
    call RasterEffect.Initialize
    ld a,RASTER_TIMER_INTERVAL
    ld (Raster.Timer),a
    ; Initialize vdp (assume blanked screen and interrupts off):
    LOAD_IMAGE MockupAssets,MockupAssetsEnd
    ld a,FULL_SCROLL_BLANK_LEFT_COLUMN_KEEP_SPRITES_ENABLE_RASTER_INT
    ld b,0
    call SetRegister
    ld a,ENABLE_DISPLAY_ENABLE_FRAME_INTERRUPTS_NORMAL_SPRITES
    ld b,1
    call SetRegister
    ; Skip an interrupt to make sure that we start main at vblank.
    ei
    call AwaitFrameInterrupt
  jp Main
  ;
  Main:
    call AwaitFrameInterrupt
    ; This is first line of vblank. Time to update the vdp...
    ld hl,(Raster.Pointer)
    call RasterEffect.BeginNewFrame
    ;
    ; Non-vblank stuff below this line...
    ;
    ld hl,Raster.Timer
    dec (hl)
    ld a,(Raster.Timer)
    or a
    jp nz,SkipRasterPointerUpdate
      ; Time to update the raster effect pointer. First set the timer.
      ld a,RASTER_TIMER_INTERVAL
      ld (Raster.Timer),a
      ; Load the current raster pointer into HL.
      ld hl,Raster.Pointer
      ld a,(hl)
      inc hl
      ld h,(hl)
      ld l,a
      ; Skip forward one raster effect table element.
      ld de,6
      add hl,de
      ; Load the updated pointer from HL back into ram.
      ld (Raster.Pointer),hl
      ; If we have now moved past the raster effects meta table, then reset
      ; the pointer to the start of the meta table.
      MATCH_WORDS Raster.Pointer, RasterTablesEnd
      jp nc,+
        ld hl,RasterTablesStart
        ld (Raster.Pointer),hl
      +:
    SkipRasterPointerUpdate:
    ;
  jp Main
.ends
.bank 1 slot 1
  ; Stuff in bank 1 goes here...
  ;
.bank 2 slot 2
; -----------------------------------------------------------------------------
.section "Raster Tables" free
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
  RasterTablesStart:
    MakeRasterEffectTable 0, ALIGN_SLICES
    MakeRasterEffectTable 0, SKEW_SLICES
    MakeRasterEffectTable 2, ALIGN_SLICES
    MakeRasterEffectTable 2, SKEW_SLICES
    MakeRasterEffectTable 4, ALIGN_SLICES
    MakeRasterEffectTable 4, SKEW_SLICES
    MakeRasterEffectTable 6, ALIGN_SLICES
    MakeRasterEffectTable 6, SKEW_SLICES
    MakeRasterEffectTable 8, ALIGN_SLICES
    MakeRasterEffectTable 8, SKEW_SLICES
    MakeRasterEffectTable 10, ALIGN_SLICES
    MakeRasterEffectTable 10, SKEW_SLICES
    MakeRasterEffectTable 8, ALIGN_SLICES
    MakeRasterEffectTable 8, SKEW_SLICES
    MakeRasterEffectTable 6, ALIGN_SLICES
    MakeRasterEffectTable 6, SKEW_SLICES
    MakeRasterEffectTable 4, ALIGN_SLICES
    MakeRasterEffectTable 4, SKEW_SLICES
    MakeRasterEffectTable 2, ALIGN_SLICES
    MakeRasterEffectTable 2, SKEW_SLICES
    MakeRasterEffectTable 0, ALIGN_SLICES
    MakeRasterEffectTable 0, SKEW_SLICES
    MakeRasterEffectTable -2, ALIGN_SLICES
    MakeRasterEffectTable -2, SKEW_SLICES
    MakeRasterEffectTable -4, ALIGN_SLICES
    MakeRasterEffectTable -4, SKEW_SLICES
    MakeRasterEffectTable -6, ALIGN_SLICES
    MakeRasterEffectTable -6, SKEW_SLICES
    MakeRasterEffectTable -8, ALIGN_SLICES
    MakeRasterEffectTable -8, SKEW_SLICES
    MakeRasterEffectTable -10, ALIGN_SLICES
    MakeRasterEffectTable -10, SKEW_SLICES
    MakeRasterEffectTable -8, ALIGN_SLICES
    MakeRasterEffectTable -8, SKEW_SLICES
    MakeRasterEffectTable -6, ALIGN_SLICES
    MakeRasterEffectTable -6, SKEW_SLICES
    MakeRasterEffectTable -4, ALIGN_SLICES
    MakeRasterEffectTable -4, SKEW_SLICES
    MakeRasterEffectTable -2, ALIGN_SLICES
    MakeRasterEffectTable -2, SKEW_SLICES
  RasterTablesEnd:
.ends
; -----------------------------------------------------------------------------
.section "Mockup Assets" free
; -----------------------------------------------------------------------------
  MockupAssets:
    .include "MockupAssets.inc"
  MockupAssetsEnd:
.ends
