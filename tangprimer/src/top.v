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

module uart_ctrl(
  input clk,
  input rst_n,
  input en,
  input [31:0] addr,
  input [31:0] d,
  input [3:0] we,
  output reg [31:0] q,
  input uart0_rx,
  output uart0_tx
);

  // +0: UART0_CTRL
  //   bit 0: rx_valid (r)
  //   bit 1: reserved
  //   bit 2: tx_ready (r)
  //   bit 3: tx_run   (w)
  // +4: UART0_RXD (r)
  // +8: UART0_TXD (r/w)

  wire uart0_rx_valid, uart0_tx_ready;
  reg uart0_tx_run;
  wire [7:0] uart0_rx_data;
  reg [7:0] uart0_tx_data;

  uart_receiver uart0_receiver(clk, rst_n, uart0_rx, uart0_rx_valid, uart0_rx_data);
  uart_transmitter uart0_transmitter(clk, rst_n, uart0_tx, uart0_tx_ready, uart0_tx_run, uart0_tx_data);

  always @(*) begin
    case (addr[22:0])
      23'h0: q = {29'b0, uart0_tx_ready, 1'b0, uart0_rx_valid};
      23'h4: q = {24'b0, uart0_rx_data};
      23'h8: q = {24'b0, uart0_tx_data};
      default: q = 32'bx;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      uart0_tx_run <= 1'b0;
    end
    else begin
      uart0_tx_run <= 1'b0;
      if (en) begin
        if (we[0]) begin
          case (addr[22:0])
            23'h0: uart0_tx_run <= d[3];
            23'h8: uart0_tx_data <= d[7:0];
          endcase
        end
      end
    end
  end

endmodule

module top(
  input clk,
  input rst_n,
  output [2:0] rgb_led,
  input uart0_rx,
  output uart0_tx
);
  wire rst = ~rst_n;

  wire [31:0] imem_addr, imem_q, dmem_addr, dmem_d;
  wire [3:0] dmem_we;
  wire dmem_en;

  wire [31:0] ram0_q, ledctrl_q, uartctrl_q;
  reg [31:0] dmem_q;

  wire [12:0] rom0_addr = imem_addr[14:2];
  wire [12:0] ram0_addr = dmem_addr[14:2];

  `define DEV_RAM0 9'b01
  `define DEV_LED 9'b10
  `define DEV_UART 9'b11

  wire [8:0] dev_sel = dmem_addr[31:23];

  // 0x800000 - 0x808000 : RAM
  // 0x1000000 : RGBLED
  // 0x1800000 : UART

  wire ram0_en = dmem_en && dev_sel == `DEV_RAM0;
  wire ledctrl_en = dmem_en && dev_sel == `DEV_LED;
  wire uartctrl_en = dmem_en && dev_sel == `DEV_UART;

  always @(*) begin
    case (dev_sel)
      `DEV_RAM0: begin
        dmem_q = ram0_q;
      end
      `DEV_LED: begin
        dmem_q = ledctrl_q;
      end
      `DEV_UART: begin
        dmem_q = uartctrl_q;
      end
      default: dmem_q = 32'bx;
    endcase
  end

  rom0 rom0(imem_q, rom0_addr, clk, rst);
  ram0 ram0(ram0_q, dmem_d, ram0_addr, ram0_en, clk, dmem_we);
  led_ctrl ledctrl(clk, rst_n, ledctrl_en, dmem_d, dmem_we, ledctrl_q, rgb_led);
  uart_ctrl uartctrl(clk, rst_n, uartctrl_en, dmem_addr, dmem_d, dmem_we, uartctrl_q, uart0_rx, uart0_tx);

  rvcpu cpu0(clk, rst_n, imem_addr, imem_q, dmem_en, dmem_addr, dmem_d, dmem_we, dmem_q);

endmodule
