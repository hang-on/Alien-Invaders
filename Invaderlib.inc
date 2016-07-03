; Invaderlib.inc

.macro Compare ARGS _VARIABLE, _VALUE
  or a
  ld hl,_VARIABLE
  ld de,_VALUE
  sbc hl,de
  
.endm

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
.macro LoadImage
; -----------------------------------------------------------------------------
  ; This macro makes it easy to load an image. Call the macro like this:
  ; LoadImage MockupAssets,MockupAssetsEnd
  ; Include format:
  ;    MockupAssets:
  ;      .include "MockupAssets.inc"
  ;    MockupAssetsEnd:
  ; Drop a 256x192 indexed color image on \Tools\MakeAssets.bat to quickly
  ; generate an include file formatted for this macro.

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

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
.ramsection "Raster Effect Variables" slot 3
  RasterEffect.TablePointer dw
.ends
; -----------------------------------------------------------------------------
.section "Raster Effect Functions" free
; -----------------------------------------------------------------------------
  RasterEffect.BeginNewFrame:
    ; Point RasterEffect.TablePointer to the base of the raster effect table
    ; to be used to make raster effects during this frame. Then reset the
    ; vdp's hscroll register. Assumes blanked display and no interrupts.
    ; Entry: HL = Base address of this frame's raster effect table.
    ; Uses: AF, B, HL
    ld (RasterEffect.TablePointer),hl
    ld a,0
    ld b,HORIZONTAL_SCROLL_REGISTER
    call SetRegister
  ret

  RasterEffect.HandleRasterInterrupt:
    ; This function assumes it is called from the interrupt handler. Check if
    ; the current line = next slice point, which is read from this frame's
    ; raster effect table. If we are at a slice point then slice the screen by
    ; reading and applying the hscroll value from the raster effect table, and
    ; forward the table pointer accordingly.
    ; Uses: AF, B, HL
    in a,(V_COUNTER_PORT)
    ld b,a
    ld hl,(RasterEffect.TablePointer)
    ld a,(hl)
    cp b
    ret nz
    inc hl
    ld a,(hl)
    ld b,HORIZONTAL_SCROLL_REGISTER
    call SetRegister
    inc hl
    ld (RasterEffect.TablePointer),hl
  ret

  RasterEffect.Initialize:
    ; Initialize the raster effect engine.
    ; Assumes blanked display and no interrupts.
    ; Entry: A = Value to load into the raster interrupt register (number of
    ;            lines per interrupt - 1).
    ; Uses: AF, B
    ld b,RASTER_INTERRUPT_REGISTER
    call SetRegister
  ret
.ends

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
.ramsection "Timer Variables" slot 3
  Timer.Value db
.ends
; -----------------------------------------------------------------------------
.section "Timer Functions" free
; -----------------------------------------------------------------------------
  Timer.Countdown:
    ld hl,Timer.Value
    dec (hl)
  ret

  Timer.Setup:
    ; Entry: A = value 0-255.
    ld (Timer.Value),a
  ret

  Timer.IsDone:
    ; Exit: Carry set/reset = Timer is done/not yet done.
    ld a,(Timer.Value)
    or a
    ret nz
    scf
  ret

.ends
