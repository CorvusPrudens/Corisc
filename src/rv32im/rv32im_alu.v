`ifndef RV32IM_ALU_GUARD
`define RV32IM_ALU_GUARD

module rv32im_alu
  #(
    parameter XLEN = 32
  )
  (
    input wire clk_i,
    input wire data_ready_i,

    // For now, we'll just do all the decoding in the decode stage...
    // If it turns out that's inefficient, we'll do some decoding here
    input wire [3:0] operation_i,
    input wire [XLEN-1:0] operand1_i,
    input wire [XLEN-1:0] operand2_i,
    output reg [XLEN-1:0] result_o,

    output reg equal_o = 0,
    output reg less_o = 0,
    output reg less_signed_o = 0,

    input wire clear_i
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

  // wire equal = operand1_i == operand2_i;
  // wire less = operand1_i < operand2_i;
  // wire signed [XLEN-1:0] operand1_signed = operand1_i;
  // wire signed [XLEN-1:0] operand2_signed = operand2_i;
  // wire less_signed = operand1_signed < operand2_signed;

  // wire [XLEN-1:0] sll = operand1_i << operand2_i[4:0];
  // wire [XLEN-1:0] srl = operand1_i >> operand2_i[4:0];
  // wire [XLEN-1:0] sra = operand1_signed >>> operand2_i[4:0];

  wire shift_condition = operation_i == OP_SLL;
  wire arith_condition = operation_i == OP_SRA;

  wire [31:0] shifter_in = shift_condition ?
     {operand1_i[ 0], operand1_i[ 1], operand1_i[ 2], operand1_i[ 3], operand1_i[ 4], operand1_i[ 5],
      operand1_i[ 6], operand1_i[ 7], operand1_i[ 8], operand1_i[ 9], operand1_i[10], operand1_i[11],
      operand1_i[12], operand1_i[13], operand1_i[14], operand1_i[15], operand1_i[16], operand1_i[17],
      operand1_i[18], operand1_i[19], operand1_i[20], operand1_i[21], operand1_i[22], operand1_i[23],
      operand1_i[24], operand1_i[25], operand1_i[26], operand1_i[27], operand1_i[28], operand1_i[29],
      operand1_i[30], operand1_i[31]} : operand1_i;

   /* verilator lint_off WIDTH */
   wire [31:0] shifter =
               $signed({arith_condition & operand1_i[31], shifter_in}) >>> operand2_i[4:0];
   /* verilator lint_on WIDTH */

   wire [31:0] leftshift = {
     shifter[ 0], shifter[ 1], shifter[ 2], shifter[ 3], shifter[ 4],
     shifter[ 5], shifter[ 6], shifter[ 7], shifter[ 8], shifter[ 9],
     shifter[10], shifter[11], shifter[12], shifter[13], shifter[14],
     shifter[15], shifter[16], shifter[17], shifter[18], shifter[19],
     shifter[20], shifter[21], shifter[22], shifter[23], shifter[24],
     shifter[25], shifter[26], shifter[27], shifter[28], shifter[29],
     shifter[30], shifter[31]};

  // Use a single 33 bits subtract to do subtraction and all comparisons
  // (trick borrowed from swapforth/J1)
  wire [32:0] aluMinus = {1'b1, ~operand2_i} + {1'b0,operand1_i} + 33'b1;
  wire        less_signed  = (operand1_i[31] ^ operand2_i[31]) ? operand1_i[31] : aluMinus[32];
  wire        less = aluMinus[32];
  wire        equal  = (aluMinus[31:0] == 0);

  // TODO -- this extra logic (if clear ... if data_ready_i) is necessary because I guess we depend on
  // passing zeros through the ALU for certain things? -- pls fix
  always @(posedge clk_i) begin
    if (clear_i) begin
      result_o <= 0;
    end else if (data_ready_i) begin
      case (operation_i)
        default: result_o <= 0;
        OP_ADD:  result_o <= operand1_i + operand2_i;
        OP_SUB:  result_o <= aluMinus[XLEN-1:0];
        OP_SLT:  result_o <= {{XLEN-1{1'b0}}, less_signed};
        OP_SLTU: result_o <= {{XLEN-1{1'b0}}, less};
        OP_AND:  result_o <= operand1_i & operand2_i;
        OP_OR:   result_o <= operand1_i | operand2_i;
        OP_XOR:  result_o <= operand1_i ^ operand2_i;
        OP_SLL:  result_o <= leftshift;
        OP_SRL:  result_o <= shifter;
        OP_SRA:  result_o <= shifter;
      endcase
    end
  end

  always @(posedge clk_i) begin
    if (clear_i) begin
      equal_o <= 0;
      less_o <= 0;
      less_signed_o <= 0;
    end else if (data_ready_i) begin // these might need to not change except on data_ready_i and ~stall
      equal_o <= equal;
      less_o <= less;
      less_signed_o <= less_signed;
    end
  end

  // This will be where we want to execute conditional jumps and clear the pipeline
  // Something like...
  // always @(posedge clk_i) begin
  //   if (execute & equal & conditional)
  //     jump_signal_o <= 1'b1
  // end

  `ifdef FORMAL

    reg  timeValid_f;
    initial timeValid_f = 0;
    always @(posedge clk_i) timeValid_f <= 1;

    always @(*)
      assume(clear_i == ~timeValid_f);

    // Just simple sanity checks
    always @(posedge clk_i) begin
      if (timeValid_f & $past(timeValid_f) & $past(data_ready_i & ~clear_i)) begin
        assert(equal_o == $past(equal));
        assert(less_o == $past(less));
        assert(less_signed_o == $past(less_signed));
      end
    end

    always @(posedge clk_i) begin
      if (timeValid_f & $past(timeValid_f) & $past(clear_i)) begin
        assert(equal_o == 0);
        assert(less_o == 0);
        assert(less_signed_o == 0);
      end
    end

    // // We'll assume no data is input while stalled
    // always @(posedge clk_i) begin
    //   if (stall_o)
    //     assume(~data_ready_i);
    // end

    // Data will always travel through on a single clock, and will never be ready
    // if nothing was input
    // always @(posedge clk_i) begin
    //   if (timeValid_f & $past(data_ready_i) & ~$past(clear_i))
    //     assert(data_ready_o);
    //   if (timeValid_f & ~$past(data_ready_i) & ~$past(clear_i))
    //     assert(~data_ready_o);
    // end

    // // Responses should happen one clock after data is accepted, no stalling
    // always @(posedge clk_i) begin
    //   if (timeValid_f & ~$past(stall_o))
    //     assert(~stall_o);
    // end

    // This isn't quite right, and I don't get why

    // // Following a stall, the data should become valid
    // always @(posedge clk_i) begin
    //   if (timeValid_f & $past(stall_o) & ~stall_o)
    //     assert($past(clear_i) | data_ready_o);
    // end

  `endif

endmodule

`endif // RV32IM_ALU_GUARD
