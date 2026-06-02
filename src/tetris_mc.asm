org &4000

KM_WAIT_CHAR equ &BB06
KM_READ_CHAR equ &BB09
KM_GET_JOY equ &BB24
KM_SET_DELAY equ &BB3F
TXT_OUTPUT equ &BB5A
SCR_SET_MODE equ &BC0E
SCR_SET_INK equ &BC32
SCR_SET_BORDER equ &BC38
SOUND_RESET equ &BCA7
SOUND_QUEUE equ &BCAA
MC_WAIT_FLYBACK equ &BD19

start:
    call setup_palette
main_menu:
    call menu_screen
    call flush_keys
menu_wait:
    call KM_WAIT_CHAR
    call to_upper
    cp '1'
    jr nz, menu_not_keyboard
    xor a
    ld (control_mode), a
    call start_game
    jr main_menu
menu_not_keyboard:
    cp '2'
    jr nz, menu_not_joy
    ld a, 1
    ld (control_mode), a
    call start_game
    jr main_menu
menu_not_joy:
    cp '3'
    jr nz, menu_wait
    call redefine_keys
    jr main_menu

setup_palette:
    ld b, 0
    ld c, 0
    call SCR_SET_BORDER
    ld a, 0
    ld b, 0
    ld c, 0
    call SCR_SET_INK
    ld a, 1
    ld b, 20
    ld c, 20
    call SCR_SET_INK
    ld a, 2
    ld b, 24
    ld c, 24
    call SCR_SET_INK
    ld a, 3
    ld b, 8
    ld c, 8
    call SCR_SET_INK
    ld a, 4
    ld b, 18
    ld c, 18
    call SCR_SET_INK
    ld a, 5
    ld b, 6
    ld c, 6
    call SCR_SET_INK
    ld a, 6
    ld b, 2
    ld c, 2
    call SCR_SET_INK
    ld a, 7
    ld b, 15
    ld c, 15
    call SCR_SET_INK
    ld a, 8
    ld b, 13
    ld c, 13
    call SCR_SET_INK
    ld a, 9
    ld b, 26
    ld c, 26
    call SCR_SET_INK
    ret

menu_screen:
    ld a, 0
    call SCR_SET_MODE
    call clear_screen
    ld hl, menu_text
    call print_string
    ret

redefine_keys:
    ld a, 0
    call SCR_SET_MODE
    call clear_screen
    ld hl, redefine_text
    call print_string
    ld hl, left_prompt
    call print_string
    call KM_WAIT_CHAR
    call to_upper
    ld (key_left), a
    ld hl, right_prompt
    call print_string
    call KM_WAIT_CHAR
    call to_upper
    ld (key_right), a
    ld hl, rotate_prompt
    call print_string
    call KM_WAIT_CHAR
    call to_upper
    ld (key_rotate), a
    ld hl, down_prompt
    call print_string
    call KM_WAIT_CHAR
    call to_upper
    ld (key_down), a
    ld hl, drop_prompt
    call print_string
    call KM_WAIT_CHAR
    call to_upper
    ld (key_drop), a
    ret

start_game:
    ld a, 0
    call SCR_SET_MODE
    call clear_screen
    call SOUND_RESET
    ld hl, &0601
    call KM_SET_DELAY
    call music_init
    call clear_board
    call draw_frame
    call random_piece
    ld (next_piece), a
    call spawn_piece
    or a
    jp nz, game_over
    ld a, (active_piece)
    call draw_piece_colour
game_loop:
    call MC_WAIT_FLYBACK
    call music_update
    call read_controls
    xor a
    call draw_piece_colour
    call apply_actions
    ld a, (lock_flag)
    or a
    jr z, no_lock_this_frame
    call lock_piece
    call clear_lines
    call draw_board
    call spawn_piece
    or a
    jp nz, game_over
no_lock_this_frame:
    ld a, (active_piece)
    call draw_piece_colour
    jr game_loop

game_over:
    call SOUND_RESET
    ld a, 0
    call SCR_SET_MODE
    call clear_screen
    ld hl, game_over_text
    call print_string
    call KM_WAIT_CHAR
    ret

apply_actions:
    xor a
    ld (lock_flag), a
    ld a, (action_flags)
    and 1
    jr z, no_left_action
    call try_left
no_left_action:
    ld a, (action_flags)
    and 2
    jr z, no_right_action
    call try_right
no_right_action:
    ld a, (action_flags)
    and 8
    jr z, no_rotate_action
    call try_rotate
no_rotate_action:
    ld a, (action_flags)
    and 16
    jr z, no_drop_action
    call hard_drop
    ret
