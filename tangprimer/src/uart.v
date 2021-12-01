module uart_receiver(
  input wire clock,
  input wire reset_n,
  input wire rxd,
  output wire rx_valid,
  output reg [7:0] rx_data
);

  parameter WAITING = 1'b0;
  parameter RECEIVING = 1'b1;

  parameter HZ = 25'd24_000_000;
  parameter BAUDRATE = 25'd9_600;
  parameter BIT_WAIT_COUNT = HZ / BAUDRATE;
  parameter START_WAIT_COUNT = BIT_WAIT_COUNT + (BIT_WAIT_COUNT / 2);

  reg state;
  reg [24:0] count;
  reg [2:0] rx_count;

  assign rx_valid = (rx_count == 3'd7 && state == WAITING);

  always @(posedge clock or negedge reset_n) begin
    if (reset_n == 0) begin
      state <= WAITING;
      count <= 0;
    end
    else
      case (state)
        WAITING: begin
          rx_count <= 0;
          if (count != 0)
            count <= count - 1;
          else if (rxd == 0) begin
            state <= RECEIVING;
            count <= START_WAIT_COUNT;
          end
        end
        RECEIVING:
          if (count == 0) begin
            rx_data <= {rxd, rx_data[7:1]};
            count <= BIT_WAIT_COUNT;
            if (rx_count == 3'd7)
              state <= WAITING;
            else
              rx_count <= rx_count + 1;
          end
          else
            count <= count - 1;
      endcase
  end

endmodule

module uart_transmitter (
  input wire clock,
  input wire reset_n,
  output wire txd,
  output wire tx_ready,
  input wire tx_run,
  input wire [7:0] tx_data
);

  parameter WAITING = 2'b00;
  parameter START_SENDING = 2'b01;
  parameter DATA_SENDING = 2'b10;
  parameter STOP_SENDING = 2'b11;

  parameter HZ = 25'd24_000_000;
  parameter BAUDRATE = 25'd9_600;
  parameter BIT_WAIT_COUNT = HZ / BAUDRATE;

  reg [1:0] state;
  reg [2:0] tx_count;
  reg [7:0] data;
  reg [24:0] count;

  assign tx_ready = (state == WAITING);
  assign txd = (state == WAITING || state == STOP_SENDING) ? 1 : (state == START_SENDING ? 0 : data[0]);

  always @(posedge clock or negedge reset_n) begin
    if (reset_n == 0) begin
      state <= WAITING;
      tx_count <= 0;
      count <= 0;
    end
    else
      if (count == 0)
        case (state)
          WAITING:
            if (tx_run) begin
              state <= START_SENDING;
              tx_count <= 0;
              data <= tx_data;
              count <= BIT_WAIT_COUNT;
            end
          START_SENDING: begin
            state <= DATA_SENDING;
            count <= BIT_WAIT_COUNT;
          end
          DATA_SENDING: begin
            count <= BIT_WAIT_COUNT;
            if (tx_count == 3'd7)
              state <= STOP_SENDING;
            else begin
              tx_count <= tx_count + 1;
              data <= {1'b0, data[7:1]};
            end
          end
          STOP_SENDING:
            state <= WAITING;
        endcase
      else
        count <= count - 1;
  end

endmodule
