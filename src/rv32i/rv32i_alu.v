`ifndef RV32I_ALU_GUARD
`define RV32I_ALU_GUARD

module rv32i_alu
  #(
    parameter XLEN = 32
  )
  (
    input wire clk_i,
    
    input wire [3:0] operation_i,
    input wire [XLEN-1:0] operand1_i,
    input wire [XLEN-1:0] operand2_i,

    output wire equal_o,
    output wire less_o,
    output wire less_signed_o,
    output reg [XLEN-1:0] result_o
  );

  localparam OP_ADD  = 4'b0000;
  localparam OP_SUB  = 4'b1000;
  localparam OP_SLT  = 4'b0010;
  localparam OP_SLTU = 4'b0011;
  localparam OP_AND  = 4'b0111;
  localparam OP_OR   = 4'b0110;
  localparam OP_XOR  = 4'b0100;
  localparam OP_SLL  = 4'b0001;
  localparam OP_SRL  = 4'b0101;
  localparam OP_SRA  = 4'b1101;

  reg [XLEN-1:0] op1;
  reg [XLEN-1:0] op2;

  always @(posedge clk_i) begin
    op1 <= operand1_i;
    op2 <= operand2_i;
  end

  wire [XLEN-1:0] add = op1 + op2;
  wire [XLEN-1:0] sub = op1 - op2;

  assign equal_o = op1 == op2;

  assign less_o = op1 < op2;
  wire signed [XLEN-1:0] operand1_signed = op1;
  wire signed [XLEN-1:0] operand2_signed = op2;
  assign less_signed_o = operand1_signed < operand2_signed;

  wire [XLEN-1:0] slt = {{XLEN-1{1'b0}}, less_o};
  wire [XLEN-1:0] sltu = {{XLEN-1{1'b0}}, less_signed_o};

  wire [XLEN-1:0] and_ = op1 & op2;
  wire [XLEN-1:0] or_ = op1 | op2;
  wire [XLEN-1:0] xor_ = op1 ^ op2;

  wire [XLEN-1:0] sll = op1 << op2[4:0];
  wire [XLEN-1:0] srl = op1 >> op2[4:0];
  wire [XLEN-1:0] sra = op1 >>> op2[4:0];

  always @(*) begin
    case (operation_i)
      default: result_o = 0;
      OP_ADD:  result_o = add;
      OP_SUB:  result_o = sub;
      OP_SLT:  result_o = slt;
      OP_SLTU: result_o = sltu;
      OP_AND:  result_o = and_;
      OP_OR:   result_o = or_;
      OP_XOR:  result_o = xor_;
      OP_SLL:  result_o = sll;
      OP_SRL:  result_o = srl;
      OP_SRA:  result_o = sra;
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
      if (operation_i == OP_SLT)
        assert(result_o == op1_val < op2_val);
      if (operation_i == OP_SLTU)
        assert(result_o == op1_val < op2_val);
      if (operation_i == OP_AND)
        assert(result_o == op1_val & op2_val);
      if (operation_i == OP_OR)
        assert(result_o == op1_val | op2_val);
      if (operation_i == OP_XOR)
        assert(result_o == op1_val ^ op2_val);
      if (operation_i == OP_SLL)
        assert(result_o == op1_val << op2_val[4:0]);
      if (operation_i == OP_SRL)
        assert(result_o == op1_val >> op2_val[4:0]);
      if (operation_i == OP_SRA)
        assert(result_o == op1_val >>> op2_val[4:0]);
      
      assert(less_o == op1_val < op2_val);
    end

  `endif

endmodule

`endif // RV32I_ALU_GUARD
