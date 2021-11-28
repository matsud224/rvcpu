`timescale 1ns/1ps

module rvcpu_tb;
  parameter TCLK_HALF = 5;

  reg clk, rst_n;
  wire halted;

  top top(clk, rst_n, halted);

  initial begin
    clk = 1;
    forever #(TCLK_HALF) clk = ~clk;
  end

  integer i;

  initial begin
    $dumpfile("rvcpu_tb.vcd");
    $dumpvars(0, top);
    for (i=0; i<32; i++)
      $dumpvars(0, top.cpu0.regs[i]);

    rst_n = 0;
    #(20)
    rst_n = 1;
    wait(halted);
    if (top.cpu0.regs[10] !== 0) begin
      // check x10 for riscv-tests
      $display("failed! x10=%d, pc=%x", top.cpu0.regs[10], top.cpu0.pc);
    end
    $finish;
  end
endmodule
