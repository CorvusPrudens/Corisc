`ifndef RV32IM_MEMORY_GUARD
`define RV32IM_MEMORY_GUARD

`include "wb_encode_decode.v"

module rv32im_memory_nopipe
  #(
    parameter XLEN = 32
  )
  (
    input wire clk_i,

    input wire clear_i,
    input wire data_ready_i,

    input wire [XLEN-1:0] data_i,
    output reg [XLEN-1:0] data_o = 0,
    input wire [XLEN-1:0] addr_i,
    input wire [1:0] word_size_i,
    input wire write_i,
    output reg busy_o = 0,

    output reg err_o = 0,

    // Wishbone Master signals
    input  wire [XLEN-1:0] master_dat_i,
    output wire [XLEN-1:0] master_dat_o,
    input wire ack_i,
    output reg [XLEN-1:2] adr_o = 0, // XLEN sized address space with byte granularity
                                  // NOTE -- the slave will only have a port as large as its address space
    // input wire stall_i,
    input wire err_i,
    output reg [3:0] sel_o = 0,
    output reg stb_o = 0,
    output reg we_o = 0
  );

  reg [3:0] sel;
  always @(*) begin
    case (word_size_i)
      default: sel = 4'b0001 << addr_i[1:0]; // byte
      2'b01: sel = addr_i[1] ? 4'b1100 : 4'b0011; // half-word
      2'b10: sel = 4'b1111; // word
    endcase
  end

  reg [XLEN-1:0] unencoded_wb_output = 0;
  wire [XLEN-1:0] decoded_wb_input;

  wb_encode_decode #(
    .XLEN(XLEN)
  ) WB_ENCODE_DECODE (
    .sel_i(sel),
    .master_dat_i(master_dat_i),
    .unencoded_output_i(unencoded_wb_output),
    .input_decoded_o(decoded_wb_input),
    .master_dat_o(master_dat_o)
  );

  reg [1:0] mem_sm = 0;

  always @(posedge clk_i) begin
    if (clear_i) begin
      mem_sm <= 0;

      stb_o <= 1'b0;
      sel_o <= 0;
      we_o <= 1'b0;
      busy_o <= 1'b0;
      err_o <= 1'b0;
    end else begin
      case (mem_sm)
        default:
        begin
          if (data_ready_i) begin
            adr_o <= addr_i[XLEN-1:2];
            sel_o <= sel;
            stb_o <= 1'b1;
            unencoded_wb_output <= data_i;
            we_o <= write_i;
            mem_sm <= mem_sm + 1'b1;
          end
        end
        2'b01:
        begin
          if (ack_i) begin
            stb_o <= 1'b0;
            busy_o <= 1'b0;
            we_o <= 1'b0;
            data_o <= decoded_wb_input;
            mem_sm <= 0;
          end else if (err_i) begin
            stb_o <= 1'b0;
            sel_o <= 0;
            we_o <= 1'b0;
            busy_o <= 1'b0;
            err_o <= 1'b1;
            mem_sm <= 0;
          end
        end
      endcase
    end
  end

  `ifdef FORMAL
    reg  timeValid_f;
    initial timeValid_f = 0;
    always @(posedge clk_i)
      timeValid_f <= 1;

    always @(*)
      assume(clear_i == ~timeValid_f);

    always @(posedge clk_i) begin
      // A clear signal will always immediately reset the logic to a standby state
      if (timeValid_f & $past(timeValid_f) & $past(clear_i)) begin
        assert(stb_o == 1'b0);
        assert(sel_o == 0);
        assert(we_o == 1'b0);
        assert(busy_o == 1'b0);
        assert(err_o == 1'b0);
      end

      // An ack input while the strobe output is high will always complete a transaction
      if (timeValid_f & $past(timeValid_f) & $past(stb_o & ack_i & ~err_i)) begin
        assert(stb_o == 0);
        assert(busy_o == 0);
        assert(we_o == 0);
        assert(data_o == $past(master_dat_i));
      end

      // An error input while the strobe output is high will always complete a transaction
      // and raise an error flag
      if (timeValid_f & $past(timeValid_f) & $past(stb_o & err_i)) begin
        assert(stb_o == 0);
        assert(busy_o == 0);
        assert(we_o == 0);
        // We don't care what the output data is in case of error
        // assert(data_o == $past(master_dat_i));
        assert(err_o == 1'b1);
      end

      // let's be explicit just to be doubly sure
      if (timeValid_f & $past(timeValid_f) & $past(~stb_o & data_ready_i)) begin
        if ($past(word_size_i) == 2'b01) begin
          // TODO -- we acknowledge here that misaligned reads
          // will simply fail to behave as expected
          if ($past(addr_i[1:0]) == 0 || $past(addr_i[1:0]) == 1)
            assert(sel_o == 4'b0011);
          else
            assert(sel_o == 4'b1100);
        end else if ($past(word_size_i) == 2'b10) begin
          assert(sel_o == 4'b1111);
        end else begin // should fall under 2'b00
          if ($past(addr_i[1:0]) == 0)
            assert(sel_o == 4'b0001);
          else if ($past(addr_i[1:0]) == 1)
            assert(sel_o == 4'b0010);
          else if ($past(addr_i[1:0]) == 2)
            assert(sel_o == 4'b0100);
          else if ($past(addr_i[1:0]) == 3)
            assert(sel_o == 4'b1000);
        end
      end

    end

  `endif


endmodule

`endif // RV32IM_MEMORY_GUARD
