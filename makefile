ASM = nasm

.PHONY = floppyimage kernel bootloader everything

goldos: everything
	qemu-system-i386 -fda build/goldos.img

norun: everything

everything: floppyimage kernel bootloader

floppyimage: build/goldos.img

build/goldos.img: bootloader kernel
	dd if=/dev/zero of=build/goldos.img bs=512 count=2880
	mkfs.fat -F 12 -n "GOLDOS" build/goldos.img
	dd if=build/bootloader.bin of=build/goldos.img conv=notrunc
	mcopy -i build/goldos.img build/kernel.bin "::kernel.bin"

bootloader: build/bootloader.bin

build/bootloader.bin: bootloader/bootloader.asm | build
	$(ASM) bootloader/bootloader.asm -fbin -obuild/bootloader.bin

kernel: build/kernel.bin

build/kernel.bin: | build
	$(ASM) kernel/kernel.asm -fbin -obuild/kernel.bin

build:
	mkdir build