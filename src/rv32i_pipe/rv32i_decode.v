`ifndef RV32I_DECODE_GUARD
`define RV32I_DECODE_GUARD

module rv32i_decode 
  #(
    parameter XLEN = 32,
    parameter ILEN = 32
  )
  (
    input wire clk_i,
    input wire [XLEN-1:0] instruction
  );

  localparam OP_L     = 5'b00000;
  localparam OP_FENCE = 5'b00011;
  localparam OP_AI    = 5'b00100; // arithmetic immediate
  localparam OP_AUIPC = 5'b00101;
  localparam OP_S     = 5'b01000;
  localparam OP_A     = 5'b01100; // arithmetic 
  localparam OP_LUI   = 5'b01101;
  localparam OP_B     = 5'b11000;
  localparam OP_JALR  = 5'b11001;
  localparam OP_JAL   = 5'b11011;
  localparam OP_SYS   = 5'b11100;

  reg [ILEN-1:0] instruction = 0;

  wire [11:0] i_immediate = instruction[31:20];
  wire [11:0] s_immediate = {instruction[31:25], instruction[11:7]};
  wire [19:0] u_immediate = instruction[31:12];

  wire [20:0] j_immediate_u = {instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
  wire [XLEN-1:0] j_immediate = {{XLEN-21{j_immediate_u[20]}}, j_immediate_u[20:0]};

  wire [12:0] b_immediate_u = {instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
  wire [XLEN-1:0] b_immediate = {{XLEN-13{b_immediate_u[12]}}, b_immediate_u[12:0]};

  wire [6:0] opcode = instruction[6:0];
  assign funct3_o = instruction[14:12];
  assign funct7_o = instruction[31:25];

  assign rd_addr_o = instruction[11:7];
  assign rs1_addr_o = instruction[19:15];
  assign rs2_addr_o = instruction[24:20];

  wire [XLEN-1:0] load_offset = {{XLEN-12{i_immediate[11]}}, i_immediate[11:0]};
  // sign_ext #( .XLEN(XLEN), .INPUT_LEN(12) ) SIGN_EXT3 ( .data_i(i_immediate), .data_o(load_offset) );
  wire [XLEN-1:0] load_offset_add = load_offset + rs1_i;
  wire [XLEN-1:0] store_offset = {{XLEN-12{s_immediate[11]}}, s_immediate[11:0]};
  // sign_ext #( .XLEN(XLEN), .INPUT_LEN(12) ) SIGN_EXT4 ( .data_i(s_immediate), .data_o(store_offset) );
  wire [XLEN-1:0] store_offset_add = store_offset + rs1_i;

endmodule

`endif // RV32I_DECODE_GUARD
