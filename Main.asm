.include "Base.inc"
.include "Invaderlib.inc"
;
.equ VSCROLL_INIT_VALUE 223
.equ VERTICAL_SCROLL_STEP 8
.equ VERTICAL_SCROLL_LIMIT 183
.equ TIMER_INIT_VALUE 120
.equ RASTER_INIT_VALUE 7
.equ BASE_WIDTH 5
.equ BASE_HEIGHT 3
.equ CENTER_BASE_FIRST_TILE $3c5c
.equ ONE_TILEMAP_ROW 32*2
;
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
      call handle_raster_interrupt
    +:
  exx
  pop af
  ei
  reti
.ends
;
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
.ramsection "Main variables" slot 3
  vertical_scroll_value db
  vertical_scroll_timer db
  base_buffer dsb BASE_WIDTH*BASE_HEIGHT*2   ; * 2 = name table words.
  center_base_address dw
.ends
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "main" free
; -----------------------------------------------------------------------------
  setup_main:
    ld a,VSCROLL_INIT_VALUE
    ld (vertical_scroll_value),a
    ;
    ld a,TIMER_INIT_VALUE
    ld (vertical_scroll_timer),a
    ;
    ld hl,CENTER_BASE_FIRST_TILE
    ld (center_base_address),hl
    ;
    LOAD_IMAGE MockupAssets,MockupAssetsEnd
    ; Load player base tiles from vram tilemap to buffer.
    ld a,BASE_WIDTH
    ld b,BASE_HEIGHT
    ld hl,CENTER_BASE_FIRST_TILE
    ld de,base_buffer
    call copy_tilemap_rect_to_buffer
    ; Blank the center base.
    ld hl,CENTER_BASE_FIRST_TILE
    ld a,BASE_WIDTH
    ld b,BASE_HEIGHT
    call blank_tilemap_rect
    ; Turn on screen, etc.
    ld hl,register_data
    call load_vdp_registers
    ; Skip an interrupt to make sure that we start main at vblank.
    ei
    call AwaitFrameInterrupt
  jp main
  ;
  main:
    call AwaitFrameInterrupt
    ;
    ld a,(vertical_scroll_value)
    ld b,VERTICAL_SCROLL_REGISTER
    call SetRegister
    ; Test: Write the center base
    ld a,BASE_WIDTH
    ld b,BASE_HEIGHT
    ld hl,base_buffer
    ld de,(center_base_address)
    call copy_buffer_to_tilemap_rect
    ;
    ; Non-vblank stuff below this line...
    ;
    ld a,(vertical_scroll_timer)
    or a
    jp nz,decrement_timer
      ; Time is up - handle scrolling.
      ld a,TIMER_INIT_VALUE
      ld (vertical_scroll_timer),a
      ld a,(vertical_scroll_value)
      sub VERTICAL_SCROLL_STEP
      cp VERTICAL_SCROLL_LIMIT
      jp nz,+
        ld a,VSCROLL_INIT_VALUE
        ld (vertical_scroll_value),a
        ld hl,CENTER_BASE_FIRST_TILE
        ld (center_base_address),hl
        jp vertical_scroll_end
      +:
      ld (vertical_scroll_value),a
      ld hl,(center_base_address)
      ld de,ONE_TILEMAP_ROW
      sbc hl,de
      ld (center_base_address),hl
      ;
      jp vertical_scroll_end                           ;
    decrement_timer:
      ; Not time for scrolling yet - just decrement the timer.
      dec a
      ld (vertical_scroll_timer),a
    vertical_scroll_end:
    ;
  jp main
.ends
;
.bank 1 slot 1
; -----------------------------------------------------------------------------
.section "Mockup Assets" free
; -----------------------------------------------------------------------------
  MockupAssets:
    .include "MockupAssets.inc"
  MockupAssetsEnd:
  ;
  register_data:
    .db FULL_SCROLL_BLANK_LEFT_COLUMN_KEEP_SPRITES_ENABLE_RASTER_INT
    .db ENABLE_DISPLAY_ENABLE_FRAME_INTERRUPTS_NORMAL_SPRITES
    .db $ff,$ff,$ff,$ff,$ff,$00,$00,VSCROLL_INIT_VALUE,RASTER_INIT_VALUE
.ends
;
.bank 2 slot 2
