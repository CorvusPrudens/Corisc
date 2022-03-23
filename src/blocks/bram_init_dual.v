`ifndef INIT_BRAM_DUAL_GUARD
`define INIT_BRAM_DUAL_GUARD

module bram_init_dual
  #(
    parameter memSize_p = 8,
    parameter dataWidth_p = 16,
    parameter initFile_p = ""
  )
  (
    input wire clk_i,
    input wire write_i,
    input wire [(dataWidth_p - 1):0] data_i,
    input wire [(memSize_p - 1):0]  waddr_i,
    input wire [(memSize_p - 1):0]  raddr_i,

    output wire [(dataWidth_p - 1):0] data_o
  );

  reg [(dataWidth_p - 1):0] memory [2**memSize_p-1:0] /* synthesis syn_ramstyle = "no_rw_check" */;

  initial if (initFile_p) $readmemh(initFile_p, memory);

  reg [(dataWidth_p-1):0] bram_out;
  reg [(dataWidth_p-1):0] writethrough;

  wire writethrough_condition = (waddr_i == raddr_i) && write_i;
  reg writethrough_satisfied;

  assign data_o = writethrough_satisfied ? writethrough : bram_out;

  always @(posedge clk_i) begin
    if (write_i)
      memory[waddr_i] <= data_i;
  end

  always @(posedge clk_i) begin
    bram_out <= memory[raddr_i];
    writethrough <= data_i;
    writethrough_satisfied <= writethrough_condition;
  end

endmodule
`endif // INIT_BRAM_DUAL_GUARD
