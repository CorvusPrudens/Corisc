`ifndef RV32I_PIPE_GUARD
`define RV32I_PIPE_GUARD

`include "rv32_alu_pipe.v"

module rv32i_pipe
  #(
    parameter XLEN = 32,
    parameter REG_BITS = 5
  )
  (
    input wire reset_i
  );

  wire clear_pipeline;

  // TODO -- For now, the program memory could be self-contained, making the
  // instruction caching unnecessary for the moment.
  // Obviously we'll need to figure that out later

  //////////////////////////////////////////////////////////////
  // Instruction decode signals
  //////////////////////////////////////////////////////////////

  wire [XLEN-1:0] decode_immediate_data;
  wire decode_data_ready_o;
  wire [3:0] alu_operation_decode;
  wire decode_immediate;
  wire [REG_BITS-1:0] decode_rd_addr;
  wire [REG_BITS-1:0] decode_rs1_addr;
  wire [REG_BITS-1:0] decode_rs2_addr;

  //////////////////////////////////////////////////////////////
  // register signals
  //////////////////////////////////////////////////////////////

  wire registers_write;
  wire [REG_BITS-1:0] rs1_addr;
  wire [REG_BITS-1:0] rs2_addr;
  wire [REG_BITS-1:0] rd_addr;
  wire [XLEN-1:0] rs1;
  wire [XLEN-1:0] rs2;
  wire [XLEN-1:0] registers_in;
  wire push_ras;
  wire pop_ras;

  rv32i_registers_pipe #(
    .XLEN          (XLEN),
    .REG_BITS      (REG_BITS)
  ) u_rv32i_registers_pipe (
    .clk_i         (clk_i),
    .write_i       (registers_write),
    .data_i        (registers_in),
    .rs1_addr_i    (rs1_addr),
    .rs2_addr_i    (rs2_addr),
    .rd_addr_i     (rd_addr),
    .rs1_o         (rs1),
    .rs2_o         (rs2),
    .push_ras_i    (push_ras_i),
    .pop_ras_i     (pop_ras_i)
  );

  //////////////////////////////////////////////////////////////
  // register pipeline logic
  //////////////////////////////////////////////////////////////

  // Whether the next instruction is allowed to read rs1 and rs2 depends on if the 
  // previous one(s) will write to them. If it doesn't, then the reads can proceed
  wire opfetch_wait_on_alu = alu_rd_addr > 0 && ((decode_rs1_addr == alu_rd_addr) || (decode_rs2_addr == alu_rd_addr));
  // TODO -- how many stages do we need to wait for?
  // wire opfetch_wait_on_writeback = alu_rd_addr > 0 && ((decode_rs1_addr == alu_rd_addr) || (decode_rs2_addr == alu_rd_addr));
  wire opfetch_busy = opfetch_wait_on_alu;

  reg opfetch_data_ready_o;
  wire opfetch_ce;
  wire opfetch_stall;

  reg opfetch_immediate = 0;
  reg [XLEN-1:0] opfetch_immediate_data;
  reg [3:0] alu_operation_opfetch = 0;
  reg [REG_BITS-1:0] opfetch_rd_addr;
  reg [REG_BITS-1:0] opfetch_rs1_addr;
  reg [REG_BITS-1:0] opfetch_rs2_addr;

  assign opfetch_stall = opfetch_data_ready_o & (alu_stalled | opfetch_busy);
  assign opfetch_ce = decode_data_ready_o & ~opfetch_stall;

  always @(posedge clk_i) begin
    if (reset_i | clear_pipeline)
      opfetch_data_ready_o <= 1'b0;
    else if (opfetch_ce) begin
      opfetch_data_ready_o <= decode_data_ready_o;
      alu_operation_opfetch <= alu_operation_decode; 
      opfetch_immediate <= decode_immediate;
      opfetch_immediate_data <= decode_immediate_data;
      opfetch_rd_addr <= decode_rd_addr;

      opfetch_rs1_addr <= decode_rs1_addr;
      opfetch_rs2_addr <= decode_rs2_addr;
    end else if (alu_ce) // this will obviously need to change depending on what module we're actually writing to
      opfetch_data_ready_o <= 1'b0;
  end

  //////////////////////////////////////////////////////////////
  // ALU signals
  //////////////////////////////////////////////////////////////

  // I/O
  wire alu_data_ready_o;
  wire [3:0] alu_operation = alu_operation_opfetch;
  wire [XLEN-1:0] alu_operand1 = rs1;
  wire [XLEN-1:0] alu_operand2 = opfetch_immediate ? opfetch_immediate_data : rs2;
  wire [XLEN-1:0] alu_result;
  wire alu_equal;
  wire alu_less;
  wire alu_less_signed;
  wire alu_clear;

  // Pipeline
  wire alu_ce;
  wire alu_stalled;
  reg [REG_BITS-1:0] alu_rd_addr;
  reg [REG_BITS-1:0] alu_rs1_addr;
  reg [REG_BITS-1:0] alu_rs2_addr;

  rv32i_alu_pipe #(
    .XLEN                    (XLEN)
  ) u_rv32i_alu_pipe (
    .clk_i                   (clk_i),
    .data_ready_i            (alu_ce),
    .data_ready_o            (alu_data_ready_o),
    // For now, we'll just do all the decoding in the decode stage...
    // If it turns out that's inefficient, we'll do some decoding here
    .operation_i             (alu_operation),
    .operand1_i              (alu_operand1),
    .operand2_i              (alu_operand2),
    .result_o                (alu_result),
    .equal_o                 (alu_equal),
    .less_o                  (alu_less),
    .less_signed_o           (alu_less_signed),
    .clear_i                 (alu_clear)
  );

  // no internal busy because the ALU will always complete in one cycle

  //////////////////////////////////////////////////////////////
  // ALU pipeline logic
  //////////////////////////////////////////////////////////////

  assign alu_stalled = 0;
  assign alu_ce = opfetch_data_ready_o & ~alu_stalled;

  always @(posedge clk_i) begin
    if (alu_ce) begin
      alu_rd_addr <= opfetch_rd_addr;
      alu_rs1_addr <= opfetch_rs1_addr;
      alu_rs2_addr <= opfetch_rs2_addr;
    end
  end

  //////////////////////////////////////////////////////////////
  // Writeback signals
  //////////////////////////////////////////////////////////////

  reg writeback_registers_write;
  wire writeback_ce;
  wire writeback_stalled;

  assign rd_addr = alu_rd_addr;
  assign registers_write = writeback_registers_write;

  assign writeback_stalled = 0;
  assign writeback_ce = alu_data_ready_o & ~writeback_stalled; // TODO -- again, this will significantly change with the addition of memory and mul/div

  always @(posedge clk_i) begin
    if (reset_i | clear_pipeline)
      writeback_registers_write <= 1'b0;
    else if (writeback_ce)
      writeback_registers_write <= 1'b1;
    else
      writeback_registers_write <= 1'b0;
  end

endmodule

`endif