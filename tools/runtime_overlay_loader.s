; Resident hidden-sector overlay loader for the DSK-only v0.5 build.
; This path uses the FDC directly, so runtime overlays can be loaded after
; CPCtelera has disabled firmware/AMSDOS.

SPLASH_TITLE_DEST      = #0x5000
SPLASH_TITLE_TRACK     = #30
SPLASH_TITLE_SECTORS   = #32
GAMEPLAY_MUSIC_DEST    = #0x9400
GAMEPLAY_MUSIC_TRACK   = #34
GAMEPLAY_MUSIC_SECTORS = #2
GAMEPLAY_SCREEN_DEST   = #0xC000
GAMEPLAY_SCREEN_TRACK  = #22
GAMEPLAY_SCREEN_SECTORS = #32
RUNTIME_FONT_DEST      = #0x5000
RUNTIME_FONT_TRACK     = #35
RUNTIME_FONT_SECTORS   = #2

HW_RED                 = #0x1C
HW_PURPLE              = #0x05
HW_WHITE               = #0x00
HW_BLACK               = #0x14

.area _DATA

splash_title_segment:
   .dw #SPLASH_TITLE_DEST
   .db #SPLASH_TITLE_TRACK
   .db #0
   .db #SPLASH_TITLE_SECTORS

gameplay_music_segment:
   .dw #GAMEPLAY_MUSIC_DEST
   .db #GAMEPLAY_MUSIC_TRACK
   .db #0
   .db #GAMEPLAY_MUSIC_SECTORS

gameplay_screen_segment:
   .dw #GAMEPLAY_SCREEN_DEST
   .db #GAMEPLAY_SCREEN_TRACK
   .db #0
   .db #GAMEPLAY_SCREEN_SECTORS

runtime_font_segment:
   .dw #RUNTIME_FONT_DEST
   .db #RUNTIME_FONT_TRACK
   .db #0
   .db #RUNTIME_FONT_SECTORS

current_dest:
   .dw #0x0000
current_track:
   .db #0
current_sector_index:
   .db #0
current_sectors_left:
   .db #0
seeked_track:
   .db #0xFF
current_sector_id:
   .db #0
interrupt_was_enabled:
   .db #0
result_data:
   .ds 7

sector_table:
   .db #0xC1,#0xC6,#0xC2,#0xC7,#0xC3,#0xC8,#0xC4,#0xC9,#0xC5

.area _CODE

.globl _overlay_load_initial_segments
.globl _overlay_load_gameplay_screen
.globl _overlay_load_runtime_font

_overlay_load_initial_segments::
   push ix
   push iy

   call init_fdc_loader
   jp nc,overlay_recal_error
   ld hl,#splash_title_segment
   call load_segment
   jp nc,overlay_sector_error
   ld hl,#gameplay_music_segment
   call load_segment
   jp nc,overlay_sector_error
   call fdc_stop

   pop iy
   pop ix
   ret

_overlay_load_gameplay_screen::
   push ix
   push iy

   call init_fdc_loader
   jp nc,overlay_recal_error
   ld hl,#gameplay_screen_segment
   call load_segment
   jp nc,overlay_sector_error
   call fdc_stop

   pop iy
   pop ix
   ret

_overlay_load_runtime_font::
   push ix
   push iy

   call init_fdc_loader
   jp nc,overlay_recal_error
   ld hl,#runtime_font_segment
   call load_segment
   jp nc,overlay_sector_error
   call fdc_stop
   ld hl,#RUNTIME_FONT_DEST
   call verify_runtime_font
   jp nc,overlay_signature_error

   pop iy
   pop ix
   ret

init_fdc_loader:
   call fdc_motor_on
   call fdc_drain_results
   call fdc_recalibrate
   ret nc
   xor a
   ld (seeked_track),a
   scf
   ret

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
   jr nz,load_next_sector
   scf
   ret

load_next_sector:
   call ensure_current_track
   ret nc

   ld a,(current_sector_index)
   ld e,a
   ld d,#0
   ld hl,#sector_table
   add hl,de
   ld a,(hl)
   ld (current_sector_id),a

   call fdc_read_current_sector
   ret nc

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

ensure_current_track:
   ld a,(current_track)
   ld b,a
   ld a,(seeked_track)
   cp b
   jr nz,fdc_seek_current_track
   scf
   ret

fdc_motor_on:
   ld bc,#0xFA7E
   ld a,#1
   out (c),a
   ld b,#5
motor_delay_outer:
   push bc
   ld de,#0xFFFF
motor_delay_inner:
   dec de
   ld a,d
   or e
   jr nz,motor_delay_inner
   pop bc
   djnz motor_delay_outer
   ret

fdc_stop:
   xor a
   ld bc,#0xFA7E
   out (c),a
   ret

fdc_drain_results:
   ld d,#16
drain_loop:
   ld bc,#0xFB7E
   in a,(c)
   and #0xC0
   cp #0xC0
   ret nz
   inc c
   in a,(c)
   dec d
   jr nz,drain_loop
   ret

fdc_recalibrate:
   ld b,#3
recal_retry:
   push bc
   ld a,#0x07
   call fdc_write_byte
   pop bc
   ret nc
   push bc
   xor a
   call fdc_write_byte
   pop bc
   ret nc
   push bc
   call fdc_wait_seek_complete
   pop bc
   ret c
   djnz recal_retry
   or a
   ret

