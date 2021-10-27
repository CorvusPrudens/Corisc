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

    output wire [REG_BITS-1:0] rs1_addr_o,
    output wire [REG_BITS-1:0] rs2_addr_o,
    output wire [REG_BITS-1:0] rd_addr_o,
    output wire [2:0] funct3_o,
    output wire [6:0] funct7_o,

    output wire registers_write,
    output wire [XLEN-1:0] registers_in_o,
    input wire [XLEN-1:0] alu_out_i,

    output wire [XLEN-1:0] alu_operand2_o,

    input wire [XLEN-1:0] rs1_i,
    input wire [XLEN-1:0] rs2_i,
    input wire [XLEN-1:0] pc_i,

    output reg [XLEN-1:0] pc_o,
    output wire pc_write_o,

    input wire [INST_BITS-1:0] instruction_i,

    output wire memory_read_o,
    output wire memory_write_o
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
  localparam OP_E     = 5'b11100; // EBREAK / ECALL

  reg initial_reset = 0;
  wire [INST_BITS-1:0] instruction_unmixed = {instruction_i[7:0], instruction_i[15:8]};

  reg [5:0] trap_vector = 0;
  wire [31:0] control_vector_raw;
  wire [31:0] control_vector = initial_reset ? control_vector_raw : 32'b0;

  reg [ILEN-1:0] instruction = 0;

  wire [11:0] i_immediate = instruction[31:20];
  wire [11:0] s_immediate = {instruction[31:25], instruction[11:7]};
  wire [19:0] u_immediate = instruction[31:12];

  // wire [11:0] b_immediate = {instruction[31], instruction[7], instruction[30:25], instruction[11:8]};
  // wire [19:0] j_immediate = {instruction[31], instruction[19:12], instruction[20], instruction[30:21]};

  wire [20:0] j_immediate_u = {instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
  wire [XLEN-1:0] j_immediate;

  sign_ext #(
    .XLEN(XLEN),
    .INPUT_LEN(21)
  ) SIGN_EXT1 (
    .data_i(j_immediate_u),
    .data_o(j_immediate)
  );

  wire [12:0] b_immediate_u = {instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
  wire [XLEN-1:0] b_immediate;

  sign_ext #(
    .XLEN(XLEN),
    .INPUT_LEN(13)
  ) SIGN_EXT2 (
    .data_i(b_immediate_u),
    .data_o(b_immediate)
  );

  wire [6:0] opcode = instruction[6:0];
  assign funct3_o = instruction[14:12];
  assign funct7_o = instruction[31:25];

  assign rd_addr_o = instruction[11:7];
  assign rs1_addr_o = instruction[19:15];
  assign rs2_addr_o = instruction[24:20];
  
  assign memory_read_o = control_vector[0];
  assign memory_write_o = control_vector[1];
  
  wire [2:0] mem_addr_src = control_vector[4:2];

  wire [XLEN-1:0] load_offset;
  sign_ext #( .XLEN(XLEN), .INPUT_LEN(12) ) SIGN_EXT3 ( .data_i(i_immediate), .data_o(load_offset) );
  wire [XLEN-1:0] load_offset_add = load_offset + rs1_i;
  wire [XLEN-1:0] store_offset;
  sign_ext #( .XLEN(XLEN), .INPUT_LEN(12) ) SIGN_EXT4 ( .data_i(s_immediate), .data_o(store_offset) );
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
  wire [2:0] word_size_o = word_size_src ? funct3_o : 3'b001;

  reg [XLEN-1:0] immediate_switch;

  wire [1:0] immediate_src = control_vector[7:6];
  always @(*) begin
    case (immediate_src)
      default: immediate_switch = 0;
      2'b00: immediate_switch = load_offset;
      2'b01: immediate_switch = {20'b0, i_immediate};
      2'b10: immediate_switch = {u_immediate, 12'b0};
    endcase
  end

  // assign immediate_o = unsigned_immediate ? {i_immediate} : load_offset;

  // assign increment_pc_o = control_vector[8];
  // assign increment_pc2_o = control_vector[9];

  assign pc_write_o = control_vector[8];

  // We'll use a reg array here to store microinstruction steps
  reg [4:0] microcode_step = 0;
  wire microcode_reset = control_vector[10];

  always @(posedge clk_i) begin
    if (~microcode_reset & initial_reset)
      microcode_step <= microcode_step + 1'b1;
    else if (microcode_reset & initial_reset)
      microcode_step <= 5'b1;
    else
      microcode_step <= 5'b0;
  end

  localparam FETCH_SIZE = 3;
  reg [4:0] operand_offset = 0;

  // for the fetch cycles, the address should
  // always point to the beginning of the memory
  wire [4:0] microcode_mux = microcode_step < FETCH_SIZE ? 
    microcode_step : microcode_step + operand_offset;
  wire [4:0] microcode_addr = microcode_reset ? 5'b0 : microcode_mux;

  init_bram #(
    .memSize_p(5),
    .dataWidth_p(32),
    .initFile_p("microcode.hex")
  ) INIT_BRAM (
    .clk_i(clk_i),
    .write_i(1'b0),
    // TODO -- This isn't an ideal solution... we need to figure out how to solve the 
    // two-clock same-instruction issue we get at the beginning without this
    // initial read hack
    .read_i(initial_reset),
    .data_i(0),
    .waddr_i(0),
    .raddr_i(microcode_addr),
    .data_o(control_vector_raw)
  );

  wire write_lower_instr = control_vector[11];
  wire write_upper_instr = control_vector[12];

  always @(posedge clk_i) begin
    if (write_lower_instr)
      instruction[15:0] <= instruction_unmixed;
    if (write_upper_instr)
      instruction[31:16] <= instruction_unmixed;
  end

  // TODO -- need to fill this in with the
  // actual sizes ofc
  always @(posedge clk_i) begin
    if (write_lower_instr) begin
      case (instruction_unmixed[6:2])
          OP_L:     
            begin
              case (funct3_o[1:0])
                default: operand_offset <= 0;
                2'b01: operand_offset <= 2;
                2'b10: operand_offset <= 4;
              endcase 
            end
          OP_FENCE: operand_offset <= 7;
          OP_AI:    operand_offset <= 8;
          OP_AUIPC: operand_offset <= 9;
          OP_S:     operand_offset <= 10;
          OP_A:     operand_offset <= 11;
          OP_LUI:   operand_offset <= 12;
          OP_B:     operand_offset <= 13;
          OP_JALR:  operand_offset <= 14;
          OP_JAL:   operand_offset <= 15;
          OP_E:     operand_offset <= 16;
          default:  operand_offset <= 16;
      endcase
    end
  end

  wire registers_input_imm = control_vector[13];
  wire add_pc_upper = control_vector[16];

  wire [XLEN-1:0] upper_immediate = add_pc_upper ? {u_immediate, 12'b0} + pc_i - 32'd4 : {u_immediate, 12'b0};
  assign registers_in_o = registers_input_imm ? upper_immediate : alu_out_i;

  wire alu_op2_immediate = control_vector[14];
  wire [XLEN-1:0] op2_immediate = funct3_o == 3'b011 ? {20'b0, i_immediate} : load_offset;
  assign alu_operand2_o = alu_op2_immediate ? op2_immediate : rs2_i;

  assign registers_write = control_vector[15];
  wire [2:0] pc_src = control_vector[19:17];

  wire [XLEN-1:0] j_reg = load_offset + rs1_i;
  wire [XLEN-1:0] instruction_addr = (pc_i - 32'd4);

  always @(*) begin
    case (pc_src)
      default: pc_o = pc_i + (INST_BITS / 8);
      3'b001: pc_o = j_immediate + instruction_addr;
      3'b010: pc_o = {j_reg[XLEN-1:1], 1'b0};
      3'b100: pc_o = b_immediate + instruction_addr;
    endcase
  end

  wire register_input_pc = control_vector[20];
  wire load_byte = control_vector[21];
  wire load_half = control_vector[22];
  wire store_byte = control_vector[23];
  wire store_half = control_vector[24];
  wire add_mem_addr = control_vector[25];

  // TODO -- the intial reset should probably also hold the control vector to zero
  reg [2:0] reset_delay = 0;
  always @(posedge clk_i) begin
    if (~reset_delay[2])
      reset_delay <= reset_delay + 1'b1;
    else begin
      if (reset_i) begin
        initial_reset <= 1'b0;
        reset_delay <= 3'b0;
      end else
        initial_reset <= 1'b1;
    end
  end

endmodule

`endif // RV32I_CONTROL_GUARD
