#!/bin/sh

set -eu

# Clone riscv-tests and install to riscv-tests/target before running this script.

rm -rf tests-tmp
mkdir tests-tmp
cp riscv-tests/target/share/riscv-tests/isa/rv32ui-p-* tests-tmp
cp riscv-tests/target/share/riscv-tests/isa/rv32um-p-* tests-tmp
rm tests-tmp/*.dump

for test in $(ls ./tests-tmp);
do
  echo -n Testing$test ...
  TESTELF=tests-tmp/$test
  riscv32-unknown-elf-objcopy -O binary $TESTELF $TESTELF.bin
  hexdump -v -e '/4 "%08x\n"' $TESTELF.bin | ruby -e 'ARGF.map.with_index{|line, i| puts "@#{(i*4).to_s(16)} #{line}"}' > rom.txt
  iverilog -o rvcpu_tb -s rvcpu_tb top.v rvcpu_tb.v rvcpu.v
  if vvp ./rvcpu_tb | grep -q "failed!"; then
    printf "\e[37;41;4mFAIL\e[m\n"
  else
    echo "OK"
  fi
done
