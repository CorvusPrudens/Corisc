
module rv32i_memory
  #(
    XLEN = 32
    MAP_SIZE = 5
    REGION_1_B = 0,          // Memory Mapped modules
    REGION_1_E = 64,
    REGION_2_B = 0x00010000, // RAM
    REGION_2_E = 0x00010800,
    REGION_3_B = 0x00020000, // ROM
    REGION_3_E = 0x00040000,
    REGION_4_B = 0x00050000, // GPU
    REGION_4_E = 0x00050200
  )
  (
    input wire clk_i,
    input wire write_i,
    input wire read_i,

    input wire [XLEN-1:0] read_i,
    input wire [XLEN-1:0] data_i,

    input wire [XLEN-1:0] data1_i,
    input wire [XLEN-1:0] data2_i,
    input wire [XLEN-1:0] data3_i,
    input wire [XLEN-1:0] data4_i,

    output wire [MAP_SIZE-1:0] data_region_o,

    output wire [XLEN-1:0] data_o,
    output wire illegal_access_o
  );



endmodule