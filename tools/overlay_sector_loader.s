; DSK-only v0.5 sector overlay bootstrap.
; Loaded and run as TETRIS.BIN. It reads the resident game payload from fixed
; data-format sectors into PAYLOAD_LOAD, then jumps to PAYLOAD_RUN.

.area _DATA

game_dest:
   .dw #0x1000
game_track:
   .db #20
game_sector_index:
   .db #0
game_sectors_left:
   .db #51

current_dest:
   .dw #0x0000
current_track:
   .db #0
current_sector_index:
   .db #0
current_sectors_left:
   .db #0

select_format_far:
   .dw #0x0000
   .db #0x00
read_sector_far:
   .dw #0x0000
   .db #0x00

cmd_select_format:
   .db #0x83
cmd_read_sector:
   .db #0x84

sector_table:
   .db #0xC1,#0xC6,#0xC2,#0xC7,#0xC3,#0xC8,#0xC4,#0xC9,#0xC5

msg_start:
   .asciz "Sit down tightly while the game loads.."
msg_find_error:
   .asciz " RSX"
msg_sector_error:
   .asciz " SEC"

.area _CODE

TXT_OUTPUT      = #0xBB5A
KL_INIT_BACK    = #0xBCCE
KL_FIND_COMMAND = #0xBCD4

ROM_AMSDOS      = #0x07
LOWEST_USABLE   = #0x1000
HIGHEST_USABLE  = #0x7FFF
PAYLOAD_RUN     = #0x2B22

_loader_start::
   di
   ld sp,#0xBFF0
   ld hl,#msg_start
   call print_string

   ld c,#ROM_AMSDOS
   ld de,#LOWEST_USABLE
   ld hl,#HIGHEST_USABLE
   call KL_INIT_BACK

   ld hl,#cmd_select_format
   call KL_FIND_COMMAND
   jp nc,find_error
   ld (select_format_far),hl
   ld a,c
   ld (select_format_far+2),a

   ld hl,#cmd_read_sector
   call KL_FIND_COMMAND
   jp nc,find_error
   ld (read_sector_far),hl
   ld a,c
   ld (read_sector_far+2),a

   ld a,#0xC1
   ld e,#0x00
   .db #0xDF
   .dw select_format_far

   ld hl,#game_dest
   call load_segment
   jp PAYLOAD_RUN

load_segment:
   ld e,(hl)
   inc hl
   ld d,(hl)
   inc hl
   push hl
   ex de,hl
   ld (current_dest),hl
   pop hl
   ld a,(hl)
   inc hl
   ld (current_track),a
   ld a,(hl)
   inc hl
   ld (current_sector_index),a
   ld a,(hl)
   ld (current_sectors_left),a

load_loop:
   ld a,(current_sectors_left)
   or a
   ret z

   ld a,(current_sector_index)
   ld e,a
   ld d,#0
   ld hl,#sector_table
   add hl,de
   ld c,(hl)

   ld hl,(current_dest)
   ld e,#0x00
   ld a,(current_track)
   ld d,a
   .db #0xDF
   .dw read_sector_far
   jp nc,sector_error

   ld hl,(current_dest)
   ld de,#0x0200
   add hl,de
   ld (current_dest),hl

   ld a,(current_sector_index)
   inc a
   cp #9
   jr c,store_sector_index
   xor a
   ld (current_sector_index),a
   ld a,(current_track)
   inc a
   ld (current_track),a
   jr sector_advanced

store_sector_index:
   ld (current_sector_index),a

sector_advanced:
   ld a,(current_sectors_left)
   dec a
   ld (current_sectors_left),a
   jr load_loop

find_error:
   ld hl,#msg_find_error
   call print_string
   jr halt_forever

sector_error:
   ld hl,#msg_sector_error
   call print_string

halt_forever:
   jr halt_forever

print_string:
   ld a,(hl)
   or a
   ret z
   call TXT_OUTPUT
   inc hl
   jr print_string
