ASM = nasm

.PHONY = floppyimage kernel bootloader

floppyimage: build/goldos.img

build/goldos.img: bootloader kernel
	dd if=/dev/zero of=build/goldos.img bs=512 count=2880
	mkfs.fat -F 12 -n "GOLDOS" build/goldos.img
	dd if=build/bootloader.bin of=build/goldos.img conv=notrunc
	mcopy -i build/goldos.img build/kernel.bin "::kernel.bin"

bootloader: build/bootloader.bin

build/bootloader.bin: bootloader/bootloader.asm
	$(ASM) bootloader/bootloader.asm -fbin -obuild/bootloader.bin

kernel: build/kernel.bin

build/kernel.bin:
	$(ASM) kernel/kernel.asm

run: build/bootloader.img
	qemu-system-i386 -fda build/goldos.img