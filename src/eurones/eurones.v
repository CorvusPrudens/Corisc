
`default_nettype none

`include "rv32i_pipe.v"

module eurones(
    input wire clk_i,
    input wire reset_i
  );

  localparam XLEN = 32;
  localparam ILEN = 32;
  localparam REG_BITS = 5;

  wire [XLEN-1:0] master_dat_i;
  wire [XLEN-1:0] master_dat_o;
  wire master_ack;
  wire [XLEN-1:2] master_adr;
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

  

endmodule