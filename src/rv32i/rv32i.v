`ifndef RV32I_GUARD
`define RV32I_GUARD

`include "rv32i_registers.v"
`include "rv32i_alu.v"
`include "rv32i_memory.v"
`include "rv32i_control.v"
`include "bram.v"

module rv32i(
    input clk_i
  );

  localparam XLEN = 32;
  localparam REG_BITS = 5;
  localparam MEM_LEN = 16;

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

  wire [XLEN-1:0] alu_operand2;
  wire aly_equal;
  wire alu_less;
  wire alu_less_signed;
  wire [XLEN-1:0] alu_result;

  rv32i_alu #(
    .XLEN(XLEN)
  ) RV32I_ALU (
    .clk_i(clk_i),
    // TODO -- this doesn't quite work, since it will
    // be messed up by immediates in funct7!!
    .operation_i({funct7[5], funct3}),
    .operand1_i(rs1),
    .operand2_i(alu_operand2),
    .equal_o(aly_equal),
    .less_o(alu_less),
    .less_signed_o(alu_less_signed),
    .result_o(alu_result)
  );

  wire memory_write;
  wire memory_read;
  wire memory_reset = 1'b0;
  wire [XLEN-1:0] memory_addr;
  wire [MEM_LEN-1:0] memory_in;
  wire [MEM_LEN-1:0] memory_out;
  wire illegal_memory_access;

  wire [3:0] memory_region;
  wire [MEM_LEN-1:0] ram_out;
  wire [MEM_LEN-1:0] rom_out;

  wire [MEM_LEN-1:0] write_mask;
  
  rv32i_memory #(
    .XLEN(XLEN),
    .PORT_LEN(MEM_LEN),
    .MAP_SIZE(4),
    .REGION_1_B(32'd0),
    .REGION_1_E(32'd1024),
    .REGION_2_B(32'd1024),
    .REGION_2_E(32'd2048),
    .REGION_3_B(32'd4096),
    .REGION_3_E(32'd4096),
    .REGION_4_B(32'd4096),
    .REGION_4_E(32'd4096)
  ) RV32I_MEMORY (
    .clk_i(clk_i),
    .write_i(memory_write),
    .read_i(memory_read),
    .reset_i(memory_reset),
    .addr_i(memory_addr),
    .data_i(memory_in),

    .data1_i(rom_out),
    .data2_i(ram_out),
    .data3_i(16'b0),
    .data4_i(16'b0),

    .data_region_o(memory_region),
    .data_o(memory_out),
    .illegal_access_o(illegal_memory_access)
  );

  // Keep in mind that RISC-V is _byte_ addressed, so memories with word sizes
  // of 16 will actually ignore the lsb of the address
  bram_init #(
    .memSize_p(9),
    .dataWidth_p(MEM_LEN),
    .initFile_p("program.hex")
  ) INIT_BRAM (
    .clk_i(clk_i),
    .write_i(memory_region[0] & memory_write),
    .data_i(memory_in),
    .addr_i(memory_addr[9:1]),
    .data_o(rom_out)
  );

  bram_mask #(
    .MEMORY_SIZE(9),
    .XLEN(MEM_LEN)
  ) BRAM_MASK (
    .clk_i(clk_i),
    .write_i(memory_region[1] & memory_write),
    .data_i(memory_in),
    .write_mask_i(),
    .addr_i({memory_addr[10], memory_addr[8:1]}),
    .data_o(ram_out)
  );

  rv32i_control #(
    .XLEN(XLEN),
    .ILEN(XLEN),
    .REG_BITS(REG_BITS),
    .INST_BITS(MEM_LEN)
  ) RV32I_CONTROL (
    .clk_i(clk_i),
    .reset_i(1'b0),
    .program_counter_i(pc),
    .memory_addr_o(memory_addr),
    .rs1_addr_o(rs1_addr),
    .rs2_addr_o(rs2_addr),
    .rd_addr_o(rd_addr),
    .funct3_o(funct3),
    .funct7_o(funct7),
    .registers_write(registers_write),
    .registers_in_o(registers_data),
    .alu_out_i(alu_result),
    .alu_operand2_o(alu_operand2),
    .rs1_i(rs1),
    .rs2_i(rs2),
    .pc_i(pc),
    .pc_o(registers_pc_data),
    .pc_write_o(registers_pc_write),
    .instruction_i(memory_out),
    .memory_read_o(memory_read),
    .memory_write_o(memory_write),
    .memory_write_mask_o(write_mask),
    .memory_in_o(memory_in)
  );

endmodule

`endif // RV32I_GUARD
