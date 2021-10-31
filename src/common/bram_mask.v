`ifndef BRAM_MASK_GUARD
`define BRAM_MASK_GUARD

// Simple inferred bram with write mask
// TODO -- ensure this is properly inferred for lattice

module bram_mask
  #(
    parameter MEMORY_SIZE = 8,
    parameter XLEN = 16
  )
  (
    input wire clk_i,
    input wire write_i,
    input wire [XLEN-1:0] data_i,
    input wire [XLEN-1:0] write_mask_i,

    input wire [MEMORY_SIZE-1:0]  addr_i,

    output wire [XLEN-1:0] data_o
  );

  reg [XLEN-1:0] memory [2**MEMORY_SIZE-1:0];

  wire [XLEN-1:0] data_mux;

  bitwise_mux #(
    .LENGTH(XLEN)
  ) BITWISE_MUX (
    .data1_i(data_i),
    .data2_i(data_o),
    .select(write_mask_i),
    .data_o(data_mux)
  );

  always @(posedge clk_i) begin
    if (write_i) memory[addr_i] <= data_mux;
  end

  assign data_o = memory[addr_i];

  `ifdef FORMAL
    // FORMAL prove
    reg timeValid_f = 0;
    always @(posedge clk_i) timeValid_f <= 1;

    always @(posedge clk_i) begin
      // Check that data is correctly written
      if (timeValid_f && $past(write_i)) begin
        assert(memory[$past(waddr_i)] == $past(data_i));
      end

      // // Check that data will be correctly read on the next clock
      // if (timeValid_f && $past(write_i) && read_i && raddr_i == $past(waddr_i)) begin
      //   assert(data_o == $past(data_i));
      // end
    end
    
  `endif

endmodule
`endif // BRAM_MASK_GUARD
