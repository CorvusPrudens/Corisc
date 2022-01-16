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

    output reg equal_o,
    output reg less_o,
    output reg less_signed_o,

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

  wire equal = operand1_i == operand2_i;
  wire less = operand1_i < operand2_i;
  wire signed [XLEN-1:0] operand1_signed = operand1_i;
  wire signed [XLEN-1:0] operand2_signed = operand2_i;
  wire less_signed = operand1_signed < operand2_signed;

  wire [XLEN-1:0] sll = operand1_i << operand2_i[4:0];
  wire [XLEN-1:0] srl = operand1_i >> operand2_i[4:0];
  wire [XLEN-1:0] sra = operand1_signed >>> operand2_i[4:0];

  // TODO -- this extra logic (if clear ... if data_ready_i) is necessary because I guess we depend on
  // passing zeros through the ALU for certain things? -- pls fix
  always @(posedge clk_i) begin
    if (clear_i) begin
      result_o <= 0;
    end else if (data_ready_i) begin
      case (operation_i)
        default: result_o <= 0;
        OP_ADD:  result_o <= operand1_i + operand2_i;
        OP_SUB:  result_o <= operand1_i - operand2_i; 
        OP_SLT:  result_o <= {{XLEN-1{1'b0}}, less_signed};
        OP_SLTU: result_o <= {{XLEN-1{1'b0}}, less};
        OP_AND:  result_o <= operand1_i & operand2_i;
        OP_OR:   result_o <= operand1_i | operand2_i;
        OP_XOR:  result_o <= operand1_i ^ operand2_i;
        OP_SLL:  result_o <= sll;
        OP_SRL:  result_o <= srl;
        OP_SRA:  result_o <= sra;
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
