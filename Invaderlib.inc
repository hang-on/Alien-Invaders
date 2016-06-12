; Invaderlib.inc

.macro LoadImage
  ld a,0
  ld b,\2-\1
  ld hl,\1
  call LoadCRam

  ld bc,\3-\2
  ld de,0
  ld hl,\2
  call LoadVRam

  ld bc,\4
  ld de,NAME_TABLE_START
  ld hl,\3
  call LoadVRam
.endm
