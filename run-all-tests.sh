#!/bin/sh

set -eu

# Clone riscv-tests and install to riscv-tests/build before running this script.

if [ ! -e tests-tmp ]; then
  mkdir tests-tmp
  cp riscv-tests/build/share/riscv-tests/isa/rv32ui-p-* tests-tmp
  cp riscv-tests/build/share/riscv-tests/isa/rv32um-p-* tests-tmp
  rm tests-tmp/*.dump
fi

for test in $(ls ./tests-tmp | grep -v ".*\.bin");
do
  ./run-one-test.sh $test nowin
done
