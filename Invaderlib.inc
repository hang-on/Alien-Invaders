; Invaderlib.inc

.macro WordMatch ARGS _VARIABLE, _VALUE
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
