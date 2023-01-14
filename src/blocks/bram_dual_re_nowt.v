`ifndef BRAM_DUAL_RE_NOWT_GUARD
`define BRAM_DUAL_RE_NOWT_GUARD

// Dual port inferred block ram with read enable without write-through

module bram_dual_re_nowt
  #(
    parameter memSize_p = 6,
    parameter XLEN = 32
  )
  (
    input wire clk_i,
    input wire write_i,
    input wire read_i,
    input wire [XLEN-1:0] data_i,

    input wire [(memSize_p - 1):0]  waddr_i,
    input wire [(memSize_p - 1):0]  raddr_i,

    output wire [(XLEN - 1):0] data_o
  );

  reg [(XLEN-1):0] memory [2**memSize_p-1:0];
  reg [(XLEN-1):0] bram_out = 0;

  assign data_o = bram_out;

  always @(posedge clk_i) begin
    if (write_i)
      memory[waddr_i] <= data_i;
  end

  always @(posedge clk_i) begin
    if (read_i)
      bram_out <= memory[raddr_i];
  end

endmodule
`endif // BRAM_DUAL_RE_NOWT_GUARD
