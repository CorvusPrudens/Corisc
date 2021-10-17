
module timer(
    input wire clk_i,
    input wire [15:0] data_i,
    input wire [2:0] addr_i,
    input wire write_i,
    input wire read_i,

    output wire [15:0] data_o,
    output reg intVec_o,
    input wire data_c
  );

  // Register structure:
  // treg[0] == timer state (bit 0 activates timer 0)
  // treg[1] == timer 0 compare register
  // treg[2] == timer 0 prescaler

  reg [15:0] treg [0:3];
  wire [2:0] smolAddr = addr_i - 3'b101;

  assign data_o = treg[smolAddr[1:0]];

  always @(posedge clk_i) begin
    if (write_i) treg[smolAddr[1:0]] <= data_i;
  end


  reg [7:0] prescaler0;
  reg [15:0] timer0;

  always @(posedge clk_i) begin
    if (prescaler0 == 8'b0) begin
      if (timer0 == treg[1]) begin
        timer0 <= 16'b0;
        if (treg[0][0]) intVec_o <= 1'b1;
      end else begin
        timer0 <= timer0 + 1'b1;
      end
      prescaler0 <= treg[2][7:0];
    end else begin
      prescaler0 <= prescaler0 - 1'b1;
    end

    if (intVec_o & data_c) intVec_o <= 1'b0;
  end

endmodule
