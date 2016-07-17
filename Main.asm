.include "Base.inc"
.include "Spritelib.inc"
.include "Invaderlib.inc"
;
.equ ALIEN_ARMY_FIRST_ROW 5
.equ SHIELDS_HSCROLL_INIT_VALUE 0
.equ ROBOTS_HSCROLL_INIT_VALUE 0
.equ LAST_VISIBLE_LINE 191
.equ VSCROLL_INIT_VALUE 223
.equ VERTICAL_SCROLL_STEP 8
.equ VERTICAL_SCROLL_LIMIT 191
.equ TIMER_INIT_VALUE 120
.equ RASTER_INIT_VALUE 7
.equ BASE_WIDTH 5
.equ BASE_HEIGHT 3
.equ ONE_TILEMAP_ROW 32*2
;
.equ NUMBER_OF_PLAYER_BASES 3
.equ CENTER_BASE_FIRST_TILE $3c5c
.equ LEFT_BASE_FIRST_TILE $3c4a
.equ RIGHT_BASE_FIRST_TILE $3c6e
;
.equ ARMY_DIRECTION_RIGHT 00
.equ ARMY_DIRECTION_LEFT $ff
.equ ARMY_OFFSET_LIMIT 16
.equ ARMY_OFFSET_INIT_VALUE ARMY_OFFSET_LIMIT/2
.equ ARMY_MOVE_INTERVAL 40
.equ ARMY_SPEED 1
;
.equ SKEW_ON 00
.equ SKEW_OFF $ff
.equ ARMY_SKEW_VALUE 6
;
.equ ENABLED $ff
.equ DISABLED 0
;
.bank 0 slot 0
.org $0038
; ---------------------------------------------------------------------------
.section "!VDP interrupt" force
; ---------------------------------------------------------------------------
  push af
  exx
    in a,CONTROL_PORT
    ld (VDPStatus),a
    bit 7,a
    jp nz,+
      call handle_raster_interrupt
    +:
  exx
  pop af
  ei
  reti
.ends
;
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
.ramsection "Main variables" slot 3
  robots_zone_start db                ; These two zone variables MUST be in
  shields_zone_start db               ; this order (handle_raster_interrupt).
  ;
  army_offset db
  army_move_timer db
  army_direction db
  army_skew_mode db
  ;
  shields_horizontal_scroll_value db
  robots_horizontal_scroll_value db
  vertical_scroll_status db
  vertical_scroll_value db
  base_buffer dsb BASE_WIDTH*((BASE_HEIGHT+1)*2)  ; * 2 = name table words.
                                                  ; +1 to add empty btm. row.
  left_base_address dw                 ; These base address variables MUST be
  center_base_address dw               ; in this order (used during vertical
  right_base_address dw                ; scroll).
