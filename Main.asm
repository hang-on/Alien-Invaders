.include "Base.inc"
; Definitions for raster effects
.equ ONE_ROW 7
.equ RASTER_INTERRUPT_VALUE ONE_ROW
.equ RASTER_TIMER_INTERVAL 45           ; How many frames between each move?
  .equ SLICE_POINT_1 5                  ; Screen layout -  trooper slice.
  .equ SLICE_POINT_2 10                 ; - start of shield slice.
  .equ SLICE_POINT_3 13                 ; - end of shield slice (reset scroll).
  .equ ARMY_BUFFER_SIZE 7*32
; -----------------------------------------------------------------------------
.macro MATCH_WORDS ARGS _VARIABLE, _VALUE
; -----------------------------------------------------------------------------
  ; Match the contents of a 16-bit variable (_VARIABLE) with a given 16-bit
  ; value (_VALUE). If the words match then set carry. Else reset carry. Used
  ; to see if the Raster.MetaPtr points beyond the end of the meta table.
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
      call raster_handle_interrupt
    +:
  exx
  pop af
  ei
  reti
.ends
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
.ramsection "Main variables" slot 3
  raster_meta_effect_ptr dw ; Cycles through the table of raster effects.
  raster_effect_ptr dw      ; Set up up the current frame's raster effect.
  raster_timer db           ; When it is done, get next effect from meta table.
  ;
  army_buffer dsb ARMY_BUFFER_SIZE
.ends
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Main" free
; -----------------------------------------------------------------------------
  SetupMain:
    ; Initialize the raster effect:
    ld hl,raster_meta_table
    ld (raster_meta_effect_ptr),hl
    ld a,RASTER_INTERRUPT_VALUE
    ld b,RASTER_INTERRUPT_REGISTER
    call SetRegister
    ld a,RASTER_TIMER_INTERVAL
    ld (raster_timer),a
    ;
    LOAD_IMAGE MockupAssets,MockupAssetsEnd
    ;

    ;
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
    ld hl,(raster_meta_effect_ptr)
    ld (raster_effect_ptr),hl
    ;
    ; Non-vblank stuff below this line...
    ;
    ld hl,raster_timer
    dec (hl)
    ld a,(raster_timer)
    or a
    jp nz,skip_raster_update
      ; Time to update the raster meta table pointer. First set the timer.
      ld a,RASTER_TIMER_INTERVAL
      ld (raster_timer),a
      ; Load the current raster meta table pointer into HL.
      ld hl,raster_meta_effect_ptr
      ld a,(hl)
      inc hl
      ld h,(hl)
      ld l,a
      ; Skip forward one raster effect table element.
      ld de,RASTER_EFFECT_TABLE_SIZE
      add hl,de
      ; Load the updated pointer from HL back into ram.
      ld (raster_meta_effect_ptr),hl
      ; If we have now moved past the raster effects meta table, then reset
      ; the pointer to the start of the meta table.
      MATCH_WORDS raster_meta_effect_ptr, raster_meta_table_end
      jp nc,+
        ld hl,raster_meta_table
        ld (raster_meta_effect_ptr),hl
      +:
    skip_raster_update:
    ;
  jp Main
  ;
  raster_handle_interrupt:
    ; This function assumes it is called from the interrupt handler. Check if
    ; the current line = next slice point, which is read from this frame's
    ; raster effect table. If we are at a slice point then slice the screen by
    ; reading and applying the hscroll value from the raster effect table, and
    ; forward the table pointer accordingly.
    ; Uses: AF, B, HL
    in a,(V_COUNTER_PORT)
    ld b,a
    ld hl,(raster_effect_ptr)
    ld a,(hl)                       ; Load A with next slice point value.
    cp b                            ; Is the current line == next slice point?
    ret nz                          ; If not, then just return.
    inc hl                          ; Else, increment HL to point to scroll.
    ld a,(hl)                       ; Load scroll value into A, and set the
    ld b,HORIZONTAL_SCROLL_REGISTER ; horizontal scroll register to the given
    call SetRegister                ; value.
    inc hl                          ; Finish by incrementing the pointer and
    ld (raster_effect_ptr),hl       ; loading it back into memory. Now it is
  ret                               ; pointing at the next slicepoint...
.ends
;
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
  .equ RASTER_EFFECT_TABLE_SIZE 6         ; 3 pairs [slicepoint, scroll] bytes.
  .macro MAKE_RASTER_EFFECT_TABLE ARGS OFFSET, SLICE_MODE
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
  raster_meta_table:
    ; The raster meta table consists of a long list of raster effect tables.
    MAKE_RASTER_EFFECT_TABLE 0, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE 0, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE 2, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE 2, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE 4, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE 4, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE 6, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE 6, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE 8, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE 8, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE 10, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE 10, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE 8, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE 8, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE 6, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE 6, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE 4, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE 4, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE 2, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE 2, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE 0, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE 0, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE -2, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE -2, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE -4, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE -4, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE -6, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE -6, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE -8, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE -8, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE -10, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE -10, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE -8, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE -8, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE -6, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE -6, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE -4, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE -4, SKEW_SLICES
    MAKE_RASTER_EFFECT_TABLE -2, ALIGN_SLICES
    MAKE_RASTER_EFFECT_TABLE -2, SKEW_SLICES
  raster_meta_table_end:
.ends
; -----------------------------------------------------------------------------
.section "Mockup Assets" free
; -----------------------------------------------------------------------------
  MockupAssets:
    .include "MockupAssets.inc"
  MockupAssetsEnd:
.ends
