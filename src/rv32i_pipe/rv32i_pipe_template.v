
module pipe (
    input wire data_ready_i,
    output reg data_ready_o,
    input wire [XLEN-1:0] data_i,
    output reg [XLEN-1:0] data_o,
    input wire downstream_stall_i,
    input wire downstream_execute_i,
    output wire stall_o,
    output wire execute_o,

    input wire clear_i,
    input wire reset_i
  );


  wire local_stall; // this goes high if this stage is waiting on something for its internal operation

  assign stall_o = data_ready_o & (downstream_stall_i | local_stall);
  assign execute_o = data_ready_i & ~stall_o;

  always @(posedge clk_i) begin
    if (reset_i | clear_i)
      data_ready_o <= 1'b0;
    if (execute_o) begin
      data_ready_o <= data_ready_i; // this assumes one clock cycle per operation
      // This is where we do the thing

      // This is the end of the thing
    end else if (downstream_execute_i)
      data_ready_o <= 1'b0;
  end 

endmodule