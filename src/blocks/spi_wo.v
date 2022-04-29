`ifndef SPI_WO_GUARD
`define SPI_WO_GUARD

module spi_wo
    #(
      localparam CLK_DIV = 2
    ) (
    input wire clk_i,
    input wire [7:0] data_i,
    input wire start_i,

    output wire busy_o,
    output wire sdo_o,
    output wire sck_o,
    output wire cs_o
  );

  reg ack;
  localparam divisor = CLK_DIV; // this can be set to 1 for final version
  reg [divisor:0] clkdiv;
  always @(posedge clk_i) clkdiv <= clkdiv + 1'b1;

  wire clk_spi = clkdiv[divisor];

  reg edge_detect;
  wire rising_edge = ~edge_detect & clk_spi;
  wire falling_edge = edge_detect & ~clk_spi;
  always @(posedge clk_i)
    edge_detect <= clk_spi;

  reg [3:0] spiState;
  reg [7:0] dout;
  reg dout_bit;

  wire internal_busy = spiState[3] | ack;

  // always @(negedge clk_i) begin
  //   if (start_i & ~busy_o) begin
  //     ack <= 1'b1;
  //     dout <= data_i;
  //   end else if (spiState[3]) ack <= 1'b0;
  // end
  always @(posedge clk_i) begin
    if (start_i & ~internal_busy) begin
      ack <= 1'b1;
      dout <= data_i;
    end else if (spiState[3]) ack <= 1'b0;
  end

  always @(posedge clk_i) begin
    if (rising_edge) begin
      case (spiState)
        4'b0000: if (ack) spiState <= 4'b0111;
        4'b0111: spiState <= 4'b1110;
        4'b1110: spiState <= 4'b1101;
        4'b1101: spiState <= 4'b1100;
        4'b1100: spiState <= 4'b1011;
        4'b1011: spiState <= 4'b1010;
        4'b1010: spiState <= 4'b1001;
        4'b1001: spiState <= 4'b1000;
        4'b1000: spiState <= 4'b1111;
        4'b1111: spiState <= 4'b0000;
        default: spiState <= 4'b0000;
      endcase
    end

    if (falling_edge) begin
      if (busy_o) dout_bit <= dout[spiState[2:0]];
    end
  end

  assign sck_o  = spiState[3] ? edge_detect : 1'b0;
  assign sdo_o  = dout_bit;
  assign busy_o = internal_busy | start_i;
  assign cs_o   = spiState == 0;

endmodule
`endif // SPI_WO_GUARD
