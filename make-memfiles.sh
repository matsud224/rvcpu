#!/bin/bash

set -eu

CFLAGS="-ffreestanding -nostartfiles -T link.ld -march=rv32im -mabi=ilp32 -mno-div"

SRC=$1

riscv32-unknown-elf-gcc $CFLAGS -o $SRC.elf $SRC start.s
riscv32-unknown-elf-objcopy -O binary -j .text.init -j .text $SRC.elf $SRC.text.bin
riscv32-unknown-elf-objcopy -O binary -j .rodata -j .data -j .bss --set-section-flags=.bss=alloc,load,contents $SRC.elf $SRC.data.bin

hexdump -v -e '/4 "%08x\n"' $SRC.text.bin | ruby -e 'ARGF.map.with_index{|line, i| puts "@#{(i*4).to_s(16)} #{line}"}' > imem.txt
hexdump -v -e '/4 "%08x\n"' $SRC.data.bin | ruby -e 'ARGF.map.with_index{|line, i| puts "@#{(i*4).to_s(16)} #{line}"}' > dmem.txt
