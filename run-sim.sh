#!/bin/sh

set -eux

iverilog -o rvcpu_tb -s rvcpu_tb top.v rvcpu_tb.v rvcpu.v
vvp ./rvcpu_tb
gtkwave rvcpu_tb.vcd
