%define endl 0Dh, 0Ah

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

main:
	mov si, str_hello
	call talk

str_hello: db "do u hav som ppsi", 0, endl 