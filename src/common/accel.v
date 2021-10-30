`ifndef ACCEL_GUARD
`define ACCEL_GUARD
// verilator lint_off WIDTH

`include "bram_dual.v"
`include "bram_init_dual.v"

module accel
  #(
    parameter gpuSize_p = 9,
    parameter gpuInputWidth_p = 12
  )
  (
    input wire clk_i,
    input wire [gpuInputWidth_p:0] waddr_i, // larger to write in req/sprite rams
    input wire [8:0]  raddr_i,
    input wire [15:0] data_i,
    input wire ext,
    input wire write_i,

    output wire [15:0] data_o,
    output reg  intVec_o,
    input wire reset_i
  );

  reg accelActive = 0;
  assign data_o = dataOutMux;
  wire extCtrl = ext | ~accelActive;

  // write request structure
  // word 1:
  // 0    = color (0 white, 1 black)
  // 1    = horz flip
  // 2    = vert flip
  // 3    = spr/text (1 sprite, 0 text)
  // 4-7  = spriteWidth
  // 8-15 = index (index of 255 indicates list done)
  // word 2:
  // 0-7  = x position
  // 8-15 = y position

  // y screen position is mapped to 16 - 80
  // x screen position is mapped to 16 - 134

  // we can do text by only writing 8 bits
  // to the 16 bit column word
  wire       color  = instr1[0];
  reg [15:0] col    = 0;
  reg [15:0] word1  = 0;
  reg [15:0] word2  = 0;

  reg [15:0] instr1 = 0;
  reg [15:0] instr2 = 0;
  // for translating from input address
  // to actual bram address
  reg [6:0] cleanedX = 0;
  reg [5:0] cleanedY = 0;
  // I'm just going to hardcode this for now
  wire [7:0] instrAddr1  = {(cleanedY[5] | cleanedY[4]), cleanedX};
  wire [7:0] instrAddr2  = {cleanedY[5], cleanedX};

  // wire [3:0] instrShift = cleanedY[3:0];
  wire [3:0] instrShift = instr2[11:8];
  reg  [3:0] xPos  = 0; // extra bit for counting
  wire [4:0] xPosPlus = xPos + 1'b1;

  wire [15:0] reqDataOut;
  wire reqWrite = waddr_i[9] ? write_i : 1'b0;
  reg [9:0] reqRaddr = 0; // extra bit for counting

  wire [15:0] sprDataOut;
  wire [7:0]  chrDataOut;
  wire sprWrite = waddr_i[10] ? write_i : 1'b0;
  wire chrWrite = waddr_i[11] ? write_i : 1'b0;
  reg [9:0] sprChrRaddr = 0;

  // backwards spr data
  genvar i;
  wire [15:0] sprDataOutBack;
  for (i = 0; i < 16; i = i + 1) begin
    assign sprDataOutBack[i] = sprDataOut[15 - i];
  end

  // backwards chr data
  wire [7:0] chrDataOutBack;
  for (i = 0; i < 8; i = i + 1) begin
    assign chrDataOutBack[i] = chrDataOut[7 - i];
  end


  wire [15:0] accelWord1 = cleanedY[4] ? word2 : word1;
  wire [15:0] accelWord2 = cleanedY[4] ? word1 : word2;

  reg  [15:0] bramDataIn1    = 0;
  reg  [15:0] bramDataIn2    = 0;
  reg         bramDataWrite1 = 0;
  reg         bramDataWrite2 = 0;
  wire [15:0] bramDataOut1;
  wire [15:0] bramDataOut2;

  reg [(gpuSize_p - 2): 0] bramWaddr1 = 0;
  reg [(gpuSize_p - 2): 0] bramWaddr2 = 0;
  reg [(gpuSize_p - 2): 0] bramRaddr1 = 0;
  reg [(gpuSize_p - 2): 0] bramRaddr2 = 0;

  wire [15:0] bram1DataInDoubleMux = extCtrl ? data_i : accelWord1;
  wire [7:0] bram1WaddrDoubleMux = extCtrl ? {waddr_i[8], waddr_i[6:0]} : instrAddr1;
  wire [7:0] bram1RaddrDoubleMux = extCtrl ? {raddr_i[8], raddr_i[6:0]} : instrAddr1;

  wire writeInMux1 = (waddr_i[gpuInputWidth_p:9] == 0 && ~waddr_i[7]) ? write_i : 1'b0;
  wire writeInMux2 = (waddr_i[gpuInputWidth_p:9] == 0 && waddr_i[7]) ? write_i : 1'b0;

  wire bram1WriteMux = extCtrl ? writeInMux1 : bramDataWrite1;

  wire [15:0] dataOutMux = raddr_i[7] ? bramDataOut2 : bramDataOut1;

  wire [15:0] bram2DataInDoubleMux = extCtrl ? data_i : accelWord2;
  wire [7:0] bram2WaddrDoubleMux = extCtrl ? {waddr_i[8], waddr_i[6:0]} : instrAddr2;
  wire [7:0] bram2RaddrDoubleMux = extCtrl ? {raddr_i[8], raddr_i[6:0]} : instrAddr2;
  wire bram2WriteMux = extCtrl ? writeInMux2 : bramDataWrite2;

  reg clear = 0;
  reg [15:0] clearWord = 0;
  reg [8:0] clearCount = 0;

  reg [15:0] sprChrData = 0;

  always @(posedge clk_i) begin
    if (waddr_i[gpuInputWidth_p] & write_i) begin
      if (~waddr_i[0]) begin
        clear <= data_i[0];
      end else begin
        clearWord <= data_i;
      end
    end
  end

  localparam SM_ACCEL_IDLE     = 0;
  localparam SM_ACCEL_CLEAR    = 1;
  localparam SM_ACCEL_READ1    = 2;
  localparam SM_ACCEL_READ2    = 3;
  localparam SM_ACCEL_INCR     = 4;
  localparam SM_ACCEL_WRITE    = 5;
  localparam SM_ACCEL_PREWRITE = 6;
  localparam SM_ACCEL_WRITE1   = 7;
  localparam SM_ACCEL_WRITE2   = 8;
  localparam SM_ACCEL_WRITE3   = 9;
  localparam SM_ACCEL_WRITE4   = 10;
  //localparam SM_ACCEL_IDLE   = 4;
  localparam SM_ACCEL_DONE     = 14;
  localparam SM_ACCEL_EXIT     = 15;

  reg init = 1'b0;

  reg [3:0] accel_sm = 0;
  reg accelStart     = 0;
  reg accelDone      = 0;
  always @(posedge clk_i) begin
    case (accel_sm)
      SM_ACCEL_IDLE:
        begin
          if (intVec_o) intVec_o <= 1'b0;
          if (~ext & ~accelDone & init) begin
            if (clear) begin
              accel_sm <= SM_ACCEL_CLEAR;
              word1 <= clearWord;
              word2 <= clearWord;
              bramDataWrite1 <= 1'b1;
              bramDataWrite2 <= 1'b1;
              // a bit hacky to access addresses, but she'll be right
              // cleanedX    <= clearCount[6:0];
              // cleanedY[5] <= clearCount[7];
              cleanedX <= 0;
              cleanedY <= 0;
              clearCount  <= clearCount + 1'b1;
            end else accel_sm <= SM_ACCEL_READ1;
            accelActive <= 1'b1;
          end else if (ext) begin
            accelDone <= 1'b0;
            // tricking icecube to synthesize this
            init <= reset_i ? 1'b0 : 1'b1;
          end
        end
      SM_ACCEL_CLEAR:
        begin
          if (clearCount[8]) begin
            accel_sm <= SM_ACCEL_READ1;
            bramDataWrite1 <= 1'b0;
            bramDataWrite2 <= 1'b0;
            clearCount <= 9'b0;
          end else begin
            cleanedX    <= clearCount[6:0];
            cleanedY[5:4] <= {clearCount[7], 1'b0};
            clearCount <= clearCount + 1'b1;
          end
        end
      SM_ACCEL_READ1:
        begin
          if (reqRaddr[9]) begin
            accel_sm <= SM_ACCEL_EXIT;
          end else begin
            reqRaddr <= reqRaddr + 1'b1;
            instr1   <= reqDataOut;
            if   (reqDataOut[1]) sprChrRaddr <= {1'b0, reqDataOut[15:8], 1'b0} + (reqDataOut[7:4] - 1'b1);
            else sprChrRaddr <= reqDataOut[3] ? {reqDataOut[15:8], 2'b0} : {1'b0, reqDataOut[15:8], 1'b0};
            accel_sm <= SM_ACCEL_READ2;
          end
        end
      SM_ACCEL_READ2:
        begin
          if (instr1[15:8] == 8'hFF) begin
            accel_sm <= SM_ACCEL_EXIT;
          end else begin
            reqRaddr <= reqRaddr + 1'b1;
            instr2 <= reqDataOut;
            accel_sm <= SM_ACCEL_WRITE;
          end
        end
      SM_ACCEL_INCR:
        begin
          if ((instr1[7:4] != 0 && xPosPlus == instr1[7:4]) || xPosPlus[4]) begin
            accel_sm <= SM_ACCEL_DONE;
          end else begin
            xPos <= xPos + 1'b1;
            if (instr1[1]) sprChrRaddr <= sprChrRaddr - 1'b1;
            else sprChrRaddr <= sprChrRaddr + 1'b1;
            accel_sm <= SM_ACCEL_WRITE;
          end

          instr2 <= instr2 + 1'b1;
          bramDataWrite1 <= 1'b0;
          bramDataWrite2 <= 1'b0;
        end
      SM_ACCEL_WRITE:
        begin
          cleanedX <= instr2[7:0] - 5'h10;
          cleanedY <= instr2[15:8] - 5'h10;
          accel_sm <= SM_ACCEL_PREWRITE;
        end
      SM_ACCEL_PREWRITE:
        begin
          if (instr2[7:0] < 8'd16 ) begin
            accel_sm <= SM_ACCEL_INCR;
          end else if (instr2[7:0] > 8'd143) begin
            // no more to write if x is greater than display
            accel_sm <= SM_ACCEL_DONE;
          end else if (instr2[15:8] < 8'd16) begin
            accel_sm <= SM_ACCEL_WRITE1;
            word2 <= bramDataOut1;
          end else if (instr2[15:8] > 8'd63) begin
            accel_sm <= SM_ACCEL_WRITE3;
            word1 <= cleanedY[4] ? bramDataOut2 : bramDataOut1;
          end else begin
            word1 <= cleanedY[4] ? bramDataOut2 : bramDataOut1;
            word2 <= cleanedY[4] ? bramDataOut1 : bramDataOut2;
            accel_sm <= SM_ACCEL_WRITE2;
          end

          if (instr1[2]) sprChrData <= instr1[3] ? {8'b0, chrDataOutBack} : sprDataOutBack;
          else sprChrData <= instr1[3] ? {8'b0, chrDataOut} : sprDataOut[15:0];
        end
      SM_ACCEL_WRITE1:
      // TODO -- make word1 and word2 actually integrated
        begin
          if (color) begin
            // word1 <= word1 | sprChrData[(4'd15 - instrShift):0];
            word2 <= (instrShift > 0) ? word2 | (sprChrData >> (5'd16 - instrShift)) : word2;
          end else begin
            // word1 <= word1 & ~sprChrData[(4'd15 - instrShift):0];
            word2 <= (instrShift > 0) ? word2 & ~(sprChrData >> (5'd16 - instrShift)) : word2;
          end
          accel_sm <= SM_ACCEL_INCR;
          bramDataWrite1 <= 1'b1; // this will always write to bram1
        end
      SM_ACCEL_WRITE2:
        begin
          if (~color) begin // white is 0
            word1 <= word1 | (sprChrData << instrShift);
            word2 <= (instrShift > 0) ? word2 | (sprChrData >> (5'd16 - instrShift)) : word2;
          end else begin
            word1 <= word1 & ~(sprChrData << instrShift);
            word2 <= (instrShift > 0) ? word2 & ~(sprChrData >> (5'd16 - instrShift)) : word2;
          end
          accel_sm <= SM_ACCEL_INCR;
          bramDataWrite1 <= 1'b1;
          bramDataWrite2 <= 1'b1;
        end
      SM_ACCEL_WRITE3:
        begin
          if (~color) begin
            word1 <= word1 | (sprChrData << instrShift);
            // word2 <= (pos > 0) ? word2 | sprChrData[15:(5'd16 - instrShift)] : word2;
          end else begin
            word1 <= word1 & ~(sprChrData << instrShift);
            // word2 <= (pos > 0) ? word2 & ~sprChrData[15:(5'd16 - instrShift)] : word2;
          end
          accel_sm <= SM_ACCEL_INCR;
          bramDataWrite2 <= 1'b1; // this will always write to bram2
        end
      SM_ACCEL_DONE:
        begin
          xPos <= 1'b0;
          accel_sm <= SM_ACCEL_READ1;
        end
      SM_ACCEL_EXIT:
        begin
          accelDone <= 1'b1;
          reqRaddr <= 0;
          accel_sm <= SM_ACCEL_IDLE;
          accelActive <= 1'b0;
          intVec_o <= 1'b1;
        end
    endcase
  end

  bram_dual #(
    .memSize_p(gpuSize_p - 1'b1),
    .dataWidth_p(16)
  ) BRAM1 (
    .clk_i(clk_i),
    .write_i(bram1WriteMux),
    .data_i(bram1DataInDoubleMux),

    .waddr_i(bram1WaddrDoubleMux),
    .raddr_i(bram1RaddrDoubleMux),

    .data_o(bramDataOut1)
  );

  bram_dual #(
    .memSize_p(gpuSize_p - 1'b1),
    .dataWidth_p(16)
  ) BRAM2 (
    .clk_i(clk_i),
    .write_i(bram2WriteMux),
    .data_i(bram2DataInDoubleMux),

    .waddr_i(bram2WaddrDoubleMux),
    .raddr_i(bram2RaddrDoubleMux),

    .data_o(bramDataOut2)
  );

  bram_dual #(
    .memSize_p(gpuSize_p),
    .dataWidth_p(16)
  ) BRAM_REQ (
    .clk_i(clk_i),
    .write_i(reqWrite),
    .data_i(data_i),

    .waddr_i(waddr_i[8:0]),
    .raddr_i(reqRaddr[8:0]),

    .data_o(reqDataOut)
  );

  bram_dual #(
    .memSize_p(gpuSize_p),
    .dataWidth_p(16)
  ) BRAM_SPR (
    .clk_i(clk_i),
    .write_i(sprWrite),
    .data_i(data_i),

    .waddr_i(waddr_i[8:0]),
    .raddr_i(sprChrRaddr[8:0]),

    .data_o(sprDataOut)
  );

  bram_init_dual #(
    .memSize_p(gpuSize_p + 1),
    .dataWidth_p(8),
    .initFile_p("../cpu-arch/core/include/chardata.hex")
    // .initFile_p("../units/include/bigchardata.hex")
  ) BRAM_CHR (
    .clk_i(clk_i),
    .write_i(chrWrite),
    .data_i(data_i[7:0]),

    .waddr_i(waddr_i[9:0]),
    .raddr_i(sprChrRaddr),

    .data_o(chrDataOut)
  );

endmodule
`endif // ACCEL_GUARD
