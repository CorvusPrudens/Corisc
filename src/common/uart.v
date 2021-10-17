`ifndef UART_GUARD
`define UART_GUARD
// 8 data bits, 1 stop bit, no parity

module uart(
    input wire clk_i,
    input wire RX,
    input wire [7:0] TXbuffer_i,
    input wire TXstart_i,

    output wire TX,
    output reg [7:0] RXbuffer_o = 0,
    output reg RXready_o = 0,
    output wire TXbusy_o
  );


  // assuming a frequncy of 14.31818 MHz, 458
  // produces a baudrate of 31,262 -- close enough!
  reg [8:0] tx_acc = 0;
  reg tx_tick = 0;
  localparam ACC_COMPARE = 458;

  // TRANSMITTER

  reg [3:0] TXstate = 0;
  wire TXready = (TXstate==0);
  assign TXbusy_o = ~TXready;

  reg [7:0] TXshift = 0;

  always @(negedge clk_i) begin

    if(TXready & TXstart_i) TXshift <= TXbuffer_i;
    else if(TXstate[3] & tx_tick) TXshift <= (TXshift >> 1);

    if (TXstate == 4'b0000) tx_acc <= 0;
    else begin
      if (tx_acc == ACC_COMPARE) begin
        tx_tick <= 1'b1;
        tx_acc <= 0;
      end else begin
        tx_tick <= 0;
        tx_acc <= tx_acc + 1'b1;
      end
    end

    case(TXstate)
      4'b0000: if(TXstart_i)  TXstate <= 4'b0100;
      4'b0100: if(tx_tick) TXstate <= 4'b1000; // start bit
      4'b1000: if(tx_tick) TXstate <= 4'b1001; // bit 0
      4'b1001: if(tx_tick) TXstate <= 4'b1010; // bit 1
      4'b1010: if(tx_tick) TXstate <= 4'b1011; // bit 2
      4'b1011: if(tx_tick) TXstate <= 4'b1100; // bit 3
      4'b1100: if(tx_tick) TXstate <= 4'b1101; // bit 4
      4'b1101: if(tx_tick) TXstate <= 4'b1110; // bit 5
      4'b1110: if(tx_tick) TXstate <= 4'b1111; // bit 6
      4'b1111: if(tx_tick) TXstate <= 4'b0001; // bit 7
      4'b0001: if(tx_tick) TXstate <= 4'b0000; // stop bit
      default: if(tx_tick) TXstate <= 4'b0000;
    endcase
  end

  assign TX = (TXstate < 4) | (TXstate[3] & TXshift[0]);

  // RECIEVER

  reg [3:0] RXstate = 0;
  reg [8:0] rx_acc = 0;
  reg rx_tick = 0;

  always @(negedge clk_i) begin

    case (RXstate)
      4'b0000: if (~RX) RXstate <= 4'b1000;     // start bit found
      4'b1000: if (rx_tick) RXstate <= 4'b1001; // bit 0
      4'b1001: if (rx_tick) RXstate <= 4'b1010; // bit 1
      4'b1010: if (rx_tick) RXstate <= 4'b1011; // bit 2
      4'b1011: if (rx_tick) RXstate <= 4'b1100; // bit 3
      4'b1100: if (rx_tick) RXstate <= 4'b1101; // bit 4
      4'b1101: if (rx_tick) RXstate <= 4'b1110; // bit 5
      4'b1110: if (rx_tick) RXstate <= 4'b1111; // bit 6
      4'b1111: if (rx_tick) RXstate <= 4'b0001; // bit 7
      4'b0001: if (rx_tick) RXstate <= 4'b0000; // stop bit
      default: RXstate <= 4'b0000;
    endcase

    if (RXstate == 4'b0000) rx_acc <= 0;
    else begin
      if (rx_acc == ACC_COMPARE) begin
        rx_tick <= 1'b1;
        rx_acc <= 0;
      end else begin
        rx_tick <= 0;
        rx_acc <= rx_acc + 1'b1;
      end
    end

    if (rx_tick && RXstate[3]) RXbuffer_o <= {RX, RXbuffer_o[7:1]};
    RXready_o <= (rx_tick && RXstate == 4'b0001);
  end

endmodule
`endif // UART_GUARD
