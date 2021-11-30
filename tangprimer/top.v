module led_ctrl(
  input clk,
  input rst_n,
  input en,
  input [31:0] d,
  input [3:0] we,
  output [31:0] q,
  output [2:0] out
);

  reg [2:0] led_reg;
  assign q = {29'b0, led_reg};
  assign out = led_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      led_reg <= 3'b0;
    else begin
      if (en) begin
        if (we == 4'b1111)
          led_reg <= d[2:0];
      end
    end
  end

endmodule

module top(
  input clk,
  input rst_n,
  output [2:0] rgb_led
);
  wire rst = ~rst_n;

  wire [31:0] imem_addr, imem_q, dmem_addr, dmem_d;
  wire [3:0] dmem_we;
  wire dmem_en;

  wire [31:0] ram0_q, ledctrl_q;
  reg [31:0] dmem_q;

  wire [12:0] rom0_addr = imem_addr[14:2];
  wire [12:0] ram0_addr = dmem_addr[14:2];

  `define DEV_RAM0 9'b01
  `define DEV_LED 9'b10

  wire [8:0] dev_sel = dmem_addr[31:23];

  // 0x800000 - 0x808000 : RAM
  // 0x1000000 : RGBLED

  wire ram0_en = dmem_en && dev_sel == `DEV_RAM0;
  wire ledctrl_en = dmem_en && dev_sel == `DEV_LED;

  always @(*) begin
    case (dev_sel)
      `DEV_RAM0: begin
        dmem_q = ram0_q;
      end
      `DEV_LED: begin
        dmem_q = ledctrl_q;
      end
      default: dmem_q = 32'bx;
    endcase
  end

  rom0 rom0(imem_q, rom0_addr, clk, rst);
  ram0 ram0(ram0_q, dmem_d, ram0_addr, ram0_en, clk, dmem_we);
  wire [2:0] dummy;
  led_ctrl ledctrl(clk, rst_n, ledctrl_en, dmem_d, dmem_we, ledctrl_q, dummy);

  wire [31:0] cpu_pc;
  assign rgb_led = cpu_pc == 32'h8 ? 3'b101 : 3'b110;
  rvcpu cpu0(clk, rst_n, imem_addr, imem_q, dmem_en, dmem_addr, dmem_d, dmem_we, dmem_q, cpu_pc);

endmodule
