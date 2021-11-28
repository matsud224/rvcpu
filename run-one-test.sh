#!/bin/sh

set -e

# Clone riscv-tests and install to riscv-tests/target before running this script.

rm -rf tests-tmp
mkdir tests-tmp
cp riscv-tests/target/share/riscv-tests/isa/rv32ui-p-* tests-tmp
cp riscv-tests/target/share/riscv-tests/isa/rv32um-p-* tests-tmp
rm tests-tmp/*.dump

TEST=$1
echo -n Testing $TEST ...
TESTELF=tests-tmp/$TEST
riscv32-unknown-elf-objcopy -O binary $TESTELF $TESTELF.bin
hexdump -v -e '/4 "%08x\n"' $TESTELF.bin | ruby -e 'ARGF.map.with_index{|line, i| puts "@#{(i*4).to_s(16)} #{line}"}' > rom.txt
iverilog -o rvcpu_tb -s rvcpu_tb top.v rvcpu_tb.v rvcpu.v
if vvp ./rvcpu_tb | grep "failed!"; then
  printf "\e[37;41;4mFAIL\e[m\n"
else
  echo "OK"
fi

if [ -z $2 ]; then
  gtkwave rvcpu_tb.vcd &
fi
