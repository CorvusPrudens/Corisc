
`default_nettype none

`include "rv32i_pipe.v"

module eurones(
    input wire clk_i,
    input wire reset_i,

    output wire [15:0] SRAM_ADDR,
    `ifdef SIM
    input wire [15:0] SRAM_I,
    output wire [15:0] SRAM_O,
    `else
    inout wire [15:0] SRAM_DATA,
    `endif
    output wire SRAM_WE,
    output wire SRAM_CE,
    output wire SRAM_OE,
    output wire SRAM_LB,
    output wire SRAM_UB
  );

  localparam XLEN = 32;
  localparam ILEN = 32;
  localparam REG_BITS = 5;

  wire [XLEN-1:0] master_dat_i;
  wire [XLEN-1:0] master_dat_o;
  wire master_ack;
  wire [XLEN-3:0] master_adr;
  wire master_cyc;
  wire master_err;
  wire [3:0] master_sel;
  wire master_stb;
  wire master_we;

  rv32i_pipe #(
    .XLEN(XLEN),
    .ILEN(ILEN),
    .REG_BITS(REG_BITS)
  ) RV32I_PIPE (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .interrupt_vector(8'b0),
    .master_dat_i(master_dat_i),
    .master_dat_o(master_dat_o),
    .ack_i(master_ack),
    .adr_o(master_adr),
    .cyc_o(master_cyc),
    .err_i(master_err),
    .sel_o(master_sel),
    .stb_o(master_stb),
    .we_o(master_we)
  );

  wb_sram16 #(
    .XLEN(XLEN),
    .ADDR_BITS(17)
  ) WB_SRAM16 (
    .clk_i(clk_i),
    .slave_dat_i(master_dat_o),
    .slave_dat_o(master_dat_i),
    .rst_i(reset_i),
    .ack_o(master_ack),
    .adr_i(master_adr[14:0]),
    .cyc_i(master_cyc),
    .err_o(master_err),
    .sel_i(master_sel),
    .stb_i(master_stb),
    .we_i(master_we),
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
  

endmodule
