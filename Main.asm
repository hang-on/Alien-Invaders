.include "Base.inc"
.include "Invaderlib.inc"


.bank 0 slot 0
.org $0038
; ---------------------------------------------------------------------------
.section "!VDP interrupt" force
; ---------------------------------------------------------------------------
  push af
  push bc
  push de
  push hl
    in a,CONTROL_PORT
    ld (VDPStatus),a
    bit 7,a
    call z,HandleRasterInterrupt
  pop hl
  pop de
  pop bc
  pop af
  ei
  reti

  HandleRasterInterrupt:
    nop
  ret

.ends

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
.ramsection "Main variables" slot 3

.ends
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Main" free
; -----------------------------------------------------------------------------
  SetupMain:

    LoadImage MockupAssets,MockupAssetsEnd

    ld a,FULL_SCROLL_SHOW_LEFT_COLUMN_KEEP_SPRITES_ENABLE_RASTER_INT
    ld b,0
    call SetRegister

    ld a,89
    ld b,10
    call SetRegister


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
  MockupAssets:
    .include "MockupAssets.inc"
  MockupAssetsEnd:
  .ends
