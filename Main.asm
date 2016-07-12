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
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "main" free
; -----------------------------------------------------------------------------
  setup_main:
    ld a,VSCROLL_INIT_VALUE
    call initialize_vs_controller
    ;
    ld a,TIMER_INIT_VALUE
    call initialize_timer
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
    call handle_vs_controller
    ;
    ; Non-vblank stuff below this line...
    ;
    call handle_timer
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