no_drop_action:
    ld a, (action_flags)
    and 4
    jr z, no_soft_down
    call try_down
    ret
no_soft_down:
    ld a, (gravity_count)
    inc a
    ld (gravity_count), a
    ld b, a
    ld a, (gravity_delay)
    cp b
    ret nz
    xor a
    ld (gravity_count), a
    call try_down
    ret

try_left:
    ld a, (active_x)
    dec a
    ld (cand_x), a
    ld a, (active_y)
    ld (cand_y), a
    ld a, (active_rot)
    ld (cand_rot), a
    call check_collision
    or a
    ret nz
    ld a, (cand_x)
    ld (active_x), a
    ret

try_right:
    ld a, (active_x)
    inc a
    ld (cand_x), a
    ld a, (active_y)
    ld (cand_y), a
    ld a, (active_rot)
    ld (cand_rot), a
    call check_collision
    or a
    ret nz
    ld a, (cand_x)
    ld (active_x), a
    ret

try_rotate:
    ld a, (active_x)
    ld (cand_x), a
    ld a, (active_y)
    ld (cand_y), a
    ld a, (active_rot)
    inc a
    and 3
    ld (cand_rot), a
    call check_collision
    or a
    ret nz
    ld a, (cand_rot)
    ld (active_rot), a
    ret

try_down:
    ld a, (active_x)
    ld (cand_x), a
    ld a, (active_y)
    inc a
    ld (cand_y), a
    ld a, (active_rot)
    ld (cand_rot), a
    call check_collision
    or a
    jr nz, down_locks
    ld a, (cand_y)
    ld (active_y), a
    ret
down_locks:
    ld a, 1
    ld (lock_flag), a
    ret

hard_drop:
hard_drop_loop:
    ld a, (active_x)
    ld (cand_x), a
    ld a, (active_y)
    inc a
    ld (cand_y), a
    ld a, (active_rot)
    ld (cand_rot), a
    call check_collision
    or a
    jr nz, hard_drop_done
    ld a, (cand_y)
    ld (active_y), a
    jr hard_drop_loop
hard_drop_done:
    ld a, 1
    ld (lock_flag), a
    ret

spawn_piece:
    ld a, (next_piece)
    ld (active_piece), a
    call random_piece
    ld (next_piece), a
    ld a, 3
    ld (active_x), a
    xor a
    ld (active_y), a
    ld (active_rot), a
    ld (gravity_count), a
    ld a, (active_x)
    ld (cand_x), a
    ld a, (active_y)
    ld (cand_y), a
    ld a, (active_rot)
    ld (cand_rot), a
    call check_collision
    ret

random_piece:
    ld a, (rng_seed)
    add a, 37
    ld (rng_seed), a
    and 7
    jr nz, random_non_zero
    inc a
random_non_zero:
    ret

check_collision:
    call get_shape_ptr_cand
    ld b, 4
collision_loop:
    ld a, (cand_x)
    add a, (hl)
    cp 10
    jr nc, collision_yes
    ld (tmp_x), a
    inc hl
    ld a, (cand_y)
    add a, (hl)
    cp 20
    jr nc, collision_yes
    ld (tmp_y), a
    inc hl
    push bc
    push hl
    call board_addr_tmp
    ld a, (hl)
    pop hl
    pop bc
    or a
    jr nz, collision_yes
    djnz collision_loop
    xor a
    ret
collision_yes:
    ld a, 1
    ret

lock_piece:
    call get_shape_ptr_active
    ld b, 4
lock_loop:
    ld a, (active_x)
    add a, (hl)
    ld (tmp_x), a
    inc hl
    ld a, (active_y)
    add a, (hl)
    ld (tmp_y), a
    inc hl
    push bc
    push hl
    call board_addr_tmp
    ld a, (active_piece)
    ld (hl), a
    pop hl
    pop bc
    djnz lock_loop
    ret

clear_lines:
    ld a, 19
    ld (scan_y), a
clear_line_loop:
    call row_full
    or a
    jr z, row_not_full
    call collapse_row
    call line_was_cleared
    jr clear_line_loop
row_not_full:
    ld a, (scan_y)
    or a
    ret z
    dec a
    ld (scan_y), a
    jr clear_line_loop

row_full:
    xor a
    ld (tmp_x), a
row_full_loop:
    ld a, (scan_y)
    ld (tmp_y), a
    call board_addr_tmp
    ld a, (hl)
    or a
    jr z, row_is_not_full
    ld a, (tmp_x)
    inc a
    ld (tmp_x), a
    cp 10
    jr nz, row_full_loop
    ld a, 1
    ret
