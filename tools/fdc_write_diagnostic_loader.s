; Direct FDC write diagnostic loader.
; Loaded by AMSDOS as FDWTEST.BIN, then writes track 27/sector &C1 directly,
; reads it back directly, and prints the last completed phase/status.

WRITE_SRC     = #0x4E00
READ_DEST     = #0x5000
TEST_TRACK    = #27
TEST_SECTOR   = #0xC1

HW_BLACK      = #0x14
HW_BLUE       = #0x04
HW_GREEN      = #0x16
HW_RED        = #0x1C
HW_PURPLE     = #0x05
HW_ORANGE     = #0x0E
HW_YELLOW     = #0x1E
HW_CYAN       = #0x13
HW_WHITE      = #0x00

.area _DATA

result_data:
   .ds 8
last_msr:
   .db #0
fail_step:
   .db #0

msg_start:
   .ascii "FDC WRITE DIAG"
   .db 13,10,0
msg_motor:
   .ascii "MOTOR"
   .db 13,10,0
msg_specify:
   .ascii "SPECIFY"
   .db 13,10,0
msg_recal:
   .ascii "RECAL"
   .db 13,10,0
msg_seek:
   .ascii "SEEK27"
   .db 13,10,0
msg_write:
   .ascii "WRITE"
   .db 13,10,0
msg_write_ok:
   .ascii "WRITE OK"
   .db 13,10,0
msg_read:
   .ascii "READBACK"
   .db 13,10,0
msg_read_ok:
   .ascii "READ OK"
   .db 13,10,0
msg_ok:
   .ascii "OK"
   .db 13,10,0
msg_fail:
   .ascii "FAIL STEP "
   .db 0
msg_msr:
   .ascii "MSR "
   .db 0
msg_status:
   .ascii "ST "
   .db 0
msg_write_bytes:
   .ascii "W "
   .db 0
msg_read_bytes:
   .ascii "R "
   .db 0
msg_phase:
   .ascii "P "
   .db 0
msg_crlf:
   .db 13,10,0

.area _CODE

TXT_OUTPUT = #0xBB5A

_fdc_write_diag_start::
   ld hl,#msg_start
   call print_string
   ld a,#HW_BLUE
   call set_border_colour

   call prepare_write_buffer
   call clear_read_buffer
   call clear_result_data

   ld hl,#msg_motor
   call print_string
   ld a,#HW_BLUE
   call set_border_colour
   call fdc_motor_on
   call fdc_drain_results

   ld hl,#msg_specify
   call print_string
   ld a,#HW_ORANGE
   call set_border_colour
   ld a,#0x01
   ld (fail_step),a
   call fdc_specify
   jr nc,diag_fail

   ld hl,#msg_recal
   call print_string
   ld a,#HW_YELLOW
   call set_border_colour
   ld a,#0x10
   ld (fail_step),a
   call fdc_recalibrate
   jr nc,diag_fail

   ld hl,#msg_seek
   call print_string
   ld a,#HW_CYAN
   call set_border_colour
   ld a,#0x20
   ld (fail_step),a
   call fdc_seek_test_track
   jr nc,diag_fail

   ld hl,#msg_write
   call print_string
   ld a,#HW_PURPLE
   call set_border_colour
   ld a,#0x30
   ld (fail_step),a
   call fdc_write_test_sector
   jr nc,diag_fail

   ld hl,#msg_write_ok
   call print_string

   ld hl,#msg_read
   call print_string
   ld a,#HW_WHITE
   call set_border_colour
   ld a,#0x40
   ld (fail_step),a
   call fdc_read_test_sector
   jr nc,diag_fail

   ld hl,#msg_read_ok
   call print_string
   call verify_readback
   jr nc,diag_fail_signature

diag_success:
   call fdc_stop
   ld hl,#msg_ok
   call print_string
   ld a,#HW_GREEN
   call set_border_colour
   jr diag_halt

diag_fail_signature:
   ld a,#0x50
   ld (fail_step),a

diag_fail:
   call fdc_stop
   ld a,#HW_RED
   call set_border_colour
   ld hl,#msg_fail
   call print_string
   ld a,(fail_step)
   call print_hex_byte
   ld hl,#msg_crlf
   call print_string
   call print_msr_line
   call print_status_line
   call print_write_bytes
   call print_read_bytes

diag_halt:
   di
diag_halt_loop:
   jr diag_halt_loop

prepare_write_buffer:
   ld hl,#WRITE_SRC
   ld b,#0
   ld a,#0xA5
prepare_write_loop_0:
   ld (hl),a
   inc hl
   djnz prepare_write_loop_0
   ld b,#0
