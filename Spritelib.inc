; *****************************************************************************
;                           SPRITE LIBRARY
; *****************************************************************************
; Note: Spritelib depends on constants from Base.inc.

.equ FIRST_FREE_SPRITE 0    ; First sprite controlled by this library.
                            ; FIXME - Library actually assumes full control.
.equ ASCENDING 0
.equ DESCENDING $ff

; MetaSpriteFlags:
.equ RIGHT_MASK   %0000001
.equ LEFT_MASK    %0000010
.equ NO_MASKS     %0000000

.ramsection "Spritelib Variables" slot 3
  SpriteBufferY dsb 64
  SpriteBufferXC dsb 128
  NextFreeSprite db
  MasterY db
  MasterX db
  MetaSpriteFlags db
  MetaSpriteSize db
  SATLoadMode db             ; Ascending or descending - for flickering.
.ends
; -----------------------------------------------------------------------------
.section "LoadSAT" free
; -----------------------------------------------------------------------------
  ; Load the vram sat with the SatY and SatXC buffers.
  ; Sonic 2 inspired flicker engine is in place: Flicker sprites by loading the
  ; SAT in ascending/descending order every other frame. Always keep first 8
  ; sprites on top (for a non-flickering master object, i.e. the player).
  LoadSAT:
    ld a,(SATLoadMode)
    cp DESCENDING
    jp z,_DescendingLoad
      ; If not descending, then fall through to ascending load mode.

      ; Load y-coordinates.
      ld hl,SAT_Y_START
      ld a,l
      out (CONTROL_PORT),a
      ld a,h
      or VRAM_WRITE_COMMAND
      out (CONTROL_PORT),a
      ld hl,SpriteBufferY
      ld c,DATA_PORT
      .rept 64
        outi
      .endr

      ; Load x-coordinates and character codes.
      ld hl,SAT_XC_START
      ld a,l
      out (CONTROL_PORT),a
      ld a,h
      or VRAM_WRITE_COMMAND
      out (CONTROL_PORT),a
      ld hl,SpriteBufferXC
      ld c,DATA_PORT
      .rept 128
        outi
      .endr
  ret

    _DescendingLoad:
      ; Load y-coordinates.
      ld hl,SAT_Y_START
      ld a,l
      out (CONTROL_PORT),a
      ld a,h
      or VRAM_WRITE_COMMAND
      out (CONTROL_PORT),a
      ld c,DATA_PORT
      ld hl,SpriteBufferY
      .rept 8
        outi
      .endr

      ld hl,SpriteBufferY+63    ; Point to last y-value in buffer.
      .rept 56
        outd                    ; Output and decrement HL, thus going
      .endr                     ; backwards (descending) through the buffer.

      ; Load x-coordinates and character codes
      ld hl,SAT_XC_START
      ld a,l
      out (CONTROL_PORT),a
      ld a,h
      or VRAM_WRITE_COMMAND
      out (CONTROL_PORT),a
      ld c,DATA_PORT
      ld hl,SpriteBufferXC
      .rept 8
        outi
        outi
      .endr

      ld hl,SpriteBufferXC+126
      ld de,-4
      .rept 56
        outi
        outi
        add hl,de
      .endr
  ret

.ends

; -----------------------------------------------------------------------------
.section "BeginMetaSprites" free
; -----------------------------------------------------------------------------
  WipeData:
    .rept 64
      .db $e0
    .endr

  BeginMetaSprites:
    ; Reset the NextFreeSprite index at the beginning of every frame
    ld a,FIRST_FREE_SPRITE
    ld (NextFreeSprite),a

    ; Toggle ascending/descending sat load mode.
    ld a,(SATLoadMode)
    cpl
    ld (SATLoadMode),a

    ; Wipe Y-buffer with $e0 to get unused sprites out of the way.
    ld hl,WipeData
    ld de,SpriteBufferY
    ld bc,64
    ldir
  ret
.ends

