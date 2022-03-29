`ifndef RV32IM_NO_PIPE_GUARD
`define RV32IM_NO_PIPE_GUARD

module rv32im_no_pipe 
  #(
    parameter XLEN = 32,
    parameter ILEN = 32,
    parameter REG_BITS = 5,
    parameter INT_VECT_LEN = 8,
    parameter VTABLE_ADDR = 32'h00300000
  )
  (
    input wire clk_i,
    input wire reset_i,

    input wire [XLEN-1:0] interrupt_vector_offset_i,
    input wire interrupt_trigger_i,
    output wire interrupt_routine_complete_o,

    input wire [XLEN-1:0] master_dat_i,
    output wire [XLEN-1:0] master_dat_o,
    input wire ack_i,
    output wire [XLEN-3:0] adr_o,
    output wire cyc_o,
    input wire err_i,
    output wire [3:0] sel_o,
    output wire stb_o,
    output wire we_o,
    
    input wire ctrl_req_i,
    output wire ctrl_grant_o
  );

  wire memory_ctrl_req;

  // Bus arbitration
  reg [2:0] bus_master;
  wire [2:0] bus_requests = {ctrl_req_i, prefetch_ctrl_req, memory_ctrl_req};
  assign ctrl_grant_o = bus_master[2];

  always @(posedge clk_i) begin
    // This could be made parametric, but this works for now
    case (bus_master)
      3'b000:
      begin
        if (bus_requests[0])
          bus_master <= 3'b001;
        else if (bus_requests[1])
          bus_master <= 3'b010;
        else if (bus_requests[2])
          bus_master <= 3'b100;
      end
      3'b001:
      begin
        if (~bus_requests[0])
          bus_master <= 0;
      end
      3'b010:
      begin
        if (~bus_requests[1])
          bus_master <= 0;
      end
      3'b100:
      begin
        if (~bus_requests[2])
          bus_master <= 0;
      end
      default:
        bus_master <= 0;
    endcase
  end

  wire [XLEN-3:0] prefetch_adr;
  wire prefetch_cyc;
  wire [3:0] prefetch_sel;
  wire prefetch_stb;

  wire [XLEN-1:0] memory_dat_o;
  wire [XLEN-3:0] memory_adr;
  wire memory_cyc;
  wire [3:0] memory_sel;
  wire memory_stb;
  wire memory_we_o;


  // For the moment, if external control of the bus is taken,
  // the the state of the bus doesn't matter within this module
  assign master_dat_o = memory_dat_o;
  assign we_o = bus_master[1]  ? 1'b0 : memory_we_o;
  assign stb_o = bus_master[1] ? prefetch_stb : memory_stb;
  assign cyc_o = bus_master[1] ? prefetch_cyc : memory_cyc;
  assign sel_o = bus_master[1] ? prefetch_sel : memory_sel;


  reg initial_push;

  always @(posedge clk_i) begin
    if (reset_i)
      initial_push <= 1'b0;
    else if (prefetch_data_ready)
      initial_push <= 1'b1;
  end

  reg [XLEN-1:0] program_counter;
  wire prefetch_advance = ~initial_push | writeback_data_ready | prefetch_advance_after_jump;
  wire prefetch_data_ready;
  wire [XLEN-1:0] prefetch_instruction;

  wire prefetch_ctrl_req;
  wire prefetch_ctrl_grant = bus_master[1];

  wire [XLEN-1:0] interrupt_pc;
  wire interrupt_pc_write;

  wire jalr_jump = jalr & ~stb_o;
  wire branch_jump = writeback_branch;

  wire prefetch_advance_after_jump;

  assign prefetch_pc_write = jal_jump | jalr_jump | branch_jump | interrupt_pc_write;

  wire [XLEN-1:0] jalr_base = ras_pop ? ras : rs1;

  always @(*) begin
    casez ({vtable_pc_write, branch_jump, jalr_jump})
      default: prefetch_pc_in = prefetch_pc_in_jal;
      3'b001: prefetch_pc_in = mret ? uepc : immediate + jalr_base;
      3'b01?: prefetch_pc_in = writeback_branch_data;
      3'b1??: prefetch_pc_in = interrupt_pc;
    endcase
  end

  // This is sure to cause some bugs
  always @(posedge clk_i) begin
    if (reset_i) begin

    end else if (prefetch_advance) begin
      if (prefetch_pc_write) begin
        program_counter <= prefetch_pc_in + 32'b100;
      end else begin
        program_counter <= program_counter + 32'b100;
      end
    end else if (prefetch_pc_write) begin
      program_counter <= prefetch_pc_in;
    end
  end

  always @(posedge clk_i) begin
    if (reset_i) begin
      prefetch_advance_after_jump <= 1'b0;
    end else if (prefetch_pc_write) begin
      prefetch_advance_after_jump <= 1'b1;
    end else if (prefetch_data_ready) begin
      prefetch_advance_after_jump <= 1'b0;
    end
  end

  // The only thing that each stage needs to do is check if the next one is ready.
  // No need for more complex chained stalls.

  rv32im_prefetch #(
    .XLEN(XLEN)
  ) RV32IM_PREFETCH (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .program_counter_i(prefetch_pc_write ? prefetch_pc_in : program_counter),
    .advance_i(prefetch_advance),
    .data_ready_o(prefetch_data_ready),
    .instruction_o(prefetch_instruction),
    .ctrl_req_o(prefetch_ctrl_req),
    .ctrl_grant_i(prefetch_ctrl_grant),
    .master_dat_i(master_dat_i),
    .ack_i(ack_i),
    .adr_o(prefetch_adr),
    .cyc_o(prefetch_cyc),
    .err_i(err_i),
    .sel_o(prefetch_sel),
    .stb_o(prefetch_stb),

    .interrupt_trigger_i(interrupt_trigger_i),
    .vtable_addr(VTABLE_ADDR),
    .vtable_offset(interrupt_vector_offset_i),

    .interrupt_pc_o(interrupt_pc),
    .interrupt_pc_write(interrupt_pc_write)
  );

  wire [3:0] alu_operation;
  wire [2:0] word_size;
  wire [REG_BITS-1:0] rs1_addr;
  wire [REG_BITS-1:0] rs2_addr;
  wire [REG_BITS-1:0] rd_addr;
  wire [XLEN-1:0] immediate;
  wire immediate_valid;
  wire [XLEN-1:0] irrelevant_pc;

  wire mret;
  wire [XLEN-1:0] uepc;
  wire jal_jump;
  wire [XLEN-1:0] pc_jal_data;
  wire jalr;
  wire branch;
  wire [2:0] branch_condition;
  wire link;
  wire [XLEN-1:0] link_data;
  wire [2:0] stage4_path;
  wire memory_write;
  wire processing_jump;

  wire ras_pop;
  wire ras_push;
  wire ras_write;

  rv32im_decode #(
    .XLEN(XLEN),
    .ILEN(ILEN),
    .REG_BITS(REG_BITS)
  ) RV32IM_DECODE (
    .clk_i(clk_i),
    .clear_i(reset_i),
    .instruction_i(prefetch_instruction),
    .data_ready_i(prefetch_data_ready),
    .alu_operation_o(alu_operation),
    .word_size_o(word_size),
    .rs1_addr_o(rs1_addr),
    .rs2_addr_o(rs2_addr),
    .rd_addr_o(rd_addr),
    .immediate_o(immediate),
    .immediate_valid_o(immediate_valid),
    .pc_data_i(program_counter),
    .pc_data_o(irrelevant_pc),
    .interrupt_trigger_i(interrupt_trigger_i),
    .mret_o(mret),
    .uepc_o(uepc),
    .jal_jump_o(jal_jump),
    .pc_jal_data_o(pc_jal_data),
    .jalr_o(jalr),
    .branch_o(branch),
    .branch_condition_o(branch_condition),
    .clear_branch_stall_i(1'b0),
    .link_o(link),
    .link_data_o(link_data),
    .pop_ras_o(ras_pop),
    .push_ras_o(ras_push),
    .stage4_path_o(stage4_path),
    .memory_write_o(memory_write),
    .processing_jump(processing_jump)
  );

  wire decode_clear = reset_i | jal_jump | jalr_jump | branch_jump;;
  reg decode_data_ready;

  always @(posedge clk_i) begin
    if (decode_clear)
      decode_data_ready <= 1'b0;
    else if (prefetch_data_ready)
      decode_data_ready <= prefetch_data_ready;
    else
      decode_data_ready <= 1'b0;
  end

  wire registers_write = writeback_registers_write;
  wire [XLEN-1:0] writeback_data;

  wire [XLEN-1:0] rs1;
  wire [XLEN-1:0] rs2;
  wire [XLEN-1:0] ras;

  rv32im_registers #(
    .XLEN(XLEN),
    .REG_BITS(REG_BITS)
  ) RV32IM_REGISTERS (
    .clk_i(clk_i),
    .write_i(registers_write),
    .data_i(writeback_data),
    .data_ready_i(decode_data_ready),
    .rs1_addr_i(rs1_addr),
    .rs2_addr_i(rs2_addr),
    .rd_addr_i(rd_addr),
    .rs1_o(rs1),
    .rs2_o(rs2),
    .ras_o(ras),
    .pc_i(program_counter),
    .ras_write_i(),
    .push_ras_i(branch_jump ? 1'b0 : ras_push),
    .pop_ras_i(mret & jalr_jump ? 1'b0 : ras_pop)
  );

  wire opfetch_clear = reset_i | jalr_jump | branch_jump;
  reg opfetch_data_ready;
  reg stage4_data_ready;

  always @(posedge clk_i) begin
    if (opfetch_clear)
      opfetch_data_ready <= 1'b0;
    else if (decode_data_ready)
      opfetch_data_ready <= decode_data_ready;
    else if (stage4_data_ready)
      opfetch_data_ready <= 1'b0;
  end

  wire stage4_path_alu = stage4_path[0];
  reg [XLEN-1:0] stage4_result;
  reg [XLEN-1:0] mem_data_out;

  // Splitty stage
  wire [XLEN-1:0] alu_result;
  wire alu_equal;
  wire alu_less;
  wire alu_less_unsigned;

  wire alu_advance = stage4_path[0] & opfetch_data_ready;
  wire [XLEN-1:0] alu_operand2 = immediate_valid ? immediate : rs2;
  reg alu_data_ready;

  always @(posedge clk_i) begin
    if (reset_i) begin
      alu_data_ready <= 1'b0;
    end else if (alu_advance) begin
      alu_data_ready <= 1'b1;
    end else if (writeback_advance) begin
      alu_data_ready <= 1'b0;
    end
  end

  rv32im_alu #(
    .XLEN(XLEN)
  ) RV32IM_ALU (
    .clk_i(clk_i),
    .data_ready_i(alu_advance),
    .operation_i(alu_operation),
    .operand1_i(rs1),
    .operand2_i(alu_operand2),
    .result_o(alu_result),
    .equal_o(alu_equal),
    .less_o(alu_less_unsigned),
    .less_signed_o(alu_less),
    .clear_i(1'b0)
  );

  wire memory_clear = reset_i;
  wire memory_ctrl_grant = bus_master[0];
  wire [XLEN-1:0] memory_addr_in = rs1 + immediate;
  wire mem_busy;
  wire mem_err;
  wire mem_advance = opfetch_data_ready & stage4_path[1];

  wire mem_transaction_done = ack_i & memory_ctrl_grant & memory_ctrl_req;
  reg mem_data_ready;

  rv32im_memory_nopipe #(
    .XLEN(XLEN)
  ) RV32IM_MEMORY (
    .clk_i(clk_i),
    .clear_i(memory_clear),
    .data_ready_i(mem_advance),
    .data_i(rs2),
    .data_o(mem_data_out),
    .addr_i(memory_addr_in),
    .word_size_i(word_size),
    .write_i(memory_write),
    .busy_o(mem_busy),
    .err_o(mem_err),

    .master_dat_i(master_dat_i),
    .master_dat_o(memory_dat_o),
    .ack_i(ack_i),
    .adr_o(memory_adr),
    .cyc_o(memory_cyc),
    .err_i(err_i),
    .sel_o(memory_sel),
    .stb_o(memory_stb),
    .we_o(memory_we_o),

    .ctrl_grant_i(memory_ctrl_grant),
    .ctrl_req_o(memory_ctrl_req)
  );
 
  always @(posedge clk_i) begin
    if (memory_clear) begin
      mem_data_ready <= 1'b0;
    end else if (mem_transaction_done) begin
      mem_data_ready <= 1'b1;
    end else if (writeback_advance) begin
      mem_data_ready <= 1'b0;
    end
  end

  wire [XLEN-1:0] muldiv_result;
  wire muldiv_clear = reset_i;
  wire muldiv_advance = opfetch_data_ready & stage4_path[2];
  wire muldiv_data_ready;
  wire muldiv_busy;

  rv32im_muldiv #(
    .XLEN(XLEN)
  ) RV32IM_MULDIV (
    .clk_i(clk_i),
    .clear_i(muldiv_clear),
    .operation_i(alu_operation[2:0]),
    .data_ready_i(muldiv_advance),
    .operand1_i(rs1),
    .operand2_i(rs2),
    .result_o(muldiv_result),
    .data_ready_o(muldiv_data_ready),
    .busy_o(muldiv_busy),
    .writeback_ce_i(writeback_advance)
  );

  always @(*) begin
    case (stage4_path)
      default: stage4_data_ready = alu_data_ready;
      3'b010: stage4_data_ready = mem_data_ready;
      3'b100: stage4_data_ready = muldiv_data_ready;
    endcase
  end

  always @(*) begin
    case (stage4_path)
      default: stage4_result = alu_link ? alu_link_data : alu_result;
      3'b010: stage4_result = mem_data_out;
      3'b100: stage4_result = muldiv_result;
    endcase
  end
  
  // writeback stage
  reg writeback_branch;
  reg [XLEN-1:0] writeback_data;
  reg [XLEN-1:0] writeback_branch_data;
  wire writeback_advance = stage4_data_ready;
  reg writeback_data_ready;

  always @(posedge clk_i) begin
    if (writeback_clear) begin
      writeback_registers_write <= 1'b0;
      writeback_data <= 0;
      writeback_branch <= 1'b0;
      writeback_data_ready <= 1'b0;
    end else if (writeback_advance) begin
      writeback_data_ready <= 1'b1;
      writeback_data <= stage4_result;
      writeback_registers_write <= (rd_addr > 0);
      writeback_branch_data <= immediate + program_counter;
      if (branch) begin
        case (branch_condition)
          default: writeback_branch <= 1'b0;
          3'b000: if (alu_equal) writeback_branch <= 1'b1;
          3'b001: if (~alu_equal) writeback_branch <= 1'b1;
          3'b100: if (alu_less) writeback_branch <= 1'b1;
          3'b101: if (~alu_less) writeback_branch <= 1'b1;
          3'b110: if (alu_less_unsigned) writeback_branch <= 1'b1;
          3'b111: if (~alu_less_unsigned) writeback_branch <= 1'b1;
        endcase
      end else begin
        writeback_branch <= 1'b0;
      end
    end else begin
      writeback_registers_write <= 1'b0;
      writeback_branch <= 1'b0;
      if (prefetch_data_ready)
        writeback_data_ready <= 1'b0;
    end
  end


endmodule

`endif // RV32IM_NO_PIPE_GUARD