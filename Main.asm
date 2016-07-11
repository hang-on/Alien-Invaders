.include "Base.inc"
;
.equ VSCROLL_INIT_VALUE $df
.equ TIMER_INIT_VALUE 120
.equ RASTER_INIT_VALUE 7

;
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
  vertical_scroll db
  timer db
.ends
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Main" free
; -----------------------------------------------------------------------------
  SetupMain:
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
  jp Main
  ;
  Main:
    call AwaitFrameInterrupt
    ld a,(vertical_scroll)
    ld b,VERTICAL_SCROLL_REGISTER
    call SetRegister
    ;
    ; Non-vblank stuff below this line...
    ;
    call handle_timer
  jp Main
  ;
  ; ---------------------------------------------------------------------------
  handle_raster_interrupt:
    ; FIXME: Doing nothing at the moment. Can control horizontal scrolling.
    in a,(V_COUNTER_PORT)
  ret
  ; ---------------------------------------------------------------------------
  handle_timer:
    ; If the timer is zero then initialize it, else decrement it.
    ld a,(timer)
    or a
    jp nz,+
      ld a,TIMER_INIT_VALUE
      call initialize_timer
      ret
    +:
    dec a
    ld (timer),a
  ret
  ; ---------------------------------------------------------------------------
  initialize_vs_controller:
    ; Initialize the vertical scroll controller.
    ; Load the init value into the vertical scroll register.
    ; Entry: A = Init value for the vertical scroll register.
    ld (vertical_scroll),a
  ret
  ; ---------------------------------------------------------------------------
  initialize_timer:
    ; Load the init value into the timer variable.
    ; Entry: A = Timer init value
    ld (timer),a
  ret
  ; ---------------------------------------------------------------------------
  load_vdp_registers:
    ; Load all 11 vdp registers with preset values.
    ; Entry: HL pointing to init data block (11 bytes).
    xor b
    -:
      ld a,(hl)
      out (CONTROL_PORT),a
      inc hl
      ld a,b
      or REGISTER_WRITE_COMMAND
      out (CONTROL_PORT),a
      cp REGISTER_WRITE_COMMAND|10
      ret z
      inc b
    jr -
  ret
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