row_is_not_full:
    xor a
    ret

collapse_row:
    ld a, (scan_y)
    or a
    jr z, clear_top_row
    ld (copy_y), a
collapse_loop:
    ld a, (copy_y)
    ld (tmp_y), a
    xor a
    ld (tmp_x), a
    call board_addr_tmp
    ld d, h
    ld e, l
    ld bc, 10
    or a
    sbc hl, bc
    ld bc, 10
    ldir
    ld a, (copy_y)
    dec a
    ld (copy_y), a
    or a
    jr nz, collapse_loop
clear_top_row:
    ld hl, board
    ld b, 10
clear_top_loop:
    ld (hl), 0
    inc hl
    djnz clear_top_loop
    ret

line_was_cleared:
    ld a, (line_mod)
    inc a
    cp 10
    jr nz, store_line_mod
    xor a
    ld (line_mod), a
    ld a, (gravity_delay)
    cp 5
    ret z
    dec a
    ld (gravity_delay), a
    ret
store_line_mod:
    ld (line_mod), a
    ret

read_controls:
    xor a
    ld (action_flags), a
    ld a, (control_mode)
    or a
    jr nz, read_joy_controls
    call KM_READ_CHAR
    ret nc
    call to_upper
    ld b, a
    ld a, (key_left)
    cp b
    jr nz, key_not_left
    ld a, 1
    ld (action_flags), a
    ret
key_not_left:
    ld a, (key_right)
    cp b
    jr nz, key_not_right
    ld a, 2
    ld (action_flags), a
    ret
key_not_right:
    ld a, (key_down)
    cp b
    jr nz, key_not_down
    ld a, 4
    ld (action_flags), a
    ret
key_not_down:
    ld a, (key_rotate)
    cp b
    jr nz, key_not_rotate
    ld a, 8
    ld (action_flags), a
    ret
key_not_rotate:
    ld a, (key_drop)
    cp b
    ret nz
    ld a, 16
    ld (action_flags), a
    ret

read_joy_controls:
    call KM_GET_JOY
    ld b, a
    bit 2, b
    jr z, joy_no_left
    ld a, (action_flags)
    or 1
    ld (action_flags), a
joy_no_left:
    bit 3, b
    jr z, joy_no_right
    ld a, (action_flags)
    or 2
    ld (action_flags), a
joy_no_right:
    bit 1, b
    jr z, joy_no_down
    ld a, (action_flags)
    or 4
    ld (action_flags), a
joy_no_down:
    bit 5, b
    jr z, joy_no_rotate
    ld a, (last_joy)
    and 32
    jr nz, joy_no_rotate
    ld a, (action_flags)
    or 8
    ld (action_flags), a
joy_no_rotate:
    ld a, b
    and 17
    jr z, joy_no_drop
    ld a, (last_joy)
    and 17
    jr nz, joy_no_drop
    ld a, (action_flags)
    or 16
    ld (action_flags), a
joy_no_drop:
    ld a, b
    ld (last_joy), a
    ret

draw_piece_colour:
    ld (draw_colour), a
    call get_shape_ptr_active
    ld b, 4
draw_piece_loop:
    ld a, (active_x)
    add a, (hl)
    ld (tmp_x), a
    inc hl
    ld a, (active_y)
    add a, (hl)
    ld (tmp_y), a
    inc hl
    push bc
    push hl
    ld a, (draw_colour)
    ld (cell_colour), a
    call draw_cell_tmp
    pop hl
    pop bc
    djnz draw_piece_loop
    ret

draw_board:
    xor a
    ld (tmp_y), a
draw_board_y:
    xor a
    ld (tmp_x), a
draw_board_x:
    call board_addr_tmp
    ld a, (hl)
    ld (cell_colour), a
    call draw_cell_tmp
    ld a, (tmp_x)
    inc a
    ld (tmp_x), a
    cp 10
    jr nz, draw_board_x
    ld a, (tmp_y)
    inc a
    ld (tmp_y), a
    cp 20
    jr nz, draw_board_y
    ret

draw_frame:
    ld a, 8
    ld (cell_colour), a
    ld a, 2
    ld (raw_y), a
frame_side_loop:
    ld a, 6
    ld (raw_x), a
    call draw_cell_raw
    ld a, 28
    ld (raw_x), a
    call draw_cell_raw
    ld a, (raw_y)
    inc a
    ld (raw_y), a
    cp 22
    jr nz, frame_side_loop
    ld a, 22
    ld (raw_y), a
    ld a, 6
    ld (raw_x), a
frame_bottom_loop:
    call draw_cell_raw
    ld a, (raw_x)
    add a, 2
    ld (raw_x), a
    cp 30
    jr nz, frame_bottom_loop
    ret

