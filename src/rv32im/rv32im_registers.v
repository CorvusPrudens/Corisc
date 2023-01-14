`ifndef RV32I_REGISTERS_GUARD
`define RV32I_REGISTERS_GUARD

// `include "bram_dual_re.v"
`include "bram_dual_re_nowt.v"

// TODO -- remove write-through for non-pipelined setup

// NOTE -- address setup needs at least half a clock!
module rv32im_registers
  #(
    parameter XLEN = 32,
    parameter REG_BITS = 5
  )
  (
    input wire clk_i,
    input wire write_i,
    input wire [XLEN-1:0] data_i,
    input wire data_ready_i,

    input wire [REG_BITS-1:0] rs1_addr_i,
    input wire [REG_BITS-1:0] rs2_addr_i,
    input wire [REG_BITS-1:0] rd_addr_i,

    output wire [XLEN-1:0] rs1_o,
    output wire [XLEN-1:0] rs2_o
  );

  // Register 0 can't be written to
  wire reg_write = rd_addr_i == 0 ? 1'b0 : write_i;

  bram_dual_re_nowt #(
    .memSize_p(REG_BITS),
    .XLEN(XLEN)
  ) RS1 (
    .clk_i(clk_i),
    .write_i(reg_write),
    .read_i(data_ready_i),
    .data_i(data_i),

    .waddr_i(rd_addr_i),
    .raddr_i(rs1_addr_i),

    .data_o(rs1_o)
  );

  bram_dual_re_nowt #(
    .memSize_p(REG_BITS),
    .XLEN(XLEN)
  ) RS2 (
    .clk_i(clk_i),
    .write_i(reg_write),
    .read_i(data_ready_i),
    .data_i(data_i),

    .waddr_i(rd_addr_i),
    .raddr_i(rs2_addr_i),

    .data_o(rs2_o)
  );

endmodule`endif // RV32I_REGISTERS_GUARD
