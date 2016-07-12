.include "Base.inc"
.include "Invaderlib.inc"
;
.equ VSCROLL_INIT_VALUE $df
.equ TIMER_INIT_VALUE 120
.equ RASTER_INIT_VALUE 7
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
    LOAD_IMAGE MockupAssets,MockupAssetsEnd
    ;
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
    ;
    ; Non-vblank stuff below this line...
    ;
    ld a,(vertical_scroll_timer)      ; Get vertical_scroll_timer.
    or a                              ; Is it zero?
    jp nz,+
      ld a,TIMER_INIT_VALUE           ; Yes - load init value.
      ld (vertical_scroll_timer),a    ;
      ; FIXME: Scroll stuff happens here!
      jp ++                           ;
    +:                                ; No - decrement timer.
      dec a                           ;
      ld (vertical_scroll_timer),a    ;
    ++:                               ; End of vertical_scroll_timer handler.
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
