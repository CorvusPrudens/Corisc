`ifndef RV32IM_MUL_GUARD
`define RV32IM_MUL_GUARD

module rv32im_mul #(
    parameter XLEN = 32
  ) (
    input wire clk_i,
    input wire reset_i,
    input wire start_i,
    output reg busy_o,
    output reg valid_o,

    input wire [XLEN-1:0] operand1_i,
    input wire [XLEN-1:0] operand2_i,
    output reg [XLEN*2-1:0] product_o
  );

  localparam XLEN_FULL = XLEN*2;
  reg [XLEN-1:0] operand1;
  reg [XLEN-1:0] operand2;
  reg [$clog2(XLEN):0] counter; // NOTE -- requires inputs to be powers of two!
  wire [$clog2(XLEN):0] counter_p1 = counter + 1;

  always @(posedge clk_i) begin
    if (reset_i) begin
      busy_o <= 1'b0;
      valid_o <= 1'b0;
    end else if (start_i) begin
      busy_o <= 1'b1;
      valid_o <= 1'b0;
      counter <= 0;
    end else if (busy_o) begin
      counter <= counter + 1'b1;
      if (counter_p1[$clog2(XLEN)]) begin
        valid_o <= 1'b1;
        busy_o <= 1'b0;
      end
    end else begin
      valid_o <= 1'b0;
    end
  end

  always @(posedge clk_i) begin
    if (start_i) begin // NOTE -- requires 1-clock start signal
      product_o[XLEN_FULL-1:XLEN] <= 0;
      operand1 <= operand1_i;
      operand2 <= operand2_i;
    end else if (busy_o) begin
      operand2 <= {1'b0, operand2[XLEN-1:1]};
      product_o <= {1'b0, product_o[XLEN_FULL-1:1]};
      if (operand2[0])
        product_o[XLEN_FULL-1:XLEN-1] <= {1'b0, product_o[XLEN_FULL-1:XLEN]} + operand1;
    end
  end

endmodule

`endif
