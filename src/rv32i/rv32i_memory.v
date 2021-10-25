
module rv32i_memory
  #(
    XLEN = 32,
    PORT_LEN = 32,
    MAP_SIZE = 4,
    REGION_1_B = 0,          // Memory Mapped modules
    REGION_1_E = 64,
    REGION_2_B = 32'h00010000, // RAM
    REGION_2_E = 32'h00010800,
    REGION_3_B = 32'h00020000, // ROM
    REGION_3_E = 32'h00040000,
    REGION_4_B = 32'h00050000, // GPU
    REGION_4_E = 32'h00050200
  )
  (
    input wire clk_i,
    input wire write_i,
    input wire read_i,
    input wire reset_i,

    input wire [XLEN-1:0] addr_i,
    input wire [PORT_LEN-1:0] data_i,

    input wire [PORT_LEN-1:0] data1_i,
    input wire [PORT_LEN-1:0] data2_i,
    input wire [PORT_LEN-1:0] data3_i,
    input wire [PORT_LEN-1:0] data4_i,

    output reg [MAP_SIZE-1:0] data_region_o,

    output reg [PORT_LEN-1:0] data_o,
    output reg illegal_access_o
  );

  wire region_1 = addr_i >= REGION_1_B && addr_i < REGION_1_E;
  wire region_2 = addr_i >= REGION_2_B && addr_i < REGION_2_E;
  wire region_3 = addr_i >= REGION_3_B && addr_i < REGION_3_E;
  wire region_4 = addr_i >= REGION_4_B && addr_i < REGION_4_E;

  assign data_region_o = {region_4, region_3, region_2, region_1};

  always @(*) begin
    case (data_region_o)
      default: data_o = data1_i;
      4'b0001: data_o = data1_i;
      4'b0010: data_o = data2_i;
      4'b0100: data_o = data3_i;
      4'b1000: data_o = data4_i;
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