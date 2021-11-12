// TODO -- we'll want an uncached section of memory directly in the cache
// module so interrupts can be handled without incurring a cache miss...
// We could have it be an init_bram and run the bootloader without needing
// to reconfigure the FGPA (program code could be written there after the bootload process)

// TODO -- need  to figure out VTABLE lookup!
`default_nettype none

`include "rv32i_pipe.v"
`include "wb_sram16.v"
`include "wb_apu.v"

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

  reg  [XLEN-1:0] master_dat_i;
  wire [XLEN-1:0] master_dat_o;
  reg  master_ack;
  wire [XLEN-3:0] master_adr;
  wire master_cyc;
  wire master_err;
  wire [3:0] master_sel;
  wire master_stb;
  wire master_we;

  wire [1:0] address_select = {master_adr[21:20]};

  wire [XLEN-1:0] apu_data;
  wire [XLEN-1:0] gen_data = 0;
  wire [XLEN-1:0] gpu_data = 0;
  wire [XLEN-1:0] ram_data;

  wire apu_ack;
  wire gen_ack = 0;
  wire gpu_ack = 0;
  wire ram_ack;

  wire apu_err;
  wire gen_err = 0;
  wire gpu_err = 0;
  wire ram_err;

  assign master_err = apu_err | gen_err | gpu_err | ram_err;

  reg apu_sel;
  reg gen_sel = 0;
  reg gpu_sel = 0;
  reg ram_sel;

  // Address decode scheme
  always @(*) begin
    case (address_select)
      2'b00: master_dat_i = apu_data;
      2'b01: master_dat_i = gen_data;
      2'b10: master_dat_i = gpu_data;
      2'b11: master_dat_i = ram_data;
    endcase
  end

  always @(*) begin
    case (address_select)
      2'b00: master_ack = apu_ack;
      2'b01: master_ack = gen_ack;
      2'b10: master_ack = gpu_ack;
      2'b11: master_ack = ram_ack;
    endcase
  end

  always @(*) begin
    case (address_select)
      2'b00: {ram_sel, gpu_sel, gen_sel, apu_sel} = 4'b0001;
      2'b01: {ram_sel, gpu_sel, gen_sel, apu_sel} = 4'b0010;
      2'b10: {ram_sel, gpu_sel, gen_sel, apu_sel} = 4'b0100;
      2'b11: {ram_sel, gpu_sel, gen_sel, apu_sel} = 4'b1000;
    endcase
  end

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
    .slave_dat_o(ram_data),
    .rst_i(reset_i),
    .ack_o(ram_ack),
    .adr_i(master_adr[14:0]),
    .cyc_i(master_cyc),
    .err_o(ram_err),
    .sel_i(master_sel),
    .stb_i(master_stb & ram_sel),
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

  wire [15:0] apuMaster;

  wb_apu WB_APU (
    .clk_i(clk_i),
    .audio_o(apuMaster),
    .slave_dat_i(master_dat_o),
    .slave_dat_o(apu_data),
    .rst_i(reset_i),
    .ack_o(apu_ack),
    .adr_i(master_adr[13:0]),
    .cyc_i(master_cyc),
    .err_o(apu_err),
    .sel_i(master_sel),
    .stb_i(master_stb & apu_sel),
    .we_i(master_we)
  );

  ///////////////////////////////////////////////////////////////
  // Audio Section 
  ///////////////////////////////////////////////////////////////

  reg [24:0] clkdiv = 0;

  always @(posedge clk_i) begin
    clkdiv <= clkdiv + 1'b1;
  end

  assign HB_O = clkdiv[22];

  assign D_SYSCK = clkdiv[0];
  assign D_LRCLK = clkdiv[7];
  assign D_BCK = clkdiv[1];
  assign D_FMT = 1'b1;
  assign D_EMP = 1'b1;
  assign D_MUTE = 1'b0;
  assign D_DATA = osc;

  wire [3:0] oscpos = 4'hF - clkdiv[5:2];
  reg [15:0] audiobuff;
  reg [22:0] audioAcc = 0;
  reg osc;

  always @(posedge clk_i) begin
      if (clkdiv[6:0] == 7'b0) begin
        audiobuff <= audioAcc[22:7] + {7'b0, apuMaster[15:7]};
        audioAcc <= 0;
      end else begin
        audioAcc <= audioAcc + {7'b0, apuMaster};
      end
  end

  always @(negedge clk_i) begin
    osc <= audiobuff[oscpos];
  end

  wire [15:0] apuMaster;

  `ifdef SIM
  assign DAC_INTERFACE = apuMaster;
  `endif
  
  

endmodule
