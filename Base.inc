; Base.inc - SMS project boilerplate and standard library.
; Latest revision: 2016-08-30

; *****************************************************************************
;                              BASE LIBRARY
; *****************************************************************************
.equ ROMSIZE 128                      ; Make a 128k or 256k rom.
;.equ INCLUDE_VDP_INTERRUPT_HANDLER    ; Comment out to exclude it.
.equ INCLUDE_PAUSE_BUTTON_HANDLER     ; Comment out to exclude it.

; -----------------------------------------------------------------------------
; HARDWARE DEFINITIONS
; -----------------------------------------------------------------------------
.equ NAME_TABLE_START $3800
.equ NAME_TABLE_SIZE 2*32*24
.equ SAT_Y_START $3f00
.equ SAT_XC_START SAT_Y_START+64+64
.equ SPRITE_TERMINATOR $d0

.equ V_COUNTER_PORT $7e
.equ CONTROL_PORT $BF
.equ DATA_PORT $BE
.equ VRAM_WRITE_COMMAND %01000000
.equ VRAM_READ_COMMAND %00000000
.equ REGISTER_WRITE_COMMAND %10000000
.equ CRAM_WRITE_COMMAND %11000000

.equ ENABLE_DISPLAY_ENABLE_FRAME_INTERRUPTS_NORMAL_SPRITES %11100000
.equ DISABLE_DISPLAY_ENABLE_FRAME_INTERRUPTS_NORMAL_SPRITES %10100000
.equ ENABLE_DISPLAY_DISABLE_FRAME_INTERRUPTS_NORMAL_SPRITES %11000000
.equ DISABLE_DISPLAY_DISABLE_FRAME_INTERRUPTS_NORMAL_SPRITES %10000000

.equ FULL_SCROLL_BLANK_LEFT_COLUMN_SHIFT_SPRITES_NO_RASTER_INT %00101110
.equ FULL_SCROLL_BLANK_LEFT_COLUMN_KEEP_SPRITES_NO_RASTER_INT %00100110
.equ FULL_SCROLL_SHOW_LEFT_COLUMN_KEEP_SPRITES_ENABLE_RASTER_INT %00010110
.equ FULL_SCROLL_BLANK_LEFT_COLUMN_KEEP_SPRITES_ENABLE_RASTER_INT %00110110

.equ HORIZONTAL_SCROLL_REGISTER 8
.equ VERTICAL_SCROLL_REGISTER 9
.equ RASTER_INTERRUPT_REGISTER 10

.equ SLOT_2_CONTROL $ffff
.equ STACK_INIT_ADDRESS $dff0
.equ RAM_START $c000

.equ INPUT_PORT_1 $dc
.equ INPUT_PORT_2 $dd

.equ PAUSE_FLAG_RESET $00
.equ PAUSE_FLAG_SET $ff

; -----------------------------------------------------------------------------
; SOFTWARE DEFINITIONS
; -----------------------------------------------------------------------------
.equ TRUE $ff
.equ FALSE 0


; =============================================================================
; M A C R O S
; =============================================================================

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
.macro SAVE_REGISTERS
; -----------------------------------------------------------------------------
  push af
  push bc
  push de
  push hl
.endm
; -----------------------------------------------------------------------------
.macro RESTORE_REGISTERS
; -----------------------------------------------------------------------------
  pop hl
  pop de
  pop bc
  pop af
.endm


; -----------------------------------------------------------------------------
.memorymap
; -----------------------------------------------------------------------------
  defaultslot 0
  slotsize $4000
  slot 0 $0000
  slot 1 $4000
  slot 2 $8000
  slotsize $2000
  slot 3 RAM_START
.endme
.if ROMSIZE == 128
  .rombankmap ; 128K rom
    bankstotal 8
    banksize $4000
    banks 8
  .endro
.endif
.if ROMSIZE == 256
  .rombankmap ; 256K rom
    bankstotal 16
    banksize $4000
    banks 16
  .endro
.endif

; -----------------------------------------------------------------------------
.ramsection "Global Variables" slot 3
; -----------------------------------------------------------------------------
  VDPStatus db    ; Set by the VDP interrupt handler and AwaitFrameInterrupt.
  PauseFlag db    ; Toggled by the pause button interrupt handler.
  InputPorts dw
.ends

