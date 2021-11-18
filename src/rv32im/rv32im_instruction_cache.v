`ifndef RV32IM_INSTRUCTION_CACHE
`define RV32IM_INSTRUCTION_CACHE

`include "bram_dual_re.v"
`include "rv32im_interrupts.v"

module rv32im_instruction_cache 
  #(
    parameter CACHE_LEN = 7, // 128 instructions in cache (512 bytes)
    parameter LINE_LEN = 4, // 16 instructions per line (64 bytes) therefore 8 lines
    parameter ILEN = 32,
    parameter XLEN = 32,
    parameter VTABLE_ADDRESS = 32'h00000000,
    parameter UNUSED_ADDR_BITS = 8
  )
  (
    input wire clk_i,
    input wire reset_i,
    input wire advance_i,
    input wire jump_i,
    output wire busy_o,
    input wire [XLEN-1:0] addr_i,
    output wire [ILEN-1:0] instruction_o,
    output reg [XLEN-1:0] vtable_pc_o,
    output reg vtable_pc_write,
    output wire cache_invalid_o,

    input wire interrupt_trigger_i,
    input wire [XLEN-1:0] vtable_offset_i,

    // Arbitration signals
    output wire ctrl_req_o,
    input wire ctrl_grant_i,

    // Wishbone Master signals
    input wire [XLEN-1:0] master_dat_i,
    input wire ack_i,
    output wire [XLEN-3:0] adr_o, // XLEN sized address space with byte granularity
                                  // NOTE -- the slave will only have a port as large as its address space
    output wire cyc_o,
    // input wire stall_i,
    input wire err_i,
    output wire [3:0] sel_o,
    output wire stb_o
  );

  reg  cache_valid;
  initial cache_valid = 0;
  // assign cache_invalid_o = ~cache_valid;
  assign cache_invalid_o = matching_tag[LINE_COUNT];

  reg  cache_busy;
  initial cache_busy = 0;
  reg  vtable_busy;
  initial vtable_busy = 0;
  reg  cache_req;
  initial cache_req = 0;
  reg  vtable_req;
  initial vtable_req = 0;
  reg  cache_stb;
  initial cache_stb = 0;
  reg  vtable_stb;
  initial vtable_stb = 0;
  reg [XLEN-3:0] cache_adr;
  initial cache_adr = 0;
  reg [XLEN-3:0] vtable_adr;
  initial vtable_adr = 0;
  
  assign busy_o = cache_busy | vtable_busy;
  assign ctrl_req_o = cache_req | vtable_req;
  assign adr_o = cache_req ? cache_adr : vtable_adr;
  assign stb_o = cache_stb | vtable_stb;

  assign sel_o = 4'b1111;
  assign cyc_o = stb_o;

  // reg cache_write = 0;
  // wire [ILEN-1:0] instruction_i;
  reg [CACHE_LEN-1:0] cache_waddr;
  initial cache_waddr = 0;
  wire [CACHE_LEN-1:0] cache_raddr;

  reg [XLEN-1:0] working_addr;
  initial working_addr = 0;

  bram_dual_re #(
    .memSize_p(CACHE_LEN),
    .dataWidth_p(ILEN)
  ) BRAM_DUAL_RE (
    .clk_i(clk_i),
    .write_i(ack_i & cache_req),
    .read_i(advance_i | jump_i),
    .data_i(master_dat_i),
    .waddr_i(cache_waddr),
    .raddr_i(cache_raddr),
    .data_o(instruction_o)
  );

  localparam TAG_WIDTH = (XLEN-2-LINE_LEN-UNUSED_ADDR_BITS)+1; // we store the valid bit at MSB
  localparam LINE_COUNT = (CACHE_LEN-LINE_LEN);
  
  wire [TAG_WIDTH-2:0] tag_i = addr_i[XLEN-1-UNUSED_ADDR_BITS:LINE_LEN+2];
  wire [TAG_WIDTH-2:0] working_tag_i = working_addr[XLEN-1-UNUSED_ADDR_BITS:LINE_LEN+2];
  // wire [CACHE_LEN-1:0] index = addr_i[LINE_LEN+1:2];
  wire misaligned_exception = addr_i[0] | addr_i[1];

  reg [LINE_COUNT-1:0] current_line;
  initial current_line = 0;
  reg [TAG_WIDTH-1:0] tags [(2**LINE_COUNT)-1:0]; 

  reg [LINE_COUNT:0] matching_tag;
  integer i;
  always @(*) begin
    matching_tag = {1'b1, {LINE_COUNT{1'b0}}};
    for (i = 0; i < 2**LINE_COUNT; i = i + 1)
      if ((tag_i == tags[i][TAG_WIDTH-2:0]) & tags[i][TAG_WIDTH-1])
        matching_tag = {1'b0, i[LINE_COUNT-1:0]};
  end

  assign cache_raddr = {matching_tag[LINE_COUNT-1:0], addr_i[LINE_LEN+1:2]};
  reg  fetch_done;
  initial fetch_done = 0;
  reg  vtable_lookup_init;
  initial vtable_lookup_init = 0;
  
  always @(posedge clk_i) begin
    if (reset_i) begin
      cache_busy <= 1'b0;
      working_addr <= 0;
      cache_valid <= 1'b0;
      vtable_lookup_init <= 1'b0;
      interrupt_accepted <= 1'b0;
    end else if (advance_i) begin
      if (~vtable_lookup_init | interrupt_trigger_i) begin
        vtable_busy <= 1'b1;
        vtable_lookup_init <= 1'b1;
      end else begin
        if (matching_tag[LINE_COUNT]) begin // cache miss
          cache_busy <= 1'b1;
          working_addr <= addr_i;
          cache_valid <= 1'b0;
          // initiate the data grab here
        end else begin // cache hit
          cache_valid <= 1'b1;
          // nothing -- the output will be the valid cached instruction
        end
      end
    end else if (fetch_done) begin
      cache_busy <= 1'b0;
    end else if (vtable_done) begin
      vtable_busy <= 1'b0;
    end
  end

  reg [LINE_LEN:0] cache_write_idx;
  initial cache_write_idx = 0;
  // wire [LINE_LEN:0] cache_write_idx_p1 = cache_write_idx + 1'b1;
  wire cache_write_done = cache_write_idx[LINE_LEN];
  reg [2:0] fetch_sm;
  initial fetch_sm = 0;
  localparam FETCH_IDLE = 3'b000;
  localparam FETCH_ARB =  3'b001;
  localparam FETCH_READ = 3'b010;
  localparam FETCH_DONE = 3'b100;
  
  wire [XLEN-3:0] cache_write_src_addr = {{UNUSED_ADDR_BITS{1'b0}}, working_addr[XLEN-1-UNUSED_ADDR_BITS:LINE_LEN+2], cache_write_idx[LINE_LEN-1:0]};
  wire [CACHE_LEN-1:0] cache_waddr_wire = {current_line, cache_write_idx[LINE_LEN-1:0]};

  integer j;
  always @(posedge clk_i) begin
    if (reset_i) begin
      for (j = 0; j < 2**LINE_COUNT; j = j + 1)
        tags[j][TAG_WIDTH-1] <= 1'b0;
      fetch_sm <= FETCH_IDLE;
      cache_write_idx <= 0;
      fetch_done <= 1'b0;
      cache_req <= 1'b0;
      current_line <= 0;
    end else if (cache_busy) begin
      case (fetch_sm)
        default: 
          begin
            fetch_sm <= FETCH_ARB;
            cache_req <= 1'b1;
          end
        FETCH_ARB: 
          begin
            if (ctrl_grant_i) begin
              fetch_sm <= FETCH_READ;
              cache_stb <= 1'b1;
              cache_adr <= cache_write_src_addr;
              cache_write_idx <= cache_write_idx + 1'b1;
              cache_waddr <= cache_waddr_wire;
            end
          end
        FETCH_READ:
          begin
            if (ack_i) begin
              cache_adr <= cache_write_src_addr;
              cache_waddr <= cache_waddr_wire;
              cache_write_idx <= cache_write_idx + 1'b1;
              if (cache_write_done) begin
                cache_stb <= 1'b0;
                fetch_sm <= FETCH_DONE;
                fetch_done <= 1'b1;
                cache_req <= 1'b0;
              end
            end
          end
        FETCH_DONE:
          begin
            fetch_sm <= FETCH_IDLE;
            fetch_done <= 1'b0;
            cache_write_idx <= 0;
            tags[current_line][TAG_WIDTH-1] <= 1'b1;
            tags[current_line][TAG_WIDTH-2:0] <= working_tag_i;
            current_line <= current_line + 1'b1;
          end
      endcase
    end
  end

  // TODO -- if the critical path lies along the memory, then consider
  // combining the always blocks of these two state machines so the
  // output address doesn't have to be muxed
  reg [2:0] vtable_sm;
  initial vtable_sm = 0;
  localparam VTABLE_IDLE = 3'b000;
  localparam VTABLE_ARB  = 3'b001;
  localparam VTABLE_WRITE = 3'b010;
  localparam VTABLE_DONE = 3'b100;
  reg  vtable_done;
  initial vtable_done = 0;

  // TODO -- may want to distinguish this activity since it will write to the program counter
  always @(posedge clk_i) begin
    if (reset_i) begin
      vtable_sm <= VTABLE_IDLE;
      vtable_done <= 1'b0;
      vtable_req <= 1'b0;
    end else if (vtable_busy) begin
      case (vtable_sm)
        default:
          begin
            vtable_sm <= VTABLE_ARB;
            vtable_req <= 1'b1;
          end
        VTABLE_ARB:
          begin
            if (ctrl_grant_i) begin
              vtable_sm <= VTABLE_WRITE;
              vtable_stb <= 1'b1;
              vtable_adr <= VTABLE_ADDRESS[XLEN-1:2] + vtable_offset_i[XLEN-1:2];
            end
          end
        VTABLE_WRITE:
          begin
            if (ack_i) begin
              vtable_pc_o <= master_dat_i;
              vtable_sm <= VTABLE_DONE;
              vtable_req <= 1'b0;
              vtable_stb <= 1'b0;
              vtable_pc_write <= 1'b1;
              vtable_done <= 1'b1;
            end
          end
        VTABLE_DONE:
          begin
            vtable_sm <= VTABLE_IDLE;
            vtable_done <= 1'b0;
            vtable_pc_write <= 1'b0;
          end
      endcase
    end
  end

  `ifdef FORMAL
    reg  timeValid_f;
    initial timeValid_f = 0;
    always @(posedge clk_i) timeValid_f <= 1;

    initial assume(reset_i);

    // These cause huge slowdowns
    // // Ensuring everything is reset properly
    // always @(posedge clk_i) begin
    //   if (timeValid_f & $past(reset_i)) begin
    //     assert(cache_busy == 1'b0);
    //     assert(working_addr == 0);
    //     assert(cache_valid == 1'b0);
    //     assert(vtable_lookup_init == 1'b0);
    //     assert(vtable_sm == VTABLE_IDLE);
    //     assert(vtable_done == 1'b0);
    //     assert(vtable_req == 1'b0);
    //     assert(fetch_sm == FETCH_IDLE);
    //     assert(cache_write_idx == 0);
    //     assert(fetch_done == 1'b0);
    //     assert(cache_req == 1'b0);
    //     assert(current_line == 0);
    //   end
    // end

    // always @(posedge clk_i) begin
    //   if (timeValid_f & $past(fetch_done))
    //     assert(cache_busy == 0);
    // end

  `endif

endmodule

`endif
