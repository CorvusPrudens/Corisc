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

    output reg [(dataWidth_p - 1):0] data_o
  );

  reg [(dataWidth_p - 1):0] memory [2**memSize_p-1:0];

  initial $readmemh(initFile_p, memory);

  always @(posedge clk_i) begin
    if (write_i) begin
      memory[waddr_i] <= data_i;
      if (waddr_i == raddr_i)
        data_o <= data_i;
      else
        data_o <= memory[raddr_i];
    end else
      data_o <= memory[raddr_i];
  end

endmodule
`endif // INIT_BRAM_DUAL_GUARD
