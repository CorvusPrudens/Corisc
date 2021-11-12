`ifndef GPU_GUARD
`define GPU_GUARD

`include "spi_wo.v"
`include "accel.v"

module wb_gpu
  #(
    parameter gpuSize_p = 9,
    parameter gpuInputWidth_p = 12,
    parameter initData_p = "../units/include/initdata.hex",
    parameter ADDR_BITS = 14,
    parameter XLEN = 32
  )
  (
    input wire clk_i,

     // Wishbone slave signals
    input wire [XLEN-1:0] slave_dat_i,
    output wire [XLEN-1:0] slave_dat_o,
    input wire rst_i,

    output reg ack_o,
    input wire [ADDR_BITS-3:0] adr_i,
    input wire cyc_i,
    // output reg stall_o, // if a stall is necessary, raise this
    output wire err_o, // if an invalid command is issued, raise this
    input wire [3:0] sel_i,
    input wire stb_i,
    input wire we_i,

    output wire SDO,
    output wire SCK,
    output reg  DC, // remember to change these three to reg
    output wire CS,
    output reg  RES,

    output wire intVec_o
  );

  wire halfword_offset = ~sel_i[0]; // There will be bugs if we dont write in aligned half words XDD
  wire [gpuInputWidth_p:0] waddr_w = {adr_i, halfword_offset};
  reg [gpuInputWidth_p:0] waddr;
  reg write;
  reg [15:0] data;

  assign slave_dat_o = 0;
  assign err_o = 0;

  // this will be hardcoded out of necessity
  // (not easy to parametrize)
  reg  [10:0]  dataWord;
  wire [15:0] bramOut;
  reg  [8:0]  raddr;
  reg extCtrl = 0;

  // bram #(
  //   .memSize_p(gpuSize_p),
  //   .dataWidth_p(16)
  // ) BRAM (
  //   .clk_i(clk_i),
  //   .write_i(write_i),
  //   .read_i(1'b1),
  //   .data_i(data_i),
  //
  //   .waddr_i(waddr_i),
  //   .raddr_i(raddr),
  //
  //   .data_o(bramOut)
  // );

  always @(posedge clk_i) begin
    if (stb_i & cyc_i & we_i) begin
      waddr <= waddr_w;
      write <= 1'b1;
      ack_o <= 1'b1;
      data <= slave_dat_i[15:0];
    end else begin
      write <= 1'b0;
      ack_o <= 1'b0;
    end
  end

  accel #(
      .gpuSize_p(gpuSize_p),
      .gpuInputWidth_p(gpuInputWidth_p)
    ) ACCEL (
    .clk_i(clk_i),
    .write_i(write),
    .data_i(data),

    .waddr_i(waddr),
    .raddr_i(raddr),

    .ext(extCtrl),
    .data_o(bramOut),

    .intVec_o(intVec_o),
    .reset_i(1'b0)
  );

  wire busy;
  reg transmit;
  reg [7:0] data_o;

  localparam [4:0] numWords = 5'd30;
  reg [7:0] initdata [0:numWords - 1'b1];
  initial $readmemh(initData_p, initdata);
  `ifdef SIM
  localparam delayBits = 8;
  `else
  localparam delayBits = 20;
  `endif
  localparam frameBits = 18; // roughly 100 fps
  localparam frameCompare = 19'd477273;
  reg frameReset = 0;

  reg [3:0] displayState;
  reg [4:0] commandWord;
  reg [delayBits:0] resetDelay = 0;
  reg [frameBits:0] frameDelay = 0;

  wire reset = 1'b0;
  wire [10:0] dataWordPlus = dataWord + 1'b1;

  always @(posedge clk_i) begin
    case (displayState)
      4'h0:
        begin
          RES <= 1'b0;
          displayState <= 4'h1;
        end
      4'h1:
        begin
          if (resetDelay[delayBits]) begin
            RES <= 1'b1;
            displayState <= 4'h2;
            resetDelay <= 0;
          end else resetDelay <= resetDelay[delayBits - 1'b1:0] + 1'b1;
        end
      4'h2:
        begin
          if (resetDelay[delayBits]) begin
            displayState <= 4'h3;
            resetDelay <= 0;
          end else resetDelay <= resetDelay[delayBits - 1'b1:0] + 1'b1;
        end
      4'h3:
        begin
          if (commandWord == numWords) begin
            transmit <= 1'b0;
            displayState <= 4'h4;
            commandWord <= 0;
            extCtrl <= 1'b1;
          end else if (~busy) begin
            data_o <= initdata[commandWord];
            commandWord <= commandWord + 1'b1;
            transmit <= 1'b1;
            DC <= 1'b0;
          end else transmit <= 1'b0;
        end
      4'h4:
        begin
          frameReset <= 1'b0;
          if (dataWord[10]) begin
            transmit <= 1'b0;
            displayState <= reset ? 4'h0 : 4'h5;
            raddr <= 0;
            dataWord <= 0;
          end else if (~busy) begin
            data_o <= dataWord[7] ? bramOut[15:8] : bramOut[7:0];
            dataWord <= dataWord + 1'b1;
            raddr <= {dataWordPlus[9:8], dataWordPlus[6:0]};
            transmit <= 1'b1;
            DC <= 1'b1;
          end else transmit <= 1'b0;
        end
      4'h5:
        begin
          if (frameDelay == frameCompare) begin // exactly 60 fps
            frameReset <= 1'b1;
            displayState <= 4'h4;
            // frameDelay <= 0;
            extCtrl <= 1'b1;
          end else begin
            extCtrl <= 1'b0;
            // frameDelay <= frameDelay + 1'b1;
          end
        end
      default: displayState <= 4'h0;
    endcase

    if (frameReset) frameDelay <= 0;
    else frameDelay <= frameDelay + 1'b1;
  end

  spi_wo SPI(
    .clk_i(clk_i),
    .start_i(transmit),
    .busy_o(busy),
    .data_i(data_o),
    .sdo_o(SDO),
    .sck_o(SCK),
    .cs_o(CS)
  );

endmodule
`endif // GPU_GUARD
