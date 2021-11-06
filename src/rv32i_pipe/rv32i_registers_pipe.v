`ifndef RV32I_REGISTERS_GUARD
`define RV32I_REGISTERS_GUARD

`include "bram_dual.v"
`include "stack.v"

// NOTE -- address setup needs at least half a clock!
module rv32i_registers_pipe 
  #(
    parameter XLEN = 32,
    parameter REG_BITS = 5
  )
  (
    input wire clk_i,
    input wire write_i,
    input wire [XLEN-1:0] data_i,

    input wire [REG_BITS-1:0] rs1_addr_i,
    input wire [REG_BITS-1:0] rs2_addr_i,
    input wire [REG_BITS-1:0] rd_addr_i,

    output wire [XLEN-1:0] rs1_o,
    output wire [XLEN-1:0] rs2_o,

    input wire push_ras_i,
    input wire pop_ras_i
  );

  // Register 0 can't be written to
  wire reg_write = rd_addr_i == 0 ? 1'b0 : write_i;
  
  wire [XLEN-1:0] rs1_raw;
  assign rs1_o = pop_ras_i ? stack_out : rs1_raw;

  bram_dual #(
    .memSize_p(REG_BITS),
    .dataWidth_p(XLEN)
  ) RS1 (
    .clk_i(clk_i),
    .write_i(reg_write),
    .data_i(data_i),

    .waddr_i(rd_addr_i),
    .raddr_i(rs1_addr_i),

    .data_o(rs1_raw)
  );

  bram_dual #(
    .memSize_p(REG_BITS),
    .dataWidth_p(XLEN)
  ) RS2 (
    .clk_i(clk_i),
    .write_i(reg_write),
    .data_i(data_i),

    .waddr_i(rd_addr_i),
    .raddr_i(rs2_addr_i),

    .data_o(rs2_o)
  );

  wire stack_overflow;
  wire [XLEN-1:0] stack_out;

  stack #(
    .XLEN(XLEN),
    .SIZE(7) // 128 address ought to be way more than sufficient
  ) RAS (
    .clk_i(clk_i),
    .push_i(push_ras_i),
    .pop_i(pop_ras_i),
    .data_i(data_i),
    .data_o(stack_out),
    .overflow_o(stack_overflow)
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