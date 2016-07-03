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
