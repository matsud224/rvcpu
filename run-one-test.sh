#!/bin/sh

set -e

# Clone riscv-tests and install to riscv-tests/build before running this script.

if [ ! -e tests-tmp ]; then
  mkdir tests-tmp
  cp riscv-tests/build/share/riscv-tests/isa/rv32ui-p-* tests-tmp
  cp riscv-tests/build/share/riscv-tests/isa/rv32um-p-* tests-tmp
  rm tests-tmp/*.dump
fi

TEST=$1
echo -n Testing $TEST ...
TESTELF=tests-tmp/$TEST

riscv32-unknown-elf-objcopy -O binary -j .text.init -j .tohost -j .text $TESTELF $TESTELF.text.bin
riscv32-unknown-elf-objcopy -O binary -j .data -j .bss --set-section-flags=.bss=alloc,load,contents $TESTELF $TESTELF.data.bin
hexdump -v -e '/4 "%08x\n"' $TESTELF.text.bin | ruby -e 'ARGF.map.with_index{|line, i| puts "@#{i.to_s(16)} #{line}"}' > imem.txt
hexdump -v -e '/4 "%08x\n"' $TESTELF.data.bin | ruby -e 'ARGF.map.with_index{|line, i| puts "@#{i.to_s(16)} #{line}"}' > dmem.txt

iverilog -o rvcpu_tb -s rvcpu_tb top.v rvcpu_tb.v rvcpu.v
if vvp ./rvcpu_tb | grep "failed!"; then
  printf "\e[37;41;4mFAIL\e[m\n"
else
  echo "OK"
fi

if [ -z $2 ]; then
  gtkwave rvcpu_tb.vcd &
fi
