
`include "rv32i_registers.v"

module rv32i_registers_test(
    input wire clk_i
  );

  reg write = 0;
  reg write_pc = 0;
  reg increment_pc = 0;

  reg [31:0] data = 0;
  reg [31:0] data_pc = 0;

  reg [4:0] rs1_addr = 0;
  reg [4:0] rs2_addr = 0;
  reg [4:0] rd_addr = 0;

  wire [31:0] rs1;
  wire [31:0] rs2;
  wire [31:0] pc;

  rv32i_registers #(
    .XLEN(32),
    .REG_BITS(5)
  ) RV32I_REGISTERS (
    .clk_i(clk_i),
    .write_i(write),
    .write_pc_i(write_pc),
    .increment_pc_i(increment_pc),
    .data_i(data),
    .data_pc_i(data_pc),
    .rs1_addr_i(rs1_addr),
    .rs2_addr_i(rs2_addr),
    .rd_addr_i(rd_addr),
    .rs1_o(rs1),
    .rs2_o(rs2),
    .pc_o(pc)
  );

endmodule