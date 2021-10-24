`ifndef RV32I_GUARD
`define RV32I_GUARD

`include "rv32i_registers.v"
`include "rv32i_alu.v"
`include "rv32i_memory.v"
`include "rv32i_control.v"

module rv32i(
    input clk_i
  );

  localparam XLEN = 32;
  localparam REG_BITS = 5;

  wire registers_write;
  wire registers_pc_write;
  wire [XLEN-1:0] registers_data;
  wire [XLEN-1:0] registers_pc_data;
  wire [REG_BITS-1:0] rs1_addr;
  wire [REG_BITS-1:0] rs2_addr;
  wire [REG_BITS-1:0] rd_addr;
  wire [XLEN-1:0] rs1;
  wire [XLEN-1:0] rs2;
  wire [XLEN-1:0] pc;

  rv32i_registers #(
    .XLEN(XLEN),
    .REG_BITS(REG_BITS)
  ) RV32I_REGISTERS (
    .clk_i(clk_i),
    .write_i(registers_write),
    .write_pc_i(registers_pc_write),
    .data_i(registers_data),
    .data_pc_i(registers_pc_data),
    .rs1_addr_i(rs1_addr),
    .rs2_addr_i(rs2_addr),
    .rd_addr_i(rd_addr),
    .rs1_o(rs1),
    .rs2_o(rs2),
    .pc_o(pc)
  );

  wire [2:0] funct3;
  wire [6:0] funct7;

  rv32i_alu #(
    .XLEN(XLEN)
  ) RV32I_ALU (
    .clk_i(clk_i),
    // TODO -- this doesn't quite work, since it will
    // be messed up by immediates in funct7!!
    .operation_i({funct7[5], funct3}),
    .operand1_i(),
    .operand2_i(),
    .equal_o(),
    .less_o(),
    .less_signed_o(),
    .result_o()
  );
  
  rv32i_memory #(
    .XLEN(XLEN),
    .MAP_SIZE(),
    .REGION_1_B(),
    .REGION_1_E(),
    .REGION_2_B(),
    .REGION_2_E(),
    .REGION_3_B(),
    .REGION_3_E(),
    .REGION_4_B(),
    .REGION_4_E()
  ) RV32I_MEMORY (
    .clk_i(clk_i),
    .write_i(),
    .read_i(),
    .reset_i(),
    .addr_i(),
    .data_i(),
    .data1_i(),
    .data2_i(),
    .data3_i(),
    .data4_i(),
    .data_region_o(),
    .data_o(),
    .illegal_access_o()
  );

  rv32i_control #(
    .XLEN(XLEN),
    .ILEN(XLEN),
    .REG_BITS(REG_BITS),
    .INST_BITS()
  ) RV32I_CONTROL (
    .clk_i(clk_i),
    .reset_i(),
    .program_counter_i(pc),
    .memory_addr_o(),
    .word_size_o(),
    .rs1_addr_o(rs1_addr),
    .rs2_addr_o(rs2_addr),
    .rd_addr_o(rd_addr),
    .funct3_o(),
    .funct7_o(),
    .registers_write(registers_write),
    .registers_in_o(registers_data),
    .alu_out_i(),
    .alu_operand2_o(),
    .immediate_o(),
    .rs1_i(rs1),
    .rs2_i(rs2),
    .pc_i(pc),
    .pc_o(registers_pc_data),
    .pc_write_o(registers_pc_write),
    .instruction_i(),
    .memory_read_o(),
    .memory_write_o()
  );

endmodule

`endif // RV32I_GUARD
