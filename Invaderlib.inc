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
  ; ---------------------------------------------------------------------------
  copy_tilemap_rect_to_buffer:
    ; Copy the tilemap words under a rectangle to a buffer.
    ; A = Rect width.
    ; B = Rect height.
    ; HL = Top left tile (address) of rectangle to copy.
    ; DE = Destination buffer.
    add a,a                 ; Double width - the table elements are words.
    ld c,a                  ; Save width in C for counting.
    ; For each 'rect-height' do the following...
    --:
      ld a,l
      out (CONTROL_PORT),a
      ld a,h
      or VRAM_READ_COMMAND
      out (CONTROL_PORT),a
      push de
        ld de,ONE_TILEMAP_ROW
        add hl,de
      pop de
      push bc               ; Save rect width*2.
      ; For each 'rect-width*2' do the following...
        -:
          in a,(DATA_PORT)  ; Get byte from tilemap.
          ld (de),a         ; Store it in the buffer.
          inc de            ; Update buffer pointer.
          dec c             ; Decrement 'for counter'.
          xor a             ; Do the rect-width*2 for-loop logic...
          cp c
        jp nz,-
      pop bc                ; Restore rect-width*2.
    djnz --                 ; The rect-height for-loop.
  ret
  ; ---------------------------------------------------------------------------
  blank_tilemap_rect:
    ; Write $0000 to the tilemap words under a rectangle.
    ; A = Rect width.
    ; B = Rect height.
    ; HL = Address of first tile to blank.
    add a,a                 ; Double width - the table elements are words.
    ld c,a                  ; Save width in C for counting.
    ; For each 'rect-height' do the following...
    --:
      ld a,l
      out (CONTROL_PORT),a
      ld a,h
      or VRAM_WRITE_COMMAND
      out (CONTROL_PORT),a
      ld de,ONE_TILEMAP_ROW
      add hl,de
      ld a,$00
      push bc               ; Save rect width*2.
      ; For each 'rect-width*2' do the following...
        -:
          out (DATA_PORT),a
          dec c             ; Decrement 'for counter'.
          cp c              ; A is already $00 = blanked.
        jp nz,-
      pop bc                ; Restore rect-width*2.
    djnz --                 ; The rect-height for-loop.
  ret
  ; ---------------------------------------------------------------------------
  copy_buffer_to_tilemap_rect:
    ; Reverse of copy_tilemap_rect_to_buffer.
    ; A = Rect width.
    ; B = Rect height.
    ; HL = Base address of buffer.
    ; DE = Address of top left tile of tilemap rectangle.
    ; Preserves all registers used.
    ; Time: 11 lines.
    push af
    push bc
    push de
    push hl
    add a,a                 ; Double width - the table elements are words.
    ld c,a                  ; Save width in C for counting.
    ; For each 'rect-height' do the following...
    --:
      ld a,e
      out (CONTROL_PORT),a
      ld a,d
      or VRAM_WRITE_COMMAND
      out (CONTROL_PORT),a
      push hl
        ld hl,ONE_TILEMAP_ROW
        add hl,de
        ex de,hl
      pop hl
      push bc               ; Save rect width*2.
      ; For each 'rect-width*2' do the following...
        -:
          ld a,(hl)
          out (DATA_PORT),a
          inc hl
          dec c             ; Decrement 'for counter'.
          xor a             ; Do the rect-width*2 for-loop logic...
          cp c
        jp nz,-
      pop bc                ; Restore rect-width*2.
    djnz --                 ; The rect-height for-loop.
    pop hl
    pop de
    pop bc
    pop af
  ret
  ; ---------------------------------------------------------------------------
  subtract_one_row:
    ; Take a pointer to a variable containing a screen address. Get the
    ; screen address, and subtract one row of tiles from it. Store the
    ; updated screen address back into the variable and return.
    ; Used to update the player base's addresses as the screen scrolls
    ; vertically.
    ; Entry: HL = Pointer to variable.
    ; Uses: AF, DE (HL is saved).
    push hl
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    ld de,ONE_TILEMAP_ROW
    sbc hl,de
    ex de,hl
    pop hl
    ld (hl),e
    inc hl
    ld (hl),d
    dec hl
  ret

.ends
