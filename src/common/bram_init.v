`ifndef INIT_BRAM_GUARD
`define INIT_BRAM_GUARD

module bram_init
  #(
    parameter memSize_p = 8,
    parameter dataWidth_p = 16,
    parameter initFile_p = ""
  )
  (
    input wire clk_i,
    input wire write_i,
    input wire [(dataWidth_p - 1):0] data_i,
    input wire [(memSize_p - 1):0]  addr_i,

    output wire [(dataWidth_p - 1):0] data_o
  );

  reg [(dataWidth_p - 1):0] memory [2**memSize_p];

  initial $readmemh(initFile_p, memory);

  always @(posedge clk_i) begin
    if (write_i) memory[addr_i] <= data_i;
  end

  assign data_o = memory[addr_i];

endmodule
`endif // INIT_BRAM_GUARD
