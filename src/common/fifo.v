module fifo #(
    memSize_p = 8,
    dataWidth_p = 16
  )
  (
    input wire clk_i,
    input wire write_i,
    input wire read_i,
    input wire [(dataWidth_p - 1):0] data_i,

    output reg [(dataWidth_p - 1):0] data_o,
    output wire full_o,
    output wire empty_o
  );

  reg [(memSize_p - 1):0] index_read  = 0;
  reg [(memSize_p - 1):0] index_write = 0;

  wire [(dataWidth_p - 1):0] bramOut;

  assign full_o = index_read - index_write == 1;
  assign empty_o = index_read == index_write;

  always @(posedge clk_i) begin
    if (write_i) begin
      index_write <= index_write + 1'b1;
    end
    if (read_i) begin
      index_read <= index_read + 1'b1;
      // WARNING -- this cannot be read immediately on the next clock
      data_o <= bramOut;
    end
  end

  bram #(
    // this equates to a single bram
    .memSize_p(memSize_p),
    .dataWidth_p(dataWidth_p)
  ) BRAM (
    .clk_i(clk_i),
    .write_i(write_i),
    .read_i(1'b1),
    .data_i(data_i),

    .waddr_i(index_write),
    .raddr_i(index_read),

    .data_o(bramOut)
  );

endmodule
