`ifndef STACK_GUARD
`define STACK_GUARD

`include "bram.v"

module stack
  #(
    parameter XLEN = 32,
    parameter SIZE = 7
  )
  (
    input wire clk_i,
    input wire push_i,
    input wire pop_i,

    input wire [XLEN-1:0] data_i,
    output wire [XLEN-1:0] data_o,
    output wire overflow_o
  );

  reg [SIZE:0] index = 0;
  assign overflow_o = index[SIZE];

  wire [1:0] index_state = {pop_i, push_i};
  always @(posedge clk_i) begin
    case (index_state)
      default: ;
      2'b01: index <= index[SIZE-1:0] + 1'b1;
      2'b10: index <= index == 0 ? 0 : index - 1'b1;
      2'b11: index <= index == 0 ? index + 1'b1 : index; // sneaky this one is!
    endcase
  end

  bram #(
    .memSize_p(SIZE),
    .dataWidth_p(XLEN)
  ) BRAM (
    .clk_i(clk_i),
    .write_i(push_i),
    .data_i(data_i),
    .addr_i(index),
    .data_o(data_o)
  );

endmodule

`endif // STACK_GUARD
