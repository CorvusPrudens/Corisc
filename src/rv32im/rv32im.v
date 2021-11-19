`ifndef RV32IM_GUARD
`define RV32IM_GUARD

`include "rv32im_alu.v"
`include "rv32im_decode.v"
`include "rv32im_registers.v"
`include "rv32im_memory.v"
`include "rv32im_instruction_cache.v"
`include "rv32im_muldiv.v"

module rv32im
  #(
    parameter XLEN = 32,
    parameter ILEN = 32,
    parameter INT_VECT_LEN = 8,
    parameter REG_BITS = 5
  )
  (
    input wire clk_i,
    input wire reset_i,

    input wire [XLEN-1:0] interrupt_vector_offset_i,
    input wire interrupt_trigger_i,
    output wire interrupt_routine_complete_o,

    // Wishbone Master signals
    input wire [XLEN-1:0] master_dat_i,
    output wire [XLEN-1:0] master_dat_o,
    input wire ack_i,
    output wire [XLEN-3:0] adr_o, // XLEN sized address space with byte granularity
                                  // NOTE -- the slave will only have a port as large as its address space
    output wire cyc_o,
    // input wire stall_i,
    input wire err_i,
    output wire [3:0] sel_o,
    output wire stb_o,
    output wire we_o
  );

  wire wb_we;

  wire clear_pipeline = reset_i;

  //////////////////////////////////////////////////////////////
  // ~~STAGE 1~~ Prefetch signals 
  //////////////////////////////////////////////////////////////

  // pipeline
  wire prefetch_ce;
  wire prefetch_stall;
  wire prefetch_clear = prefetch_pc_write;
  reg  prefetch_data_ready_o;
  initial prefetch_data_ready_o = 0;

  wire jal_jump;
  wire jalr_jump;
  wire branch_jump;

  // Prefetch
  // I/O
  wire [ILEN-1:0] prefetch_instruction;
  reg [XLEN-1:0] prefetch_pc_in;
  initial prefetch_pc_in = 0;
  wire [XLEN-1:0] prefetch_pc_in_jal;
  wire [XLEN-1:0] prefetch_pc_in_jalr;
  wire [XLEN-1:0] prefetch_pc_in_branch;
  wire prefetch_pc_write;
  reg [XLEN-1:0] prefetch_pc;
  initial prefetch_pc = 0;

  reg [XLEN-1:0] program_counter;
  initial program_counter = 0;
  localparam VTABLE_ADDR = 32'h00300000;

  // Instruction cache
  reg  instruction_cache_arbitor;
  initial instruction_cache_arbitor = 0;
  wire icache_cyc_o;
  wire [XLEN-3:0] icache_adr_o;
  wire [3:0] icache_sel_o;
  wire icache_stb_o;
  wire icache_arb_req;
  wire icache_busy;
  wire [XLEN-1:0] vtable_pc;
  wire vtable_pc_write;
  wire cache_invalid;

  assign cyc_o = instruction_cache_arbitor ? icache_cyc_o : mem_cyc_o;
  assign adr_o = instruction_cache_arbitor ? icache_adr_o : mem_adr_o;
  assign sel_o = instruction_cache_arbitor ? icache_sel_o : mem_sel_o;
  assign stb_o = instruction_cache_arbitor ? icache_stb_o : mem_stb_o;

  // Extremely simple bus arbitor
  wire branch_in_pipeline = decode_branch | decode_jalr;
  always @(posedge clk_i) begin
    if (icache_arb_req & ~mem_stb_o & ~branch_in_pipeline)
      instruction_cache_arbitor <= 1'b1;
    else if (instruction_cache_arbitor & ~icache_arb_req)
      instruction_cache_arbitor <= 1'b0;
  end

  assign we_o = instruction_cache_arbitor ? 1'b0 : wb_we;

  rv32im_instruction_cache #(
    .CACHE_LEN(7),
    .LINE_LEN(4), // NOTE -- this is the bits for the word count, not byte count
    .ILEN(ILEN),
    .XLEN(XLEN),
    .VTABLE_ADDRESS(VTABLE_ADDR)
  ) RV32IM_INSTRUCTION_CACHE (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .advance_i(prefetch_ce),
    .jump_i(prefetch_pc_write),
    .busy_o(icache_busy),
    .addr_i(prefetch_pc_write ? prefetch_pc_in : program_counter),
    .instruction_o(prefetch_instruction),
    .cache_invalid_o(cache_invalid),
    .ctrl_req_o(icache_arb_req),
    .ctrl_grant_i(instruction_cache_arbitor),
    .interrupt_trigger_i(interrupt_trigger_i),
    .vtable_offset_i(interrupt_vector_offset_i),
    .vtable_pc_o(vtable_pc),
    .vtable_pc_write(vtable_pc_write),
    .master_dat_i(master_dat_i),
    .ack_i(ack_i),
    .adr_o(icache_adr_o),
    .cyc_o(icache_cyc_o),
    .err_i(err_i),
    .sel_o(icache_sel_o),
    .stb_o(icache_stb_o)
  );

  assign prefetch_pc_write = jal_jump | jalr_jump | branch_jump | vtable_pc_write;

  always @(*) begin
    casez ({vtable_pc_write, branch_jump, jalr_jump})
      default: prefetch_pc_in = prefetch_pc_in_jal;
      3'b001: prefetch_pc_in = mret ? uepc : prefetch_pc_in_jalr;
      3'b01?: prefetch_pc_in = prefetch_pc_in_branch;
      3'b1??: prefetch_pc_in = vtable_pc;
    endcase
  end

  // // For rolling back after a cache miss
  // reg [XLEN-1:0] prev_program_counter;
  // initial prev_program_counter = 0;
  // always @(posedge clk_i) begin
  //   prev_program_counter <= prefetch_pc;
  // end

  always @(posedge clk_i) begin
    if (reset_i) begin
      program_counter <= 0;
      prefetch_pc <= 0;
    end else if (prefetch_ce & ~cache_invalid) begin
      if (prefetch_pc_write) begin
        prefetch_pc <= prefetch_pc_in;
        program_counter <= prefetch_pc_in + 32'b100;
      end else begin
        prefetch_pc <= program_counter;
        program_counter <= program_counter + 32'b100;
      end
    end else if (prefetch_pc_write) begin
      prefetch_pc <= prefetch_pc_in;
      program_counter <= prefetch_pc_in;
    // end else if (vtable_pc_write) begin
    //   prefetch_pc <= prefetch_pc_in;
    //   program_counter <= prefetch_pc_in;
    // end else if (cache_invalid & decode_ce) begin
    //   program_counter <= program_counter - 4;
    //   // program_counter <= prev_program_counter;
    //   // prefetch_pc <= prev_program_counter;
    end else if (decode_ce)
      prefetch_pc <= program_counter;
  end

  //////////////////////////////////////////////////////////////
  // ~~STAGE 1~~ Prefetch pipeline logic 
  //////////////////////////////////////////////////////////////

  assign prefetch_stall = (prefetch_data_ready_o & decode_stall) | icache_busy | jal_jump | jalr_jump | branch_jump; // just be careful with this jal_jump stall
  assign prefetch_ce = ~prefetch_stall;

  always @(posedge clk_i) begin
    if (reset_i | jal_jump | jalr_jump | branch_jump | icache_arb_req)
      prefetch_data_ready_o <= 1'b0;
    else if (prefetch_ce & ~cache_invalid)
      prefetch_data_ready_o <= 1'b1;
    else if (decode_ce)
      prefetch_data_ready_o <= 1'b0;
  end

  //////////////////////////////////////////////////////////////
  // ~~STAGE 2~~ Instruction decode signals 
  //////////////////////////////////////////////////////////////

  reg  decode_data_ready_o;
  initial decode_data_ready_o = 0;

  wire processing_jump;

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
  wire [2:0] decode_stage4_path;
  wire decode_write;
  wire mret;
  wire [XLEN-1:0] uepc;

  // If a branch instruction is being evaluated and another branch instruction will be decoded, 
  // the decode stage needs to stall until that branch is evaluated, since JAL and JALR would otherwise happen first
  reg branch_stall_condition_clear;

  assign interrupt_routine_complete_o = mret & jalr_jump;

  wire decode_jalr;
  wire decode_branch;

  wire decode_link;
  wire [XLEN-1:0] decode_link_data;

  rv32im_decode #(
    .XLEN(32),
    .ILEN(32),
    .REG_BITS(5)
  ) RV32IM_DECODE (
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
    .interrupt_trigger_i(vtable_pc_write),
    .mret_o(mret),
    .uepc_o(uepc),
    .link_o(decode_link),
    .link_data_o(decode_link_data),
    .pc_data_i(prefetch_pc),
    .pc_data_o(decode_pc),
    .jal_jump_o(jal_jump),
    .jalr_o(decode_jalr),
    .branch_o(decode_branch),
    .branch_condition_o(decode_branch_condition),
    .clear_branch_stall_i(branch_stall_condition_clear),
    .pc_jal_data_o(prefetch_pc_in_jal),
    .pop_ras_o(pop_ras),
    .push_ras_o(push_ras),
    .stage4_path_o(decode_stage4_path),
    .memory_write_o(decode_write),
    .processing_jump(processing_jump)
  );

  //////////////////////////////////////////////////////////////
  // ~~STAGE 2~~ Instruction decode pipeline logic
  //////////////////////////////////////////////////////////////

  assign decode_stall = (decode_data_ready_o & opfetch_stall) | (processing_jump & ~branch_stall_condition_clear & (decode_branch | opfetch_branch | alu_branch)) | mret | decode_jalr;
  assign decode_ce = prefetch_data_ready_o & ~decode_stall;

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

  wire opfetch_ce;

  rv32im_registers #(
    .XLEN          (XLEN),
    .REG_BITS      (REG_BITS)
  ) RV32IM_REGISTERS (
    .clk_i         (clk_i),
    .write_i       (registers_write),
    .data_i        (registers_in),
    .data_ready_i  (opfetch_ce),
    .rs1_addr_i    (rs1_addr),
    .rs2_addr_i    (rs2_addr),
    .rd_addr_i     (rd_addr),
    .rs1_o         (rs1),
    .rs2_o         (rs2),
    .pc_i          (decode_pc),
    .ras_o         (ras),
    .ras_write_i   (prefetch_pc_write),
    .push_ras_i    (branch_jump ? 1'b0 : push_ras),
    .pop_ras_i     (mret & jalr_jump ? 1'b0 : pop_ras) // TODO -- could this cause bugs?
  );

  //////////////////////////////////////////////////////////////
  // ~~STAGE 3~~ Opfetch pipeline logic
  //////////////////////////////////////////////////////////////

  wire opfetch_busy = 1'b0;

  reg  opfetch_data_ready_o;
  initial opfetch_data_ready_o = 0;
  wire opfetch_stall;
  wire opfetch_clear = clear_pipeline | jalr_jump | branch_jump;

  reg  opfetch_jalr;
  initial opfetch_jalr = 0;
  assign jalr_jump = opfetch_jalr & ~mem_stb_o;
  reg [XLEN-1:0] opfetch_jalr_target;
  initial opfetch_jalr_target = 0;
  reg  opfetch_pop_ras;
  initial opfetch_pop_ras = 0;
  reg [XLEN-1:0] opfetch_ras;
  initial opfetch_ras = 0;

  wire [XLEN-1:0] jalr_base = opfetch_pop_ras ? opfetch_ras : stage4_latest_rs1;
  assign prefetch_pc_in_jalr = opfetch_jalr_target + jalr_base;
  reg  opfetch_branch;
  initial opfetch_branch = 0;
  reg [2:0] opfetch_branch_conditions;
  initial opfetch_branch_conditions = 0;

  reg  opfetch_immediate;
  initial opfetch_immediate = 0;
  reg [XLEN-1:0] opfetch_immediate_data;
  initial opfetch_immediate_data = 0;
  reg [3:0] alu_operation_opfetch;
  initial alu_operation_opfetch = 0;
  reg [REG_BITS-1:0] opfetch_rd_addr;
  initial opfetch_rd_addr = 0;
  reg [REG_BITS-1:0] opfetch_rs1_addr;
  initial opfetch_rs1_addr = 0;
  reg [REG_BITS-1:0] opfetch_rs2_addr;
  initial opfetch_rs2_addr = 0;
  reg [2:0] opfetch_stage4_path;
  initial opfetch_stage4_path = 0;
  reg [2:0] opfetch_word_size;
  initial opfetch_word_size = 0;
  reg  opfetch_write;
  initial opfetch_write = 0;
  reg [XLEN-1:0] opfetch_pc;
  initial opfetch_pc = 0;
  reg  opfetch_link;
  initial opfetch_link = 0;
  reg [XLEN-1:0] opfetch_link_data;
  initial opfetch_link_data = 0;

  assign opfetch_stall = opfetch_data_ready_o & (stage4_stalled | opfetch_busy);
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
      opfetch_write <= 1'b0;
      opfetch_pc <= 0;
      opfetch_link <= 1'b0;
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

      opfetch_write <= decode_write;
      opfetch_pc <= decode_pc;

      opfetch_link <= decode_link;
      opfetch_link_data <= decode_link_data;

      if (decode_jalr) begin
        opfetch_jalr_target <= decode_immediate_data;
        opfetch_immediate_data <= decode_pc;
        opfetch_jalr <= 1'b1;
        opfetch_pop_ras <= pop_ras;
        opfetch_ras <= ras;
      end else
        opfetch_immediate_data <= decode_immediate_data;
        
    end else if (stage4_ce)
      opfetch_data_ready_o <= 1'b0;
  end

  //////////////////////////////////////////////////////////////
  // ~~STAGE 4~~ ~~ALL BRANCHes~~ Stage 4 I/O
  //////////////////////////////////////////////////////////////

  wire stage4_stalled = alu_stalled | memory_stalled | muldiv_stall;

  // // TODO -- is this actually valid?
  // reg stage4_ce;
  // always @(*) begin
  //   case (opfetch_stage4_path)
  //     default: stage4_ce = opfetch_data_ready_o & ~alu_stalled;
  //     3'b010: stage4_ce = opfetch_data_ready_o & ~memory_stalled;
  //     3'b100: stage4_ce = opfetch_data_ready_o & ~muldiv_stall;
  //   endcase
  // end
  wire stage4_ce = opfetch_data_ready_o & ~stage4_stalled;

  wire stage4_clear = clear_pipeline | branch_jump; // TODO -- should jalr's also clear this?
  wire stage4_data_ready_o = alu_data_ready_o | mem_data_ready_o | muldiv_data_ready_o;

  reg [REG_BITS-1:0] stage4_rs1_addr;
  initial stage4_rs1_addr = 0;
  reg [REG_BITS-1:0] stage4_rs2_addr;
  initial stage4_rs2_addr = 0;
  reg [REG_BITS-1:0] stage4_rd_addr;
  initial stage4_rd_addr = 0;

  reg [XLEN-1:0] stage4_result;
  initial stage4_result = 0;
  reg [2:0] stage4_stage4_path;
  initial stage4_stage4_path = 0;

  wire latest_rs1_in_writeback1 = (opfetch_rs1_addr == stage4_rd_addr) & (stage4_rd_addr != 0);
  wire latest_rs2_in_writeback1 = (opfetch_rs2_addr == stage4_rd_addr) & (stage4_rd_addr != 0);

  wire latest_rs1_in_writeback2 = (opfetch_rs1_addr == writeback_rd_addr) & (writeback_rd_addr != 0);
  wire latest_rs2_in_writeback2 = (opfetch_rs2_addr == writeback_rd_addr) & (writeback_rd_addr != 0);

  wire [XLEN-1:0] stage4_latest_rs1 = latest_rs1_in_writeback1 ? stage4_result : latest_rs1_in_writeback2 ? writeback_data : rs1;
  wire [XLEN-1:0] stage4_latest_rs2 = latest_rs2_in_writeback1 ? stage4_result : latest_rs2_in_writeback2 ? writeback_data : rs2;

  always @(posedge clk_i) begin
    if (stage4_clear) begin
      stage4_rd_addr <= 0;
      stage4_stage4_path <= 0;
    end else if (stage4_ce) begin
      stage4_rs1_addr <= opfetch_rs1_addr;
      stage4_rs2_addr <= opfetch_rs2_addr;
      stage4_rd_addr <= opfetch_rd_addr;
      stage4_stage4_path <= opfetch_stage4_path;
    end
  end
  
  always @(*) begin
    case (stage4_stage4_path)
      default: stage4_result = alu_link ? alu_link_data : alu_result;
      3'b010: stage4_result = mem_data_out;
      3'b100: stage4_result = muldiv_result;
    endcase
  end

  //////////////////////////////////////////////////////////////
  // ~~STAGE 4~~ ~~BRANCH 1~~ ALU signals
  //////////////////////////////////////////////////////////////

  // I/O
  reg  alu_data_ready_o;
  initial alu_data_ready_o = 0;
  wire [3:0] alu_operation = alu_operation_opfetch;
  wire [XLEN-1:0] alu_result;
  wire [XLEN-1:0] alu_operand1 = stage4_latest_rs1;
  wire [XLEN-1:0] alu_operand2 = opfetch_immediate ? opfetch_immediate_data : stage4_latest_rs2;
  wire alu_equal;
  wire alu_less;
  wire alu_less_signed;

  // Pipeline
  wire alu_ce;
  wire alu_stalled;
  wire alu_clear;
  reg [XLEN-1:0] alu_immediate_data;
  initial alu_immediate_data = 0;
  reg [XLEN-1:0] alu_pc;
  initial alu_pc = 0;
  reg  alu_branch;
  initial alu_branch = 0;
  reg [2:0] alu_branch_conditions;
  initial alu_branch_conditions = 0;

  reg  alu_link;
  initial alu_link = 0;
  reg [XLEN-1:0] alu_link_data;
  initial alu_link_data = 0;

  rv32im_alu #(
    .XLEN                    (XLEN)
  ) RV32IM_ALU (
    .clk_i                   (clk_i),
    .data_ready_i            (alu_ce),
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

  assign alu_stalled = alu_data_ready_o & writeback_stalled;
  assign alu_ce = stage4_ce & opfetch_stage4_path[0];
  assign alu_clear = stage4_clear;

  wire writeback_ce;

  always @(posedge clk_i) begin
    if (alu_clear) begin
      alu_branch <= 1'b0;
      alu_branch_conditions <= 3'b0;
      alu_immediate_data <= 0;
      alu_pc <= 0;
      alu_data_ready_o <= 1'b0;
      alu_link <= 1'b0;
    end else if (alu_ce) begin
      alu_immediate_data <= opfetch_immediate_data;
      alu_branch <= opfetch_branch;
      alu_branch_conditions <= opfetch_branch_conditions;
      alu_pc <= opfetch_pc;
      alu_data_ready_o <= opfetch_data_ready_o;
      alu_link <= opfetch_link;
      alu_link_data <= opfetch_link_data;
    end else if (writeback_ce)
      alu_data_ready_o <= 1'b0;
  end


  //////////////////////////////////////////////////////////////
  // ~~STAGE 4~~ ~~BRANCH 2~~ Memory signals
  //////////////////////////////////////////////////////////////

  // TODO -- store operations could be made to be non-blocking (no need to stall the ALU if we're doing a single store)

  wire mem_busy;
  wire [XLEN-1:0] mem_data_out_raw;
  reg [XLEN-1:0] mem_data_out;
  initial mem_data_out = 0;
  wire mem_err;

  reg  mem_data_ready_o;
  initial mem_data_ready_o = 0;
  wire mem_transaction_done = ack_i & ~instruction_cache_arbitor;
  wire memory_clear = stage4_clear;
  wire memory_ce = stage4_ce & opfetch_stage4_path[1];
  wire memory_stalled = (mem_data_ready_o & writeback_stalled) | mem_busy | (opfetch_data_ready_o & instruction_cache_arbitor & opfetch_stage4_path[1]);

  wire [XLEN-1:0] memory_data_in = stage4_latest_rs2;
  wire [XLEN-1:0] memory_addr_in = stage4_latest_rs1 + opfetch_immediate_data;

  reg [2:0] mem_word_size;
  initial mem_word_size = 0;

  // Wishbone muxed signals
  wire [XLEN-3:0] mem_adr_o;
  wire mem_cyc_o;
  wire [3:0] mem_sel_o;
  wire mem_stb_o;

  rv32im_memory #(
    .XLEN(XLEN)
  ) RV32IM_MEMORY (
    .clk_i(clk_i),
    .rst_i(reset_i),
    .clear_i(memory_clear),
    .data_ready_i(memory_ce),
    .data_i(memory_data_in),
    .data_o(mem_data_out_raw),
    .addr_i(memory_addr_in),
    .word_size_i(opfetch_word_size[1:0]),
    .write_i(opfetch_write),
    .busy_o(mem_busy),
    .err_o(mem_err),
    .master_dat_i(master_dat_i),
    .master_dat_o(master_dat_o),
    .ack_i(ack_i & ~instruction_cache_arbitor),
    .adr_o(mem_adr_o),
    .cyc_o(mem_cyc_o),
    .err_i(err_i),
    .sel_o(mem_sel_o),
    .stb_o(mem_stb_o),
    .we_o(wb_we)
  );

  always @(posedge clk_i) begin
    if (memory_clear)
      mem_word_size <= 0;
    else if (memory_ce) begin
      mem_word_size <= opfetch_word_size;
    end
  end

  always @(posedge clk_i) begin
    if (memory_clear)
       mem_data_ready_o <= 1'b0;
    else if (mem_transaction_done) begin
      mem_data_ready_o <= 1'b1;
      // mem_word_size <= opfetch_word_size;
      // case (mem_word_size)
      //   3'b000: mem_data_out <= {{XLEN-8{mem_data_out_raw[7]}}, mem_data_out_raw[7:0]};
      //   3'b001: mem_data_out <= {{XLEN-16{mem_data_out_raw[15]}}, mem_data_out_raw[15:0]};
      //   default: mem_data_out <= mem_data_out_raw;
      // endcase
    end else if (writeback_ce)
      mem_data_ready_o <= 1'b0;
  end 

  // Shouldn't this just be synchronous?
  always @(*) begin
    case (mem_word_size)
      3'b000: mem_data_out = {{XLEN-8{mem_data_out_raw[7]}}, mem_data_out_raw[7:0]};
      3'b001: mem_data_out = {{XLEN-16{mem_data_out_raw[15]}}, mem_data_out_raw[15:0]};
      default: mem_data_out = mem_data_out_raw;
    endcase
  end

  //////////////////////////////////////////////////////////////
  // ~~STAGE 4~~ ~~BRANCH 3~~ Muldiv signals
  //////////////////////////////////////////////////////////////

  wire muldiv_clear = stage4_clear;
  wire muldiv_busy;
  wire muldiv_ce;
  wire muldiv_stall;
  wire muldiv_valid;

  wire [XLEN-1:0] muldiv_result;

  wire  muldiv_data_ready_o;

  assign muldiv_ce = stage4_ce & opfetch_stage4_path[2];
  assign muldiv_stall = (muldiv_data_ready_o & writeback_stalled) | muldiv_busy;

  rv32im_muldiv #(
    .XLEN(XLEN)
  ) RV32IM_MULDIV (
    .clk_i(clk_i),
    .clear_i(muldiv_clear),
    .operation_i(alu_operation[2:0]),
    .data_ready_i(muldiv_ce),
    .operand1_i(stage4_latest_rs1),
    .operand2_i(stage4_latest_rs2),
    .result_o(muldiv_result),
    .data_ready_o(muldiv_valid),
    .busy_o(muldiv_busy),
    .writeback_ce_i(writeback_ce)
  );

  assign muldiv_data_ready_o = muldiv_valid;

  // always @(posedge clk_i) begin
  //   if (muldiv_clear) begin
  //     muldiv_data_ready_o <= 1'b0;
  //   end else if (muldiv_valid) begin
  //     muldiv_data_ready_o <= 1'b1;
  //   end else if (writeback_ce)
  //     muldiv_data_ready_o <= 1'b0;
  // end

  //////////////////////////////////////////////////////////////
  // ~~STAGE 5~~ Writeback signals
  //////////////////////////////////////////////////////////////

  reg [XLEN-1:0] writeback_data;
  initial writeback_data = 0;
  reg [REG_BITS-1:0] writeback_rd_addr;
  initial writeback_rd_addr = 0;
  reg  writeback_registers_write;
  initial writeback_registers_write = 0;
  wire writeback_stalled;
  wire writeback_clear = clear_pipeline | writeback_branch;
  reg  writeback_branch;
  initial writeback_branch = 0;
  assign branch_jump = writeback_branch;
  reg [XLEN-1:0] writeback_branch_data;
  initial writeback_branch_data = 0;
  assign prefetch_pc_in_branch = writeback_branch_data;

  assign rd_addr = writeback_rd_addr;
  assign registers_in = writeback_data;
  assign registers_write = writeback_registers_write;

  assign writeback_stalled = 0;
  assign writeback_ce = stage4_data_ready_o & ~writeback_stalled;

  always @(posedge clk_i) begin
    if (writeback_clear) begin
      writeback_registers_write <= 1'b0;
      writeback_data <= 0;
      writeback_rd_addr <= 0;
      writeback_branch <= 1'b0;
      branch_stall_condition_clear <= 1'b0;
    end else if (writeback_ce) begin
      writeback_data <= stage4_result;
      writeback_rd_addr <= stage4_rd_addr;
      writeback_registers_write <= (stage4_rd_addr > 0);
      writeback_branch_data <= alu_immediate_data + alu_pc;
      if (alu_branch) begin
        case (alu_branch_conditions)
          default: writeback_branch <= 1'b0;
          3'b000: if (alu_equal) writeback_branch <= 1'b1; else branch_stall_condition_clear <= 1'b1;
          3'b001: if (~alu_equal) writeback_branch <= 1'b1; else branch_stall_condition_clear <= 1'b1;
          3'b100: if (alu_less) writeback_branch <= 1'b1; else branch_stall_condition_clear <= 1'b1;
          3'b101: if (~alu_less) writeback_branch <= 1'b1; else branch_stall_condition_clear <= 1'b1;
          3'b110: if (alu_less_signed) writeback_branch <= 1'b1; else branch_stall_condition_clear <= 1'b1;
          3'b111: if (~alu_less_signed) writeback_branch <= 1'b1; else branch_stall_condition_clear <= 1'b1;
        endcase
      end else begin
        writeback_branch <= 1'b0;
        branch_stall_condition_clear <= 1'b0;
      end
    end else begin
      writeback_registers_write <= 1'b0;
      writeback_branch <= 1'b0;
      branch_stall_condition_clear <= 1'b0;
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

  `ifdef FORMAL
    reg  timeValid_f;
    initial timeValid_f = 0;
    always @(posedge clk_i) timeValid_f <= 1;

    initial assume(reset_i);

    always @(*)
      assume(master_dat_i == 0); // no need for other kinds of testing I think
    
    // for now we're ignoring interrupt testing
    always @(*)
      assume(interrupt_vector == 0);

    // We'll also assume a global reset isn't issues after startup (which probably won't ever happen XD)
    always @(*)
      if (timeValid_f)
        assume(reset_i == 0);
      else
        assume(reset_i == 1);

    // Valid assuming reset_i is asserted at startup
    always @(*) begin
      if (~timeValid_f) begin
        assume(vtable_pc_write == 0);
        assume(jal_jump == 0);
        assume(jalr_jump == 0);
      end
    end
    
    //////////////////////////////////////////////////////////////
    // ~~STAGE 1~~ Prefetch section
    //////////////////////////////////////////////////////////////

    // Checking program counter writes
    always @(posedge clk_i) begin
      if (timeValid_f & $past(vtable_pc_write)) begin
        assert(program_counter == $past(prefetch_pc_in));
      end

      if (timeValid_f & $past(prefetch_pc_write) & ~cache_invalid)
        assert(program_counter == $past(prefetch_pc_in + (prefetch_ce ? 4 : 0)));
    end
    

    

  `endif

endmodule

`endif
