org 0x7C00 ;start at
bits 16 ;16bit real mode

%define endl 0x0D, 0x0A

jmp short start ;go back to your place bitch
nop

; FAT12 HEADER

bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                    ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; EBR SECTION

ebr_drive_number:           db 0                    ; 0x00 floppy, 0x80 hdd, useless
ebr_useless:			    db 0                    ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; serial number, value doesn't matter
ebr_volume_label:           db 'GOLD OS    '        ; 11 bytes, padded with spaces
ebr_system_id:              db 'FAT12   '           ; 8 bytes

; END OF HEADER

start:
	jmp main ;go to the main function, not talk

;says shit
talk: 
	;save registers to stack
	push si
	push ax

.loop:
	lodsb ;load next character in al
	or al, al ;verify if next character is null
	jz .done ;if null then complete

	;BIOS INTERRUPT, SEE RESOURCES.md
	mov ah, 0x0e ;print character
	mov bh, 0 ;page 0
	int 0x10 ;INTERRUPT VIDEO SERVICE

	jmp .loop ;restart
.done:
	pop ax
	pop si
	ret

;shutdown function
shutdown:
	mov ax, 0x1
	mov ss, ax
	mov sp, 0xf
	mov ax, 0x5307
	mov bx, 0x1
	mov cx, 0x3
	int 0x15
	ret

;main function
main:
	;setup registers
	mov ax, 0 ;clear ax
	mov ds, ax ;clear ds by copying ax
	mov es,ax ;clear es by copying ax

	;setup stack
	mov ss, ax ;clear ss by copying ax
	mov sp, 0x7c00 ;set stack to work without overwriting our stuff

	mov si, str_hello ;set string to write
	call talk ;print

	call halt ;halt until esc key pressed

;check for the esc key
halt:
	hlt
	;BIOS INTERRUPT, SEE RESOURCES.md
	mov ah, 0 ;Check keyboard input
    int 0x16 ;INTERRUPT KEYBOARD SERVICE

    ;AH will contain the scan code of the pressed key
    cmp ah, 0x01 ;esc key in pt keyboard
    jne halt ;if not equal, continue checking

	mov si, str_escfound ; say that it found the esc key, just debugging, usually the user can't see it
	call talk ;print the message
	call shutdown ;shutdown



str_hello: db "Do u hav som ppsi", endl, 0

str_escfound: db "Esc found, shutdown attempted", endl, 0

times 510-($-$$) db 0 ;nullify the rest of the 512 bytes we can use
dw 0AA55h ;bootloader signature