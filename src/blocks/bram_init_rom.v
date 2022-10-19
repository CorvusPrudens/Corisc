`ifndef INIT_BRAM_ROM_GUARD
`define INIT_BRAM_ROM_GUARD

module bram_init_rom
  #(
    parameter memSize_p = 8,
    parameter dataWidth_p = 16,
    parameter initFile_p = ""
  )
  (
    input wire clk_i,
    input wire [(memSize_p - 1):0]  addr_i,

    output reg [(dataWidth_p - 1):0] data_o = 0
  );

  reg [(dataWidth_p - 1):0] memory [2**memSize_p-1:0];

  `ifndef SIM
  initial if (initFile_p) $readmemh(initFile_p, memory);
  `else
  initial $readmemh(initFile_p, memory);
  `endif

  always @(posedge clk_i) begin
    data_o <= memory[addr_i];
  end

endmodule
`endif // INIT_BRAM_ROM_GUARD
