; Invaderlib.inc

; -----------------------------------------------------------------------------
.macro LoadImage
; -----------------------------------------------------------------------------
  ; This macro makes it easy to load an image. Call the macro like this:
  ; LoadImage MockupPalette,MockupTiles,MockupTilemap and make sure that you
  ; have included the image's data under the labels passed as arguments.
  ; Include format:
  ;    MockupPalette:
  ;      .include "MockupPalette.inc"
  ;    MockupTiles:
  ;      .include "MockupTiles.inc"
  ;    MockupTilemap:
  ;      .include "MockupTilemap.inc"
  ld a,0
  ld b,16
  ld hl,\1
  call LoadCRam

  ld bc,NAME_TABLE_SIZE
  ld de,NAME_TABLE_START
  ld hl,\1+16
  call LoadVRam

  ld bc,\2-(\1+16+NAME_TABLE_SIZE)
  ld de,0
  ld hl,\1+16+NAME_TABLE_SIZE
  call LoadVRam

.endm
