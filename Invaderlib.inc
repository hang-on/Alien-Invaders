; Invaderlib.inc
;
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
; -----------------------------------------------------------------------------
.section "Invaderlib functions" free
; -----------------------------------------------------------------------------
  handle_raster_interrupt:
    ; FIXME: Doing nothing at the moment. Can control horizontal scrolling.
    in a,(V_COUNTER_PORT)
  ret
  ; ---------------------------------------------------------------------------
  load_vdp_registers:
    ; Load all 11 vdp registers with preset values.
    ; Entry: HL pointing to init data block (11 bytes).
    xor b
    -:
      ld a,(hl)
      out (CONTROL_PORT),a
      inc hl
      ld a,b
      or REGISTER_WRITE_COMMAND
      out (CONTROL_PORT),a
      cp REGISTER_WRITE_COMMAND|10
      ret z
      inc b
    jr -
  ret
  ;
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
.ends
