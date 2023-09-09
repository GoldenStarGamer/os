org 7C00h ;start at
bits 16 ;16bit real mode

%define endl 0Dh, 0Ah

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
ebr_useless:	            db 0                    ; reserved, windows stuff, i guess
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; serial number, value doesn't matter
ebr_volume_label:           db 'GOLD OS    '        ; 11 bytes, padded with spaces
ebr_system_id:              db 'FAT12   '           ; 8 bytes          db 'FAT12   '           ; 8 bytes

; END OF HEADER

;MAIN AREA

start:
	jmp setup ;go to the main function, not talk

;setup registers and stack
setup:
	;setup registers
	mov ax, 0 ;clear ax
	mov ds, ax ;clear ds by copying ax
	mov es,ax ;clear es by copying ax

	;setup stack
	mov ss, ax ;clear ss by copying ax
	mov sp, 0x7c00 ;set stack to work without overwriting our stuff

	;set disk number
	mov [ebr_drive_number], dl

	jmp main

;says shit
;PARAMS: si - String to print.
;RETURNS: nothing
talk:
	;save registers to stack
	push si
	push ax

.loop:
	lodsb ;load next character in al
	or al, al ;verify if next character is null
	jz .done ;if null then complete

	;BIOS INTERRUPT, SEE RESOURCES.md
	mov ah, 0eh ;print character
	mov bh, 0 ;page 0
	int 10h ;INTERRUPT VIDEO SERVICE

	jmp .loop ;restart
.done:
	pop ax
	pop si
	ret

;reboot function
reboot:
	jmp 0FFFFh:0 ;jump to beginning of bios, 

;shutdown function
shutdown:
	mov ax, 0x1
	mov ss, ax
	mov sp, 0xf
	mov ax, 0x5307
	mov bx, 0x1
	mov cx, 0x3
	int 15h
	ret

;main function
main:
	;disk read test
	mov ax, 1 ;second sector of disk, like c arrays, they start at 0.
	mov cl, 1 ;read 1 sector
	mov bx, 7E00h ;store at that address
	call disk_read 

	mov si, str_hello ;set string to write
	call talk ;print

	call halt ;halt until esc key pressed

;check for the esc key
halt:
	hlt
	;BIOS INTERRUPT, SEE RESOURCES.md
	mov ah, 0 ;Check keyboard input
    int 16h ;INTERRUPT KEYBOARD SERVICE

    ;AH will contain the scan code of the pressed key
    cmp ah, 1h ;esc key in pt keyboard
    jne halt ;if not equal, continue checking

	mov si, str_escfound ; say that it found the esc key, just debugging, usually the user can't see it
	call talk ;print the message
	call shutdown ;shutdown

;DISK AREA

;converts LBA(logical block addressing) address to CHS(cylinder, head, sector) address
;PARAMS: ax - LBA Address.
;RETURNS: cx[0-5] - Sector number.
;		: cx[6-15] - Cylinder.
;		: dh - Head.
disk_lba_chs_conversion:

	;save registers that are used, but are not part of param or input
	push ax
	push dx

	xor dx, dx ;clear dx register
	div word [bdb_sectors_per_track] ;ax = LBA Address / Sectors per Track
									 ;dx = LBA Address % Sectors per Track
	inc dx ;dx = the previous operation + 1 = sector
	mov cx, dx ;send to the correct output register

	xor dx, dx ;clear dx
	div word [bdb_heads] ;ax = (address / sectors per track) / Heads = cylinder
						 ;dx = (address / sectors per track) % Heads = head

	mov dh, dl ;send value to output location
			   ;dl = lower 8 bits of dx
	mov ch, al ;ye same shit
	shl ah, 6 ;shift 6 bits to left
	or cl, ah ;move the data, don't replace everything

	; restore registers
	pop ax
	mov dl, al
	pop ax

	ret



floppy_error:
	mov si, str_read_failed
	call talk
	;BIOS INTERRUPT, SEE RESOURCES.md
	mov ah, 0 ;wait for keypress
	int 16h
	jmp reboot

;reads the disk
;PARAMS: ax - LBA Address.
;	   : cl - nuber of sectors to read.
;	   : dl - drive number.
;	   : es:bx - memory address to store the data.
;RETURNS: (relative) - data read.
disk_read:

    push ax                             ; save registers we will modify
    push bx
    push cx
    push dx
    push di

    push cx                             ; temporarily save CL (number of sectors to read)
    call disk_lba_chs_conversion                   ; compute CHS
    pop ax                              ; AL = number of sectors to read
    
    mov ah, 02h
    mov di, 3                           ; retry count

.retry:
    pusha                               ; save all registers, we don't know what bios modifies
    stc                                 ; set carry flag, some BIOS'es don't set it
    int 13h                             ; carry flag cleared = success
    jnc .done                           ; jump if carry not set

    ; read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; all attempts are exhausted
    jmp floppy_error

.done:
	mov si, str_read_success
	call talk
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax                             ; restore registers modified
    ret

disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret

;STRING AREA

str_hello: db "do u hav som ppsi", endl, 0 ;do you?

str_read_failed: db "ERROR: Disk read operation Failed", endl, 0 ;message for when it can't read the disk.

str_read_success: db "Read Operation Success", endl, 0

str_escfound: db "Esc found, shutdown attempted", endl, 0 ;usually you won't see this from how fast it shuts down,
														  ;this is only for debugging purposes

times 510-($-$$) db 0 ;nullify the rest of the 512 bytes we can use
dw 0AA55h ;bootloader signature, DO NOT TOUCH, DON'T EVEN THINK ABOUT IT.