prepare_write_loop_1:
   ld (hl),a
   inc hl
   djnz prepare_write_loop_1

   ld hl,#WRITE_SRC
   ld a,#'W'
   ld (hl),a
   inc hl
   ld a,#'R'
   ld (hl),a
   inc hl
   ld a,#'0'
   ld (hl),a
   inc hl
   ld a,#'7'
   ld (hl),a
   ret

clear_read_buffer:
   ld hl,#READ_DEST
   ld b,#0
   ld a,#0xEE
clear_read_loop_0:
   ld (hl),a
   inc hl
   djnz clear_read_loop_0
   ld b,#0
clear_read_loop_1:
   ld (hl),a
   inc hl
   djnz clear_read_loop_1
   ret

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
   ld (last_msr),a
   and #0xC0
   cp #0xC0
   ret nz
   inc c
   in a,(c)
   dec d
   jr nz,drain_loop
   ret

fdc_specify:
   ld a,#0x02
   ld (fail_step),a
   ld a,#0x03
   call fdc_write_byte
   ret nc
   ld a,#0x03
   ld (fail_step),a
   ld a,#0xDF
   call fdc_write_byte
   ret nc
   ld a,#0x04
   ld (fail_step),a
   ld a,#0x03
   call fdc_write_byte
   ret nc
   scf
   ret

fdc_recalibrate:
   ld b,#3
recal_retry:
   push bc
   ld a,#0x11
   ld (fail_step),a
   ld a,#0x07
   call fdc_write_byte
   pop bc
   ret nc
   push bc
   ld a,#0x12
   ld (fail_step),a
   xor a
   call fdc_write_byte
   pop bc
   ret nc
   push bc
   ld a,#0x13
   ld (fail_step),a
   call fdc_wait_seek_complete
   pop bc
   ret c
   djnz recal_retry
   or a
   ret

fdc_seek_test_track:
   ld b,#3
seek_retry:
   push bc
   ld a,#0x21
   ld (fail_step),a
   ld a,#0x0F
   call fdc_write_byte
   pop bc
   ret nc
   push bc
   ld a,#0x22
   ld (fail_step),a
   xor a
   call fdc_write_byte
   pop bc
   ret nc
   push bc
   ld a,#0x23
   ld (fail_step),a
   ld a,#TEST_TRACK
   call fdc_write_byte
   pop bc
   ret nc
   push bc
   ld a,#0x24
   ld (fail_step),a
   call fdc_wait_seek_complete
   pop bc
   ret c
   djnz seek_retry
   or a
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
   ld (result_data+1),a

   ld a,(result_data)
   bit 5,a
   jr nz,seek_complete_status

seek_complete_wait:
   dec de
   ld a,d
   or e
   jr nz,seek_complete_loop
   or a
   ret

seek_complete_status:
   bit 4,a
   jr z,seek_ok
   or a
   ret

seek_ok:
   scf
   ret

fdc_write_test_sector:
   call clear_result_data

   ld a,#0x31
   ld (fail_step),a
   call print_phase_marker
   ld a,#0x45
   call fdc_write_byte
   ret nc
   ld a,#0x32
   ld (fail_step),a
   call print_phase_marker
   xor a
   call fdc_write_byte
   ret nc
   ld a,#0x33
   ld (fail_step),a
   call print_phase_marker
   ld a,#TEST_TRACK
   call fdc_write_byte
   ret nc
   ld a,#0x34
   ld (fail_step),a
   call print_phase_marker
   xor a
   call fdc_write_byte
   ret nc
   ld a,#0x35
   ld (fail_step),a
   call print_phase_marker
   ld a,#TEST_SECTOR
   call fdc_write_byte
   ret nc
   ld a,#0x36
   ld (fail_step),a
   call print_phase_marker
   ld a,#0x02
   call fdc_write_byte
   ret nc
   ld a,#0x37
   ld (fail_step),a
   call print_phase_marker
   ld a,#TEST_SECTOR
   call fdc_write_byte
   ret nc
   ld a,#0x38
   ld (fail_step),a
   call print_phase_marker
   ld a,#0x2A
   call fdc_write_byte
   ret nc
   ld a,#0x39
   ld (fail_step),a
   call print_phase_marker
   ld a,#0xFF
   call fdc_write_byte
   ret nc

   ld a,#0x3A
   ld (fail_step),a
   call print_phase_marker

   ld de,#WRITE_SRC
   ld hl,#0x1200
   ld bc,#0xFB7E
   di

write_data_wait_reset:
   exx
   ld bc,#0x2000
   exx

