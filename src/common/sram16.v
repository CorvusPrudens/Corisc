`ifndef SRAM16_GUARD
`define SRAM16_GUARD

module sram16 (
    input wire clk_i,
    input wire write_i,
    input wire [15:0] addr_i,
    input wire [15:0] data_i,
    output wire [15:0] data_o,
    input wire [15:0] mask_i,
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

  assign SRAM_ADDR = addr_i;

  `ifdef SIM
  assign data_o = SRAM_I;
  assign SRAM_O = data_i;
  `else
  assign SRAM_DATA = write_i ? data_i : 16'bz;
  assign data_o = SRAM_DATA;
  `endif

  assign SRAM_CE = 1'b0;
  assign SRAM_WE = ~write_i;
  assign SRAM_OE = write_i;
  assign SRAM_LB = mask_i[7:0] == 0;
  assign SRAM_UB = mask_i[15:8] == 0;

endmodule

`endif // SRAM16_GUARD
