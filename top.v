module imem(
  input clk,
  input [31:0] addr,
  output reg [31:0] q
);
  reg [31:0] rom[0:8192-1];

  always @(posedge clk) begin
    q <= rom[addr];
  end

  initial begin
    $readmemh("imem.txt", rom);
  end
endmodule

module dmem(
  input clk,
  input en,
  input [31:0] addr,
  input [31:0] d,
  input [3:0] we,
  output reg [31:0] q
);
  reg [31:0] ram[0:4096-1];

  reg [7:0] d0, d1, d2, d3;

  wire is_dmem_addr = (addr[31:23] == 9'b1);
  wire [31:0] paddr = {9'b0, addr[22:0]};

  always @(*) begin
    d0 = we[0] ? d[7:0] : ram[paddr][7:0];
    d1 = we[1] ? d[15:8] : ram[paddr][15:8];
    d2 = we[2] ? d[23:16] : ram[paddr][23:16];
    d3 = we[3] ? d[31:24] : ram[paddr][31:24];
  end

  always @(posedge clk) begin
    if (en && is_dmem_addr) begin
      ram[paddr] <= {d3, d2, d1, d0};
      q <= ram[paddr];
    end
  end

  initial begin
    $readmemh("dmem.txt", ram);
  end
endmodule

module top(
  input clk,
  input rst_n,
  output halted
);
  wire [31:0] imem_addr, imem_q, dmem_addr, dmem_d, dmem_q;
  wire [3:0] dmem_we;
  wire dmem_en;

  imem imem0(clk, imem_addr, imem_q);
  dmem dmem0(clk, dmem_en, dmem_addr, dmem_d, dmem_we, dmem_q);
  rvcpu cpu0(clk, rst_n, imem_addr, imem_q, dmem_en, dmem_addr, dmem_d, dmem_we, dmem_q, halted);
endmodule
