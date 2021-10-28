`ifndef RV32I_GUARD
`define RV32I_GUARD

`include "rv32i_registers.v"
`include "rv32i_alu.v"
`include "rv32i_memory.v"
`include "rv32i_control.v"
`include "bram_init.v"
`include "uartwrapper.v"
`include "sram16.v"

module rv32i(
    input clk_i,
    input RX,
    output TX,

    `ifdef SIM
    output wire [15:0] SRAM_O,
    input wire [15:0] SRAM_I,
    `else
    inout wire [15:0] SRAM_DATA,
    `endif
    output wire [15:0] SRAM_ADDR,
    output wire SRAM_WE,
    output wire SRAM_CE,
    output wire SRAM_OE,
    output wire SRAM_UB,
    output wire SRAM_LB
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
  wire push_ras;
  wire pop_ras;

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
    .pc_o(pc),
    .push_ras_i(push_ras),
    .pop_ras_i(pop_ras)
  );

  wire [2:0] funct3;
  wire [6:0] funct7;

  wire [XLEN-1:0] alu_operand2;
  wire alu_equal;
  wire alu_less;
  wire alu_less_signed;
  wire [XLEN-1:0] alu_result;
  wire immediate_arithmetic;

  rv32i_alu #(
    .XLEN(XLEN)
  ) RV32I_ALU (
    .clk_i(clk_i),
    // TODO -- this doesn't quite work, since it will
    // be messed up by immediates in funct7!!
    .operation_i({funct7[5] & ~immediate_arithmetic, funct3}),
    .operand1_i(rs1),
    .operand2_i(alu_operand2),
    .equal_o(alu_equal),
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

  wire [8:0] memory_region;

  wire [MEM_LEN-1:0] bootloader_out;
  wire [MEM_LEN-1:0] general_out;
  wire [MEM_LEN-1:0] gpu_out = 0;
  wire [MEM_LEN-1:0] apu_out = 0;
  wire [MEM_LEN-1:0] vrc6_1_out = 0;
  wire [MEM_LEN-1:0] vrc6_2_out = 0;
  wire [MEM_LEN-1:0] vrc6_3_out = 0;
  wire [MEM_LEN-1:0] progmem_out;
  wire [MEM_LEN-1:0] sram_out;

  wire [MEM_LEN-1:0] uart_out;
  assign general_out = uart_out;

  wire [MEM_LEN-1:0] write_mask;
  
  rv32i_memory #(
    .XLEN(XLEN),
    .PORT_LEN(MEM_LEN),
    .MAP_SIZE(9),
    .REGION_0_B(32'h00000000),
    .REGION_0_E(32'h00000400),
    .REGION_1_B(32'h00001000),
    .REGION_1_E(32'h00001040),
    .REGION_2_B(32'h00002000),
    .REGION_2_E(32'h00002400),
    .REGION_3_B(32'h00004000),
    .REGION_3_E(32'h00004018),
    .REGION_4_B(32'h00009000),
    .REGION_4_E(32'h00009004),
    .REGION_5_B(32'h0000A000),
    .REGION_5_E(32'h0000A004),
    .REGION_6_B(32'h0000B000),
    .REGION_6_E(32'h0000B004),
    .REGION_7_B(32'h00010000),
    .REGION_7_E(32'h00020000),
    .REGION_8_B(32'h00020000),
    .REGION_8_E(32'h00030000)
  ) RV32I_MEMORY (
    .clk_i(clk_i),
    .write_i(memory_write),
    .read_i(memory_read),
    .reset_i(memory_reset),
    .addr_i(memory_addr),
    .data_i(memory_in),

    .data0_i(bootloader_out),
    .data1_i(general_out),
    .data2_i(gpu_out),
    .data3_i(apu_out),
    .data4_i(vrc6_1_out),
    .data5_i(vrc6_2_out),
    .data6_i(vrc6_3_out),
    .data7_i(progmem_out),
    .data8_i(sram_out),

    .data_region_o(memory_region),
    .data_o(memory_out),
    .illegal_access_o(illegal_memory_access)
  );

  ///////////////////////////////////////////////////////////////
  // Memory mapped modules
  ///////////////////////////////////////////////////////////////

  uartwrapper UARTWRAPPER (
    .clk_i(clk_i),
    .data_i(memory_in[7:0]),
    .write_i(memory_region[1] & memory_write & ~memory_addr[0]),
    .read_i(memory_region[1] & memory_read & ~memory_addr[0]),
    .data_o(uart_out[7:0]),
    .status_o(uart_out[15:8]),
    .RX(RX),
    .TX(TX)
  );

  // Keep in mind that RISC-V is _byte_ addressed, so memories with word sizes
  // of 16 will actually ignore the lsb of the address
  bram_init #(
    .memSize_p(9),
    .dataWidth_p(MEM_LEN),
    .initFile_p("program.hex")
  ) BOOTLOADER (
    .clk_i(clk_i),
    .write_i(memory_region[0] & memory_write),
    .data_i(memory_in),
    .addr_i(memory_addr[9:1]),
    .data_o(bootloader_out)
  );

  assign progmem_out = sram_out;
  // Should progmem be unwritable in the non-bootloader configuration? (nah probably not, we could easily
  // load program linked for certain sections of progmem in-app)
  sram16 SRAM16 (
    .clk_i(clk_i),
    .write_i(memory_write & (memory_region[7] | memory_region[8])),
    .addr_i({~memory_addr[16], memory_addr[15:1]}),
    .data_i(memory_in),
    .data_o(sram_out),
    .mask_i(write_mask),
    .SRAM_ADDR(SRAM_ADDR),
    `ifdef SIM
    .SRAM_I(SRAM_I),
    .SRAM_O(SRAM_O),
    `else
    .SRAM_DATA(SRAM_DATA),
    `endif
    .SRAM_WE(SRAM_WE),
    .SRAM_CE(SRAM_CE),
    .SRAM_OE(SRAM_OE),
    .SRAM_LB(SRAM_LB),
    .SRAM_UB(SRAM_UB)
  );

  ///////////////////////////////////////////////////////////////
  // Memory mapped modules end
  ///////////////////////////////////////////////////////////////

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
    .alu_equal_i(alu_equal),
    .alu_less_i(alu_less),
    .alu_less_signed_i(alu_less_signed),
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
    .memory_i(memory_out),
    .memory_read_o(memory_read),
    .memory_write_o(memory_write),
    .memory_write_mask_o(write_mask),
    .memory_o(memory_in),
    .immediate_arithmetic_o(immediate_arithmetic),
    .push_ras_o(push_ras),
    .pop_ras_o(pop_ras)
  );

endmodule

`endif // RV32I_GUARD
