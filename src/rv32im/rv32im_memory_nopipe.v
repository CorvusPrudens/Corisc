`ifndef RV32IM_MEMORY_GUARD
`define RV32IM_MEMORY_GUARD

module rv32im_memory_nopipe
  #(
    parameter XLEN = 32
  )
  (
    input wire clk_i,

    input wire clear_i,
    input wire data_ready_i,

    input wire [XLEN-1:0] data_i,
    output reg [XLEN-1:0] data_o,
    input wire [XLEN-1:0] addr_i,
    input wire [1:0] word_size_i,
    input wire write_i,
    output reg busy_o,

    output reg err_o,

    // Wishbone Master signals
    input wire [XLEN-1:0] master_dat_i,
    output reg [XLEN-1:0] master_dat_o,
    input wire ack_i,
    output reg [XLEN-1:2] adr_o, // XLEN sized address space with byte granularity
                                  // NOTE -- the slave will only have a port as large as its address space
    output wire cyc_o,
    // input wire stall_i,
    input wire err_i,
    output reg [3:0] sel_o,
    output reg stb_o,
    output reg we_o,

    input wire ctrl_grant_i,
    output reg ctrl_req_o
  );

  // Works for simple one-master busses
  assign cyc_o = stb_o;

  // NOTE -- misaligned addresses are silently ignored atm
  // NOTE -- sel doesn't actually set the bit position for reads 
  // TODO -- make sel behavior align with spec
  // (i.e. 4'b1000 means put a byte with offset 3 in the lowest 8 bits)
  reg [3:0] sel;
  always @(*) begin
    case (word_size_i)
      default: sel = 4'b0001 << addr_i[1:0]; // byte
      2'b01: sel = addr_i[1] ? 4'b1100 : 4'b0011; // half-word
      2'b10: sel = 4'b1111; // word
    endcase
  end

  always @(posedge clk_i) begin
    if (clear_i) begin
      stb_o <= 1'b0;
      sel_o <= 0;
      we_o <= 1'b0;
      busy_o <= 1'b0;
      err_o <= 1'b0;
      ctrl_req_o <= 1'b0;
    end else if (data_ready_i & ~ctrl_req_o) begin
      ctrl_req_o <= 1'b1;
    end else if (ctrl_req_o & ctrl_grant_i & ~stb_o) begin
      adr_o <= addr_i[XLEN-1:2];
      sel_o <= sel;
      stb_o <= 1'b1;
      master_dat_o <= data_i;
      we_o <= write_i;
    end else if (ctrl_req_o & ctrl_grant_i & err_i) begin
      // an error occurred and the transaction is immediately cancelled
      stb_o <= 1'b0;
      sel_o <= 0;
      we_o <= 1'b0;
      busy_o <= 1'b0;
      err_o <= 1'b1;
      ctrl_req_o <= 1'b0;
    end else if (ctrl_req_o & ctrl_grant_i & ack_i) begin
      // transaction complete
      stb_o <= 1'b0;
      busy_o <= 1'b0;
      we_o <= 1'b0;
      data_o <= master_dat_i;
      ctrl_req_o <= 1'b0;
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
