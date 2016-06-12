.include "Base.inc"
.include "Invaderlib.inc"


.bank 0 slot 0
.org $0038
; ---------------------------------------------------------------------------
.section "!VDP interrupt" force
; ---------------------------------------------------------------------------
  push af
    in a,CONTROL_PORT
    ld (VDPStatus),a
  pop af
  ei
  reti
.ends

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
.ramsection "Main variables" slot 3

.ends
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Main" free
; -----------------------------------------------------------------------------
  SetupMain:

    LoadImage MockupPalette,MockupTiles,MockupTilemap,2*32*24

    ld a,ENABLE_DISPLAY_ENABLE_FRAME_INTERRUPTS_NORMAL_SPRITES
    ld b,1
    call SetRegister
    ei
    call AwaitFrameInterrupt

  Main:
    call AwaitFrameInterrupt

  jp Main

.ends


.bank 1 slot 1


.bank 2 slot 2
; -----------------------------------------------------------------------------
  .section "Data" free
; -----------------------------------------------------------------------------
    MockupPalette:
      .include "MockupPalette.inc"
    MockupTiles:
      .include "MockupTiles.inc"
    MockupTilemap:
      .include "MockupTilemap.inc"
  .ends
