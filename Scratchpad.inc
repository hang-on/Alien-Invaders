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

; -----------------------------------------------------------------------------
tilemap_to_buffer:
  ; fill a buffer with tilemap words read from a table
  ; A = number of words to read
  ; HL = table of tilemap addresses
  ; DE = Destination buffer.
  ld b,a
  -:
    push hl
      ; convert HL from pointer to word pointed to...
      ld a,(hl)
      inc hl
      ld h,(hl)
      ld l,a
      ; Read one word into buffer and update both pointers
      ld a,l
      out (CONTROL_PORT),a
      ld a,h
      or VRAM_READ_COMMAND
      out (CONTROL_PORT),a
    pop hl
    .rept 2
      in a,(DATA_PORT)
      ld (de),a
      inc de
      inc hl
    .endr
  djnz -
ret

base_tilemap_table:
  .dw CENTER_BASE_FIRST_TILE,
  .dw CENTER_BASE_FIRST_TILE+2
  .dw CENTER_BASE_FIRST_TILE+4
  .dw CENTER_BASE_FIRST_TILE+6
  .dw CENTER_BASE_FIRST_TILE+8
  ;
  .dw CENTER_BASE_FIRST_TILE+(32*2)
  .dw CENTER_BASE_FIRST_TILE+2+(32*2)
  .dw CENTER_BASE_FIRST_TILE+4+(32*2)
  .dw CENTER_BASE_FIRST_TILE+6+(32*2)
  .dw CENTER_BASE_FIRST_TILE+8+(32*2)
  ;
  .dw CENTER_BASE_FIRST_TILE+(62*2)
  .dw CENTER_BASE_FIRST_TILE+2+(62*2)
  .dw CENTER_BASE_FIRST_TILE+4+(62*2)
  .dw CENTER_BASE_FIRST_TILE+6+(62*2)
  .dw CENTER_BASE_FIRST_TILE+8+(62*2)
  ;
; -----------------------------------------------------------------------------



; ---
      ; FIXME: Test army_move_counter to see if it is time to scroll down and
      ; change direction.
      ; !!
      ld a,(army_skew_mode)
      or a
      cpl
      ld (army_skew_mode),a
      jp nz,+
        ld c,ARMY_SKEW_VALUE
        jp ++
      +:
        ld c,(-ARMY_SKEW_VALUE)
      ++:
      ld b,ARMY_SPEED
      ld a,(army_direction)
      or a
      jp z,+
        ld a,b
        neg
        ld b,a
      +:
      ld a,(robots_horizontal_scroll_value)
      add a,b
      add a,c
      ld (robots_horizontal_scroll_value),a
      ld a,(shields_horizontal_scroll_value)
      add a,b
      sub c
      ld (shields_horizontal_scroll_value),a
      jp finish_army_movement
