`ifndef FIFO_GUARD
`define FIFO_GUARD

`include "bram_dual.v"

module fifo #(
    memSize_p = 8,
    dataWidth_p = 16
  )
  (
    input wire clk_i,
    input wire write_i,
    input wire read_i,
    input wire [(dataWidth_p - 1):0] data_i,

    output wire [(dataWidth_p - 1):0] data_o,
    output wire full_o,
    output wire empty_o
  );

  reg [(memSize_p - 1):0] index_read  = 0;
  reg [(memSize_p - 1):0] index_write = 0;

  // wire [(dataWidth_p - 1):0] bramOut;

  assign full_o = index_read - index_write == 1;
  assign empty_o = index_read == index_write;

  always @(posedge clk_i) begin
    if (write_i) begin
      index_write <= index_write + 1'b1;

      // data not read fast enough is ejected
      if (index_write + 1'b1 == index_read)
        index_read <= index_read + 1'b1;
    end
    if (read_i) begin
      // The address is only incremented if the FIFO isn't empty
      if (!empty_o)
        index_read <= index_read + 1'b1;
      // WARNING -- this cannot be read immediately on the next clock
    end
  end

  bram_dual #(
    // this equates to a single bram
    .memSize_p(memSize_p),
    .dataWidth_p(dataWidth_p)
  ) BRAM (
    .clk_i(clk_i),
    .write_i(write_i),
    .data_i(data_i),

    .waddr_i(index_write),
    .raddr_i(index_read),

    .data_o(data_o)
  );

  `ifdef FORMAL
    // FORMAL prove
    reg timeValid_f = 0;
    always @(posedge clk_i) timeValid_f <= 1;

    always @(posedge clk_i) begin
      // Ensure FIFO cannot be both full and empty
      if (full_o)
        assert(!empty_o);
      if (empty_o)
        assert(!full_o);
      
      // Only increment read address if there's data to be read
      if ($past(empty_o) && read_i && timeValid_f)
        assert($past(index_read) == index_read);
    end
    
  `endif

endmodule
`endif // FIFO_GUARD
