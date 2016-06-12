; Invaderlib.inc

.macro LoadImage
  ld a,0
  ld b,\2
  ld hl,\1
  call LoadCRam

  ld bc,\4
  ld de,0
  ld hl,\3
  call LoadVRam

  ld bc,\6
  ld de,NAME_TABLE_START
  ld hl,\5
  call LoadVRam
.endm
