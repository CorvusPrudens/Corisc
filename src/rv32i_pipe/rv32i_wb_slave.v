`ifndef RV32I_WB_SLAVE_GUARD
`define RV32I_WB_SLAVE_GUARD

// template wb slave module
// Right now, it's a simple non-pipelined synchronous slave
// We could try out asynchronous and pipelined setups to test out the tradeoffs
module rv32i_wb_slave
  #(
    parameter XLEN = 32
  )
  (
    // Wishbone slave signals
    input wire [XLEN-1:0] slave_dat_i,
    output reg [XLEN-1:0] slave_dat_o,

    output wire ack_o,
    input wire [XLEN-1:2] adr_i, // NOTE -- the slave will only have a port as large as its address space,
                                 // so none will actually be XLEN-1
    input wire cyc_i,
    // output reg stall_o, // if a stall is necessary, raise this
    output reg err_o, // if an invalid command is issued, raise this
    input wire [3:0] sel_i,
    input wire stb_i,
    input wire we_i
  );

  wire [XLEN-1:0] data;
  wire execute = cyc_i & stb_i;

  always @(posedge clk_i) begin
    if (rst_i) begin
      ack_o <= 1'b0;
      err_o <= 1'b0;
      // stall_o <= 1'b0; // to be added with pipelining
    end else if (execute & ~ack_o)
      ack_o <= 1'b1; // The ack doesn't need to happen immediately -- say we're reading from
                     // flash, it can wait until the data has actually been pulled up
    else
      ack_o <= 1'b0;
  end

  always @(posedge clk_i) begin
    if (execute) begin
      if (we_i) begin
        // Do the write thing

      end else begin
        // Do the other things

      end
    end
  end

endmodule

`endif // RV32I_WB_SLAVE_GUARD
