`ifndef RV32I_CONTROL_GUARD
`define RV32I_CONTROL_GUARD

// TODO -- we could make a little baby instruction prefetch that just grabs one
// of the two next instruction bytes so that the fetch is only one cycle O.O
// This ^ would work on every instruction that's not a jump or load / store, speeding
// up execution by literally 50%!!!

`include "bram_init.v"

module rv32i_control
  #(
    XLEN = 32,
    ILEN = 32,
    REG_BITS = 5,
    INST_BITS = 16,
    INITIAL_ADDR = 32'h0,
    MICRO_CODE = "microcode.hex",
    INT_VECT_LEN = 5
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
    output reg [XLEN-1:0] registers_in_o,
    input wire [XLEN-1:0] alu_out_i,

    output wire [XLEN-1:0] alu_operand2_o,

    input wire [XLEN-1:0] rs1_i,
    input wire [XLEN-1:0] rs2_i,
    input wire [XLEN-1:0] pc_i,

    input wire alu_equal_i,
    input wire alu_less_i,
    input wire alu_less_signed_i,

    output reg [XLEN-1:0] pc_o,
    output reg pc_write_o,

    input wire [INST_BITS-1:0] memory_i,

    output wire memory_read_o,
    output wire memory_write_o,
    output reg [INST_BITS-1:0] memory_write_mask_o,
    output reg [INST_BITS-1:0] memory_o,
    output wire immediate_arithmetic_o,

    output reg push_ras_o,
    output reg pop_ras_o
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

  // TODO -- need to get exception support in here at some point
  reg [5:0] trap_vector = 0;

  localparam 
  reg [INT_VECT_LEN-1:0] interrupt_vector = 0;
  reg [INT_VECT_LEN-1:0] interrupt_mask = 0;

  wire [INT_VECT_LEN-1:0] interrupt_vector_lowest = 0;

  

  wire [31:0] control_vector_raw;
  wire [31:0] control_vector = initial_reset ? control_vector_raw : 32'b0;

  // The ~clk_i helps prevent glitching as addresses etc settle
  assign memory_read_o = control_vector[0] & ~clk_i;
  assign memory_write_o = control_vector[1] & ~clk_i;
  wire [2:0] mem_addr_src = control_vector[4:2];
  wire word_size_src = control_vector[5];
  wire [1:0] immediate_src = control_vector[7:6];
  wire pc_write = control_vector[8];
  wire microcode_reset = control_vector[10];
  wire write_lower_instr = control_vector[11];
  wire write_upper_instr = control_vector[12];
  wire registers_input_imm = control_vector[13];
  wire add_pc_upper = control_vector[16];
  wire alu_op2_immediate = control_vector[14];
  assign immediate_arithmetic_o = alu_op2_immediate;
  assign registers_write = control_vector[15];
  wire [3:0] pc_src = {~initial_reset, control_vector[19:17]};
  wire register_input_pc = control_vector[20];
  wire load_byte = control_vector[21];
  wire load_half = control_vector[27];
  wire load_word = control_vector[22];
  wire store_byte = control_vector[23];
  wire store_upper = control_vector[24];
  wire add_mem_addr = control_vector[25];
  wire build_temp = control_vector[26];
  wire cond_write_pc = control_vector[28];
  wire jal_ras = control_vector[29];
  wire jalr_ras = control_vector[30];

  reg initial_reset = 0;

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

  wire [XLEN-1:0] load_offset;
  sign_ext #( .XLEN(XLEN), .INPUT_LEN(12) ) SIGN_EXT3 ( .data_i(i_immediate), .data_o(load_offset) );
  wire [XLEN-1:0] load_offset_add = load_offset + rs1_i;
  wire [XLEN-1:0] store_offset;
  sign_ext #( .XLEN(XLEN), .INPUT_LEN(12) ) SIGN_EXT4 ( .data_i(s_immediate), .data_o(store_offset) );
  wire [XLEN-1:0] store_offset_add = store_offset + rs1_i;

  always @(*) begin
    case (mem_addr_src)
      default: memory_addr_o = {INITIAL_ADDR[31:2], reset_delay[0], 1'b0}; // for reading the entry point
      3'b001: memory_addr_o = program_counter_i;
      3'b010: memory_addr_o = add_mem_addr ? load_offset_add + 32'd2 : load_offset_add;
      3'b100: memory_addr_o = add_mem_addr ? store_offset_add + 32'd2 : store_offset_add;
    endcase 
  end

  // Not sure whether this will actually be used, since the
  // memory handling should all be handled in the micro code
  // (might be useful for detecting errors tho)
  
  wire [2:0] word_size_o = word_size_src ? funct3_o : 3'b001;

  reg [XLEN-1:0] immediate_switch;
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

  // assign pc_write_o = control_vector[8];

  // We'll use a reg array here to store microinstruction steps
  reg [4:0] microcode_step = 0;

  always @(posedge clk_i) begin
    if (~microcode_reset & initial_reset)
      microcode_step <= microcode_step + 1'b1;
    else
      microcode_step <= 5'b0;
  end

  localparam FETCH_SIZE = 2;
  reg [4:0] operand_offset = 0;

  // for the fetch cycles, the address should
  // always point to the beginning of the memory
  wire [4:0] microcode_mux = microcode_step < FETCH_SIZE ? 
    microcode_step : microcode_step + operand_offset;
  wire [4:0] microcode_addr = microcode_mux;

  bram_init #(
    .memSize_p(5),
    .dataWidth_p(32),
    .initFile_p(MICRO_CODE)
  ) INIT_BRAM (
    .clk_i(clk_i),
    .write_i(1'b0),
    .data_i(0),
    .addr_i(microcode_addr),
    .data_o(control_vector_raw)
  );

  always @(posedge clk_i) begin
    if (write_lower_instr)
      instruction[15:0] <= memory_i;
    if (write_upper_instr)
      instruction[31:16] <= memory_i;
  end

  always @(posedge clk_i) begin
    if (write_lower_instr) begin
      case (memory_i[6:2])
          OP_L:     
            begin
              case (memory_i[13:12])
                default: operand_offset <= 0;
                2'b01: operand_offset <= 1;
                2'b10: operand_offset <= 2;
              endcase 
            end
          OP_FENCE: operand_offset <= 4;
          OP_AI:    operand_offset <= 5;
          OP_AUIPC: operand_offset <= 6;
          OP_S:
            begin
              case (memory_i[13:12])
                default: operand_offset <= 7;
                2'b01: operand_offset <= 8;
                2'b10: operand_offset <= 9;
              endcase 
            end
          OP_A:     operand_offset <= 11;
          OP_LUI:   operand_offset <= 12;
          OP_B:     operand_offset <= 13;
          OP_JALR:  operand_offset <= 14;
          OP_JAL:   operand_offset <= 15;
          OP_SYS:   operand_offset <= 16; // TODO I know I know, non-compliant... but we'll always assume this is an mret
          default:  operand_offset <= 4; // simple nop
      endcase
    end
  end

  wire [XLEN-1:0] upper_immediate = add_pc_upper ? {u_immediate, 12'b0} + pc_i - 32'd4 : {u_immediate, 12'b0};

  wire [2:0] registers_in_state = {register_input_pc, (load_word | load_half | load_byte), registers_input_imm};
  always @(*) begin
    case (registers_in_state)
      default: registers_in_o = alu_out_i;
      3'b001: registers_in_o = upper_immediate;
      3'b010: registers_in_o = load_mux;
      3'b100: registers_in_o = pc_i;
    endcase
  end

  wire [XLEN-1:0] op2_immediate = funct3_o == 3'b011 ? {20'b0, i_immediate} : load_offset;
  assign alu_operand2_o = alu_op2_immediate ? op2_immediate : rs2_i;

  wire [XLEN-1:0] j_reg = load_offset + rs1_i;
  wire [XLEN-1:0] instruction_addr = (pc_i - 32'd4);

  always @(*) begin
    case (pc_src)
      default: pc_o = pc_i + (INST_BITS / 8);
      4'b0001: pc_o = j_immediate + instruction_addr;
      4'b0010: pc_o = {j_reg[XLEN-1:1], 1'b0};
      4'b0100: pc_o = b_immediate + instruction_addr;
      4'b1000: pc_o = reset_delay[0] ? {memory_i, pc_i[15:0]} : {pc_i[31:16], memory_i};
    endcase
  end

  reg [XLEN-1:0] load_mux;
  reg [INST_BITS-1:0] load_temp = 0;

  always @(posedge clk_i) begin
    if (build_temp) load_temp <= memory_i;
  end

  wire [7:0] byte_offset = memory_addr_o[0] ? memory_i[15:8] : memory_i[7:0];
  wire [XLEN-1:0] signed_byte;
  sign_ext #( .XLEN(XLEN), .INPUT_LEN(8) ) SIGN_EXT5 ( .data_i(byte_offset), .data_o(signed_byte) );
  wire [XLEN-1:0] byte_mux = funct3_o[2] ? {24'b0, byte_offset} : signed_byte;

  wire [XLEN-1:0] memory_signed;
  sign_ext #( .XLEN(XLEN), .INPUT_LEN(16) ) SIGN_EXT6 ( .data_i(memory_i), .data_o(memory_signed) );

  wire [1:0] load_state = {load_byte, load_word};
  always @(*) begin
    case (load_state)
      default: load_mux = funct3_o[2] ? {16'b0, memory_i} : memory_signed;
      2'b01: load_mux = {memory_i, load_temp};
      2'b10: load_mux = byte_mux;
    endcase
  end

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

  wire [1:0] mask_state = {memory_addr_o[0], store_byte};
  always @(*) begin
    case (mask_state)
      default: memory_write_mask_o = 16'h0;
      2'b01: memory_write_mask_o = 16'hFF00;
      2'b11: memory_write_mask_o = 16'h00FF;
    endcase
  end 

  wire [1:0] store_state = {store_upper, store_byte};
  always @(*) begin
    case (store_state)
      default: memory_o = rs2_i[15:0];
      2'b01: memory_o = memory_addr_o[0] ?  {rs2_i[7:0], 8'b0} : {8'b0, rs2_i[7:0]};
      2'b10: memory_o = {rs2_i[23:16], rs2_i[31:24]};
    endcase
  end 

  always @(*) begin
    case ({cond_write_pc, funct3_o})
      default: pc_write_o = pc_write | ~initial_reset;
      4'b1000: pc_write_o = alu_equal_i;
      4'b1001: pc_write_o = ~alu_equal_i;
      4'b1100: pc_write_o = alu_less_signed_i;
      4'b1101: pc_write_o = ~alu_less_signed_i;
      4'b1110: pc_write_o = alu_less_i;
      4'b1111: pc_write_o = ~alu_less_i;
    endcase
  end

  localparam x1 = 5'h01;
  localparam x5 = 5'h05;

  wire rd_link = (rd_addr_o == x1) | (rd_addr_o == x5);
  wire rs1_link = (rs1_addr_o == x1) | (rs1_addr_o == x5);
  wire rd_rs1_eq = rd_addr_o == rs1_addr_o;

  always @(*) begin
    case ({rd_link & (jal_ras | jalr_ras), rs1_link & jalr_ras})
      default: 
        begin
          pop_ras_o = 1'b0;
          push_ras_o = 1'b0;
        end
      2'b01: 
        begin
          pop_ras_o = 1'b1;
          push_ras_o = 1'b0;
        end
      2'b10:
        begin
          pop_ras_o = 1'b0;
          push_ras_o = 1'b1;
        end
      2'b11:
        begin
          pop_ras_o = rd_rs1_eq ? 1'b1 : 1'b0;
          push_ras_o = 1'b1;
        end
    endcase
  end

endmodule

`endif // RV32I_CONTROL_GUARD
