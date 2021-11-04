`ifndef BRAM_DUAL_GUARD
`define BRAM_DUAL_GUARD

// Dual port inferred block ram

module bram_dual
  #(
    parameter memSize_p = 8,
    parameter dataWidth_p = 16
  )
  (
    input wire clk_i,
    input wire write_i,
    input wire [dataWidth_p-1:0] data_i,

    input wire [(memSize_p - 1):0]  waddr_i,
    input wire [(memSize_p - 1):0]  raddr_i,

    output reg [(dataWidth_p - 1):0] data_o = 0
  );

  reg [(dataWidth_p - 1):0] memory [2**memSize_p-1:0] /* synthesis syn_ramstyle = "no_rw_check" */;

  always @(posedge clk_i) begin
    if (write_i) begin
      memory[waddr_i] <= data_i;
      if (waddr_i == raddr_i)
        data_o <= data_i;
      else
        data_o <= memory[raddr_i];
    end else
      data_o <= memory[raddr_i];
  end

  // always @(negedge clk_i) begin
  //   data_o <= memory[raddr_i];
  // end

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
`endif // BRAM_DUAL_GUARD