write_data_wait:
   in a,(c)
   ld (last_msr),a
   bit 7,a
   jr z,write_data_wait_tick
   bit 5,a
   jr z,write_data_result
   ; ULIfAC can report DIO=1 during write execution (MSR F0).
   ; For WRITE DATA diagnostics, output bytes while RQM and EXM are set.

   inc c
   ld a,(de)
   out (c),a
   dec c
   inc de
   dec hl
   ld a,h
   or l
   jr nz,write_data_wait_reset
   jr write_data_timeout

write_data_wait_tick:
   exx
   dec bc
   ld a,b
   or c
   exx
   jr nz,write_data_wait
   jr write_data_timeout

write_data_timeout:
   ei
   or a
   ret

write_data_result:
   ld a,#0x3C
   ld (fail_step),a
   ei
   call fdc_read_results_until_idle
   ret nc
   jp fdc_check_write_results

write_data_end:
   ld a,#0x3B
   ld (fail_step),a
   exx
   ld bc,#0x2000
   exx

write_finish_wait:
   in a,(c)
   ld (last_msr),a
   bit 5,a
   jr z,write_data_result_after_end
   bit 6,a
   jr nz,write_data_result_after_end
   exx
   dec bc
   ld a,b
   or c
   exx
   jr nz,write_finish_wait
   jr write_data_timeout

write_data_result_after_end:
   ld a,#0x3D
   ld (fail_step),a
   ei
   call fdc_read_results_until_idle
   ret nc
   jp fdc_check_write_results

fdc_read_test_sector:
   call clear_result_data
   call clear_read_buffer

   ld a,#0x41
   ld (fail_step),a
   ld a,#0x46
   call fdc_write_byte
   ret nc
   ld a,#0x42
   ld (fail_step),a
   xor a
   call fdc_write_byte
   ret nc
   ld a,#0x43
   ld (fail_step),a
   ld a,#TEST_TRACK
   call fdc_write_byte
   ret nc
   ld a,#0x44
   ld (fail_step),a
   xor a
   call fdc_write_byte
   ret nc
   ld a,#0x45
   ld (fail_step),a
   ld a,#TEST_SECTOR
   call fdc_write_byte
   ret nc
   ld a,#0x46
   ld (fail_step),a
   ld a,#0x02
   call fdc_write_byte
   ret nc
   ld a,#0x47
   ld (fail_step),a
   ld a,#TEST_SECTOR
   call fdc_write_byte
   ret nc
   ld a,#0x48
   ld (fail_step),a
   ld a,#0x2A
   call fdc_write_byte
   ret nc
   ld a,#0x49
   ld (fail_step),a
   ld a,#0xFF
   call fdc_write_byte
   ret nc

   ld a,#0x4A
   ld (fail_step),a
   ld de,#READ_DEST
   ld hl,#0x0200
   ld bc,#0xFB7E
   di
   exx
   ld bc,#0xFFFF
   exx

read_data_wait:
   in a,(c)
   ld (last_msr),a
   bit 7,a
   jr z,read_data_wait_tick
   bit 6,a
   jr z,read_data_result
   bit 5,a
   jr z,read_data_result

   inc c
   in a,(c)
   ld (de),a
   dec c
   inc de
   dec hl
   ld a,h
   or l
   jr nz,read_data_wait
   jr read_data_end

read_data_wait_tick:
   exx
   dec bc
   ld a,b
   or c
   exx
   jr nz,read_data_wait
   jr read_data_timeout

read_data_timeout:
   ei
   or a
   ret

read_data_result:
   ld a,#0x4C
   ld (fail_step),a
   ei
   call fdc_read_results_until_idle
   ret nc
   jp fdc_check_read_results

read_data_end:
   ld a,#0x4B
   ld (fail_step),a
   exx
   ld bc,#0xFFFF
   exx

read_finish_wait:
   in a,(c)
   ld (last_msr),a
   bit 5,a
   jr z,read_data_result_after_end
   exx
   dec bc
   ld a,b
   or c
   exx
   jr nz,read_finish_wait
   jr read_data_timeout

read_data_result_after_end:
   ld a,#0x4D
   ld (fail_step),a
   ei
   call fdc_read_results_until_idle
   ret nc
   jp fdc_check_read_results

fdc_write_byte:
   ld e,a
   ld d,#8
   ld hl,#0x1000
   ld bc,#0xFB7E
write_wait:
   in a,(c)
   ld (last_msr),a
   bit 7,a
   jr nz,write_rqm
   dec hl
   ld a,h
   or l
   jr nz,write_wait
   dec d
   jr nz,write_wait
   or a
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
   ld hl,#0x1000
   ld bc,#0xFB7E
read_result_wait:
   in a,(c)
   ld (last_msr),a
   and #0xC0
   cp #0xC0
   jr z,read_result_ready
   dec hl
   ld a,h
   or l
   jr nz,read_result_wait
   dec d
   jr nz,read_result_wait
   or a
   ret

