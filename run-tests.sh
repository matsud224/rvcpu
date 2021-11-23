#!/bin/sh

set -eux

rm -rf tests-tmp
mkdir tests-tmp
cp riscv-tests/target/share/riscv-tests/isa/rv32ui-p-* tests-tmp
rm tests-tmp/*.dump

