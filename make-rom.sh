#!/bin/bash

set -eux

riscv32-unknown-elf-as -o test.elf test.s
riscv32-unknown-elf-objcopy -O binary test.elf test.bin
hexdump -v -e '/4 "%08x\n"' test.bin | ruby -e 'ARGF.map.with_index{|line, i| puts "@#{(i*4).to_s(16)} #{line}"}' > rom.txt
