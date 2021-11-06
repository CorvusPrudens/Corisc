`ifndef RV32I_DECODE_GUARD
`define RV32I_DECODE_GUARD

module rv32i_decode 
  #(
    parameter XLEN = 32,
    parameter ILEN = 32,
    parameter REG_BITS = 5
  )
  (
    input wire clk_i,
    input wire clear_i,
    input wire [XLEN-1:0] instruction_i,
    input wire data_ready_i,

    output reg [3:0] alu_operation_o,
    output reg [2:0] word_size_o,

    output reg [REG_BITS-1:0] rs1_addr_o,
    output reg [REG_BITS-1:0] rs2_addr_o,
    output reg [REG_BITS-1:0] rd_addr_o,

    output reg [XLEN-1:0] immediate_o,

    input wire [XLEN-1:0] pc_data_in,
    output reg [XLEN-1:0] pc_data_o
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

  wire [11:0] i_immediate = instruction_i[31:20];
  wire [11:0] s_immediate = {instruction_i[31:25], instruction_i[11:7]};
  wire [19:0] u_immediate = instruction_i[31:12];

  wire [20:0] j_immediate_u = {instruction_i[31], instruction_i[19:12], instruction_i[20], instruction_i[30:21], 1'b0};
  wire [XLEN-1:0] j_immediate = {{XLEN-21{j_immediate_u[20]}}, j_immediate_u[20:0]};

  wire [12:0] b_immediate_u = {instruction_i[31], instruction_i[7], instruction_i[30:25], instruction_i[11:8], 1'b0};
  wire [XLEN-1:0] b_immediate = {{XLEN-13{b_immediate_u[12]}}, b_immediate_u[12:0]};

  wire [6:0] opcode = instruction_i[6:0];
  assign funct3 = instruction_i[14:12];
  assign funct7 = instruction_i[31:25];

  assign rd_addr = instruction_i[11:7];
  assign rs1_addr = instruction_i[19:15];
  assign rs2_addr = instruction_i[24:20];

  wire [XLEN-1:0] load_offset = {{XLEN-12{i_immediate[11]}}, i_immediate[11:0]};
  wire [XLEN-1:0] load_offset_add = load_offset + rs1_i;
  wire [XLEN-1:0] store_offset = {{XLEN-12{s_immediate[11]}}, s_immediate[11:0]};
  wire [XLEN-1:0] store_offset_add = store_offset + rs1_i;

  wire [XLEN-1:0] op2_immediate = funct3_o == 3'b011 ? {20'b0, i_immediate} : load_offset;

  localparam LINK_REGISTER = 5'h01;
  localparam LINK_REGISTER_ALT = 5'h05;

  wire rd_link = (rd_addr_o == LINK_REGISTER) | (rd_addr_o == LINK_REGISTER_ALT);
  wire rs1_link = (rs1_addr_o == LINK_REGISTER) | (rs1_addr_o == LINK_REGISTER_ALT);
  wire rd_rs1_eq = rd_addr_o == rs1_addr_o;

  reg push_ras;
  reg pop_ras;

  wire jal_ras = (opcode[6:2] == OP_JAL);
  wire jalr_ras = (opcode[6:2] == OP_JALR);

  always @(*) begin
    case ({rd_link & (jal_ras | jalr_ras), rs1_link & jalr_ras})
      default: 
        begin
          pop_ras = 1'b0;
          push_ras = 1'b0;
        end
      2'b01: 
        begin
          pop_ras = 1'b1;
          push_ras = 1'b0;
        end
      2'b10:
        begin
          pop_ras = 1'b0;
          push_ras = 1'b1;
        end
      2'b11:
        begin
          pop_ras = rd_rs1_eq ? 1'b1 : 1'b0;
          push_ras = 1'b1;
        end
    endcase
  end

  always @(*) begin
    case (opcode[6:2])
      default: pc_o = pc_i + (INST_BITS / 8);
      OP_JAL:  pc_o = j_immediate + instruction_addr;
      OP_JALR: pc_o = pop_ras ? ras : {j_reg[XLEN-1:1], 1'b0}; // naturally, jalr and b values / writes will be determined later
      OP_B:    pc_o = b_immediate + instruction_addr;
      6'b010000: pc_o = pc_save_uepc ? {pc_i[31:16], memory_i} : {memory_i, pc_i[15:0]};
      OP_SYS: pc_o = uepc;
    endcase
  end

  reg assert_rs1;
  reg assert_rs2;
  reg assert_rd;

  reg [5:0] instruction_encoding;
  localparam R_TYPE = 6'b000001; // Register-register operations
  localparam I_TYPE = 6'b000010; // Immediate operations
  localparam S_TYPE = 6'b000100; // Stores
  localparam U_TYPE = 6'b001000; // Upper immediates
  localparam B_TYPE = 6'b010000; // Branches
  localparam J_TYPE = 6'b100000; // Jumps

  always @(*) begin
    case (opcode[6:2])
      default:  instruction_encoding = 0;
      OP_L:     instruction_encoding = I_TYPE;
      // OP_FENCE: instruction_encoding = N_TYPE;
      OP_AI:    instruction_encoding = I_TYPE; // arithmetic immediate
      OP_AUIPC: instruction_encoding = U_TYPE;
      OP_S:     instruction_encoding = S_TYPE;
      OP_A:     instruction_encoding = R_TYPE; // arithmetic 
      OP_LUI:   instruction_encoding = U_TYPE;
      OP_B:     instruction_encoding = B_TYPE;
      OP_JALR:  instruction_encoding = I_TYPE;
      OP_JAL:   instruction_encoding = J_TYPE;
      OP_SYS:   instruction_encoding = I_TYPE;
    endcase
  end

  always @(posedge clk_i) begin
    if (data_ready_i) begin

      alu_operation_o <= {funct7[5] & (opcode[6:2] == OP_A), funct3}

      pop_ras_o <= pop_ras;
      push_ras_o <= push_ras;

      pc_data_o <= pc_data_in;

      // determining whether the register addresses should be asserted
      case (instruction_encoding) 
        default: 
          begin
            rs1_addr_o <= 0;
            rs2_addr_o <= 0;
            rd_addr_o <= 0;
          end
        R_TYPE:
          begin
            rs1_addr_o <= rs1_addr;
            rs2_addr_o <= rs2_addr;
            rd_addr_o <= rd_addr;
          end
        I_TYPE:
          begin
            rs1_addr_o <= rs1_addr;
            rs2_addr_o <= 0;
            rd_addr_o <= rd_addr;
            immediate_o <= i_immediate;
          end
        S_TYPE:
          begin
            rs1_addr_o <= rs1_addr;
            rs2_addr_o <= rs2_addr;
            rd_addr_o <= 0;
            immediate_o <= s_immediate;
          end
        U_TYPE:
          begin
            rs1_addr_o <= 0;
            rs2_addr_o <= 0;
            rd_addr_o <= rd_addr;
            // Difference between AUIPC and LUI is bit 5
            immediate_o <= opcode[5] ? u_immediate : pc_data_in + u_immediate;
          end
        J_TYPE:
          begin
            rs1_addr_o <= 0;
            rs2_addr_o <= 0;
            rd_addr_o <= rd_addr;
            // j immediate is just added to PC, and we'll jump immediately from here, 
            // so this doesn't need to be set
            // immediate_o <= j_immediate; 
          end
        B_TYPE:
          begin
            rs1_addr_o <= rs1_addr;
            rs2_addr_o <= rs2_addr;
            rd_addr_o <= 0;
            immediate_o <= b_immediate; 
          end
      endcase

    end
  end

endmodule

`endif // RV32I_DECODE_GUARD
