; Invaderlib.inc


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
; -----------------------------------------------------------------------------
.section "Timer Functions" free
; -----------------------------------------------------------------------------
  Timer.Countdown:
    ld hl,Raster.Timer
    dec (hl)
  ret

  
  Timer.IsDone:
    ; Exit: Carry set/reset = Timer is done/not yet done.
    ld a,(Raster.Timer)
    or a
    ret nz
    scf
  ret

.ends
