`ifndef RV32I_CONTROL_GUARD
`define RV32I_CONTROL_GUARD

module rv32i_control
  #(
    XLEN = 32,
    ILEN = 32,
    REG_BITS = 5,
    INST_BITS = 16
  )
  (
    input wire clk_i,
    input wire reset_i,

    input wire [XLEN-1:0] program_counter_i,

    output reg [XLEN-1:0] memory_addr_o,
    output wire [2:0] word_size_o,

    output wire [REG_BITS-1:0] rs1_addr_o,
    output wire [REG_BITS-1:0] rs2_addr_o,
    output wire [REG_BITS-1:0] rd_addr_o,
    output wire [2:0] funct3_o,
    output wire [6:0] funct7_o,

    output wire [XLEN-1:0] immediate_o,

    input wire [XLEN-1:0] rs1_i,
    input wire [XLEN-1:0] rs2_i,

    input wire [INST_BITS-1:0] instruction_i,

    output wire memory_read_o,
    output wire memory_write_o,

    output wire increment_pc_o,
    output wire increment_pc2_o

  );

  localparam OP_LUI   = 7'b0110111;
  localparam OP_AUIPC = 7'b0010111;
  localparam OP_JAL   = 7'b1101111;
  localparam OP_JALR  = 7'b1100111;
  localparam OP_B     = 7'b1100011;
  localparam OP_L     = 7'b0000011;
  localparam OP_S     = 7'b0100011;
  localparam OP_AI    = 7'b0010011; // arithmetic immediate
  localparam OP_A     = 7'b0110011; // arithmetic 
  localparam OP_FENCE = 7'b0001111;
  localparam OP_E     = 7'b1110011; // EBREAK / ECALL

  reg [5:0] trap_vector = 0;
  wire [15:0] control_vector;

  reg [ILEN-1:0] instruction = 0;

  wire [11:0] i_immediate = instruction[31:20];
  wire [11:0] s_immediate = {instruction[31:25], instruction[11:7]};
  wire [19:0] u_immediate = instruction[31:12];

  wire [11:0] b_immediate = {instruction[31], instruction[7], instruction[30:25], instruction[11:8]};
  wire [19:0] j_immediate = {instruction[31], instruction[19:12], instruction[20], instruction[30:21]};

  wire [6:0] opcode = instruction[6:0];
  funct3_o = instruction[14:12];
  funct7_o = instruction[31:25];

  assign rd_addr_o = instruction[11:7];
  assign rs1_addr_o = instruction[19:15];
  assign rs2_addr_o = instruction[24:20];
  
  assign memory_read_o = control_vector[0];
  assign memory_write_o = control_vector[1];
  
  wire [2:0] mem_addr_src = control_vector[4:2];

  wire [XLEN-1:0] load_offset;
  sign_ext #( .XLEN(XLEN), .INPUT_LEN(12) ) SIGN_EXT ( .data_i(i_immediate), .data_o(load_offset) );
  wire [XLEN-1:0] load_offset_add = load_offset + rs1_i;
  wire [XLEN-1:0] store_offset;
  sign_ext #( .XLEN(XLEN), .INPUT_LEN(12) ) SIGN_EXT ( .data_i(s_immediate), .data_o(store_offset) );
  wire [XLEN-1:0] store_offset_add = store_offset + rs1_i;

  always @(*) begin
    case (mem_addr_src)
      default: memory_addr_o = 0;
      3'b001: memory_addr_o = program_counter_i;
      3'b010: memory_addr_o = load_offset_add;
      3'b100: memory_addr_o = store_offset_add;
    endcase 
  end

  // Not sure whether this will actually be used, since the
  // memory handling should all be handled in the micro code
  // (might be useful for detecting errors tho)
  wire word_size_src = control_vector[5];
  assign word_size_o = word_size_src ? funct3_o : 0b001;

  wire immediate_src = control_vector[7:6];
  always @(*) begin
    case (immediate_src)
      default: immediate_o = 0;
      2'b00: immediate_o = load_offset;
      2'b01: immediate_o = {20'b0, i_immediate};
      2'b10: immediate_o = {u_immediate, 12'b0};
    endcase
  end
  assign immediate_o = unsigned_immediate ? {i_immediate} : load_offset;

  assign increment_pc_o = control_vector[8];
  assign increment_pc2_o = control_vector[9];

  // We'll use a reg array here to store microinstruction steps
  reg [3:0] microcode_step = 0;
  wire microcode_reset = control_vector[10];

  always @(posedge clk_i) begin
    if (~microcode_reset)
      microcode_step <= microcode_step + 1'b1;
    else
      microcode_step <= 4'b0;
  end

  // for the fetch cycles, the address should
  // always point to the beginning of the memory,
  // so some logic is needed (e.g. if (microcode_step < 3) then microcde_addr is just the step)
  reg [9:0] microcode_addr = 0;
  init_bram #(
    .memSize_p(10),
    .dataWidth_p(16),
    .initFile_p("microcode.hex")
  ) INIT_BRAM (
    .clk_i(clk_i),
    .write_i(1'b0),
    .read_i(1'b1),
    .data_i(0),
    .waddr_i(0),
    .raddr_i(microcode_addr),
    .data_o(control_vector)
  );

endmodule

`endif // RV32I_CONTROL_GUARD
