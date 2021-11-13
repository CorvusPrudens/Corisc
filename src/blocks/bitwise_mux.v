`ifndef BITWISE_MUX_GUARD
`define BITWISE_MUX_GUARD

// select[n] = 0 -> data_o[n] = data1_i[n]
// select[n] = 1 -> data_o[n] = data2_i[n]

module bitwise_mux
  #(
    parameter LENGTH = 8
  )
  (
    input wire [LENGTH-1:0] data1_i,
    input wire [LENGTH-1:0] data2_i,
    input wire [LENGTH-1:0] select,
    output wire [LENGTH-1:0] data_o
  );

  genvar i;
  generate
    for (i = 0; i < LENGTH; i = i + 1) begin
      assign data_o[i] = select[i] ? data2_i[i] : data1_i[i];
    end
  endgenerate

endmodule

`endif // BITWISE_MUX_GUARD
