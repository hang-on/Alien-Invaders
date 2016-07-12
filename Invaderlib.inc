; Invaderlib.inc
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
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
.ramsection "Invaderlib variables" slot 3
  vertical_scroll db
  timer db
.ends
; -----------------------------------------------------------------------------
.section "Invaderlib functions" free
; -----------------------------------------------------------------------------
  handle_raster_interrupt:
    ; FIXME: Doing nothing at the moment. Can control horizontal scrolling.
    in a,(V_COUNTER_PORT)
  ret
  ; ---------------------------------------------------------------------------
  handle_vs_controller:
    ld a,(vertical_scroll)
    ld b,VERTICAL_SCROLL_REGISTER
    call SetRegister
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
