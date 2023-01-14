`ifndef BRAM_DUAL_RE_GUARD
`define BRAM_DUAL_RE_GUARD

// Dual port inferred block ram with read enable

module bram_dual_re
  #(
    parameter memSize_p = 6,
    parameter XLEN = 32
  )
  (
    input wire clk_i,
    input wire write_i,
    input wire read_i,
    input wire [XLEN-1:0] data_i,

    input wire [(memSize_p - 1):0]  waddr_i,
    input wire [(memSize_p - 1):0]  raddr_i,

    output wire [(XLEN - 1):0] data_o
  );

  reg [(XLEN-1):0] memory [2**memSize_p-1:0] /* synthesis syn_ramstyle = "no_rw_check" */;
  reg [(XLEN-1):0] bram_out = 0;
  reg [(XLEN-1):0] writethrough = 0;

  wire writethrough_condition = (waddr_i == raddr_i) && write_i;
  reg writethrough_satisfied = 0;

  assign data_o = writethrough_satisfied ? writethrough : bram_out;

  always @(posedge clk_i) begin
    if (write_i)
      memory[waddr_i] <= data_i;
  end

  always @(posedge clk_i) begin
    if (read_i) begin
      bram_out <= memory[raddr_i];
      writethrough <= data_i;
      writethrough_satisfied <= writethrough_condition;
    end
  end

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
`endif // BRAM_DUAL_RE_GUARD