; -----------------------------------------------------------------------------
.section "AddMetaSprite" free
; -----------------------------------------------------------------------------
  AddMetaSprite:
    ; Entry: NextFreeSprite is the first buffer position.
    ;        HL = Base address of meta sprite array. First byte is the size of
    ;        the meta sprite.
    ;        A = Master Y
    ;        B = Master X
    ;        C = MetaSpriteFlags (for clipping)
    ; Procedure: First the program processes the Y-offsets. Each offset is
    ; applied to the master Y, and the result is saved in SpriteBufferY. Then
    ; the X-offsets are processed, and stored pairwise with character codes in
    ; SpriteBufferXC.
    ; Exit: SpriteBufferY and SpriteBufferXC is updated. NextFreeSprite is
    ; incremented.

    ; Save the parameters in ram.
    ld (MasterY),a
    ld a,b
    ld (MasterX),a
    ld a,c
    ld (MetaSpriteFlags),a

    ; Get size of metasprite and put it in B.
    ld a,(hl)             ; HL points to size on entry.
    inc hl                ; Now hl points to first y-offset.
    ld b,a                ; Put size in B, so we can use DJNZ.
    ld (MetaSpriteSize),a ; Save the size for later counting jobs.

    ; Test for sprite overflow (more than 64 hardware sprites at once).
    ld a,(NextFreeSprite)
    add a,b
    cp 65
    ret nc

    ; Point DE to SpriteBufferY[NextFreeSprite].
    ld a,(NextFreeSprite)
    ld de,SpriteBufferY
    add a,e
    ld e,a
    ld a,0
    adc a,d
    ld d,a

    ; Apply offsets to MasterY, and write the results to SpriteBufferY.
    ld a,(MasterY)
    ld c,a
    -:
      ld a,(hl)
      add a,c
      cp SPRITE_TERMINATOR
      jp nz,+
        inc a
      +:
      ld (de),a
      inc hl
      inc de
    djnz -

    ; Apply offsets to MasterX, and save results, together with charcodes, in
    ; SpriteBufferXC. HL points to the first x-offset.

    ; Point DE to SpriteBufferY[NextFreeSprite]
    ld a,(NextFreeSprite) ; Double the buffer index because this is a buffer
    add a,a               ; word-sized elements  (x + charcode pairs).
    ld de,SpriteBufferXC
    add a,e               ; Calculate offset using 8-bit math to avoid
    ld e,a                ; disturbing HL and B.
    ld a,0
    adc a,d               ; Apply a possible carry from LSB above.
    ld d,a                ; Now, DE is pointing correctly into SpriteBufferXC.

    ; Now we got HL and DE set up, we branch according to which mask, if any,
    ; to use when placing the sprite horizontally.

    ld a,(MetaSpriteFlags)
    bit 0,a
    jp nz,_UseRightMask
    bit 1,a
    jp nz,_UseLeftMask
    ; ... If none of the masks are set, then fall through to non-masked
    ; processing.

    _UseNoMask:
      ; Apply offsets to MasterX and write results together with charcodes.
      ld a,(MasterX)
      ld c,a
      ld a,(MetaSpriteSize) ; Retrieve size and store it in B for counting.
      ld b,a
      -:
        ; First byte: X.
        ld a,(hl)           ; Get the offset.
        add a,c             ; Apply MasterX to this offset.
        ld (de),a           ; Save it in buffer.
        inc hl              ; Forward both source and destination pointers...
        inc de

        ; Second byte: Character code.
        ld a,(hl)           ; Get the char code.
        ld (de),a           ; Save it directly in buffer.
        inc hl              ; Forward the pointers again...
        inc de
      djnz -
      jp _Finish

    ; Apply offsets with right mask on:

    ; FIXME: Remove duplication!! Pass cp value as parameter, and integrate
    ; the useright/left mask functions.

    _UseRightMask:
      ; Apply offsets to MasterX and write results together with charcodes.
      ld a,(MasterX)
      ld c,a
      ld a,(MetaSpriteSize) ; Retrieve size and store it in B for counting.
      ld b,a
      -:
        ; First byte: X.
        ld a,(hl)           ; Get the offset.
        add a,c             ; Apply MasterX to this offset.

        ; Temp: Force right mask on this sprite...
        cp 191
        jp c,+
          ; Sprite is about to be drawn on the masked out area (right side).
          ; Prevent this by putting the sprite in the blanked column.
          ld a,0
        +:

        ld (de),a           ; Save it in buffer.
        inc hl              ; Forward both source and destination pointers...
        inc de

        ; Second byte: Character code.
        ld a,(hl)           ; Get the char code.
        ld (de),a           ; Save it directly in buffer.
        inc hl              ; Forward the pointers again...
        inc de
      djnz -
      jp _Finish

    _UseLeftMask:
      ; Apply offsets with left mask on:
      ; Apply offsets to MasterX and write results together with charcodes.
      ld a,(MasterX)
      ld c,a
      ld a,(MetaSpriteSize) ; Retrieve size and store it in B for counting.
      ld b,a
      -:
        ; First byte: X.
        ld a,(hl)           ; Get the offset.
        add a,c             ; Apply MasterX to this offset.

        ; Temp: Force left mask on this sprite...
        cp 7+64
        jp nc,+
          ; Sprite is about to be drawn on the masked out area (right side).
          ; Prevent this by putting the sprite in the blanked column.
          ld a,0
        +:

        ld (de),a           ; Save it in buffer.
        inc hl              ; Forward both source and destination pointers...
        inc de

        ; Second byte: Character code.
        ld a,(hl)           ; Get the char code.
        ld (de),a           ; Save it directly in buffer.
        inc hl              ; Forward the pointers again...
        inc de
      djnz -
      jp _Finish


    _Finish:
    ld hl,MetaSpriteSize
    ld a,(NextFreeSprite) ; add the size of the processed metasprite
    add a,(hl)
    ld (NextFreeSprite),a
  ret
.ends

; -----------------------------------------------------------------------------
.section "FinalizeMetaSprites" free
; -----------------------------------------------------------------------------
  FinalizeMetaSprites:
    ; Anti-flickering measure:
    ; Go through all x positions in the table (active sprites only). If x = 0
    ; (sprite is under the blanked column 0-7), let its y-pos be $e0, thus it
    ; will be moved away from the active display, and not count towards sprite
    ; on scanline limits.
    ld a,(NextFreeSprite)
    or a
    ret z

    ld de,SpriteBufferXC
    ld hl,SpriteBufferY
    ld a,(NextFreeSprite)
    ld b,a
    ld c,$e0
    -:
      ld a,(de)
      or a
      jp nz,+
        ld (hl),c
      +:
      inc de
      inc de
      inc hl
    djnz -
  ret
.ends
