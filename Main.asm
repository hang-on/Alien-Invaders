.include "Base.inc"
.include "Invaderlib.inc"
;
.equ ALIEN_ARMY_FIRST_ROW 10
.equ SHIELDS_HSCROLL_INIT_VALUE 0
.equ ROBOTS_HSCROLL_INIT_VALUE 0
.equ VSCROLL_INIT_VALUE 223
.equ VERTICAL_SCROLL_STEP 8
.equ VERTICAL_SCROLL_LIMIT 183
.equ TIMER_INIT_VALUE 120
.equ RASTER_INIT_VALUE 7
.equ BASE_WIDTH 5
.equ BASE_HEIGHT 3
.equ CENTER_BASE_FIRST_TILE $3c5c
.equ ONE_TILEMAP_ROW 32*2
.equ SKEW 6
.equ ENABLED 1
.equ DISABLED 0
.equ ARMY_DIRECTION_RIGHT 00
.equ ARMY_DIRECTION_LEFT $ff
.equ ARMY_OFFSET_LIMIT 16
.equ ARMY_OFFSET_INIT_VALUE ARMY_OFFSET_LIMIT/2
.equ ARMY_MOVE_INTERVAL 40
.equ ARMY_SPEED 1
.equ SKEW_ON 00
.equ SKEW_OFF $ff
.equ ARMY_SKEW_VALUE 8
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
  vertical_scroll_timer db
  base_buffer dsb BASE_WIDTH*((BASE_HEIGHT+1)*2)  ; * 2 = name table words.
                                                  ; +1 to add empty btm. row.
  center_base_address dw
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
    ;
    ld a,(RASTER_INIT_VALUE+1)*ALIEN_ARMY_FIRST_ROW
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
    ld a,TIMER_INIT_VALUE
    ld (vertical_scroll_timer),a
    ;
    ld a,DISABLED
    ld (vertical_scroll_status),a
    ;
    ld hl,CENTER_BASE_FIRST_TILE
    ld (center_base_address),hl
    ;
    LOAD_IMAGE MockupAssets,MockupAssetsEnd
    ; Load player base tiles from vram tilemap to buffer.
    ld a,BASE_WIDTH
    ld b,BASE_HEIGHT+1
    ld hl,CENTER_BASE_FIRST_TILE
    ld de,base_buffer
    call copy_tilemap_rect_to_buffer
    ; Blank the center base.
    ld hl,CENTER_BASE_FIRST_TILE
    ld a,BASE_WIDTH
    ld b,BASE_HEIGHT+1
    call blank_tilemap_rect
    ; Turn on screen, etc.
    ld hl,register_data
    call load_vdp_registers
    ; Skip an interrupt to make sure that we start main at vblank.
    ei
    call AwaitFrameInterrupt
  jp main
  ;
  main:
    call AwaitFrameInterrupt
    ;
    ld a,(vertical_scroll_value)
    ld b,VERTICAL_SCROLL_REGISTER
    call SetRegister
    ; Test: Write the center base
    ld a,BASE_WIDTH
    ld b,BASE_HEIGHT+1                ; +1 for the self-erasing trick.
    ld hl,base_buffer
    ld de,(center_base_address)
    call copy_buffer_to_tilemap_rect
    ;
    ; Non-vblank stuff below this line...
    ;
    ld a,(army_move_timer)
    or a
    jp nz,decrement_army_move_timer
      ; Time is up, move the alien army!
      ld a,ARMY_MOVE_INTERVAL
      ld (army_move_timer),a
      ;
      ; Check for army at left or right border and change direction.
      ld a,(army_offset)
      cp (-ARMY_OFFSET_LIMIT)
      jp nz,+
        ld a,ARMY_DIRECTION_RIGHT
        ld (army_direction),a
        call move_army_down
        jp ++
      +:
      cp ARMY_OFFSET_LIMIT
      jp nz,++
        ld a,ARMY_DIRECTION_LEFT
        ld (army_direction),a
        call move_army_down
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
      move_army_down:
        ld a,(vertical_scroll_value)
        sub VERTICAL_SCROLL_STEP
        cp VERTICAL_SCROLL_LIMIT
        jp nz,+
          ; Restart program.
          ld a,DISABLE_DISPLAY_DISABLE_FRAME_INTERRUPTS_NORMAL_SPRITES
          ld b,1
          call SetRegister
          jp 0
          ;
        +:
        ld (vertical_scroll_value),a
        ld hl,(center_base_address)
        ld de,ONE_TILEMAP_ROW
        sbc hl,de
        ld (center_base_address),hl
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
      dec a
      ld (army_move_timer),a
    finish_army_movement:
    ld a,(army_offset)
    ld (robots_horizontal_scroll_value),a
    ld (shields_horizontal_scroll_value),a
    ;
    ; Timed vertical scroll for testing.
    ld a,(vertical_scroll_status)
    cp DISABLED
    jp z,vertical_scroll_end
      ld a,(vertical_scroll_timer)
      or a
      jp nz,decrement_timer
        ; Time is up - handle scrolling.
        ld a,TIMER_INIT_VALUE
        ld (vertical_scroll_timer),a
        ld a,(vertical_scroll_value)
        sub VERTICAL_SCROLL_STEP
        cp VERTICAL_SCROLL_LIMIT
        jp nz,+
          ; Restart program.
          ld a,DISABLE_DISPLAY_DISABLE_FRAME_INTERRUPTS_NORMAL_SPRITES
          ld b,1
          call SetRegister
          jp 0
          ;
        +:
        ld (vertical_scroll_value),a
        ld hl,(center_base_address)
        ld de,ONE_TILEMAP_ROW
        sbc hl,de
        ld (center_base_address),hl
        ;
        jp vertical_scroll_end                           ;
      decrement_timer:
        ; Not time for scrolling yet - just decrement the timer.
        dec a
        ld (vertical_scroll_timer),a
    vertical_scroll_end:
    ;
  jp main
  ;
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
