; Direct FDC diagnostic loader.
; Loaded by AMSDOS as FDCTEST.BIN, then reads hidden track 35/sector &C1
; directly into &5000 and checks for the FNT5 signature.

LOAD_DEST     = #0x5000
TEST_TRACK    = #35
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

msg_start:
   .ascii "FDC DIAG"
   .db 13,10,0
msg_recal:
   .ascii "RECAL"
   .db 13,10,0
msg_seek:
   .ascii "SEEK35"
   .db 13,10,0
msg_read:
   .ascii "READ"
   .db 13,10,0
msg_ok:
   .ascii "OK"
   .db 13,10,0
msg_fail_recal:
   .ascii "FAIL RECAL"
   .db 13,10,0
msg_fail_seek:
   .ascii "FAIL SEEK"
   .db 13,10,0
msg_fail_read:
   .ascii "FAIL READ"
   .db 13,10,0
msg_fail_signature:
   .ascii "FAIL SIGN"
   .db 13,10,0
msg_status:
   .ascii "ST "
   .db 0
msg_bytes:
   .ascii "B "
   .db 0
msg_crlf:
   .db 13,10,0

.area _CODE

TXT_OUTPUT = #0xBB5A

_fdc_diag_start::
   ld hl,#msg_start
   call print_string
   ld a,#HW_BLUE
   call set_border_colour

   call fdc_motor_on
   call fdc_drain_results

   ld hl,#msg_recal
   call print_string
   ld a,#HW_ORANGE
   call set_border_colour
   call fdc_recalibrate
   jr nc,diag_fail_recal

   ld hl,#msg_seek
   call print_string
   ld a,#HW_YELLOW
   call set_border_colour
   call fdc_seek_test_track
   jr nc,diag_fail_seek

   ld hl,#msg_read
   call print_string
   ld a,#HW_CYAN
   call set_border_colour
   call fdc_read_test_sector
   jr nc,diag_fail_read

   call fdc_stop
   call verify_signature
   jr nc,diag_fail_signature

diag_success:
   ld hl,#msg_ok
   call print_string
   ld a,#HW_GREEN
   call set_border_colour
   jr diag_success_halt

diag_fail_recal:
   call fdc_stop
   ld a,#HW_RED
   call set_border_colour
   ld hl,#msg_fail_recal
   call print_string
   jr diag_fail_halt

diag_fail_seek:
   call fdc_stop
   ld a,#HW_PURPLE
   call set_border_colour
   ld hl,#msg_fail_seek
   call print_string
   jr diag_fail_halt

diag_fail_read:
   call fdc_stop
   ld a,#HW_WHITE
   call set_border_colour
   ld hl,#msg_fail_read
   call print_string
   call print_status_line
   call print_first_bytes
   jr diag_fail_halt

diag_fail_signature:
   call fdc_stop
   ld a,#HW_BLACK
   call set_border_colour
   ld hl,#msg_fail_signature
   call print_string
   call print_status_line
   call print_first_bytes

diag_fail_halt:
   di
fail_halt_loop:
   jr fail_halt_loop

diag_success_halt:
   di
success_halt_loop:
   jr success_halt_loop

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

fdc_seek_test_track:
   ld b,#3
seek_retry:
   push bc
   ld a,#0x0F
   call fdc_write_byte
   pop bc
   ret nc
   push bc
   xor a
   call fdc_write_byte
   pop bc
   ret nc
   push bc
   ld a,#TEST_TRACK
   call fdc_write_byte
   pop bc
   ret nc
   push bc
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
   push de
   call fdc_read_result_byte
   pop de
   ret nc

   ld a,(result_data)
   bit 5,a
   jr nz,seek_complete_status
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

fdc_read_test_sector:
   call clear_result_data
   call clear_first_bytes

   ld a,#0x46
   call fdc_write_byte
   ret nc
   xor a
   call fdc_write_byte
   ret nc
   ld a,#TEST_TRACK
   call fdc_write_byte
   ret nc
   xor a
   call fdc_write_byte
   ret nc
   ld a,#TEST_SECTOR
   call fdc_write_byte
   ret nc
   ld a,#0x02
   call fdc_write_byte
   ret nc
   ld a,#TEST_SECTOR
   call fdc_write_byte
   ret nc
   ld a,#0x2A
   call fdc_write_byte
   ret nc
   ld a,#0xFF
   call fdc_write_byte
   ret nc

   ld de,#LOAD_DEST
   ld bc,#0xFB7E
   di
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
   ei
   or a
   ret

data_end:
   ei
   call fdc_read_results
   ret nc
   jp fdc_check_read_results

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
   ld b,#8
read_results_loop:
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
result_delay:
   dec a
   jr nz,result_delay
   in a,(c)
   pop bc
   pop hl
   and #0x10
   jr z,read_results_done
   djnz read_results_loop
   or a
   ret

read_results_done:
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

verify_signature:
   ld hl,#LOAD_DEST
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

print_string:
   ld a,(hl)
   or a
   ret z
   call TXT_OUTPUT
   inc hl
   jr print_string

clear_result_data:
   ld hl,#result_data
   ld b,#8
   ld a,#0xEE
clear_result_loop:
   ld (hl),a
   inc hl
   djnz clear_result_loop
   ret

clear_first_bytes:
   ld hl,#LOAD_DEST
   ld b,#4
   ld a,#0xEE
clear_first_loop:
   ld (hl),a
   inc hl
   djnz clear_first_loop
   ret

print_status_line:
   ld hl,#msg_status
   call print_string
   ld hl,#result_data
   ld b,#7
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

print_first_bytes:
   ld hl,#msg_bytes
   call print_string
   ld hl,#LOAD_DEST
   ld b,#4
print_first_bytes_loop:
   ld a,(hl)
   push hl
   push bc
   call print_hex_byte
   ld a,#' '
   call TXT_OUTPUT
   pop bc
   pop hl
   inc hl
   djnz print_first_bytes_loop
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
