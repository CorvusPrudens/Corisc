`ifndef RV32I_INSTRUCTION_CACHE
`define RV32I_INSTRUCTION_CACHE

`include "bram_dual.v"

module rv32i_instruction_cache 
  #(
    parameter CACHE_LEN = 9,
    parameter LINE_LEN = 6,
    parameter ILEN = 32,
    parameter XLEN = 32
  )
  (
    input wire clk_i,
    input wire reset_i,
    input wire advance_i,
    output reg busy_o,
    input wire [XLEN-1:0] addr_i,
    output reg [ILEN-1:0] instruction_o,

    // Arbitration signals
    output reg ctrl_req_o,
    input wire ctrl_grant_i,

    // Wishbone Master signals
    input wire [XLEN-1:0] master_dat_i,
    input wire ack_i,
    output reg [XLEN-1:2] adr_o, // XLEN sized address space with byte granularity
                                  // NOTE -- the slave will only have a port as large as its address space
    output wire cyc_o,
    // input wire stall_i,
    input wire err_i,
    output wire [3:0] sel_o,
    output reg stb_o

  );

  assign sel_o = 4'b1111;
  assign cyc_o = stb_o;

  // reg cache_write;
  // wire [ILEN-1:0] instruction_i;
  reg [CACHE_LEN-1:0] cache_waddr;
  wire [CACHE_LEN-1:0] cache_raddr;

  reg [XLEN-1:0] working_addr;

  bram_dual #(
    .memSize_p(CACHE_LEN),
    .dataWidth_p(ILEN)
  ) BRAM_DUAL (
    .clk_i(clk_i),
    .write_i(ack_i),
    .data_i(master_dat_i),
    .waddr_i(cache_waddr),
    .raddr_i(cache_raddr),
    .data_o(instruction_o)
  );

  localparam TAG_WIDTH = (XLEN-2-LINE_LEN)+1; // we store the valid bit at MSB
  localparam LINE_COUNT = (CACHE_LEN-LINE_LEN);
  
  wire [TAG_WIDTH-2:0] tag_i = addr_i[XLEN-1:LINE_LEN+2];
  wire [TAG_WIDTH-2:0] working_tag_i = working_addr[XLEN-1:LINE_LEN+2];
  // wire [CACHE_LEN-1:0] index = addr_i[LINE_LEN+1:2];
  wire misaligned_exception = addr_i[0] | addr_i[1];

  reg [LINE_COUNT-1:0] current_line;
  reg [TAG_WIDTH-1:0] tags [(2**LINE_COUNT)-1:0]; 

  reg [LINE_COUNT:0] matching_tag;
  always @(*) begin
    integer i;
    matching_tag = {1'b1, {LINE_COUNT{1'b0}}};
    for (i = 0; i < 2**LINE_COUNT; i = i + 1)
      if ((tag_i == tags[i][TAG_WIDTH-2:0]) & tags[i][TAG_WIDTH-1])
        matching_tag = {1'b0, i[2:0]};
  end

  assign cache_raddr = {matching_tag[LINE_COUNT-1:0], addr_i[LINE_LEN+1:2]};
  reg fetch_done;
  
  always @(posedge clk_i) begin
    if (reset_i) begin
      // should probably reset all cache valids here
      integer i;
      for (i = 0; i < 2**LINE_COUNT; i = i + 1)
        tags[i][TAG_WIDTH-1] <= 1'b0;
      current_line <= 0;
      busy_o <= 1'b0;
      instruction_o <= 0;
      working_addr <= 0;
    end else if (advance_i) begin
      if (matching_tag[LINE_COUNT]) begin // cache miss
        busy_o <= 1'b1;
        working_addr <= addr_i;
        // initiate the data grab here
      end else begin // cache hit
        // nothing -- the output will be the valid cached instruction
      end
    end else
      if (fetch_done)
        busy_o <= 1'b0;
  end

  reg [LINE_LEN:0] cache_write_idx;
  // wire [LINE_LEN:0] cache_write_idx_p1 = cache_write_idx + 1'b1;
  wire cache_write_done = cache_write_idx[LINE_LEN];
  reg [2:0] fetch_sm;
  localparam FETCH_IDLE = 3'b000;
  localparam FETCH_ARB =  3'b001;
  localparam FETCH_READ = 3'b010;
  localparam FETCH_DONE = 3'b100;
  
  wire [XLEN-3:0] cache_write_src_addr = {working_tag_i[TAG_WIDTH-2:LINE_COUNT], current_line, cache_write_idx[LINE_LEN-1:0]};
  wire [CACHE_LEN-1:0] cache_waddr_wire = {current_line, cache_write_idx[LINE_LEN-1:0]};

  always @(posedge clk_i) begin
    if (reset_i) begin
      fetch_sm <= FETCH_IDLE;
      cache_write_idx <= 0;
      fetch_done <= 1'b0;
    end else if (busy_o) begin
      case (fetch_sm)
        default: 
          begin
            fetch_sm <= FETCH_ARB;
            ctrl_req_o <= 1'b1;
          end
        FETCH_ARB: 
          begin
            if (ctrl_grant_i) begin
              fetch_sm <= FETCH_READ;
              stb_o <= 1'b1;
              adr_o <= cache_write_src_addr;
              cache_write_idx <= cache_write_idx + 1'b1;
              cache_waddr <= cache_waddr_wire;
            end
          end
        FETCH_READ:
          begin
            if (ack_i) begin
              adr_o <= cache_write_src_addr;
              cache_waddr <= cache_waddr_wire;
              cache_write_idx <= cache_write_idx + 1'b1;
              if (cache_write_done) begin
                stb_o <= 1'b0;
                fetch_sm <= FETCH_DONE;
                fetch_done <= 1'b1;
              end
            end
          end
        FETCH_DONE:
          begin
            fetch_sm <= FETCH_IDLE;
            fetch_done <= 1'b0;
            ctrl_req_o <= 1'b0;
            tags[current_line][TAG_WIDTH-1] <= 1'b1;
            tags[current_line][TAG_WIDTH-2:0] <= working_tag_i;
            current_line <= current_line + 1'b1;
          end
      endcase
    end
  end

endmodule

`endif