draw_cell_tmp:
    call screen_addr_tmp
    jr draw_cell_at_hl

draw_cell_raw:
    call screen_addr_raw
draw_cell_at_hl:
    ld a, (cell_colour)
    ld e, a
    ld d, 0
    push hl
    ld hl, pen_bytes
    add hl, de
    ld a, (hl)
    ld (draw_byte), a
    pop hl
    ld b, 8
draw_cell_line:
    ld a, (draw_byte)
    ld (hl), a
    inc hl
    ld (hl), a
    dec hl
    ld de, &0800
    add hl, de
    djnz draw_cell_line
    ret

screen_addr_tmp:
    ld a, (tmp_y)
    add a, 2
    ld (raw_y), a
    ld a, (tmp_x)
    add a, a
    add a, 8
    ld (raw_x), a
    call screen_addr_raw
    ret

screen_addr_raw:
    ld a, (raw_y)
    ld l, a
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld d, h
    ld e, l
    add hl, hl
    add hl, hl
    add hl, de
    ld a, (raw_x)
    ld e, a
    ld d, 0
    add hl, de
    ld de, &C000
    add hl, de
    ret

board_addr_tmp:
    ld a, (tmp_y)
    ld l, a
    ld h, 0
    add hl, hl
    ld d, h
    ld e, l
    add hl, hl
    add hl, hl
    add hl, de
    ld a, (tmp_x)
    ld e, a
    ld d, 0
    add hl, de
    ld de, board
    add hl, de
    ret

get_shape_ptr_active:
    ld a, (active_rot)
    ld (shape_rot_work), a
    jr get_shape_ptr

get_shape_ptr_cand:
    ld a, (cand_rot)
    ld (shape_rot_work), a
get_shape_ptr:
    ld a, (active_piece)
    dec a
    ld l, a
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld a, (shape_rot_work)
    add a, a
    add a, a
    add a, a
    ld e, a
    ld d, 0
    add hl, de
    ld de, shapes
    add hl, de
    ret

clear_board:
    ld hl, board
    ld de, board+1
    ld bc, 199
    ld (hl), 0
    ldir
    ld a, 18
    ld (gravity_delay), a
    xor a
    ld (line_mod), a
    ld (last_joy), a
    ret

clear_screen:
    ld hl, &C000
    ld de, &C001
    ld bc, &3FFF
    ld (hl), 0
    ldir
    ret

music_init:
    xor a
    ld (music_index), a
    ld (music_timer), a
    ret

music_update:
    ld a, (music_timer)
    or a
    jr z, music_new_note
    dec a
    ld (music_timer), a
    ret
music_new_note:
    ld a, (music_index)
    ld e, a
    ld d, 0
    ld l, a
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    or a
    sbc hl, de
    ld de, music_data
    add hl, de
    ld a, (hl)
    ld (sound_a+3), a
    inc hl
    ld a, (hl)
    ld (sound_a+4), a
    inc hl
    ld a, (hl)
    ld (sound_b+3), a
    inc hl
    ld a, (hl)
    ld (sound_b+4), a
    inc hl
    ld a, (hl)
    ld (sound_c+3), a
    inc hl
    ld a, (hl)
    ld (sound_c+4), a
    inc hl
    ld a, (hl)
    ld (music_timer), a
    add a, a
    ld (sound_a+7), a
    ld (sound_b+7), a
    ld (sound_c+7), a
    xor a
    ld (sound_a+8), a
    ld (sound_b+8), a
    ld (sound_c+8), a
    ld hl, sound_a
    call SOUND_QUEUE
    ld hl, sound_b
    call SOUND_QUEUE
    ld hl, sound_c
    call SOUND_QUEUE
    ld a, (music_index)
    inc a
    cp 37
    jr nz, music_store_index
    xor a
music_store_index:
    ld (music_index), a
    ret

print_string:
    ld a, (hl)
    or a
    ret z
    push hl
    call TXT_OUTPUT
    pop hl
    inc hl
    jr print_string

flush_keys:
    call KM_READ_CHAR
    jr c, flush_keys
    ret

to_upper:
    cp 'a'
    ret c
    cp 'z'+1
    ret nc
    sub 32
    ret

menu_text:
    db 13,10,10
    db "        TETRIS",13,10,10
    db "  1 KEYBOARD",13,10
    db "  2 JOYSTICK",13,10
    db "  3 REDEFINE KEYS",13,10,10
    db "  O/P MOVE",13,10
    db "  Q ROTATE",13,10
    db "  A DOWN",13,10
    db "  SPACE DROP",13,10,0