fdc_seek_current_track:
   ld a,#0x0F
   call fdc_write_byte
   ret nc
   xor a
   call fdc_write_byte
   ret nc
   ld a,(current_track)
   call fdc_write_byte
   ret nc
   call fdc_wait_seek_complete
   ret nc
   ld a,(current_track)
   ld (seeked_track),a
   scf
   ret

fdc_wait_seek_complete:
   ld de,#0xFFFF
seek_complete_loop:
   push de
   ld a,#0x08
   call fdc_write_byte
   pop de
   ret nc
   push de
   call fdc_read_result_byte
   pop de
   ret nc
   ld (result_data),a
   and #0xC0
   cp #0x80
   jr z,seek_complete_wait
   push de
   call fdc_read_result_byte
   pop de
   ret nc

   ld a,(result_data)
   bit 5,a
   jr nz,seek_complete_status

seek_complete_wait:
   dec de
   ld a,d
   or e
   jr nz,seek_complete_loop
   ret

seek_complete_status:
   bit 4,a
   jr z,seek_ok
   or a
   ret

seek_ok:
   scf
   ret

fdc_read_current_sector:
   ld a,#0x46
   call fdc_write_byte
   ret nc
   xor a
   call fdc_write_byte
   ret nc
   ld a,(current_track)
   call fdc_write_byte
   ret nc
   xor a
   call fdc_write_byte
   ret nc
   ld a,(current_sector_id)
   call fdc_write_byte
   ret nc
   ld a,#0x02
   call fdc_write_byte
   ret nc
   ld a,(current_sector_id)
   call fdc_write_byte
   ret nc
   ld a,#0x2A
   call fdc_write_byte
   ret nc
   ld a,#0xFF
   call fdc_write_byte
   ret nc

   ld de,(current_dest)
   ld bc,#0xFB7E
   call save_and_disable_interrupts
   ld hl,#0xFFFF

wait_data_ready:
   in a,(c)
   bit 7,a
   jr z,wait_data_timeout
   bit 5,a
   jr z,data_end

data_read_ready:
   inc c
   in a,(c)
   ld (de),a
   dec c
   inc de
data_loop:
   in a,(c)
   jp p,data_loop
   bit 5,a
   jr nz,data_read_ready
   jr data_end

wait_data_timeout:
   dec hl
   ld a,h
   or l
   jr nz,wait_data_ready
   call restore_interrupts
   or a
   ret

data_end:
   call restore_interrupts
   call fdc_read_results
   ret nc
   jp fdc_check_read_results

save_and_disable_interrupts:
   xor a
   ld (interrupt_was_enabled),a
   ld a,i
   jp po,interrupt_state_saved
   ld a,#1
   ld (interrupt_was_enabled),a
interrupt_state_saved:
   di
   ret

restore_interrupts:
   ld a,(interrupt_was_enabled)
   or a
   ret z
   ei
   ret

fdc_write_byte:
   ld e,a
   ld d,#8
   ld hl,#0xFFFF
   ld bc,#0xFB7E
write_wait:
   in a,(c)
   bit 7,a
   jr nz,write_rqm
   dec hl
   ld a,h
   or l
   jr nz,write_wait
   dec d
   jr nz,write_wait
   ret

write_rqm:
   bit 6,a
   jr z,write_ready
   push de
   call fdc_drain_results
   pop de
   jr write_wait

write_ready:
   inc c
   ld a,e
   out (c),a
   ld a,#5
write_delay:
   dec a
   jr nz,write_delay
   scf
   ret

fdc_read_result_byte:
   ld d,#8
   ld hl,#0xFFFF
   ld bc,#0xFB7E
read_result_wait:
   in a,(c)
   and #0xC0
   cp #0xC0
   jr z,read_result_ready
   dec hl
   ld a,h
   or l
   jr nz,read_result_wait
   dec d
   jr nz,read_result_wait
   ret

read_result_ready:
   inc c
   in a,(c)
   scf
   ret

fdc_read_results:
   ld hl,#result_data
   ld b,#7
read_results_loop:
   push hl
   push bc
   call fdc_read_result_byte
   pop bc
   pop hl
   ret nc
   ld (hl),a
   inc hl
   djnz read_results_loop
   scf
   ret

fdc_check_read_results:
   ld a,(result_data)
   and #0x18
   jr nz,read_result_error
   ld a,(result_data+1)
   and #0x35
   jr nz,read_result_error
   ld a,(result_data+2)
   and #0x33
   jr nz,read_result_error
   scf
   ret

read_result_error:
   or a
   ret

verify_runtime_font:
   ld a,(hl)
   cp #0x46
   jr nz,signature_error
   inc hl
   ld a,(hl)
   cp #0x4E
   jr nz,signature_error
   inc hl
   ld a,(hl)
   cp #0x54
   jr nz,signature_error
   inc hl
   ld a,(hl)
   cp #0x35
   jr nz,signature_error
   scf
   ret

signature_error:
   or a
   ret

overlay_recal_error:
   ld a,#HW_RED
   jr overlay_set_error_and_halt

overlay_sector_error:
   ld a,#HW_WHITE
   jr overlay_set_error_and_halt

overlay_signature_error:
   ld a,#HW_BLACK

overlay_set_error_and_halt:
   call set_border_colour
   call fdc_stop
overlay_halt:
   jr overlay_halt

set_border_colour:
   push bc
   push af
   ld b,#0x7F
   ld a,#0x10
   out (c),a
   pop af
   or #0x40
   out (c),a
   pop bc
   ret
