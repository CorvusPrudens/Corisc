`ifndef UARTWRAPPER_GUARD
`define UARTWRAPPER_GUARD

`include "uart.v"
`include "fifo.v"

module uartwrapper(
    input wire clk_i,
    input wire [7:0] data_i,
    input wire write_i,
    input wire read_i,

    output wire [7:0] data_o,
    output wire [7:0] status_o,
    // output wire full, empty,

    input wire RX,
    output wire TX
  );

  wire uartread;
  wire [7:0] uartin;
  wire [7:0] uartout;
  wire uartoutwrite;
  wire TXbusy;
  wire outfull;

  wire TXfull;
  wire TXempty;
  wire RXfull;
  wire RXempty;
  reg sendRead = 1'b0;

  assign status_o = {4'b0, RXempty, RXfull, TXempty, TXfull};

  fifo #(
      // this equates to a single bram
      .memSize_p(9),
      .dataWidth_p(8)
    ) INFIFO(
      .clk_i(clk_i),
      .data_i(data_i),
      .write_i(write_i),
      .read_i(sendRead),
      .data_o(uartin),
      .full_o(TXfull),
      .empty_o(TXempty)
    );

  reg sendState = 1'b0;

  reg TXstart = 1'b0;

  always @(posedge clk_i) begin
    case (sendState)
      1'b0:
        begin
          TXstart <= 1'b0;
          if (~TXempty & ~TXbusy) begin
            sendRead <= 1'b1;
            sendState <= 1'b1;
          end
        end
      1'b1:
        begin
          sendRead <= 1'b0;
          TXstart <= 1'b1;
          sendState <= 1'b0;
        end
    endcase
  end


  uart UART(
      .clk_i(clk_i),
      .RX(RX),
      .TX(TX),
      .TXbuffer_i(uartin),
      .TXstart_i(TXstart),
      .RXbuffer_o(uartout),
      .RXready_o(uartoutwrite),
      .TXbusy_o(TXbusy)
    );


  fifo #(
      // this equates to a single bram
      .memSize_p(9),
      .dataWidth_p(8)
    ) OUTFIFO (
      .clk_i(clk_i),
      .data_i(uartout),
      .write_i(uartoutwrite),
      .read_i(read_i & ~RXempty),
      .data_o(data_o),
      .full_o(RXfull),
      .empty_o(RXempty)
    );

endmodule
`endif // UARTWRAPPER_GUARD