.ends
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "main" free
; -----------------------------------------------------------------------------
  setup_main:
    ld a,ARMY_MOVE_INTERVAL
    ld (army_move_timer),a
    ld a,ARMY_DIRECTION_RIGHT
    ld (army_direction),a
    ld a,ARMY_OFFSET_INIT_VALUE
    ld (army_offset),a
    ld a,SKEW_OFF
    ld (army_skew_mode),a
    ;
    ld a,(RASTER_INIT_VALUE+1)*(ALIEN_ARMY_FIRST_ROW+((VSCROLL_INIT_VALUE-LAST_VISIBLE_LINE)/8))
    ld (robots_zone_start),a
    add a,(RASTER_INIT_VALUE+1)*2
    ld (shields_zone_start),a
    ;
    ld a,ROBOTS_HSCROLL_INIT_VALUE
    ld (robots_horizontal_scroll_value),a
    ld a,SHIELDS_HSCROLL_INIT_VALUE
    ld (shields_horizontal_scroll_value),a
    ;
    ld a,VSCROLL_INIT_VALUE
    ld (vertical_scroll_value),a
    ;
    ld a,ENABLED
    ld (vertical_scroll_status),a
    ;
    ld hl,CENTER_BASE_FIRST_TILE
    ld (center_base_address),hl
    ld hl,LEFT_BASE_FIRST_TILE
    ld (left_base_address),hl
    ld hl,RIGHT_BASE_FIRST_TILE
    ld (right_base_address),hl
    ;
    LOAD_IMAGE MockupAssets,MockupAssetsEnd
    ; Load player base tiles from vram tilemap to buffer - then blank it.
    ld a,BASE_WIDTH
    ld b,BASE_HEIGHT+1
    ld hl,CENTER_BASE_FIRST_TILE
    ld de,base_buffer
    call copy_tilemap_rect_to_buffer
    call blank_tilemap_rect
    ;
    ; Turn on screen, etc.
    ld hl,register_data
    call load_vdp_registers
    ; Skip a frame to make sure that we start main at vblank.
    ei
    call AwaitFrameInterrupt
  jp main
  ;
  ; ---------------------------------------------------------------------------
  main:
    call AwaitFrameInterrupt
    ; NTSC vblank is lines 194-262 = 68 lines in total.
    ld a,(vertical_scroll_value)
    ld b,VERTICAL_SCROLL_REGISTER
    call SetRegister

    ; Write the bases.
    ld a,BASE_WIDTH
    ld b,BASE_HEIGHT+1                ; +1 for the self-erasing trick.
    ld hl,base_buffer
    ld de,(left_base_address)
    call copy_buffer_to_tilemap_rect  ; 11 lines.
    ld de,(center_base_address)
    call copy_buffer_to_tilemap_rect  ; 11 lines.
    ld de,(right_base_address)
    call copy_buffer_to_tilemap_rect  ; 11 lines.
    ;
    call LoadSAT                      ; 14 lines.
    ;
    ; Non-vblank stuff below this line...
    ;
    ; -------------------------------------------------------------------------
    ; M O V E  A L I E N  A R M Y
    ; Move army horizontally and vertically, including skewing robots/shields.
    ; ------------------------------------------------------------------------
    ld a,(army_move_timer)
    or a
    jp nz,decrement_army_move_timer
      ; Reset timer.
      ld a,ARMY_MOVE_INTERVAL
      ld (army_move_timer),a
      ; Toggle skew.
      ld a,(army_skew_mode)
      or a
      cpl
      ld (army_skew_mode),a
      ;
      ld a,(army_offset)
      cp (-ARMY_OFFSET_LIMIT)
      jp nz,+
        ; Army is at the left border. Change direction and move down one row.
        ld a,ARMY_DIRECTION_RIGHT
        ld (army_direction),a
        ld a,(vertical_scroll_status)
        cp ENABLED
        call z,do_vertical_scroll
        jp ++
      +:
      cp ARMY_OFFSET_LIMIT
      jp nz,++
        ; Army is at the right border. Change direction and move down one row.
        ld a,ARMY_DIRECTION_LEFT
        ld (army_direction),a
        ld a,(vertical_scroll_status)
        cp ENABLED
        call z,do_vertical_scroll ; Move army down and bases up!
      ++:
      ;
      ; Move army one step in the current direction.
      ld a,(army_direction)
      cp ARMY_DIRECTION_RIGHT
      ld a,ARMY_SPEED
      jp z,+
        neg
      +:
      ld b,a
      ld a,(army_offset)
      add a,b
      ld (army_offset),a
      jp finish_army_movement
      ;
      do_vertical_scroll:
        ; Only proceed if vertical scrolling is enabled. When the alien army
        ; reaches VERTICAL_SCROLL_LIMIT vertical scrolling is disabled.
        ld a,(vertical_scroll_value)
        sub VERTICAL_SCROLL_STEP
        cp VERTICAL_SCROLL_LIMIT
        jp nz,+
          ld a,DISABLED
          ld (vertical_scroll_status),a
          ret
        +:
        ; Okay, vertical scrolling is enabled. Proceed with updating vertical
        ; scroll value (for the army) and the player base addresses.
        ld (vertical_scroll_value),a
        ; When background (army) scrolls down one row, we have to draw the
        ; player bases up one row (to make them stay put).
        ld b,NUMBER_OF_PLAYER_BASES
        ld hl,left_base_address       ; Point to first base address variable.
        -:
          call subtract_one_row       ; Update the base address.
          inc hl                      ; Forward pointer to next base address
          inc hl                      ; variable.
        djnz -
        ; Adjust the horizontal scroll zones to reflect current army position.
        ld b,VERTICAL_SCROLL_STEP
        ld a,(robots_zone_start)
        add a,b
        ld (robots_zone_start),a
        ld a,(shields_zone_start)
        add a,b
        ld (shields_zone_start),a
      ret
      ;
    decrement_army_move_timer:
      ; We come here if the army_move_timer is != 0.
      dec a
      ld (army_move_timer),a
    finish_army_movement:
    ; Regardless of whether the army has moved or not, update the variables
    ; controlling the hscroll zones (robots/cannons + shields).
    ld a,(army_skew_mode)
    or a
    jp nz,+
      ; Apply skew to the army_offset.
      ld a,ARMY_SKEW_VALUE
      ld b,a
      ld a,(army_offset)
      add a,b
      ld (robots_horizontal_scroll_value),a
      sub b
      sub b
      ld (shields_horizontal_scroll_value),a
      jp ++
    +:
      ; Do NOT apply skew to the army_offset.
      ld a,(army_offset)
      ld (robots_horizontal_scroll_value),a
      ld (shields_horizontal_scroll_value),a
    ++:
    ;
    ;
  jp main
  ; ---------------------------------------------------------------------------
  handle_raster_interrupt:
    ; The screen is divided into three independent hscroll zones:
    ; 1 - Robots and cannons.
    ; 2 - Shields.
    ; 3 - Bases and player.
    ; Determine inside which zone the current line is, and apply hscroll
    ; to the vdp register.
    ; NOTE: Fills almost entire hblank by now. Speed optimized.
    ld hl,robots_zone_start
    in a,(V_COUNTER_PORT)
    ld b,HORIZONTAL_SCROLL_REGISTER
    cp (hl)
    jp nc,+
      ; Robots and cannons part.
      ld a,(robots_horizontal_scroll_value)
      out (CONTROL_PORT),a
      ld a,REGISTER_WRITE_COMMAND
      or b
      out (CONTROL_PORT),a
      ret
    +:
    inc hl
    cp (hl)
    jp nc,+
      ; Shields part.
      ld a,(shields_horizontal_scroll_value)
      out (CONTROL_PORT),a
      ld a,REGISTER_WRITE_COMMAND
      or b
      out (CONTROL_PORT),a
      ret
    +:
    ; Below shields.
    xor a
    out (CONTROL_PORT),a
    ld a,REGISTER_WRITE_COMMAND
    or b
    out (CONTROL_PORT),a
  ret
.ends
;
.bank 1 slot 1
; -----------------------------------------------------------------------------
.section "Mockup Assets" free
; -----------------------------------------------------------------------------
  MockupAssets:
    .include "MockupAssets.inc"
  MockupAssetsEnd:
  ;
  register_data:
    .db FULL_SCROLL_BLANK_LEFT_COLUMN_KEEP_SPRITES_ENABLE_RASTER_INT
    .db ENABLE_DISPLAY_ENABLE_FRAME_INTERRUPTS_NORMAL_SPRITES
    .db $ff,$ff,$ff,$ff,$ff,$00,$00,VSCROLL_INIT_VALUE,RASTER_INIT_VALUE
.ends
;
.bank 2 slot 2
