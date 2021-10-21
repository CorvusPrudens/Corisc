`ifndef RV32I_ALU_GUARD
`define RV32I_ALU_GUARD

module rv32i_alu
  #(
    parameter XLEN = 32
  )
  (
    input wire clk_i,
    
    input wire [9:0] operation_i,
    input wire [XLEN-1:0] operand1_i,
    input wire [XLEN-1:0] operand2_i,

    output wire equal_o,
    output wire less_o,
    output wire less_signed_o,
    output reg [XLEN-1:0] result_o
  );

  localparam OP_ADD  = 10'b00_0000_0001;
  localparam OP_SUB  = 10'b00_0000_0010;
  localparam OP_SLT  = 10'b00_0000_0100;
  localparam OP_SLTU = 10'b00_0000_1000;
  localparam OP_AND  = 10'b00_0001_0000;
  localparam OP_OR   = 10'b00_0010_0000;
  localparam OP_XOR  = 10'b00_0100_0000;
  localparam OP_SLL  = 10'b00_1000_0000;
  localparam OP_SRL  = 10'b01_0000_0000;
  localparam OP_SRA  = 10'b10_0000_0000;

  // TODO -- a combinational and gated version should be tested for speed!
  wire [XLEN-1:0] add = operand1_i + operand2_i;
  wire [XLEN-1:0] sub = operand1_i - operand2_i;

  assign equal_o = operand1_i == operand2_i;

  assign less_o = operand1_i < operand2_i;
  signed wire [XLEN-1:0] operand1_signed = operand1_i;
  signed wire [XLEN-1:0] operand2_signed = operand2_i;
  assign less_signed_o = operand1_signed < operand2_signed;

  wire [XLEN-1:0] slt = {(XLEN-1){1'b0}, less_o};
  wire [XLEN-1:0] sltu = {(XLEN-1){1'b0}, less_signed_o};

  wire [XLEN-1:0] and_ = operand1_i & operand2_i;
  wire [XLEN-1:0] or_ = operand1_i | operand2_i;
  wire [XLEN-1:0] xor_ = operand1_i ^ operand2_i;

  wire [XLEN-1:0] sll = operand1_i << operand2_i[4:0];
  wire [XLEN-1:0] srl = operand1_i >> operand2_i[4:0];
  wire [XLEN-1:0] sra = operand1_i >>> operand2_i[4:0];

  always @(*) begin
    case (operation_i)
      default: result_o = 0;
      OP_ADD: result_o = add;
      OP_SUB: result_o = sub;
      OP_SLT: result_o = slt;
      OP_SLTU: result_o = sltu;
      OP_AND: result_o = and_;
      OP_OR: result_o = or_;
      OP_XOR: result_o = xor_;
      OP_SLL: result_o = sll;
      OP_SRL: result_o = srl;
      OP_SRA: result_o = sra;
    endcase
  end

  `ifdef FORMAL
    reg timeValid_f = 0;
    always @(posedge clk_i) timeValid_f <= 1;

    localparam op1_val = 1;
    localparam op2_val = 5;

    always @(*) begin
      assume(operand1_i == op1_val);
      assume(operand2_i == op2_val);
    end

    always @(*) begin
      if (operation_i == OP_ADD)
        assert(result_o == op1_val + op2_val);
      if (operation_i == OP_SUB)
        assert(result_o == op1_val - op2_val);
    end

  `endif

endmodule

`endif // RV32I_ALU_GUARD