.org 0
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Boot" force
; -----------------------------------------------------------------------------
  di
  im 1
  ld sp,STACK_INIT_ADDRESS

  ; Initialize the standard Sega mapper.
  ld de,$fffc
  ld hl,_MapperInitData
  ld bc,$0004
  ldir

  call ClearRam ; Except the top (stack, slot/bank registers, etc.)
  call ClearVRam
  call InitializeVDPRegisters
  jp setup_main

  _MapperInitData:
    .db $00,$00,$01,$02
.ends

.ifdef INCLUDE_VDP_INTERRUPT_HANDLER
  .org $0038
  ; ---------------------------------------------------------------------------
  .section "!VDP interrupt" force
  ; ---------------------------------------------------------------------------
    push af
      in a,CONTROL_PORT
      ld (VDPStatus),a
    pop af
    ei
    reti
  .ends
.endif

.ifdef INCLUDE_PAUSE_BUTTON_HANDLER
  .org $0066
  ; ---------------------------------------------------------------------------
  .section "!Pause interrupt" force
  ; ---------------------------------------------------------------------------
    push af
      ld a,(PauseFlag)
      cpl
      ld (PauseFlag),a
    pop af
    retn
  .ends
.endif


; =============================================================================
; H E L P E R  F U N C T I O N S                        (sorted alphabetically)
; =============================================================================

; -----------------------------------------------------------------------------
.section "Await frame interrupt" free
; -----------------------------------------------------------------------------
  ; Await frame interrupt.
  ; Repeatedly test bit 7 of VDPStatus until it is set (by the VDP interrupt
  ; handler). Then reset this bit and return.
  ; Entry: None
  ; Exit: Bit 7 of variable VDPStatus is cleared.
  ; Uses: VDPStatus (1 byte)
  AwaitFrameInterrupt:
    push af
      -:
        ld a,(VDPStatus)
        bit 7,a
      jp z,-
      res 7,a
      ld (VDPStatus),a
    pop af
  ret
.ends


; -----------------------------------------------------------------------------
.section "ClearRam" free
; -----------------------------------------------------------------------------
  ; Overwrite ram with zeroes from RAM_START to STACK_INIT_ADDRESS - 16
  ; Uses AF, BC, DE, HL
  ClearRam:
    ld hl,RAM_START
    ld bc,STACK_INIT_ADDRESS-16-RAM_START
    ld a,0
    call _FillMemory
  ret

  _FillMemory:
    ld (hl),a
    ld d,h
    ld e,l
    inc de
    dec bc
    ld a,b
    or c
    ret z
    ldir
  ret
.ends

; -----------------------------------------------------------------------------
.section "ClearVRam" free
; -----------------------------------------------------------------------------
  ; Write 00 to all vram positions. Assumes disabled display.
  ; Uses AF, BC
  ClearVRam:
    xor a
    out (CONTROL_PORT),a
    or VRAM_WRITE_COMMAND
    out (CONTROL_PORT),a
    ld bc,$4000 ; 16K
    -:
      xor a
      out (DATA_PORT),a
      dec bc
      ld a,b
      or c
    jp nz,-
  ret
.ends

; -----------------------------------------------------------------------------
.section "GetInputPorts" free
; -----------------------------------------------------------------------------
  ; Set InputPorts (word) to mirror current state of ports $dc and $dd.
  ; Uses: AF
  GetInputPorts:
    in a,(INPUT_PORT_1)
    ld (InputPorts),a
    in a,(INPUT_PORT_2)
    ld (InputPorts+1),a
  ret
.ends

; -----------------------------------------------------------------------------
.section "InitializeVDPRegisters" free
; -----------------------------------------------------------------------------
; Initialize the 11 VDP registers with the preset data block.
; Uses: AF, B, HL
  _VDPRegisterInitData:
    .db $06
    .db DISABLE_DISPLAY_ENABLE_FRAME_INTERRUPTS_NORMAL_SPRITES
    .db $ff,$ff,$ff,$ff,$ff,$00,$00,$00,$ff

  InitializeVDPRegisters:
    ld hl,_VDPRegisterInitData
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
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer1Button1Pressed" free
; -----------------------------------------------------------------------------
  IsPlayer1Button1Pressed:
    ld a,(InputPorts)
    and %00010000
    ret nz            ; Return with carry flag reset
    scf
  ret                 ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer1Button2Pressed" free
