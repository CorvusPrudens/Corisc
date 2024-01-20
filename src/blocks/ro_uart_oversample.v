`ifndef UART_OVERSAMPLE_GUARD
`define UART_OVERSAMPLE_GUARD
// 8 data bits, 1 stop bit, no parity

module ro_uart_oversample (
    input wire clk_i,
    input wire RX,

    output reg [7:0] RXbuffer_o = 0,
    output reg RXready_o = 0,

    input wire [15:0] compare
  );

  // RECIEVER

  reg [3:0] RXstate = 0;
  reg [13:0] rx_acc = 0;

  reg [2:0] rx_oversample = 0;
  wire rx_tick = rx_oversample[2];

  always @(posedge clk_i) begin

    case (RXstate)
      4'b0000: if (~RX)     RXstate <= 4'b0001; // start bit found
      4'b0001: if (rx_tick) RXstate <= 4'b1000; // start bit found
      4'b1000: if (rx_tick) RXstate <= 4'b1001; // bit 0
      4'b1001: if (rx_tick) RXstate <= 4'b1010; // bit 1
      4'b1010: if (rx_tick) RXstate <= 4'b1011; // bit 2
      4'b1011: if (rx_tick) RXstate <= 4'b1100; // bit 3
      4'b1100: if (rx_tick) RXstate <= 4'b1101; // bit 4
      4'b1101: if (rx_tick) RXstate <= 4'b1110; // bit 5
      4'b1110: if (rx_tick) RXstate <= 4'b1111; // bit 6
      4'b1111: if (rx_tick) RXstate <= 4'b0010; // bit 7
      4'b0010: if (rx_tick) RXstate <= 4'b0000; // stop bit
      default: RXstate <= 4'b0000;
    endcase

    if (RXstate == 4'b0000) rx_acc <= 0;
    else begin
      if (rx_acc == compare[15:2]) begin

        // Skip a beat after the start bit so we sample
        // the middle of each subsequent bit.
        if (RXstate == 4'b0001 && rx_oversample[1:0] == 2'b11) begin
          rx_oversample <= 3'b110;
        end else begin
           rx_oversample <= rx_oversample + 1'b1;
        end

        rx_acc <= 0;
      end else begin
        rx_oversample[2] <= 1'b0;
        rx_acc <= rx_acc + 1'b1;
      end
    end

    if (rx_tick && RXstate[3]) RXbuffer_o <= {RX, RXbuffer_o[7:1]};
    RXready_o <= (rx_tick && RXstate == 4'b0001);
  end

endmodule
`endif // UART_OVERSAMPLE_GUARD
