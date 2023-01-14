`ifndef FIFO_GUARD
`define FIFO_GUARD

module fifo #(
    parameter memSize_p = 8,
    parameter dataWidth_p = 16
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

  reg [memSize_p:0] index_read  = 0;
  reg [memSize_p:0] index_write = 0;

  assign full_o = (index_read[memSize_p] == ~index_write[memSize_p]) &&
    (index_read[memSize_p-1:0] == index_write[memSize_p-1:0]);
  assign empty_o = index_read == index_write;

  wire [memSize_p:0] index_read_p1 = index_read + 1'b1;
  wire [memSize_p:0] index_write_p1 = index_write + 1'b1;

  always @(posedge clk_i) begin
    if (write_i & ~full_o) begin
      index_write <= index_write_p1;
    end

    // NOTE -- this feature could be made as a switch
    // if (read_i) begin
    //   // The address is only incremented if the FIFO isn't empty
    //   if (!empty_o)
    //     index_read <= index_read_p1;
    //   // WARNING -- this cannot be read immediately on the next clock
    // end else if (write_i) begin
    //   // data not read fast enough is ejected
    //   if (index_write_p1 == index_read)
    //     index_read <= index_read_p1;
    // end

  end

  always @(posedge clk_i) begin
    if (read_i & ~empty_o) begin
      index_read <= index_read_p1;
    end
  end

  reg [dataWidth_p-1:0] bram [2**memSize_p-1:0];

  always @(posedge clk_i) begin
    if (write_i & ~full_o)
      bram[index_write[memSize_p-1:0]] <= data_i;
  end

  always @(posedge clk_i) begin
    data_o <= bram[index_read[memSize_p-1:0]];
  end

endmodule
`endif // FIFO_GUARD
