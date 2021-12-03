#!/bin/bash

set -eu

CFLAGS="-Wall -O2 -ffreestanding -nostartfiles -T link.ld -march=rv32im -mabi=ilp32 -mno-div"

SRC=$1

riscv32-unknown-elf-gcc $CFLAGS -o $SRC.elf $SRC start.s
riscv32-unknown-elf-objcopy -O binary --wildcard -j .text.init -j .text -j .text.* $SRC.elf $SRC.text.bin
riscv32-unknown-elf-objcopy -O binary --wildcard -j .rodata -j .rodata.* -j .data -j .data.* -j .bss -j .bss.* --set-section-flags=.bss=alloc,load,contents $SRC.elf $SRC.data.bin

hexdump -v -e '/4 "%08x\n"' $SRC.text.bin | ruby -e 'ARGF.map.with_index{|line, i| puts "@#{i.to_s(16)} #{line}"}' > imem.txt
hexdump -v -e '/4 "%08x\n"' $SRC.data.bin | ruby -e 'ARGF.map.with_index{|line, i| puts "@#{i.to_s(16)} #{line}"}' > dmem.txt

printf "DEPTH = 8192;\nWIDTH = 32;\n\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\n\nCONTENT\nBEGIN\n" > imem.mif
hexdump -v -e '/4 "%08x\n"' $SRC.text.bin | ruby -e 'ARGF.map.with_index{|line, i| puts "#{i.to_s(16)}: #{line.scan(/.{1,2}/).join("")};"}' >> imem.mif
printf "END;\n" >> imem.mif

printf "DEPTH = 8192;\nWIDTH = 32;\n\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\n\nCONTENT\nBEGIN\n" > dmem.mif
hexdump -v -e '/4 "%08x\n"' $SRC.data.bin | ruby -e 'ARGF.map.with_index{|line, i| puts "#{i.to_s(16)}: #{line.scan(/.{1,2}/).join("")};"}' >> dmem.mif
printf "END;\n" >> dmem.mif