; -----------------------------------------------------------------------------
  IsPlayer1Button2Pressed:
    ld a,(InputPorts)
    and %00100000
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer1DownPressed" free
; -----------------------------------------------------------------------------
  IsPlayer1DownPressed:
    ld a,(InputPorts)
    and %00000010
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer1LeftPressed" free
; -----------------------------------------------------------------------------
  IsPlayer1LeftPressed:
    ld a,(InputPorts)
    and %00000100
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer1RightPressed" free
; -----------------------------------------------------------------------------
  IsPlayer1RightPressed:
    ld a,(InputPorts)
    and %00001000
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer1UpPressed" free
; -----------------------------------------------------------------------------
  IsPlayer1UpPressed:
    ld a,(InputPorts)
    and %00000001
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer2Button1Pressed" free
; -----------------------------------------------------------------------------
  IsPlayer2Button1Pressed:
    ld a,(InputPorts+1)
    and %00000100
    ret nz            ; Return with carry flag reset
    scf
  ret                 ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer2Button2Pressed" free
; -----------------------------------------------------------------------------
  IsPlayer2Button2Pressed:
    ld a,(InputPorts+1)
    and %00001000
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer2DownPressed" free
; -----------------------------------------------------------------------------
  IsPlayer2DownPressed:
    ld a,(InputPorts)
    and %10000000
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer2LeftPressed" free
; -----------------------------------------------------------------------------
  IsPlayer2LeftPressed:
    ld a,(InputPorts+1)
    and %00000001
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer2RightPressed" free
; -----------------------------------------------------------------------------
  IsPlayer2RightPressed:
    ld a,(InputPorts+1)
    and %00000010
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsPlayer2UpPressed" free
; -----------------------------------------------------------------------------
  IsPlayer2UpPressed:
    ld a,(InputPorts)
    and %01000000
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "IsResetPressed" free
; -----------------------------------------------------------------------------
  IsResetPressed:
    ld a,(InputPorts+1)
    and %00010000
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.
.ends

; -----------------------------------------------------------------------------
.section "LoadCRam" free
; -----------------------------------------------------------------------------
  ; Load a number of colors into color ram (SMS - not GG!).
  ; Entry: A = Palette index (0-31)
  ;        B = Number of colors to load
  ;        HL = Base address of source data (color bytes, SMS)
  ; Uses: AF, BC, HL
  ; Assumes blanked display and interrupts off.
  LoadCRam:
    out (CONTROL_PORT),a
    ld a,CRAM_WRITE_COMMAND
    out (CONTROL_PORT),a
    -:
      ld a,(hl)
      out (DATA_PORT),a
      inc hl
    djnz -
  ret
.ends

; -----------------------------------------------------------------------------
.section "LoadVRam" free
; -----------------------------------------------------------------------------
  ; Load a number of bytes from a source address into vram.
  ; Entry: BC = Number of bytes to load
  ;        DE = Destination address in vram
  ;        HL = Source address
  ; Exit:  DE = Next free byte in vram.
  ; Uses: AF, BC, DE, HL,
  LoadVRam:
    ld a,e
    out (CONTROL_PORT),a
    ld a,d
    or VRAM_WRITE_COMMAND
    out (CONTROL_PORT),a
    -:
      ld a,(hl)
      out (DATA_PORT),a
      inc hl
      dec bc
      ld a,c
      or b
    jp nz,-
  ret
.ends

; -----------------------------------------------------------------------------
.section "ReadVRam" free
; -----------------------------------------------------------------------------
  ; Read a number of bytes from vram into a buffer.
  ; Entry: BC = Number of bytes to read
  ;        DE = Destination address in ram (buffer)
  ;        HL = Source address in vram
  ; Uses: AF, BC, DE, HL,
  ReadVRam:
    ld a,l
    out (CONTROL_PORT),a
    ld a,h
    or VRAM_READ_COMMAND
    out (CONTROL_PORT),a
    -:
      in a,(DATA_PORT)
      ld (de),a
      inc de
      dec bc
      ld a,c
      or b
    jp nz,-
  ret
.ends

; -----------------------------------------------------------------------------
.section "Set VDP Register" free
; -----------------------------------------------------------------------------
  ; Write to target register.
  ; Entry: A = byte to be loaded into vdp register.
  ;        B = target register 0-10.
  ; Uses: AF, B
  SetRegister:
    out (CONTROL_PORT),a
    ld a,REGISTER_WRITE_COMMAND
    or b
    out (CONTROL_PORT),a
  ret
.ends
