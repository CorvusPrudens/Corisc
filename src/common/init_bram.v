`ifndef INIT_BRAM_GUARD
`define INIT_BRAM_GUARD

module init_bram
  #(
    parameter memSize_p = 8,
    parameter dataWidth_p = 16,
    parameter initFile_p = ""
  )
  (
    input wire clk_i,
    input wire write_i,
    input wire read_i,
    input wire [(dataWidth_p - 1):0] data_i,

    input wire [(memSize_p - 1):0]  waddr_i,
    input wire [(memSize_p - 1):0]  raddr_i,

    output reg [(dataWidth_p - 1):0] data_o = 0
  );

  reg [(dataWidth_p - 1):0] memory [2**memSize_p];

  initial $readmemh(initFile_p, memory);

  always @(posedge clk_i) begin
    if (write_i) memory[waddr_i] <= data_i;
    // read/write conflict resolution
    else if (read_i) data_o      <= memory[raddr_i];
  end

endmodule
`endif // INIT_BRAM_GUARD
