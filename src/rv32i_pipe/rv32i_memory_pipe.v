`ifndef RV32I_MEMORY_PIPE_GUARD
`define RV32I_MEMORY_PIPE_GUARD

module 
  #(
    XLEN = 32
  )
  (
    input wire clk_i
  );


  // TODO -- need to get a wishbone bus going here...
  // It will have two masters (arbitrated between instruction cache and the regular processor) and as many slaves as
  // the user wants
  // The memory map would be configured similar to before, where start and end addresses are indicated


endmodule

`endif // RV32I_MEMORY_PIPE_GUARD