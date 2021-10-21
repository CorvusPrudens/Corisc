`ifndef RV32I_REGISTERS_GUARD
`define RV32I_REGISTERS_GUARD

`include "common/bram.v"

// NOTE -- address setup needs at least half a clock!
module rv32i_registers 
  #(
    parameter XLEN = 32,
    parameter REG_BITS = 5
  )
  (
    input wire clk_i,
    input wire write_i,
    input wire write_pc_i,
    input wire increment_pc_i,

    input wire [XLEN-1:0] data_i,
    input wire [XLEN-1:0] data_pc_i,

    input wire [REG_BITS-1:0] rs1_addr_i,
    input wire [REG_BITS-1:0] rs2_addr_i,
    input wire [REG_BITS-1:0] rd_addr_i,

    output wire [XLEN-1:0] rs1_o,
    output wire [XLEN-1:0] rs2_o,
    output wire [XLEN-1:0] pc_o
  );

  reg [XLEN-1:0] pc = 0;
  assign pc_o = pc;

  always @(posedge clk_i) begin
    if (write_pc_i)
      pc <= data_pc_i;
    else if (increment_pc_i)
      pc <= pc + 1'b1;
  end

  bram #(
    .memSize_p(REG_BITS),
    .dataWidth_p(XLEN)
  ) RS1 (
    .clk_i(clk_i),
    .write_i(write_i),
    .read_i(1'b1),
    .data_i(data_i),

    .waddr_i(rs1_addr_i),
    .raddr_i(rd_addr_i),

    .data_o(rs1_o)
  );

  bram #(
    .memSize_p(REG_BITS),
    .dataWidth_p(XLEN)
  ) RS2 (
    .clk_i(clk_i),
    .write_i(write_i),
    .read_i(1'b1),
    .data_i(data_i),

    .waddr_i(rs1_addr_i),
    .raddr_i(rd_addr_i),

    .data_o(rs2_o)
  );

endmodule`endif // RV32I_REGISTERS_GUARD
