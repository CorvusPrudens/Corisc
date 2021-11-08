`ifndef RV32I_PIPE_GUARD
`define RV32I_PIPE_GUARD

`include "rv32i_alu_pipe.v"
`include "rv32i_decode.v"
`include "rv32i_prefetch.v"
`include "rv32i_registers_pipe.v"

module rv32i_pipe
  #(
    parameter XLEN = 32,
    parameter ILEN = 32,
    parameter REG_BITS = 5
  )
  (
    input wire clk_i,
    input wire reset_i,

    input wire [7:0] interrupt_vector,

    // Wishbone Master signals
    input wire [XLEN-1:0] master_dat_i,
    output wire [XLEN-1:0] master_dat_o,
    input wire ack_i,
    output wire [XLEN-1:2] adr_o, // XLEN sized address space with byte granularity
                                  // NOTE -- the slave will only have a port as large as its address space
    output wire cyc_o,
    // input wire stall_i,
    input wire err_i,
    output reg [3:0] sel_o,
    output reg stb_o,
    output reg we_o
  );

  // TODO -- this will need to change later, and also we'll need per-stage clearing
  // capabilities for jumps and such
  wire clear_pipeline = reset_i;

  // TODO -- For now, the program memory could be self-contained, making the
  // instruction caching unnecessary for the moment.
  // Obviously we'll need to figure that out later

  //////////////////////////////////////////////////////////////
  // ~~STAGE 1~~ Prefetch signals 
  //////////////////////////////////////////////////////////////

  // I/O
  wire [ILEN-1:0] prefetch_instruction;
  reg [XLEN-1:0] prefetch_pc_in;
  wire [XLEN-1:0] prefetch_pc_in_jal;
  wire [XLEN-1:0] prefetch_pc_in_jalr;
  wire [XLEN-1:0] prefetch_pc_in_branch;
  wire prefetch_pc_write;
  wire [XLEN-1:0] prefetch_pc;

  // pipeline
  wire prefetch_ce;
  wire prefetch_stall;
  reg prefetch_data_ready_o;

  wire jal_jump;
  wire jalr_jump;
  wire branch_jump;

  assign prefetch_pc_write = jal_jump | jalr_jump | branch_jump;

  always @(*) begin
    case ({branch_jump, jalr_jump})
      default: prefetch_pc_in = prefetch_pc_in_jal;
      2'b01: prefetch_pc_in = prefetch_pc_in_jalr;
      2'b10: prefetch_pc_in = prefetch_pc_in_branch;
    endcase
  end

  rv32i_prefetch #(
    .XLEN(XLEN),
    .ILEN(ILEN),
    .VTABLE_ADDR(32'h00000000),
    .PROGRAM_PATH("rv32i_pipe.hex")
  ) RV32I_PREFETCH (
    .clk_i(clk_i),
    .clear_i(1'b0), // TODO -- fill this in
    .reset_i(reset_i),
    .advance_i(prefetch_ce),
    .pc_i(prefetch_pc_in),
    .pc_write_i(prefetch_pc_write),
    .pc_o(prefetch_pc),
    .instruction_o(prefetch_instruction)
  );

  //////////////////////////////////////////////////////////////
  // ~~STAGE 1~~ Prefetch pipeline logic 
  //////////////////////////////////////////////////////////////

  assign prefetch_stall = prefetch_data_ready_o & decode_stall;
  assign prefetch_ce = ~prefetch_stall;

  always @(posedge clk_i) begin
    if (reset_i | clear_pipeline)
      prefetch_data_ready_o <= 1'b0;
    else if (prefetch_ce)
      prefetch_data_ready_o <= 1'b1;
    else if (decode_ce)
      prefetch_data_ready_o <= 1'b0;
  end

  //////////////////////////////////////////////////////////////
  // ~~STAGE 2~~ Instruction decode signals 
  //////////////////////////////////////////////////////////////

  reg decode_data_ready_o;

  wire decode_stall;
  wire decode_ce;
  wire decode_clear = clear_pipeline | jal_jump | jalr_jump | branch_jump;

  // Outputs
  wire [3:0] alu_operation_decode;
  wire [2:0] decode_word_size;
  wire [REG_BITS-1:0] decode_rd_addr;
  wire [REG_BITS-1:0] decode_rs1_addr;
  wire [REG_BITS-1:0] decode_rs2_addr;
  wire decode_immediate;
  wire [XLEN-1:0] decode_immediate_data;
  wire [XLEN-1:0] decode_pc;
  wire pop_ras;
  wire push_ras;
  wire [2:0] decode_branch_condition;
  wire [1:0] decode_stage4_path;

  wire decode_jalr;
  wire decode_branch;

  rv32i_decode #(
    .XLEN(32),
    .ILEN(32),
    .REG_BITS(5)
  ) RV32I_DECODE (
    .clk_i(clk_i),
    .clear_i(decode_clear),
    .instruction_i(prefetch_instruction),
    .data_ready_i(decode_ce),
    .alu_operation_o(alu_operation_decode),
    .word_size_o(decode_word_size),
    .rs1_addr_o(decode_rs1_addr),
    .rs2_addr_o(decode_rs2_addr),
    .rd_addr_o(decode_rd_addr),
    .immediate_o(decode_immediate_data),
    .immediate_valid_o(decode_immediate),
    .pc_data_in(prefetch_pc),
    .pc_data_o(decode_pc),
    .jal_jump_o(jal_jump),
    .jalr_o(decode_jalr),
    .branch_o(decode_branch),
    .branch_condition_o(decode_branch_condition),
    .pc_jal_data_o(prefetch_pc_in_jal),
    .pop_ras_o(pop_ras),
    .push_ras_o(push_ras),
    .stage4_path_o(decode_stage4_path)
  );

  //////////////////////////////////////////////////////////////
  // ~~STAGE 2~~ Instruction decode pipeline logic
  //////////////////////////////////////////////////////////////

  assign decode_stall = decode_data_ready_o & opfetch_stall;
  assign decode_ce = prefetch_data_ready_o & ~opfetch_stall;

  always @(posedge clk_i) begin
    if (decode_clear)
      decode_data_ready_o <= 1'b0;
    else if (decode_ce)
      decode_data_ready_o <= prefetch_data_ready_o;
    else if (opfetch_ce)
      decode_data_ready_o <= 1'b0;
  end

  //////////////////////////////////////////////////////////////
  // ~~STAGE 3~~ Opfetch signals
  //////////////////////////////////////////////////////////////

  wire registers_write;
  wire [REG_BITS-1:0] rs1_addr = decode_rs1_addr;
  wire [REG_BITS-1:0] rs2_addr = decode_rs2_addr;
  wire [REG_BITS-1:0] rd_addr;
  wire [XLEN-1:0] rs1;
  wire [XLEN-1:0] rs2;
  wire [XLEN-1:0] ras;
  wire [XLEN-1:0] registers_in;

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
    .pc_i          (decode_pc),
    .ras_o         (ras),
    .push_ras_i    (push_ras),
    .pop_ras_i     (pop_ras)
  );

  //////////////////////////////////////////////////////////////
  // ~~STAGE 3~~ Opfetch pipeline logic
  //////////////////////////////////////////////////////////////

  wire opfetch_busy = 1'b0;

  reg opfetch_data_ready_o;
  wire opfetch_ce;
  wire opfetch_stall;
  wire opfetch_clear = clear_pipeline | jalr_jump | branch_jump;

  reg opfetch_jalr = 0;
  assign jalr_jump = opfetch_jalr;
  reg [XLEN-1:0] opfetch_jalr_target = 0;
  reg opfetch_pop_ras = 0;
  reg [XLEN-1:0] opfetch_ras = 0;

  wire [XLEN-1:0] jalr_base = opfetch_pop_ras ? opfetch_ras : latest_rs1_in_writeback ? alu_result : rs1;
  assign prefetch_pc_in_jalr = opfetch_jalr_target + jalr_base;
  reg opfetch_branch = 0;
  reg [2:0] opfetch_branch_conditions = 0;

  reg opfetch_immediate = 0;
  reg [XLEN-1:0] opfetch_immediate_data;
  reg [3:0] alu_operation_opfetch = 0;
  reg [REG_BITS-1:0] opfetch_rd_addr;
  reg [REG_BITS-1:0] opfetch_rs1_addr;
  reg [REG_BITS-1:0] opfetch_rs2_addr;
  reg [1:0] opfetch_stage4_path;
  reg [2:0] opfetch_word_size;

  assign opfetch_stall = (opfetch_data_ready_o & alu_stalled) | opfetch_busy;
  assign opfetch_ce = decode_data_ready_o & ~opfetch_stall;

  always @(posedge clk_i) begin
    if (opfetch_clear) begin
      opfetch_data_ready_o <= 1'b0;
      opfetch_rd_addr <= 0;
      opfetch_rs1_addr <= 0;
      opfetch_rs2_addr <= 0;
      opfetch_jalr <= 1'b0;
      opfetch_branch <= 1'b0;
      opfetch_branch_conditions <= 3'b0;
      opfetch_pop_ras <= 1'b0;
      opfetch_ras <= 0;
    end else if (opfetch_ce) begin
      opfetch_data_ready_o <= decode_data_ready_o;
      alu_operation_opfetch <= alu_operation_decode; 
      
      opfetch_immediate <= decode_immediate;
      opfetch_rd_addr <= decode_rd_addr;

      opfetch_rs1_addr <= decode_rs1_addr;
      opfetch_rs2_addr <= decode_rs2_addr;

      opfetch_branch <= decode_branch;
      opfetch_branch_conditions <= decode_branch_condition;

      opfetch_stage4_path <= decode_stage4_path;
      opfetch_word_size <= decode_word_size;

      if (decode_jalr) begin
        opfetch_jalr_target <= decode_immediate_data;
        opfetch_immediate_data <= decode_pc;
        opfetch_jalr <= 1'b1;
        opfetch_pop_ras <= pop_ras;
        opfetch_ras <= ras;
      end else
        opfetch_immediate_data <= decode_immediate_data;
        
    end else if (alu_ce) // this will obviously need to change depending on what module we're actually writing to
      opfetch_data_ready_o <= 1'b0;
  end

  //////////////////////////////////////////////////////////////
  // ~~STAGE 4~~ ~~ALL BRANCHes~~ Stage 4 I/O
  //////////////////////////////////////////////////////////////

  wire stage4_stalled = alu_stalled | mem_stalled;
  wire stage4_ce = opfetch_data_ready_o & ~stage4_stalled;
  wire stage4_clear = clear_pipeline | branch_jump;
  wire stage4_data_ready_o = alu_data_ready_o | mem_data_ready_o;

  reg [REG_BITS-1:0] stage4_rs1_addr;
  reg [REG_BITS-1:0] stage4_rs2_addr;
  reg [REG_BITS-1:0] stage4_rd_addr;

  reg [XLEN-1:0] stage4_result;

  wire latest_rs1_in_writeback = opfetch_rs1_addr == stage4_rd_addr;
  wire latest_rs2_in_writeback = opfetch_rs2_addr == stage4_rd_addr;

  wire [XLEN-1:0] stage4_latest_rs1 = latest_rs1_in_writeback ? stage4_result : rs1;
  wire [XLEN-1:0] stage4_latest_rs2 = latest_rs2_in_writeback ? stage4_result : rs2;

  always @(posedge clk_i) begin
    if (stage4_clear) begin

    end else if (stage4_ce) begin
      stage4_rs1_addr <= opfetch_rs1_addr;
      stage4_rs2_addr <= opfetch_rs2_addr;
      stage4_rd_addr <= opfetch_rd_addr;
    end
  end
  
  always @(*) begin
    case (opfetch_stage4_path)
      default: stage4_result = alu_result;
      2'b10: stage4_result = mem_data_out;
    endcase
  end

  //////////////////////////////////////////////////////////////
  // ~~STAGE 4~~ ~~BRANCH 1~~ ALU signals
  //////////////////////////////////////////////////////////////

  // I/O
  wire alu_data_ready_o;
  wire [3:0] alu_operation = alu_operation_opfetch;
  wire [XLEN-1:0] alu_result;
  // TODO -- this logic will have to be duplicated across the three substages here
  wire [XLEN-1:0] alu_operand1 = stage4_latest_rs1;
  wire [XLEN-1:0] alu_operand2 = opfetch_immediate ? opfetch_immediate_data : stage4_latest_rs2;
  wire alu_equal;
  wire alu_less;
  wire alu_less_signed;

  // Pipeline
  wire alu_ce;
  wire alu_stalled;
  wire alu_clear;
  reg [XLEN-1:0] alu_immediate_data = 0;
  reg [XLEN-1:0] alu_pc = 0;
  reg alu_branch = 0;
  reg [2:0] alu_branch_conditions;

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
  // ~~STAGE 4~~ ~~BRANCH 1~~  ALU pipeline logic
  //////////////////////////////////////////////////////////////

  assign alu_stalled = 0;
  assign alu_ce = stage4_ce & opfetch_stage4_path[0];
  assign alu_clear = stage4_clear;

  always @(posedge clk_i) begin
    if (alu_clear) begin
      alu_branch <= 1'b0;
      alu_branch_conditions <= 3'b0;
      alu_immediate_data <= 0;
    end else if (alu_ce) begin
      alu_immediate_data <= opfetch_immediate_data;
      alu_branch <= opfetch_branch;
      alu_branch_conditions <= opfetch_branch_conditions;
    end
  end


  //////////////////////////////////////////////////////////////
  // ~~STAGE 4~~ ~~BRANCH 2~~ Memory signals
  //////////////////////////////////////////////////////////////

  wire mem_busy;
  wire [XLEN-1:0] mem_data_out_raw;
  reg [XLEN-1:0] mem_data_out;
  wire mem_err;

  reg mem_data_ready_o;
  wire memory_clear = stage4_clear;
  wire memory_ce = stage4_ce & opfetch_stage4_path[1];
  wire memory_stalled = (mem_data_ready_o & writeback_stalled) | mem_busy;

  wire [XLEN-1:0] memory_data_in = stage4_latest_rs2;
  wire [XLEN-1:0] memory_addr_in = stage4_latest_rs1 + opfetch_immediate_data;

  reg [2:0] mem_word_size;

  rv32i_memory_pipe #(
    .XLEN(XLEN)
  ) RV32I_MEMORY_PIPE (
    .clk_i(clk_i),
    .rst_i(reset_i),
    .clear_i(memory_clear),
    .data_ready_i(memory_ce),
    .data_i(memory_data_in),
    .data_o(mem_data_out_raw),
    .addr_i(memory_addr_in),
    .word_size_i(opfetch_word),
    .write_i(opfetch_write),
    .busy_o(mem_busy),
    .err_o(mem_err),
    .master_dat_i(master_dat_i),
    .master_dat_o(master_dat_o),
    .ack_i(ack_i),
    .adr_o(adr_o),
    .cyc_o(cyc_o),
    .err_i(err_i),
    .sel_o(sel_o),
    .stb_o(stb_o),
    .we_o(we_o)
  );

  always @(posedge clk_i) begin
    if (memory_clear)
       mem_data_ready_o <= 1'b0;
    else if (ack_i) begin
      mem_data_ready_o <= 1'b1;
      mem_word_size <= opfetch_word_size;
    end else if (writeback_ce)
      mem_data_ready_o <= 1'b0;
  end 

  always @(*) begin
    case (mem_word_size)
      3'b000: mem_data_out = {{XLEN-8{mem_data_out_raw[7]}}, mem_data_out_raw[7:0]};
      3'b001: mem_data_out = {{XLEN-16{mem_data_out_raw[15]}}, mem_data_out_raw[15:0]};
      default: mem_data_out = mem_data_out_raw;
    endcase
  end

  //////////////////////////////////////////////////////////////
  // ~~STAGE 5~~ Writeback signals
  //////////////////////////////////////////////////////////////

  reg writeback_registers_write;
  wire writeback_ce;
  wire writeback_stalled;
  wire writeback_clear = clear_pipeline;
  reg writeback_branch;
  assign branch_jump = writeback_branch;
  reg [XLEN-1:0] writeback_branch_data;
  assign prefetch_pc_in_branch = writeback_branch_data;

  assign rd_addr = stage4_rd_addr;
  // TODO -- this will need to change obviously
  assign registers_in = stage4_result;
  assign registers_write = writeback_registers_write;

  assign writeback_stalled = 0;
  assign writeback_ce = stage4_data_ready_o & ~writeback_stalled; // TODO -- again, this will significantly change with the addition of memory and mul/div

  always @(posedge clk_i) begin
    if (writeback_clear) begin
      writeback_registers_write <= 1'b0;
    end else if (writeback_ce) begin
      writeback_registers_write <= (alu_rd_addr > 0);
      writeback_branch_data <= alu_immediate_data + alu_pc;
      if (alu_branch) begin
        case (alu_branch_conditions)
          default: writeback_branch <= 1'b0;
          3'b000: if (alu_equal) writeback_branch <= 1'b1;
          3'b001: if (~alu_equal) writeback_branch <= 1'b1;
          3'b100: if (alu_less) writeback_branch <= 1'b1;
          3'b101: if (~alu_less) writeback_branch <= 1'b1;
          3'b110: if (alu_less_signed) writeback_branch <= 1'b1;
          3'b111: if (~alu_less_signed) writeback_branch <= 1'b1;
        endcase
      end else
        writeback_branch <= 1'b0;
    end
  end
  // always @(posedge clk_i) begin
  //   if (reset_i | clear_pipeline)
  //     writeback_registers_write <= 1'b0;
  //   else if (writeback_ce)
  //     writeback_registers_write <= 1'b1;
  //   else
  //     writeback_registers_write <= 1'b0;
  // end

endmodule

`endif
