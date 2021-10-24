`ifndef RV32I_REGISTERS_GUARD
`define RV32I_REGISTERS_GUARD

`include "bram.v"

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
  end

  // Register 0 can't be written to
  wire reg_write = rd_addr_i == 0 ? 1'b0 : write_i;

  bram #(
    .memSize_p(REG_BITS),
    .dataWidth_p(XLEN)
  ) RS1 (
    .clk_i(clk_i),
    .write_i(reg_write),
    .read_i(1'b1),
    .data_i(data_i),

    .waddr_i(rd_addr_i),
    .raddr_i(rs1_addr_i),

    .data_o(rs1_o)
  );

  bram #(
    .memSize_p(REG_BITS),
    .dataWidth_p(XLEN)
  ) RS2 (
    .clk_i(clk_i),
    .write_i(reg_write),
    .read_i(1'b1),
    .data_i(data_i),

    .waddr_i(rd_addr_i),
    .raddr_i(rs2_addr_i),

    .data_o(rs2_o)
  );

  `ifdef FORMAL
    // TODO -- find way to set initial BRAM values to zero
    // FORMAL prove
    reg timeValid_f = 0;
    always @(posedge clk_i) timeValid_f <= 1;

    always @(*)
        assume(rs1_addr_i == rs2_addr_i);
    
    // TODO -- how to detect two-clock delayed events?
    always @(posedge clk_i) begin
      if (timeValid_f && $past(write_i))
        assert(rs1_o == rs2_o);
    end
  `endif

endmodule`endif // RV32I_REGISTERS_GUARD
