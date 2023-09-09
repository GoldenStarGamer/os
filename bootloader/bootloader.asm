org 7C00h ;start at
bits 16 ;16bit real mode

%define endl 0Dh, 0Ah

jmp strict short setup ;go back to your place bitch
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

	jmp kernel_find

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
	jmp 0FFFFh:0 ;jump to beginning of bios

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
	mov si, ferror_read_failed
	call fatal_reboot

;reads the disk
;PARAMS: ax - LBA Address.
;	   : cl - nuber of sectors to read.
;	   : dl - drive number.
;	   : es:bx - memory address to store the data.
;RETURNS: (relative) - data read.
disk_read:

    pusha                        ; save registers we will modify

    push cx                             ; temporarily save CL (number of sectors to read)
    call disk_lba_chs_conversion                   ; compute CHS
    pop ax                              ; AL = number of sectors to read
    
    mov ah, 02h
    mov di, 3                           ; retry count

.retry:
    pusha                               ; save all registers, we don't know what bios modifies
    stc                                 ; set carry flag, some BIOS'es don't set it
    int 13h                             ; carry flag cleared = success
    popa
    jnc .done                           ; jump if carry not set

    ; read failed
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; all attempts are exhausted
    jmp floppy_error

.done:
	popa                           ; restore registers
    ret

disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret

;KERNEL LOAD AREA

KERNEL_LOAD_SEGMENT equ 0x2000
KERNEL_LOAD_OFFSET equ 0

kernel_cluster: dw 0

;just gets the size of the root directory
kernel_find:

	;get root directory address
	mov ax, [bdb_sectors_per_fat]
	mov bl, [bdb_fat_count]
	xor bh, bh
	mul bx
	add ax, [bdb_reserved_sectors]
	push ax

	;get size of root directory
	mov ax, [bdb_sectors_per_fat]
	shl ax, 5
	xor dx, dx
	div word [bdb_bytes_per_sector]
	test dx, dx
	jz .rdsdone
	inc ax
	.rdsdone:

	;read root diretory
	mov cl, al
	pop ax
	mov dl, [ebr_drive_number]
	mov bx, buffer
	call disk_read


	;find the kernel
	xor bx, bx
	mov di, buffer

	.kernelsearch:
	mov si, file_kernel
	mov cx, 11
	push di
	repe cmpsb
	pop di
	je .kernelfound

	add di, 32
	inc bx
	cmp bx, [bdb_dir_entries_count]
	jl .kernelsearch
	mov si, ferror_no_kernel
	call talk
	call fatal_reboot

	.kernelfound:
	mov ax, [di + 26]
	mov [kernel_cluster], ax

	;get stuff from disk
	mov ax, [bdb_reserved_sectors]
	mov bx, buffer
	mov cl, [bdb_sectors_per_fat]
	mov dl, [ebr_drive_number]
	call disk_read

	mov bx, KERNEL_LOAD_SEGMENT
	mov es, bx
	mov bx, KERNEL_LOAD_OFFSET

	.kernelload:
	mov ax, [kernel_cluster]

	;awfull shit, only safe in floppy disk
	add ax, 31

	mov cl, 1
	mov dl, [ebr_drive_number]
	call disk_read

	add bx, [bdb_bytes_per_sector] ;awfull shit, will overflow if kernel above 64kb, will overwrite if it happens

	mov ax, [kernel_cluster]
	mov cx, 3
	mul cx
	mov cx, 2
	div cx

	mov si, buffer
	add si, ax
	mov ax, [ds:si]

	or dx, dx
	jz .even

	.odd:
	shr ax, 4
	jmp .continue

	.even:
	and ax, 0x0FFF

	.continue: ;didn't have a better name
	cmp ax, 0x0FF8
	jae .finishreading 

	mov [kernel_cluster], ax
	jmp .kernelload

	.finishreading: ;time to go to bed, hehe
	mov dl, [ebr_drive_number]
	mov ax, KERNEL_LOAD_SEGMENT

	jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET ;goodbye

	mov si, ferror_kernel_jump_failed
	call fatal_reboot
		
	ret
;STRING AREA

file_kernel: db "KERNEL  BIN"

ferror_no_kernel: db "FATAL ERROR: Kernel Not Found", endl, 0

ferror_read_failed: db "FATAL ERROR: Disk read operation Failed", endl, 0 ;message for when it can't read the disk.

ferror_kernel_jump_failed: db "FATAL ERROR: Jump to Kernel Failed"

; MISC AREA

;reboots in case of fatal error
;PARAMS: si - error string
fatal_reboot:
	call talk ;here just to gain a little bit of space
	;BIOS INTERRUPT, SEE RESOURCES.md
	mov ah, 0 ;wait for keypress
	int 16h ;INTERRUPT KEYBOARD SERVICE
	jmp reboot
	ret


times 510-($-$$) db 0 ;nullify the rest of the 512 bytes we can use
dw 0AA55h ;bootloader signature, DO NOT TOUCH, DON'T EVEN THINK ABOUT IT.
;everything beyond this point will not be protected and can be overwritten by the stack, write at your own risk.
buffer: ;label to unused space
