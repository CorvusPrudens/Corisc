`ifndef RV32IM_MULDIV_GUARD
`define RV32IM_MULDIV_GUARD

`include "rv32im_div.v"

module rv32im_muldiv #(
    XLEN = 32
  ) (
    input wire clk_i,
    input wire [2:0] operation_i
  );

  localparam MUL    = 3'b000;
  localparam MULH   = 3'b001;
  localparam MULHSU = 3'b010;
  localparam MULHU  = 3'b011;
  localparam DIV    = 3'b100;
  localparam DIVU   = 3'b101;
  localparam REM    = 3'b110;
  localparam REMU   = 3'b111;


  
endmodule

`endif // RV32IM_MULDIV_GUARD