read_result_ready:
   inc c
   in a,(c)
   scf
   ret

fdc_read_results_until_idle:
   ld hl,#result_data
   ld b,#8
read_results_idle_loop:
   push hl
   push bc
   call fdc_read_result_byte
   pop bc
   pop hl
   ret nc
   ld (hl),a
   inc hl

   push hl
   push bc
   ld bc,#0xFB7E
   ld a,#5
result_idle_delay:
   dec a
   jr nz,result_idle_delay
   in a,(c)
   ld (last_msr),a
   pop bc
   pop hl
   and #0x10
   jr z,read_results_idle_done
   djnz read_results_idle_loop
   or a
   ret

read_results_idle_done:
   scf
   ret

fdc_read_results_visible:
   ld hl,#result_data
   ld b,#8
   ld e,#0xD0
read_results_visible_loop:
   ld a,e
   ld (fail_step),a
   push hl
   push bc
   push de
   call print_phase_marker
   call fdc_read_result_byte
   pop de
   pop bc
   pop hl
   ret nc
   ld (hl),a
   inc hl
   inc e

   push hl
   push bc
   push de
   ld bc,#0xFB7E
   ld a,#5
result_visible_delay:
   dec a
   jr nz,result_visible_delay
   in a,(c)
   ld (last_msr),a
   pop de
   pop bc
   pop hl
   and #0x10
   jr z,read_results_visible_done
   djnz read_results_visible_loop
   or a
   ret

read_results_visible_done:
   scf
   ret

fdc_check_read_results:
   ld a,(result_data)
   and #0x18
   jr nz,fdc_result_error
   ld a,(result_data+1)
   and #0x35
   jr nz,fdc_result_error
   ld a,(result_data+2)
   and #0x33
   jr nz,fdc_result_error
   scf
   ret

fdc_check_write_results:
   ld a,(result_data)
   and #0x18
   jr nz,fdc_result_error
   ld a,(result_data+1)
   and #0x37
   jr nz,fdc_result_error
   ld a,(result_data+2)
   and #0x33
   jr nz,fdc_result_error
   scf
   ret

fdc_result_error:
   or a
   ret

verify_readback:
   ld hl,#READ_DEST
   ld a,(hl)
   cp #'W'
   jr nz,verify_error
   inc hl
   ld a,(hl)
   cp #'R'
   jr nz,verify_error
   inc hl
   ld a,(hl)
   cp #'0'
   jr nz,verify_error
   inc hl
   ld a,(hl)
   cp #'7'
   jr nz,verify_error
   scf
   ret

verify_error:
   or a
   ret

clear_result_data:
   ld hl,#result_data
   ld b,#8
   ld a,#0xEE
clear_result_loop:
   ld (hl),a
   inc hl
   djnz clear_result_loop
   ld a,#0
   ld (last_msr),a
   ret

print_string:
   ld a,(hl)
   or a
   ret z
   call TXT_OUTPUT
   inc hl
   jr print_string

print_msr_line:
   ld hl,#msg_msr
   call print_string
   ld a,(last_msr)
   call print_hex_byte
   ld hl,#msg_crlf
   jp print_string

print_phase_marker:
   ld hl,#msg_phase
   call print_string
   ld a,(fail_step)
   call print_hex_byte
   ld a,#' '
   jp TXT_OUTPUT

print_status_line:
   ld hl,#msg_status
   call print_string
   ld hl,#result_data
   ld b,#8
print_status_loop:
   ld a,(hl)
   push hl
   push bc
   call print_hex_byte
   ld a,#' '
   call TXT_OUTPUT
   pop bc
   pop hl
   inc hl
   djnz print_status_loop
   ld hl,#msg_crlf
   jp print_string

print_write_bytes:
   ld hl,#msg_write_bytes
   call print_string
   ld hl,#WRITE_SRC
   ld b,#4
   jr print_bytes_loop

print_read_bytes:
   ld hl,#msg_read_bytes
   call print_string
   ld hl,#READ_DEST
   ld b,#4

print_bytes_loop:
   ld a,(hl)
   push hl
   push bc
   call print_hex_byte
   ld a,#' '
   call TXT_OUTPUT
   pop bc
   pop hl
   inc hl
   djnz print_bytes_loop
   ld hl,#msg_crlf
   jp print_string

print_hex_byte:
   push af
   rrca
   rrca
   rrca
   rrca
   call print_hex_nibble
   pop af
   and #0x0F
   jr print_hex_nibble_value

print_hex_nibble:
   and #0x0F
print_hex_nibble_value:
   cp #10
   jr c,print_hex_digit
   add a,#'A' - 10
   jp TXT_OUTPUT

print_hex_digit:
   add a,#'0'
   jp TXT_OUTPUT
