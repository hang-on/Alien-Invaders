.include "Base.inc"

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

    ld a,0
    ld b,PaletteEnd-Palette
    ld hl,Palette
    call LoadCRam

    ld bc,TilesEnd-Tiles
    ld de,0
    ld hl,Tiles
    call LoadVRam

    ld bc,TilemapEnd-Tilemap
    ld de,NAME_TABLE_START
    ld hl,Tilemap
    call LoadVRam


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
  .include "Invaderlib.inc"



.bank 2 slot 2
; -----------------------------------------------------------------------------
  .section "Data" free
; -----------------------------------------------------------------------------
    Tiles:
      .include "Screen-1-Tiles.inc"
    TilesEnd:
    Tilemap:
      .include "Screen-1-Tilemap.inc"
    TilemapEnd:
    Palette:
      .include "Screen-1-Palette.inc"
    PaletteEnd:
  .ends
