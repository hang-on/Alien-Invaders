.include "Base.inc"
; Definitions for raster effects
.equ ONE_ROW 7
.equ RASTER_INTERRUPT_VALUE ONE_ROW
.equ RASTER_TIMER_INTERVAL 45           ; How many frames between each move?
.equ RASTER_EFFECT_TABLE_SIZE 6         ;
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
  Raster.MetaTablePointer dw
  Raster.ActiveEffect dw
  Raster.Timer db
.ends
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Main" free
; -----------------------------------------------------------------------------
  SetupMain:
    ; Initialize the raster effect:
    ld hl,RasterMetaTable
    ld (Raster.MetaTablePointer),hl
    ld a,RASTER_INTERRUPT_VALUE
    ld b,RASTER_INTERRUPT_REGISTER
    call SetRegister
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
    ld hl,(Raster.MetaTablePointer)
    call RasterEffect.BeginNewFrame
    ;
    ; Non-vblank stuff below this line...
    ;
    ld hl,Raster.Timer
    dec (hl)
    ld a,(Raster.Timer)
    or a
    jp nz,SkipRasterMetaTablePointerUpdate
      ; Time to update the raster meta table pointer. First set the timer.
      ld a,RASTER_TIMER_INTERVAL
      ld (Raster.Timer),a
      ; Load the current raster meta table pointer into HL.
      ld hl,Raster.MetaTablePointer
      ld a,(hl)
      inc hl
      ld h,(hl)
      ld l,a
      ; Skip forward one raster effect table element.
      ld de,RASTER_EFFECT_TABLE_SIZE
      add hl,de
      ; Load the updated pointer from HL back into ram.
      ld (Raster.MetaTablePointer),hl
      ; If we have now moved past the raster effects meta table, then reset
      ; the pointer to the start of the meta table.
      MATCH_WORDS Raster.MetaTablePointer, RasterMetaTableEnd
      jp nc,+
        ld hl,RasterMetaTable
        ld (Raster.MetaTablePointer),hl
      +:
    SkipRasterMetaTablePointerUpdate:
    ;
  jp Main
.ends
; -----------------------------------------------------------------------------
.section "Raster Effect Functions" free
; -----------------------------------------------------------------------------
  RasterEffect.BeginNewFrame:
    ; Point Raster.ActiveEffect to the base of the raster effect table
    ; to be used to make raster effects during this frame.
    ld (Raster.ActiveEffect),hl
  ret
  ;
  RasterEffect.HandleRasterInterrupt:
    ; This function assumes it is called from the interrupt handler. Check if
    ; the current line = next slice point, which is read from this frame's
    ; raster effect table. If we are at a slice point then slice the screen by
    ; reading and applying the hscroll value from the raster effect table, and
    ; forward the table pointer accordingly.
    ; Uses: AF, B, HL
    in a,(V_COUNTER_PORT)
    ld b,a
    ld hl,(Raster.ActiveEffect)
    ld a,(hl)
    cp b
    ret nz
    inc hl
    ld a,(hl)
    ld b,HORIZONTAL_SCROLL_REGISTER
    call SetRegister
    inc hl
    ld (Raster.ActiveEffect),hl
  ret
.ends
.bank 1 slot 1
  ; Stuff in bank 1 goes here...
  ;
.bank 2 slot 2
; -----------------------------------------------------------------------------
.section "Raster Tables" free
; -----------------------------------------------------------------------------
  .equ ALIGN_SLICES 1     ; Alien movement - align trooper and shield slices.
  .equ SKEW_SLICES 0      ; Alien movement - skew the slices.
  .equ SKEW_VALUE 8       ; Amount of pixel to skew the slices.
  .equ SLICE_POINT_1 5    ; Screen layout - start of trooper slice.
  .equ SLICE_POINT_2 10   ;               - start of shield slice.
  .equ SLICE_POINT_3 13   ;               - end of shield slice (reset scroll).
  .macro MakeRasterEffectTable ARGS OFFSET, SLICE_MODE
    ; A raster effect table consists of three pairs of [slicepoint, offset].
    ; This way the screen can be sliced in three parts:
    ; * 1: Alien army troopers and cannons - scroll     *
    ; * 2: Alien army shields              - scroll     *
    ; * 3: Bottom and top of screen        - no scroll  *
    .if SLICE_MODE == SKEW_SLICES
      ; Create slice for alien troops and cannons.
      .db ((ONE_ROW*SLICE_POINT_1)+SLICE_POINT_1-1), OFFSET+SKEW_VALUE
      ; Create slice for alien shields.
      .db ((ONE_ROW*SLICE_POINT_2)+SLICE_POINT_2-1), OFFSET-SKEW_VALUE
      ; Reset scroll until we hit the troops-and-cannon slice next frame.
      .db ((ONE_ROW*SLICE_POINT_3)+SLICE_POINT_3-1), 0
    .else
      .db ((ONE_ROW*SLICE_POINT_1)+SLICE_POINT_1-1), OFFSET
      .db ((ONE_ROW*SLICE_POINT_2)+SLICE_POINT_2-1), OFFSET
      .db ((ONE_ROW*SLICE_POINT_3)+SLICE_POINT_3-1), 0
    .endif
  .endm
  RasterMetaTable:
    ; The raster meta table consists of a long list of raster effect tables.
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
  RasterMetaTableEnd:
.ends
; -----------------------------------------------------------------------------
.section "Mockup Assets" free
; -----------------------------------------------------------------------------
  MockupAssets:
    .include "MockupAssets.inc"
  MockupAssetsEnd:
.ends
