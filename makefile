ASM = nasm

.PHONY: floppyimage kernel bootloader everything

goldos: everything
	qemu-system-i386 -fda build/goldos.img

debug: everything
	qemu-system-i386 -fda build/goldos.img -boot a -s -S

norun: everything

everything: floppyimage kernel bootloader build

floppyimage: build/goldos.img

build/goldos.img: build bootloader kernel
	dd if=/dev/zero of=build/goldos.img bs=512 count=2880
	mkfs.fat -F 12 -n "GOLDOS" build/goldos.img
	dd if=build/bootloader.bin of=build/goldos.img conv=notrunc
	mcopy -i build/goldos.img build/kernel.bin "::kernel.bin"

bootloader: build/bootloader.bin

build/bootloader.bin: build bootloader/bootloader.asm
	$(ASM) bootloader/bootloader.asm -fbin -obuild/bootloader.bin

kernel: build/kernel.bin

build/kernel.bin: build kernel/kernel.asm
	$(ASM) kernel/kernel.asm -fbin -obuild/kernel.bin

clean:
	rm -r build

build:
	mkdir -p build
