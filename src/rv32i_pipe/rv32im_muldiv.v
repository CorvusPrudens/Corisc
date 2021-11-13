`ifndef RV32IM_MULDIV_GUARD
`define RV32IM_MULDIV_GUARD

`include "rv32im_div.v"

module rv32im_muldiv #(
    XLEN = 32
  ) (
    input wire clk_i,
    input wire clear_i,
    input wire [2:0] operation_i,
    input wire data_ready_i,
    input wire [XLEN-1:0] operand1_i,
    input wire [XLEN-1:0] operand2_i,
    output reg [XLEN-1:0] result_o,
    output wire data_ready_o,
    output reg busy_o
  );

  reg [XLEN-1:0] operand1;
  reg [XLEN-1:0] operand2;
  reg [2:0] operation;
  reg [1:0] op_steps;
  reg output_ready;

  assign data_ready_o = output_ready;

  reg [XLEN-1:0] divop1;
  reg [XLEN-1:0] divop2;
  wire [XLEN-1:0] quotient;
  wire [XLEN-1:0] remainder;
  reg div_outsign;

  wire [XLEN-1:0] designed_op1 = operand1[XLEN-1] ? ~operand1 + 32'b1 : operand1;
  wire [XLEN-1:0] designed_op2 = operand2[XLEN-1] ? ~operand2 + 32'b1 : operand2;
  wire [XLEN-1:0] signed_quotient = quotient[XLEN-1] ? ~quotient + 32'b1 : quotient;
  wire [XLEN-1:0] signed_remainder = remainder[XLEN-1] ? ~remainder + 32'b1 : remainder;

  reg div_start;
  wire div_busy;
  wire div_zero;
  wire div_valid;

  localparam MUL    = 3'b000;
  localparam MULH   = 3'b001; // I'm just gonna ignore these for now since I don't find them very useful
  localparam MULHSU = 3'b010;
  localparam MULHU  = 3'b011;
  localparam DIV    = 3'b100;
  localparam DIVU   = 3'b101;
  localparam REM    = 3'b110;
  localparam REMU   = 3'b111;

  // Extra cycles are taken in feeding data to each operation.
  // I'm not too worried about it since this is so much faster than 
  // software calculations anyway
  always @(posedge clk_i) begin
    if (clear_i) begin
      busy_o <= 1'b0;
    end else if (data_ready_i & ~busy_o) begin
      busy_o <= 1'b1;
      operand1 <= operand1_i;
      operand2 <= operand2_i;
      operation <= operation_i;
    end else if (output_ready)
      busy_o <= 1'b0;
  end

  always @(posedge clk_i) begin
    if (clear_i) begin
      output_ready <= 1'b0;
      op_steps <= 0;
    end else if (busy_o) begin
      case ({op_steps, operation})
        default: // MUL
          begin
            result_o <= operand1 * operand2;
            output_ready <= 1'b1;
          end
        {2'b00, DIV}:
          begin
            divop1 <= designed_op1;
            divop2 <= designed_op2;
            div_outsign <= operand1[XLEN-1] ^ operand2[XLEN-1];
            div_start <= 1'b1;
            op_steps <= op_steps + 1'b1;
          end
        {2'b01, DIV}:
          begin
            if (div_valid) begin
              result_o <= signed_quotient;
              output_ready <= 1'b1;
            end
          end
        {2'b00, DIVU}:
          begin
            divop1 <= operand1;
            divop2 <= operand2;
            div_start <= 1'b1;
            op_steps <= op_steps + 1'b1;
          end
        {2'b01, DIVU}:
          begin
            result_o <= quotient;
            output_ready <= 1'b1;
          end
        {2'b00, REM}:
          begin
            divop1 <= designed_op1;
            divop2 <= designed_op2;
            div_outsign <= operand1[XLEN-1] ^ operand2[XLEN-1];
            div_start <= 1'b1;
            op_steps <= op_steps + 1'b1;
          end
        {2'b01, REM}:
          begin
            if (div_valid) begin
              result_o <= signed_remainder;
              output_ready <= 1'b1;
            end
          end
        {2'b00, REMU}:
          begin
            divop1 <= operand1;
            divop2 <= operand2;
            div_start <= 1'b1;
            op_steps <= op_steps + 1'b1;
          end
        {2'b01, REMU}:
          begin
            result_o <= remainder;
            output_ready <= 1'b1;
          end
      endcase
    end else begin
      output_ready <= 1'b0;
      op_steps <= 0;
    end
  end

  rv32im_div #(
    .WIDTH(XLEN)
  ) RV32IM_DIV (
    .clk_i(clk_i),
    .start(div_start),
    .busy(div_busy),
    .valid(div_valid),
    .dbz(div_zero),
    .x(divop1),
    .y(divop2),
    .q(quotient),
    .r(remainder)
  );
  
endmodule

`endif // RV32IM_MULDIV_GUARD