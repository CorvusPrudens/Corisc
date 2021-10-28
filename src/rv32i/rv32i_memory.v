
module rv32i_memory
  #(
    XLEN = 32,
    PORT_LEN = 32,
    MAP_SIZE = 9,
    REGION_0_B = 32'h00000000,
    REGION_0_E = 32'h00000400,
    REGION_1_B = 32'h00001000,
    REGION_1_E = 32'h00001040,
    REGION_2_B = 32'h00002000,
    REGION_2_E = 32'h00002400,
    REGION_3_B = 32'h00004000,
    REGION_3_E = 32'h00004018,
    REGION_4_B = 32'h00009000,
    REGION_4_E = 32'h00009004,
    REGION_5_B = 32'h0000A000,
    REGION_5_E = 32'h0000A004,
    REGION_6_B = 32'h0000B000,
    REGION_6_E = 32'h0000B004,
    REGION_7_B = 32'h00010000,
    REGION_7_E = 32'h00020000,
    REGION_8_B = 32'h00020000,
    REGION_8_E = 32'h00030000
  )
  (
    input wire clk_i,
    input wire write_i,
    input wire read_i,
    input wire reset_i,

    input wire [XLEN-1:0] addr_i,
    input wire [PORT_LEN-1:0] data_i,

    input wire [PORT_LEN-1:0] data0_i,
    input wire [PORT_LEN-1:0] data1_i,
    input wire [PORT_LEN-1:0] data2_i,
    input wire [PORT_LEN-1:0] data3_i,
    input wire [PORT_LEN-1:0] data4_i,
    input wire [PORT_LEN-1:0] data5_i,
    input wire [PORT_LEN-1:0] data6_i,
    input wire [PORT_LEN-1:0] data7_i,
    input wire [PORT_LEN-1:0] data8_i,

    output reg [MAP_SIZE-1:0] data_region_o,

    output reg [PORT_LEN-1:0] data_o,
    output reg illegal_access_o
  );

  wire [MAP_SIZE-1:0] regions;

  assign regions[0] = addr_i >= REGION_0_B && addr_i < REGION_0_E;
  assign regions[1] = addr_i >= REGION_1_B && addr_i < REGION_1_E;
  assign regions[2] = addr_i >= REGION_2_B && addr_i < REGION_2_E;
  assign regions[3] = addr_i >= REGION_3_B && addr_i < REGION_3_E;
  assign regions[4] = addr_i >= REGION_4_B && addr_i < REGION_4_E;
  assign regions[5] = addr_i >= REGION_5_B && addr_i < REGION_5_E;
  assign regions[6] = addr_i >= REGION_6_B && addr_i < REGION_6_E;
  assign regions[7] = addr_i >= REGION_7_B && addr_i < REGION_7_E;
  assign regions[8] = addr_i >= REGION_8_B && addr_i < REGION_8_E;

  genvar i;
  generate
    for (i = 0; i < MAP_SIZE; i = i + 1) begin
      assign data_region_o[i] = regions[i];
    end
  endgenerate

  always @(*) begin
    case (data_region_o)
      default: data_o = data0_i;
      9'b000000001: data_o = data0_i;
      9'b000000010: data_o = data1_i;
      9'b000000100: data_o = data2_i;
      9'b000001000: data_o = data3_i;
      9'b000010000: data_o = data4_i;
      9'b000100000: data_o = data5_i;
      9'b001000000: data_o = data6_i;
      9'b010000000: data_o = data7_i;
      9'b100000000: data_o = data8_i;
    endcase
  end

  always @(posedge clk_i) begin
    if (reset_i)
      illegal_access_o <= 1'b0;
    if (data_region_o == 0 && (read_i | write_i))
      illegal_access_o <= 1'b1;
  end

  `ifdef FORMAL
    // FORMAL prove
    reg timeValid_f = 0;
    always @(posedge clk_i) timeValid_f <= 1;
    
    // TODO -- how to detect two-clock delayed events?
    always @(posedge clk_i) begin
      if (timeValid_f && $past(data_region_o) == 0 && ($past(write_i) || $past(read_i)))
        assert(illegal_access_o == 1'b1);
    end
  `endif

endmodule
