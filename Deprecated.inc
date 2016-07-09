; -----------------------------------------------------------------------------
.macro GetNextWord ARGS _INDEX, _TABLE, _TABLE_END
; -----------------------------------------------------------------------------
  ; The purpose of this macro is to facilitate the common process of
  ; retrieving a word-sized element from a table at a given index. The macro
  ; then updates the index so it refers to the next element.
  ; NOTE: Index can be 126 at max!
  ; Entry: _INDEX is an 8-bit variable holding the index of the table.
  ;        _TABLE is the base address of the table.
  ;        _TABLE_END is the end-of-tale, used to calculate overflow.
  ; Exit:  The variable passed as _INDEX is incremented or reset.
  ;        HL = Word at position [index] in [table].

  ; Retrieve word at table[index] and store it in HL.
  ld a,(_INDEX)
  ld hl,_TABLE
  add a,a
  ld d,0
  ld e,a
  add hl,de
  ld e,(hl)
  inc hl
  ld d,(hl)
  ex de,hl

  ; Increment or reset index before saving.
  ld a,(_INDEX)
  inc a
  cp (_TABLE_END-_TABLE)/2
  jp nz,+
    xor a
  +:
  ld (_INDEX),a
.endm

; -----------------------------------------------------------------------------
.macro MATCH_WORDS ARGS _VARIABLE, _VALUE
; -----------------------------------------------------------------------------
  ; Match the contents of a 16-bit variable (_VARIABLE) with a given 16-bit
  ; value (_VALUE). If the words match then set carry. Else reset carry. Used
  ; to see if the Raster.MetaPtr points beyond the end of the meta table.
  or a              ; Clear carry so it does not interfere with sbc below.
  ld hl,_VARIABLE
  ld a,(hl)
  inc hl
  ld h,(hl)
  ld l,a
  ld de,_VALUE
  sbc hl,de
  scf
  jp z,+
    or a
  +:
.endm
