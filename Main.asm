.include "Base.inc"
; Definitions for raster effects
.equ VSCROLL_INIT_VALUE $df           
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
  HScroll db
  VScroll db
.ends
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Main" free
; -----------------------------------------------------------------------------
  SetupMain:
    ld a,VSCROLL_INIT_VALUE
    ld (VScroll),a
    ;
    LOAD_IMAGE MockupAssets,MockupAssetsEnd
    ;
    ld a,FULL_SCROLL_BLANK_LEFT_COLUMN_KEEP_SPRITES_ENABLE_RASTER_INT
    ld b,0
    call SetRegister
    ld a,ENABLE_DISPLAY_ENABLE_FRAME_INTERRUPTS_NORMAL_SPRITES
    ld b,1
    call SetRegister
    ld a,7
    ld b,RASTER_INTERRUPT_REGISTER
    call SetRegister
    ; Skip an interrupt to make sure that we start main at vblank.
    ei
    call AwaitFrameInterrupt
  jp Main
  ;
  Main:
    call AwaitFrameInterrupt
    ld a,(VScroll)
    ld b,VERTICAL_SCROLL_REGISTER
    call SetRegister
    ld a,(HScroll)
    ld b,HORIZONTAL_SCROLL_REGISTER
    call SetRegister
    ;
    ; Non-vblank stuff below this line...
    ;
    call GetInputPorts
    call IsPlayer1UpPressed
    jp nc,+
      ld hl,VScroll
      inc (hl)
    +:
    call IsPlayer1DownPressed
    jp nc,+
      ld hl,VScroll
      dec (hl)
    +:
    call IsPlayer1LeftPressed
    jp nc,+
      ld hl,HScroll
      dec (hl)
    +:
    call IsPlayer1RightPressed
    jp nc,+
      ld hl,HScroll
      inc (hl)
    +:
  jp Main
  ;
  handle_raster_interrupt:
    in a,(V_COUNTER_PORT)
    cp 127
    ret nz
    xor a
    ld b,VERTICAL_SCROLL_REGISTER
    call SetRegister
  ret                               ; pointing at the next slicepoint...
.ends
;
.bank 1 slot 1
;
; -----------------------------------------------------------------------------
.section "Mockup Assets" free
; -----------------------------------------------------------------------------
  MockupAssets:
    .include "MockupAssets.inc"
  MockupAssetsEnd:
.ends
;
.bank 2 slot 2
