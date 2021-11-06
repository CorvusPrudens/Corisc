
module decode_tb(
    input wire clk_i
  );

  localparam XLEN = 32;
  localparam ILEN = 32;
  localparam REG_BITS = 5;

  localparam MEM_BITS = 5;
  reg [ILEN-1:0] memory [31:0];
  initial memory = $readmemh("decode_tb.hex");

  // Inputs
  reg clear_pipeline = 0;
  reg [ILEN-1:0] instruction = 0;
  reg [XLEN-1:0] pc = 0;
  reg decode_ce = 0;

  // Outputs
  wire [3:0] alu_operation;
  wire [2:0] word_size;
  wire [REG_BITS-1:0] rs1_addr;
  wire [REG_BITS-1:0] rs2_addr;
  wire [REG_BITS-1:0] rd_addr;
  wire [XLEN-1:0] immediate;
  wire [XLEN-1:0] decode_pc;

  rv32i_decode #(
    .XLEN(32),
    .ILEN(32),
    .REG_BITS(5)
  ) RV32I_DECODE (
    .clk_i(clk_i),
    .clear_i(clear_pipeline),
    .instruction_i(instruction),
    .data_ready_i(decode_ce),
    .alu_operation_o(alu_operation),
    .word_size_o(word_size),
    .rs1_addr_o(rs1_addr),
    .rs2_addr_o(rs2_addr),
    .rd_addr_o(rd_addr),
    .immediate_o(immediate),
    .pc_data_in(pc),
    .pc_data_o(decode_pc)
  );

  always @(posedge clk_i) begin
    instruction <= memory[pc[MEM_BITS+1:2]];
    pc <= pc + 4;
    decode_ce <= 1'b1;
  end
  

endmodule
