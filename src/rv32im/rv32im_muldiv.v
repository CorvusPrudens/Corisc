`ifndef RV32IM_MULDIV_GUARD
`define RV32IM_MULDIV_GUARD

`include "rv32im_div.v"

`ifndef HARDWARE_MULTIPLY
`include "rv32im_mul.v"
`endif

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
    output reg data_ready_o,
    output reg busy_o
  );

  reg [XLEN-1:0] operand1;
  initial operand1 = 0;
  reg [XLEN-1:0] operand2;
  initial operand2 = 0;
  reg [2:0] operation;
  initial operation = 0;
  reg [1:0] op_steps;
  initial op_steps = 0;
  reg  output_ready;
  initial output_ready = 0;

  // assign data_ready_o = output_ready;

  reg [XLEN-1:0] divop1;
  initial divop1 = 0;
  reg [XLEN-1:0] divop2;
  initial divop2 = 0;
  wire [XLEN-1:0] quotient;
  wire [XLEN-1:0] remainder;
  reg  div_outsign;
  initial div_outsign = 0;

  wire [XLEN-1:0] designed_op1 = operand1[XLEN-1] ? ~operand1 + 32'b1 : operand1;
  wire [XLEN-1:0] designed_op2 = operand2[XLEN-1] ? ~operand2 + 32'b1 : operand2;
  wire [XLEN-1:0] signed_quotient = div_outsign ? ~quotient + 32'b1 : quotient;
  wire [XLEN-1:0] signed_remainder = div_outsign ? ~remainder + 32'b1 : remainder;

  reg  div_start;
  initial div_start = 0;
  wire div_busy;
  wire div_zero;
  wire div_valid;

  `ifndef HARDWARE_MULTIPLY
  reg  mul_start;
  initial mul_start = 0;
  wire mul_busy;
  wire mul_valid;

  reg mul_outsign;
  initial mul_outsign = 0;
  wire [XLEN*2-1:0] product;

  wire [XLEN-1:0] signed_product = mul_outsign ? ~product + 64'b1 : product;
  `endif

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
      data_ready_o <= 1'b0;
    end else if (data_ready_i & ~busy_o) begin
      data_ready_o <= 1'b0;
      busy_o <= 1'b1;
      operand1 <= operand1_i;
      operand2 <= operand2_i;
      operation <= operation_i;
    end else if (output_ready) begin
      data_ready_o <= 1'b1;
      busy_o <= 1'b0;
    end else begin
      data_ready_o <= 1'b0;
    end
  end

  always @(posedge clk_i) begin
    if (clear_i) begin
      output_ready <= 1'b0;
      op_steps <= 0;
    end else if (busy_o) begin
      case ({op_steps, operation})
        `ifdef HARDWARE_MULTIPLY
        default: // MUL
          begin
            result_o <= operand1 * operand2;
            output_ready <= 1'b1;
          end
        `else
        default: output_ready <= 1'b1; // errors silently passed
        {2'b00, MUL}: 
          begin
            mul_outsign <= operand1[XLEN-1] ^ operand2[XLEN-1];
            mul_start <= 1'b1;
            op_steps <= op_steps + 1'b1;
          end
        {2'b01, MUL}:
          begin
            mul_start <= 1'b0;
            if (mul_valid) begin
              result_o <= signed_product[XLEN-1:0];
              output_ready <= 1'b1;
            end
          end
        `endif
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
            div_start <= 1'b0;
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
            div_start <= 1'b0;
            if (div_valid) begin
              result_o <= quotient;
              output_ready <= 1'b1;
            end
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
            div_start <= 1'b0;
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
            div_start <= 1'b0;
            if (div_valid) begin
              result_o <= remainder;
              output_ready <= 1'b1;
            end
          end
      endcase
    end else begin
      output_ready <= 1'b0;
      op_steps <= 0;
    end
  end

  `ifndef HARDWARE_MULTIPLY
  rv32im_mul #(
    .XLEN(XLEN)
  ) RV32IM_MUL (
    .clk_i(clk_i),
    .reset_i(clear_i),
    .start_i(mul_start),
    .busy_o(mul_busy),
    .valid_o(mul_valid),
    .operand1_i(designed_op1),
    .operand2_i(designed_op2),
    .product_o(product)
  );
  `endif

  rv32im_div #(
    .WIDTH(XLEN)
  ) RV32IM_DIV (
    .clk_i(clk_i),
    .clear_i(clear_i),
    .start(div_start),
    .busy(div_busy),
    .valid(div_valid),
    .dbz(div_zero),
    .x(divop1),
    .y(divop2),
    .q(quotient),
    .r(remainder)
  );

  `ifdef FORMAL
    reg  timeValid_f;
    initial timeValid_f = 0;
    always @(posedge clk_i) timeValid_f <= 1;

    initial assume(clear_i);

    always @(*)
      if (~timeValid_f)
        assume(clear_i);

    // Ensuring clear will always perform its job
    always @(posedge clk_i) begin
      if (timeValid_f & $past(clear_i)) begin
        assert(busy_o == 0);
        assert(output_ready == 0);
        assert(op_steps == 0);
        assert(div_busy == 0);
        assert(div_valid == 0);
      end
    end

    // always @(*)
    //   if (busy_o) 
    //     assume(~data_ready_i);

    always @(posedge clk_i) begin
      if (timeValid_f & data_ready_o)
        assert(busy_o == 0);
    end


  `endif
  
endmodule

`endif // RV32IM_MULDIV_GUARD
