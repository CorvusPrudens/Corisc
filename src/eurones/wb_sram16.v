`ifndef WB_SRAM16_GUARD
`define WB_SRAM16_GUARD

module wb_sram16
  #(
    parameter XLEN = 32,
    parameter ADDR_BITS = 17
  )
  (
    input wire clk_i,
    // Wishbone slave signals
    input wire [XLEN-1:0] slave_dat_i,
    output reg [XLEN-1:0] slave_dat_o,
    input wire rst_i,

    output wire ack_o,
    input wire [ADDR_BITS-1:2] adr_i, // NOTE -- the slave will only have a port as large as its address space,
                                 // so none will actually be XLEN-1
    input wire cyc_i,
    // output reg stall_o, // if a stall is necessary, raise this
    output reg err_o, // if an invalid command is issued, raise this
    input wire [3:0] sel_i,
    input wire stb_i,
    input wire we_i,

    output wire [15:0] SRAM_ADDR,
    `ifdef SIM
    input wire [15:0] SRAM_I,
    output reg [15:0] SRAM_O,
    `else
    inout wire [15:0] SRAM_DATA,
    `endif
    output wire SRAM_WE,
    output wire SRAM_CE,
    output wire SRAM_OE,
    output wire SRAM_LB,
    output wire SRAM_UB
  );
  wire execute = cyc_i & stb_i;

  localparam REQ_BYTE = 3'b001;
  localparam REQ_HALF = 3'b010;
  localparam REQ_WORD = 3'b100;

  reg [2:0] req_type;

  always @(*) begin
    case (sel_i)
      default: req_type = REQ_BYTE;
      4'b0011: req_type = REQ_HALF;
      4'b1100: req_type = REQ_HALF;
      4'b1111: req_type = REQ_WORD;
    endcase
  end

  wire half_offset = ~req_type[2] & (sel_i[3] | sel_i[2]);
  reg [1:0] word_offset;
  reg sram_write;
  reg [15:0] output_data;
  wire [15:0] input_data;

  assign SRAM_ADDR = {adr_i, word_offset[1] | half_offset};
  assign SRAM_LB = ~(sel_i[0] | sel_i[2]);
  assign SRAM_UB = ~(sel_i[1] | sel_i[3]);
  assign SRAM_CE = 1'b0;
  assign SRAM_WE = ~(sram_write & ~clk_i);
  assign SRAM_OE = ~SRAM_WE;


  `ifdef SIM
  wire [7:0] byte_mux = ~SRAM_LB ? SRAM_I[7:0] : SRAM_I[15:8];
  wire [15:0] half = SRAM_I;
  `else
  wire [7:0] byte_mux = ~SRAM_LB ? SRAM_DATA[7:0] : SRAM_DATA[15:8];
  wire [15:0] half = SRAM_DATA;

  assign SRAM_DATA = sram_write ? output_data : 16'bz;

  `endif

  always @(posedge clk_i) begin
    if (rst_i) begin
      ack_o <= 1'b0;
      err_o <= 1'b0;
      word_offset <= 0;
      sram_write <= 1'b0;
      // stall_o <= 1'b0; // to be added with pipelining
    end else if (execute & ~ack_o) begin
      if (req_type[2]) begin
        word_offset <= word_offset + 1'b1;
        if (word_offset[0]) begin
          word_offset <= word_offset + 1'b1;
          ack_o <= 1'b1;
        end
      end else
        ack_o <= 1'b1;
      sram_write <= we_i;
    end else begin
      ack_o <= 1'b0;
      word_offset <= 0;
      sram_write <= 1'b0;
    end
  end

  always @(posedge clk_i) begin
    if (execute) begin
      if (we_i) begin
        // TODO -- adapt this for writing
        `ifdef SIM
        case (req_type)
          default: ;
          REQ_BYTE: SRAM_O <= SRAM_LB ? {8'b0, slave_dat_i[7:0]} : {slave_dat_i[7:0], 8'b0};
          REQ_HALF: SRAM_O <= slave_dat_i[15:0];
          REQ_WORD: 
            begin
              if (word_offset[0])
                SRAM_O <= slave_dat_i[31:16];
              else
                SRAM_O <= slave_dat_i[15:0];
            end
        endcase
        `else
        case (req_type)
          default: ;
          REQ_BYTE: output_data <= SRAM_LB ? {8'b0, slave_dat_i[7:0]} : {slave_dat_i[7:0], 8'b0};
          REQ_HALF: output_data <= slave_dat_i[15:0];
          REQ_WORD: 
            begin
              if (word_offset[0])
                output_data <= slave_dat_i[31:16];
              else
                output_data <= slave_dat_i[15:0];
            end
        endcase
        `endif
      end else begin
        case (req_type)
          default: ;
          REQ_BYTE: slave_dat_o <= {24'b0, byte_mux};
          REQ_HALF: slave_dat_o <= {16'b0, half};
          REQ_WORD: 
            begin
              if (word_offset[0])
                slave_dat_o[31:16] <= half;
              else
                slave_dat_o[15:0] <= half;
            end
        endcase
      end
    end
  end

endmodule

`endif // WB_SRAM16_GUARD