redefine_text:
    db 13,10,10,"  REDEFINE KEYS",13,10,10,0
left_prompt:
    db "  LEFT: ",0
right_prompt:
    db 13,10,"  RIGHT: ",0
rotate_prompt:
    db 13,10,"  ROTATE: ",0
down_prompt:
    db 13,10,"  DOWN: ",0
drop_prompt:
    db 13,10,"  DROP: ",0
game_over_text:
    db 13,10,10,10,"       GAME OVER",13,10,10
    db "     PRESS ANY KEY",13,10,0

pen_bytes:
    db &00,&C0,&0C,&CC,&30,&F0,&3C,&FC
    db &03,&C3,&0F,&CF,&33,&F3,&3F,&FF

shapes:
    db 0,1,1,1,2,1,3,1,2,0,2,1,2,2,2,3
    db 0,1,1,1,2,1,3,1,2,0,2,1,2,2,2,3
    db 1,0,2,0,1,1,2,1,1,0,2,0,1,1,2,1
    db 1,0,2,0,1,1,2,1,1,0,2,0,1,1,2,1
    db 1,0,0,1,1,1,2,1,1,0,1,1,2,1,1,2
    db 0,1,1,1,2,1,1,2,1,0,0,1,1,1,1,2
    db 1,0,2,0,0,1,1,1,1,0,1,1,2,1,2,2
    db 1,0,2,0,0,1,1,1,1,0,1,1,2,1,2,2
    db 0,0,1,0,1,1,2,1,2,0,1,1,2,1,1,2
    db 0,0,1,0,1,1,2,1,2,0,1,1,2,1,1,2
    db 0,0,0,1,1,1,2,1,1,0,2,0,1,1,1,2
    db 0,1,1,1,2,1,2,2,1,0,1,1,0,2,1,2
    db 2,0,0,1,1,1,2,1,1,0,1,1,1,2,2,2
    db 0,1,1,1,2,1,0,2,0,0,1,0,1,1,1,2

music_data:
    dw 190,568,380
    db 10
    dw 253,568,506
    db 5
    dw 239,568,478
    db 5
    dw 213,568,426
    db 10
    dw 239,568,478
    db 5
    dw 253,568,506
    db 5
    dw 284,568,568
    db 10
    dw 284,568,568
    db 5
    dw 239,568,478
    db 5
    dw 190,758,380
    db 10
    dw 213,758,426
    db 5
    dw 239,758,478
    db 5
    dw 253,758,506
    db 15
    dw 239,758,478
    db 5
    dw 213,758,426
    db 10
    dw 190,758,380
    db 10
    dw 239,758,478
    db 10
    dw 284,758,568
    db 10
    dw 284,758,568
    db 15
    dw 213,851,426
    db 10
    dw 179,851,358
    db 5
    dw 142,851,284
    db 10
    dw 159,851,318
    db 5
    dw 179,851,358
    db 5
    dw 190,851,380
    db 15
    dw 239,851,478
    db 5
    dw 190,758,380
    db 10
    dw 213,758,426
    db 5
    dw 239,758,478
    db 5
    dw 253,758,506
    db 10
    dw 253,758,506
    db 5
    dw 239,758,478
    db 5
    dw 213,758,426
    db 10
    dw 190,758,380
    db 10
    dw 239,758,478
    db 10
    dw 284,758,568
    db 10
    dw 284,758,568
    db 15

sound_a:
    db 1,0,0,0,0,0,12,0,0
sound_b:
    db 2,0,0,0,0,0,8,0,0
sound_c:
    db 4,0,0,0,0,0,5,0,0

control_mode:
    db 0
key_left:
    db 'O'
key_right:
    db 'P'
key_rotate:
    db 'Q'
key_down:
    db 'A'
key_drop:
    db ' '
active_piece:
    db 0
active_rot:
    db 0
active_x:
    db 0
active_y:
    db 0
next_piece:
    db 0
cand_x:
    db 0
cand_y:
    db 0
cand_rot:
    db 0
tmp_x:
    db 0
tmp_y:
    db 0
raw_x:
    db 0
raw_y:
    db 0
cell_colour:
    db 0
draw_colour:
    db 0
draw_byte:
    db 0
shape_rot_work:
    db 0
action_flags:
    db 0
lock_flag:
    db 0
gravity_count:
    db 0
gravity_delay:
    db 18
line_mod:
    db 0
scan_y:
    db 0
copy_y:
    db 0
last_joy:
    db 0
rng_seed:
    db 93
music_index:
    db 0
music_timer:
    db 0

board:
    defs 200,0
