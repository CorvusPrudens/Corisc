`ifndef SIGN_EXT_GUARD
`define SIGN_EXT_GUARD

// Should this even really be a module?
module sign_ext
  #(
    parameter XLEN = 32,
    parameter INPUT_LEN = 12
  )
  (
    input wire [INPUT_LEN-1:0] data_i,
    output wire [XLEN-1:0] data_o
  );

  assign data_o = {{XLEN-INPUT_LEN{data_i[INPUT_LEN-1]}}, data_i};

endmodule`endif // SIGN_EXT_GUARD
