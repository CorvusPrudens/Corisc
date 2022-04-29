`ifndef SPI_GUARD
`define SPI_GUARD

module spi(
    input wire clk_i,
    input wire spi_clk_i,
    input wire start_i,
    input wire [7:0] data_i,

    output reg [7:0] data_o,

    output wire busy_o,
    output wire sdo_o,
    output wire sck_o,
    input  wire sdi_i,
    output wire clk_active_o
    // cs handled by controlling module
  );

  reg start = 0;
  reg [3:0] spiState;
  reg [7:0] shift_o;
  reg [7:0] shift_i;
  reg tx_bit;

  wire internal_busy = spiState[3] | start;

  // always @(negedge clk_i) begin
  //   if (start_i & ~busy_o) begin
  //     start <= 1'b1;
  //     shift_o <= data_i;
  //   end else if (spiState[3]) start <= 1'b0;
  // end
  always @(posedge clk_i) begin
    if (start_i & ~internal_busy) begin
      start <= 1'b1;
      shift_o <= data_i;
    end else if (spiState[3]) start <= 1'b0;
  end

  // a bit messy, but
  wire [3:0] rxState = spiState + 1'b1;

  reg edge_detect;
  wire rising_edge = ~edge_detect & spi_clk_i;
  wire falling_edge = edge_detect & ~spi_clk_i;
  always @(posedge clk_i)
    edge_detect <= spi_clk_i;

  always @(posedge clk_i) begin

    if (rising_edge) begin
      case (spiState)
        4'b0000: if (start) spiState <= 4'b0111;
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

      if (rxState[3]) shift_i[spiState[2:0]] <= sdi_i;
      if (spiState == 4'b1111) data_o <= shift_i;
    end
    
    if (falling_edge) begin
      if (busy_o) tx_bit <= shift_o[spiState[2:0]];
    end

  end

  assign clk_active_o = spiState[3];
  assign sck_o  = clk_active_o ? edge_detect : 1'b0;
  assign sdo_o  = tx_bit;
  assign busy_o = internal_busy | start_i;
  // assign cs_o   = spiState == 0;

endmodule
`endif // SPI_GUARD
