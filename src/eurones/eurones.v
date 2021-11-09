// TODO -- we'll want an uncached section of memory directly in the cache
// module so interrupts can be handled without incurring a cache miss...
// We could have it be an init_bram and run the bootloader without needing
// to reconfigure the FGPA (program code could be written there after the bootload process)

// TODO -- need  to figure out VTABLE lookup!
`default_nettype none

`include "rv32i_pipe.v"
`include "wb_sram16.v"

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
    output wire SRAM_UB,

    // verilator lint_off UNDRIVEN
    input RX,
    output TX,

    `ifdef SIM
    output wire [15:0] DAC_INTERFACE,
    output wire FRAME_SYNC,
    `endif
    output wire FLASH_CS,
    output wire FLASH_SCK,
    output wire FLASH_SDI,
    input wire  FLASH_SDO,

    output wire DIS_CS,
    output wire DIS_RES,
    output wire DIS_SDI,
    output wire DIS_SCK,
    output wire DIS_DC,

    output wire D_EMP,
    output wire D_DATA,
    output wire D_LRCLK,
    output wire D_FMT,
    output wire D_BCK,
    output wire D_SYSCK,
    output wire D_MUTE,

    output wire HB_O

    // verilator lint_on UNDRIVEN
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
