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
  ./run-one-test.sh $test nowin
done
