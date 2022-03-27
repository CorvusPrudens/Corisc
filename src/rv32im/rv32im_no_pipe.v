`ifndef RV32IM_NO_PIPE_GUARD
`define RV32IM_NO_PIPE_GUARD

module rv32im_no_pipe 
  #(
    parameter XLEN = 32,
    parameter ILEN = 32,
    parameter REG_BITS = 5
  )
  (
    input wire clk_i,
    input wire reset_i,

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
    output wire ctrl_grant_o,

    input wire interrupt_trigger_i
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


  reg [XLEN-1:0] program_counter;
  wire prefetch_advance;
  wire prefetch_data_ready;
  wire [XLEN-1:0] prefetch_instruction;

  wire prefetch_ctrl_req;
  wire prefetch_ctrl_grant = bus_master[1];

  // The only thing that each stage needs to do is check if the next one is ready.
  // No need for more complex chained stalls.

  rv32im_prefetch #(
    .XLEN(XLEN)
  ) RV32IM_PREFETCH (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .program_counter_i(program_counter),
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
    .stb_o(prefetch_stb)
  );

  wire [3:0] alu_operation;
  wire [2:0] word_size;
  wire [REG_BITS-1:0] rs1_addr;
  wire [REG_BITS-1:0] rs2_addr;
  wire [REG_BITS-1:0] rd_addr;
  wire [XLEN-1:0] immediate;
  wire immediate_valid;
  wire [XLEN-1:0] irrelevant_pc;

  wire mret_o;
  wire [XLEN-1:0] uepc_o;
  wire jal_jump_o;
  wire [XLEN-1:0] pc_jal_data_o;
  wire jalr_o;
  wire branch_o;
  wire [2:0] branch_condition_o;
  wire clear_branch_stall_i;
  wire link_o;
  wire [XLEN-1:0] link_data_o;
  wire pop_ras_o;
  wire push_ras_o;
  wire [2:0] stage4_path_o;
  wire memory_write_o;
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
    .mret_o(),
    .uepc_o(),
    .jal_jump_o(),
    .pc_jal_data_o(),
    .jalr_o(),
    .branch_o(),
    .branch_condition_o(),
    .clear_branch_stall_i(),
    .link_o(),
    .link_data_o(),
    .pop_ras_o(ras_pop),
    .push_ras_o(ras_push),
    .stage4_path_o(),
    .memory_write_o(),
    .processing_jump()
  );

  reg registers_write;
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
    .data_ready_i(),
    .rs1_addr_i(rs1_addr),
    .rs2_addr_i(rs2_addr),
    .rd_addr_i(rd_addr),
    .rs1_o(rs1),
    .rs2_o(rs2),
    .ras_o(ras),
    .pc_i(program_counter),
    .ras_write_i(),
    .push_ras_i(ras_push),
    .pop_ras_i(ras_pop)
  );

  // Splitty stage
  wire [XLEN-1:0] alu_result;
  wire alu_equal;
  wire alu_less;
  wire alu_less_unsigned;

  rv32im_alu #(
    .XLEN(XLEN)
  ) RV32IM_ALU (
    .clk_i(clk_i),
    .data_ready_i(),
    .operation_i(alu_operation),
    .operand1_i(rs1),
    .operand2_i(),
    .result_o(alu_result),
    .equal_o(alu_equal),
    .less_o(alu_less_unsigned),
    .less_signed_o(alu_less),
    .clear_i(1'b0)
  );

  wire memory_ctrl_grant = bus_master[0];

  rv32im_memory_nopipe #(
    .XLEN(XLEN)
  ) RV32IM_MEMORY (
    .clk_i(clk_i),
    .clear_i(),
    .data_ready_i(),
    .data_i(),
    .data_o(),
    .addr_i(),
    .word_size_i(),
    .write_i(),
    .busy_o(),
    .err_o(),

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

  wire [XLEN-1:0] muldiv_result;

  rv32im_muldiv #(
    .XLEN(XLEN)
  ) RV32IM_MULDIV (
    .clk_i(clk_i),
    .clear_i(),
    .operation_i(alu_operation[2:0]),
    .data_ready_i(),
    .operand1_i(rs1),
    .operand2_i(),
    .result_o(muldiv_result),
    .data_ready_o(),
    .busy_o(),
    .writeback_ce_i()
  );
  
  // writeback stage



endmodule

`endif // RV32IM_NO_PIPE_GUARD