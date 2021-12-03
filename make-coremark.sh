#!/bin/bash

set -eu

CM="test/coremark"
CFLAGS="-Wall -O2 -ffreestanding -nostartfiles -T link.ld -march=rv32im -mabi=ilp32 -mno-div"
SRCS="$CM/core_list_join.c $CM/core_main.c $CM/core_matrix.c $CM/core_state.c $CM/core_util.c $CM/core_portme.c $CM/ee_printf.c"

riscv32-unknown-elf-gcc $CFLAGS -o coremark.elf $SRCS start.s
riscv32-unknown-elf-objcopy -O binary -j .text.init -j .text -j .text.startup coremark.elf coremark.text.bin
riscv32-unknown-elf-objcopy -O binary -j .rodata -j .data -j .bss --set-section-flags=.bss=alloc,load,contents coremark.elf coremark.data.bin

hexdump -v -e '/4 "%08x\n"' coremark.text.bin | ruby -e 'ARGF.map.with_index{|line, i| puts "@#{i.to_s(16)} #{line}"}' > imem.txt
hexdump -v -e '/4 "%08x\n"' coremark.data.bin | ruby -e 'ARGF.map.with_index{|line, i| puts "@#{i.to_s(16)} #{line}"}' > dmem.txt

printf "DEPTH = 8192;\nWIDTH = 32;\n\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\n\nCONTENT\nBEGIN\n" > imem.mif
hexdump -v -e '/4 "%08x\n"' coremark.text.bin | ruby -e 'ARGF.map.with_index{|line, i| puts "#{i.to_s(16)}: #{line.scan(/.{1,2}/).join("")};"}' >> imem.mif
printf "END;\n" >> imem.mif

printf "DEPTH = 8192;\nWIDTH = 32;\n\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\n\nCONTENT\nBEGIN\n" > dmem.mif
hexdump -v -e '/4 "%08x\n"' coremark.data.bin | ruby -e 'ARGF.map.with_index{|line, i| puts "#{i.to_s(16)}: #{line.scan(/.{1,2}/).join("")};"}' >> dmem.mif
printf "END;\n" >> dmem.mif
