`ifndef FLASH_GUARD
`define FLASH_GUARD
// NOTE -- we should have a fixed, non-reprogrammable
// bootloader image that warmboots to an actual writable
// image. This way, it's potentially possible to handle
// otherwise device-bricking scenarios. In fact, this
// would be quite easy to manage, as we can have
// a whole FPGA configuration dedicated to resolving
// configuration errors. It could even display
// text on screen to help guide the user XD

// TODO -- each error should really have a unique
// status code. This would be very easy to do.

`include "spi.v"
`include "bram_dual.v"
`include "crc.v"

// this module is made to communicate safely and easily
// with the same chip used to configure the fpga at startup
module flash(
    input wire clk_i,
    input wire [15:0] data_i,
    output reg [15:0] data_o,

    input wire [1:0] addr_i,
    input wire write_i,
    input wire read_i,

    output wire CS,
    output wire SDO,
    output wire SCK,
    input wire  SDI,

    input wire reset_states
  );

  localparam flashSleep_p  = 8'hB9;
  localparam flashWake_p   = 8'hA9;
  localparam flashRead_p   = 8'h03;
  localparam flashWen_p    = 8'h06;
  localparam flashErase_p  = 8'h20; // 4-kb sector
  localparam flashWrite_p  = 8'h02;
  localparam flashStatus_p = 8'h05;

  reg cs = 0;
  assign CS = ~cs;

  // data will be read and written in 256 or 512 byte packets
  // (i.e. LSB packet or LSB and MSB packet)


  // status bit positions
  // 0 = busy flag
  // 1 = error flag (previous request invalid; not executed)
  // 2 = request read  (after having written address)
  // 3 = request write (after having filled fifo with data to write)
  // 4 = request erase
  // 5 = 256 (0) or 512 (1) byte transfer
  // 6 = security bit 0 (enable re-write of configuration images, cleared after transfer)
  // 7 = security bit 1 (enable re-write of programs, cleared after transfer)
  // 8 = reset crc on next read
  reg [8:0]  status     = 0;
  reg [2:0]  readStatus = 0;
  reg [15:0] page       = 0;

  reg bramWrite = 0;
  reg bramWriteBus = 0;
  wire bramWriteSignalMux = flash_sm[3] ? bramWrite : bramWriteBus;
  // wire bramRead;
  wire [15:0] bramDataOut;
  reg  [15:0] bramDataIn = 0;
  reg  [15:0] bramDataInBus = 0;
  wire [15:0] bramMux = flash_sm[3] ? bramDataIn : bramDataInBus;
  reg  [8:0]  bramReadAddr = 0;
  reg  [8:0]  bramReadAddrBus = 0;
  wire [7:0]  bramReadMux = flash_sm[3] ? bramReadAddr[7:0] : bramReadAddrBus[7:0];
  reg  [8:0]  bramWriteAddr = 0;
  wire [8:0]  bramWriteAddrP1 = bramWriteAddr + 1'b1;
  reg  [8:0]  bramWriteAddrBus = 0;
  wire [7:0]  bramWriteMux = flash_sm[3] ? bramWriteAddr[7:0] : bramWriteAddrBus[7:0];
  reg resetStatus = 0;

  always @(posedge clk_i) begin
    if (~busy) begin
      if (write_i) begin
        case (addr_i)
          1:
            begin
              bramDataInBus    <= data_i;
              bramWriteAddrBus <= bramWriteAddrBus + 1'b1;
              bramWriteBus <= 1'b1;
            end
          2: page   <= data_i;
          3: status <= data_i[8:0];
        endcase
      end else if (read_i) begin
        case (addr_i)
          1:
            begin
              data_o          <= bramDataOut;
              bramReadAddrBus <= bramReadAddrBus + 1'b1;
            end
          2: data_o <= page;
          3: data_o <= {13'b0, readStatus};
        endcase
      end else begin
        bramWriteBus <= 1'b0;
      end
    end else begin
      if (resetStatus) begin
        status <= 0;
        bramReadAddrBus  <= 0;
        bramWriteAddrBus <= 0;
      end
      data_o <= 16'h0001;
    end
  end

  reg crc_valid;
  reg crc_reset;
  wire crcOut;
  wire spiClkActive;

  reg spi_clk = 0;
  always @(posedge clk_i) spi_clk <= ~spi_clk;

  // CRCs come from reading flash data
  crc CRC (
    .clk_i(spi_clk),
    .spi_clk(SCK),
    .clk_en_i(spiClkActive),
    .en_i(crc_valid),
    .data_i(SDI),
    .reset_i(crc_reset),
    .data_o(crcOut)
  );

  bram_dual #(
    .memSize_p(8),
    .dataWidth_p(16)
  ) FIFO (
    .clk_i(clk_i),
    .write_i(bramWriteSignalMux),
    .data_i(bramMux),
    .data_o(bramDataOut),
    .waddr_i(bramWriteMux - 1'b1),
    .raddr_i(bramReadMux)
  );

  reg spiStart = 0;
  reg [7:0] spiDataIn = 0;
  wire [7:0] spiDataOut;
  wire spiBusy;

  spi SPI (
    .clk_i(clk_i),
    .spi_clk_i(spi_clk),
    .start_i(spiStart),
    .data_i(spiDataIn),
    .data_o(spiDataOut),

    .busy_o(spiBusy),
    .sdo_o(SDO),
    .sck_o(SCK),
    .sdi_i(SDI),
    .clk_active_o(spiClkActive)
  );

  reg [3:0] flash_sm = 0;

  localparam SM_IDLE   = 4'b0000;
  localparam SM_SAMPLE = 4'b1000;
  localparam SM_READ   = 4'b1001;
  localparam SM_WRITE  = 4'b1010;
  localparam SM_ERASE  = 4'b1011;
  localparam SM_DONE   = 4'b1101;
  localparam SM_DONE_B = 4'b1110;
  localparam SM_ERROR  = 4'b1111;

  wire busy = readStatus[0];

  reg readCycle  = 0;
  reg writeCycle = 0;
  reg readDone   = 0;
  reg writeDone  = 0;
  reg eraseCycle = 0;
  reg eraseDone  = 0;
  reg busyCycle  = 0;
  reg busyDone   = 0;

  // this seems bad, let's optimze later
  localparam SM_READ_R1   = 0;
  localparam SM_READ_R2   = 1;
  localparam SM_READ_R3   = 2;
  localparam SM_READ_R4   = 3;
  localparam SM_READ_R5   = 4;
  localparam SM_READ_LOOP = 5;

  reg [2:0] read_sm = 0;

  // this seems bad, let's optimze later
  localparam SM_WRITE_EN   = 0;
  localparam SM_WRITE_BUFF = 1;
  localparam SM_WRITE_W1   = 2;
  localparam SM_WRITE_W2   = 3;
  localparam SM_WRITE_W3   = 4;
  localparam SM_WRITE_W4   = 5;
  localparam SM_WRITE_LOOP = 6;

  reg [2:0] write_sm = 0;

  localparam SM_ERASE_WEN   = 0;
  localparam SM_ERASE_BUFF  = 1;
  localparam SM_ERASE_COM   = 2;
  localparam SM_ERASE_ADDR1 = 3;
  localparam SM_ERASE_ADDR2 = 4;
  localparam SM_ERASE_ADDR3 = 5;
  localparam SM_ERASE_FIN   = 6;

  reg [2:0] erase_sm = 0;

  localparam SM_BUSY_WAKE  = 0;
  localparam SM_BUSY_BUFF  = 1;
  localparam SM_BUSY_S1    = 2;
  localparam SM_BUSY_S2    = 3;
  localparam SM_BUSY_S3    = 4;

  reg [2:0] busy_sm = 0;

  always @(posedge clk_i) begin
    readStatus[2] <= crcOut;

    // if (reset_states) begin
    //   flash_sm <= SM_IDLE;
    // end else begin
    // if (flash_sm == SM_IDLE) begin
    //   if (status[4:2] != 3'b0) begin
    //     readStatus[1:0] <= 2'b01;
    //     case (busy_sm)
    //       SM_BUSY_WAKE:
    //         begin
    //           spiStart <= 1'b1;
    //           spiDataIn <= flashWake_p;
    //           busy_sm <= SM_BUSY_BUFF;
    //           cs <= 1'b1;
    //         end
    //       SM_BUSY_BUFF:
    //         begin
    //           if (~spiBusy) begin
    //             cs <= 1'b0;
    //             busy_sm <= SM_BUSY_S1;
    //           end else spiStart <= 1'b0;
    //         end
    //       SM_BUSY_S1:
    //         begin
    //           if (~spiBusy) begin
    //             spiStart <= 1'b1;
    //             spiDataIn <= flashStatus_p;
    //             busy_sm <= SM_BUSY_S2;
    //             cs <= 1'b1;
    //           end else spiStart <= 1'b0;
    //         end
    //       SM_BUSY_S2:
    //         begin
    //           if (~spiBusy) begin
    //             spiStart <= 1'b1;
    //             spiDataIn <= flashStatus_p;
    //             busy_sm <= SM_BUSY_S3;
    //           end else spiStart <= 1'b0;
    //         end
    //       SM_BUSY_S3:
    //         begin
    //           if (~spiBusy) begin
    //             if (spiDataOut[0] == 1) begin
    //               busy_sm <= SM_BUSY_S1;
    //             end else begin
    //               busy_sm  <= SM_BUSY_WAKE;
    //               flash_sm <= SM_SAMPLE;
    //               cs <= 1'b0;
    //             end
    //           end else spiStart <= 1'b0;
    //         end
    //     endcase
    //   end
    // end

    // if (flash_sm == SM_SAMPLE) begin
    //   case (status[4:2])
    //     3'b001:
    //       begin
    //         if (page[15]) flash_sm <= SM_ERROR;
    //         else flash_sm <= SM_READ;
    //       end
    //     3'b010:
    //       begin
    //         if (page[15]) flash_sm <= SM_ERROR;
    //         else flash_sm <= SM_WRITE;
    //       end
    //     3'b100:
    //       begin
    //         if (page[15]) flash_sm <= SM_ERROR;
    //         else flash_sm <= SM_ERASE;
    //       end
    //     default: flash_sm <= SM_ERROR;
    //   endcase
    // end

    // if (flash_sm == SM_READ) begin
    //   case (read_sm)
    //     SM_READ_R1:
    //       begin
    //         if (status[8]) crc_reset <= 1'b1;
    //         spiStart <= 1'b1;
    //         spiDataIn <= flashRead_p;
    //         read_sm <= SM_READ_R2;
    //         cs <= 1'b1;
    //       end
    //     SM_READ_R2:
    //       begin
    //         if (~spiBusy) begin
    //           crc_reset <= 1'b0;
    //           spiStart <= 1'b1;
    //           spiDataIn <= page[15:8];
    //           read_sm <= SM_READ_R3;
    //         end else spiStart <= 1'b0;
    //       end
    //     SM_READ_R3:
    //       begin
    //         if (~spiBusy) begin
    //           spiStart <= 1'b1;
    //           spiDataIn <= page[7:0];
    //           read_sm <= SM_READ_R4;
    //         end else spiStart <= 1'b0;
    //       end
    //     SM_READ_R4:
    //       begin
    //         if (~spiBusy) begin
    //           spiStart <= 1'b1;
    //           spiDataIn <= 0;
    //           read_sm <= SM_READ_R5;
    //         end else spiStart <= 1'b0;
    //       end
    //     SM_READ_R5:
    //       begin
    //         if (~spiBusy) begin
    //           spiStart <= 1'b1;
    //           spiDataIn <= 0;
    //           read_sm <= SM_READ_LOOP;
    //           crc_valid <= 1'b1;
    //         end else spiStart <= 1'b0;
    //       end
    //     SM_READ_LOOP:
    //       begin
    //         if (~spiBusy) begin
    //           if (bramWriteAddrP1[8]) begin
    //             bramWriteAddr <= 0;
    //             read_sm <= SM_READ_R1;
    //             flash_sm <= SM_DONE;
    //             bramWrite <= 1'b1;
    //             spiStart <= 1'b0;
    //             cs <= 1'b0;
    //             crc_valid <= 1'b0;
    //           end else begin
    //             spiStart <= 1'b1;
    //             bramDataIn <= {8'b0, spiDataOut};
    //             bramWriteAddr <= bramWriteAddr + 1'b1;
    //             bramWrite <= 1'b1;
    //           end
    //         end else begin
    //           bramWrite <= 1'b0;
    //           spiStart <= 1'b0;
    //         end
    //       end
    //   endcase
    // end

    // if (flash_sm == SM_WRITE) begin
    //   if (page < 16'h0300 && ~status[6]) begin
    //     flash_sm <= SM_ERROR;
    //   end else if (page < 16'h0600 && ~status[7]) begin
    //     flash_sm <= SM_ERROR;
    //   end else begin
    //     case (write_sm)
    //       SM_WRITE_EN:
    //         begin
    //           spiStart <= 1'b1;
    //           spiDataIn <= flashWen_p;
    //           write_sm <= SM_WRITE_BUFF;
    //           cs <= 1'b1;
    //         end
    //       SM_WRITE_BUFF:
    //         begin
    //           if (~spiBusy) begin
    //             cs <= 1'b0;
    //             write_sm <= SM_WRITE_W1;
    //           end else spiStart <= 1'b0;
    //         end
    //       SM_WRITE_W1:
    //         begin
    //           if (~spiBusy) begin
    //             spiStart <= 1'b1;
    //             spiDataIn <= flashWrite_p;
    //             write_sm <= SM_WRITE_W2;
    //             cs <= 1'b1;
    //           end
    //         end
    //       SM_WRITE_W2:
    //         begin
    //           if (~spiBusy) begin
    //             spiStart <= 1'b1;
    //             spiDataIn <= page[15:8];
    //             write_sm <= SM_WRITE_W3;
    //           end else spiStart <= 1'b0;
    //         end
    //       SM_WRITE_W3:
    //         begin
    //           if (~spiBusy) begin
    //             spiStart <= 1'b1;
    //             spiDataIn <= page[7:0];
    //             write_sm <= SM_WRITE_W4;
    //           end else spiStart <= 1'b0;
    //         end
    //       SM_WRITE_W4:
    //         begin
    //           if (~spiBusy) begin
    //             spiStart <= 1'b1;
    //             spiDataIn <= 0;
    //             write_sm <= SM_WRITE_LOOP;
    //           end else spiStart <= 1'b0;
    //         end
    //       SM_WRITE_LOOP:
    //         begin
    //           if (~spiBusy) begin
    //             if (bramReadAddr[8]) begin
    //               bramReadAddr <= 0;
    //               write_sm <= SM_WRITE_EN;
    //               flash_sm <= SM_DONE;
    //               spiStart <= 1'b0;
    //               cs <= 1'b0;
    //             end else begin
    //               spiStart <= 1'b1;
    //               spiDataIn <= bramDataOut[7:0];
    //               bramReadAddr <= bramReadAddr + 1'b1;
    //             end
    //           end else begin
    //             bramWrite <= 1'b0;
    //             spiStart <= 1'b0;
    //           end
    //         end
    //     endcase
    //   end
    // end

    // if (flash_sm == SM_ERASE) begin
    //   if (page < 16'h0300 && ~status[6]) begin
    //     flash_sm <= SM_ERROR;
    //   end else if (page < 16'h0600 && ~status[7]) begin
    //     flash_sm <= SM_ERROR;
    //   end else begin
    //     case (erase_sm)
    //       SM_ERASE_WEN:
    //         begin
    //           spiStart <= 1'b1;
    //           spiDataIn <= flashWen_p;
    //           erase_sm <= SM_ERASE_BUFF;
    //           cs <= 1'b1;
    //         end
    //       SM_ERASE_BUFF:
    //         begin
    //           if (~spiBusy) begin
    //             cs <= 1'b0;
    //             erase_sm <= SM_WRITE_W1;
    //           end else spiStart <= 1'b0;
    //         end
    //       SM_ERASE_COM:
    //         begin
    //           if (~spiBusy) begin
    //             spiStart <= 1'b1;
    //             spiDataIn <= flashErase_p;
    //             erase_sm <= SM_ERASE_ADDR1;
    //             cs <= 1'b1;
    //           end
    //         end
    //       SM_ERASE_ADDR1:
    //         begin
    //           if (~spiBusy) begin
    //             spiStart <= 1'b1;
    //             spiDataIn <= page[15:8];
    //             erase_sm <= SM_ERASE_ADDR2;
    //           end else spiStart <= 1'b0;
    //         end
    //       SM_ERASE_ADDR2:
    //         begin
    //           if (~spiBusy) begin
    //             spiStart <= 1'b1;
    //             spiDataIn <= page[7:0];
    //             erase_sm <= SM_ERASE_ADDR3;
    //           end else spiStart <= 1'b0;
    //         end
    //       SM_ERASE_ADDR3:
    //         begin
    //           if (~spiBusy) begin
    //             spiStart <= 1'b1;
    //             spiDataIn <= 0;
    //             erase_sm <= SM_ERASE_FIN;
    //           end else spiStart <= 1'b0;
    //         end
    //       SM_ERASE_FIN:
    //         begin
    //           if (~spiBusy) begin
    //             erase_sm <= SM_ERASE_WEN;
    //             flash_sm <= SM_DONE;
    //             cs <= 1'b0;
    //           end else spiStart <= 1'b0;
    //         end
    //     endcase
    //   end
    // end

    // if (flash_sm == SM_DONE)
    //     begin
    //       flash_sm    <= SM_DONE_B;
    //       bramWrite <= 1'b0;
    //       resetStatus <= 1'b1;
    //     end

    // if (flash_sm == SM_DONE_B)
    //     begin
    //       resetStatus <= 1'b0;
    //       readStatus[0] <= 1'b0;
    //       flash_sm    <= SM_IDLE;
    //     end
    // if (flash_sm == SM_ERROR)
    //     begin
    //       resetStatus <= 1'b1;
    //       readStatus[1]  <= 1'b1;
    //       flash_sm <= SM_DONE_B;
    //       cs <= 1'b0;
    //     end
    // end
    case (flash_sm)
      SM_IDLE:
        begin
          if (status[4:2] != 3'b0) begin
            readStatus[1:0] <= 2'b01;
            case (busy_sm)
              SM_BUSY_WAKE:
                begin
                  spiStart <= 1'b1;
                  spiDataIn <= flashWake_p;
                  busy_sm <= SM_BUSY_BUFF;
                  cs <= 1'b1;
                end
              SM_BUSY_BUFF:
                begin
                  if (~spiBusy) begin
                    cs <= 1'b0;
                    busy_sm <= SM_BUSY_S1;
                  end else spiStart <= 1'b0;
                end
              SM_BUSY_S1:
                begin
                  if (~spiBusy) begin
                    spiStart <= 1'b1;
                    spiDataIn <= flashStatus_p;
                    busy_sm <= SM_BUSY_S2;
                    cs <= 1'b1;
                  end else spiStart <= 1'b0;
                end
              SM_BUSY_S2:
                begin
                  if (~spiBusy) begin
                    spiStart <= 1'b1;
                    spiDataIn <= flashStatus_p;
                    busy_sm <= SM_BUSY_S3;
                  end else spiStart <= 1'b0;
                end
              SM_BUSY_S3:
                begin
                  if (~spiBusy) begin
                    if (spiDataOut[0] == 1) begin
                      busy_sm <= SM_BUSY_S1;
                    end else begin
                      busy_sm  <= SM_BUSY_WAKE;
                      flash_sm <= SM_SAMPLE;
                      cs <= 1'b0;
                    end
                  end else spiStart <= 1'b0;
                end
            endcase
          end
        end
      SM_SAMPLE:
        begin
          case (status[4:2])
            3'b001:
              begin
                if (page[15]) flash_sm <= SM_ERROR;
                else flash_sm <= SM_READ;
              end
            3'b010:
              begin
                if (page[15]) flash_sm <= SM_ERROR;
                else flash_sm <= SM_WRITE;
              end
            3'b100:
              begin
                if (page[15]) flash_sm <= SM_ERROR;
                else flash_sm <= SM_ERASE;
              end
            default: flash_sm <= SM_ERROR;
          endcase
        end
      SM_READ:
        begin
          case (read_sm)
            SM_READ_R1:
              begin
                if (status[8]) crc_reset <= 1'b1;
                spiStart <= 1'b1;
                spiDataIn <= flashRead_p;
                read_sm <= SM_READ_R2;
                cs <= 1'b1;
              end
            SM_READ_R2:
              begin
                if (~spiBusy) begin
                  crc_reset <= 1'b0;
                  spiStart <= 1'b1;
                  spiDataIn <= page[15:8];
                  read_sm <= SM_READ_R3;
                end else spiStart <= 1'b0;
              end
            SM_READ_R3:
              begin
                if (~spiBusy) begin
                  spiStart <= 1'b1;
                  spiDataIn <= page[7:0];
                  read_sm <= SM_READ_R4;
                end else spiStart <= 1'b0;
              end
            SM_READ_R4:
              begin
                if (~spiBusy) begin
                  spiStart <= 1'b1;
                  spiDataIn <= 0;
                  read_sm <= SM_READ_R5;
                end else spiStart <= 1'b0;
              end
            SM_READ_R5:
              begin
                if (~spiBusy) begin
                  spiStart <= 1'b1;
                  spiDataIn <= 0;
                  read_sm <= SM_READ_LOOP;
                  crc_valid <= 1'b1;
                end else spiStart <= 1'b0;
              end
            SM_READ_LOOP:
              begin
                if (~spiBusy) begin
                  if (bramWriteAddrP1[8]) begin
                    bramWriteAddr <= 0;
                    read_sm <= SM_READ_R1;
                    flash_sm <= SM_DONE;
                    bramWrite <= 1'b1;
                    spiStart <= 1'b0;
                    cs <= 1'b0;
                    crc_valid <= 1'b0;
                  end else begin
                    spiStart <= 1'b1;
                    bramDataIn <= {8'b0, spiDataOut};
                    bramWriteAddr <= bramWriteAddr + 1'b1;
                    bramWrite <= 1'b1;
                  end
                end else begin
                  bramWrite <= 1'b0;
                  spiStart <= 1'b0;
                end
              end
          endcase
        end
      SM_WRITE:
        begin
          if (page < 16'h1000 && ~status[6]) begin
            flash_sm <= SM_ERROR;
          end else if (page < 16'h3000 && ~status[7]) begin
            flash_sm <= SM_ERROR;
          end else begin
            case (write_sm)
              SM_WRITE_EN:
                begin
                  spiStart <= 1'b1;
                  spiDataIn <= flashWen_p;
                  write_sm <= SM_WRITE_BUFF;
                  cs <= 1'b1;
                end
              SM_WRITE_BUFF:
                begin
                  if (~spiBusy) begin
                    cs <= 1'b0;
                    write_sm <= SM_WRITE_W1;
                  end else spiStart <= 1'b0;
                end
              SM_WRITE_W1:
                begin
                  if (~spiBusy) begin
                    spiStart <= 1'b1;
                    spiDataIn <= flashWrite_p;
                    write_sm <= SM_WRITE_W2;
                    cs <= 1'b1;
                  end
                end
              SM_WRITE_W2:
                begin
                  if (~spiBusy) begin
                    spiStart <= 1'b1;
                    spiDataIn <= page[15:8];
                    write_sm <= SM_WRITE_W3;
                  end else spiStart <= 1'b0;
                end
              SM_WRITE_W3:
                begin
                  if (~spiBusy) begin
                    spiStart <= 1'b1;
                    spiDataIn <= page[7:0];
                    write_sm <= SM_WRITE_W4;
                  end else spiStart <= 1'b0;
                end
              SM_WRITE_W4:
                begin
                  if (~spiBusy) begin
                    spiStart <= 1'b1;
                    spiDataIn <= 0;
                    write_sm <= SM_WRITE_LOOP;
                  end else spiStart <= 1'b0;
                end
              SM_WRITE_LOOP:
                begin
                  if (~spiBusy) begin
                    if (bramReadAddr[8]) begin
                      bramReadAddr <= 0;
                      write_sm <= SM_WRITE_EN;
                      flash_sm <= SM_DONE;
                      spiStart <= 1'b0;
                      cs <= 1'b0;
                    end else begin
                      spiStart <= 1'b1;
                      spiDataIn <= bramDataOut[7:0];
                      bramReadAddr <= bramReadAddr + 1'b1;
                    end
                  end else begin
                    bramWrite <= 1'b0;
                    spiStart <= 1'b0;
                  end
                end
            endcase
          end
        end
      SM_ERASE:
        begin
          if (page < 16'h1000 && ~status[6]) begin
            flash_sm <= SM_ERROR;
          end else if (page < 16'h3000 && ~status[7]) begin
            flash_sm <= SM_ERROR;
          end else begin
            case (erase_sm)
              SM_ERASE_WEN:
                begin
                  spiStart <= 1'b1;
                  spiDataIn <= flashWen_p;
                  erase_sm <= SM_ERASE_BUFF;
                  cs <= 1'b1;
                end
              SM_ERASE_BUFF:
                begin
                  if (~spiBusy) begin
                    cs <= 1'b0;
                    erase_sm <= SM_WRITE_W1;
                  end else spiStart <= 1'b0;
                end
              SM_ERASE_COM:
                begin
                  if (~spiBusy) begin
                    spiStart <= 1'b1;
                    spiDataIn <= flashErase_p;
                    erase_sm <= SM_ERASE_ADDR1;
                    cs <= 1'b1;
                  end
                end
              SM_ERASE_ADDR1:
                begin
                  if (~spiBusy) begin
                    spiStart <= 1'b1;
                    spiDataIn <= page[15:8];
                    erase_sm <= SM_ERASE_ADDR2;
                  end else spiStart <= 1'b0;
                end
              SM_ERASE_ADDR2:
                begin
                  if (~spiBusy) begin
                    spiStart <= 1'b1;
                    spiDataIn <= page[7:0];
                    erase_sm <= SM_ERASE_ADDR3;
                  end else spiStart <= 1'b0;
                end
              SM_ERASE_ADDR3:
                begin
                  if (~spiBusy) begin
                    spiStart <= 1'b1;
                    spiDataIn <= 0;
                    erase_sm <= SM_ERASE_FIN;
                  end else spiStart <= 1'b0;
                end
              SM_ERASE_FIN:
                begin
                  if (~spiBusy) begin
                    erase_sm <= SM_ERASE_WEN;
                    flash_sm <= SM_DONE;
                    cs <= 1'b0;
                  end else spiStart <= 1'b0;
                end
            endcase
          end
        end
      SM_DONE:
        begin
          flash_sm    <= SM_DONE_B;
          bramWrite <= 1'b0;
          resetStatus <= 1'b1;
        end
      SM_DONE_B:
        begin
          resetStatus <= 1'b0;
          readStatus[0] <= 1'b0;
          flash_sm    <= SM_IDLE;
        end
      SM_ERROR:
        begin
          resetStatus <= 1'b1;
          readStatus[1]  <= 1'b1;
          flash_sm <= SM_DONE_B;
          cs <= 1'b0;
        end
      default: flash_sm <= SM_ERROR;
    endcase
  end

  // TODO -- add automatic power-down mode after some interval (500 ms?)

endmodule
`endif // FLASH_GUARD
