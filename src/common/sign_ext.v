`ifndef SIGN_EXT_GUARD
`define SIGN_EXT_GUARD

// Should this even really be a module?
module sign_ext
  #(
    XLEN = 32,
    INPUT_LEN = 12
  )
  (
    input wire [INPUT_LEN-1:0] data_i,
    output wire [XLEN-1:0] data_o
  );

  assign data_o = data_i[INPUT_LEN-1] ? 
    {{XLEN-INPUT_LEN{1'b1}}, data_i}  :
    {{XLEN-INPUT_LEN{1'b0}}, data_i}  ;

endmodule`endif // SIGN_EXT_GUARD
