`ifndef RV32IM_DECODE_GUARD
`define RV32IM_DECODE_GUARD

module rv32im_decode 
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
    output reg immediate_valid_o,

    input wire [XLEN-1:0] pc_data_i,
    output reg [XLEN-1:0] pc_data_o,

    input wire interrupt_trigger_i,
    output reg mret_o,
    output reg [XLEN-1:0] uepc_o,

    output reg jal_jump_o,
    output reg [XLEN-1:0] pc_jal_data_o,

    output reg jalr_o,
    output reg branch_o,
    output reg [2:0] branch_condition_o,
    input wire clear_branch_stall_i,

    output reg link_o,
    output reg [XLEN-1:0] link_data_o,

    output reg pop_ras_o,
    output reg push_ras_o,

    output reg [2:0] stage4_path_o,
    output reg memory_write_o,

    output reg processing_jump
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
  wire [2:0] funct3 = instruction_i[14:12];
  wire [6:0] funct7 = instruction_i[31:25];

  wire [REG_BITS-1:0] rd_addr = instruction_i[11:7];
  wire [REG_BITS-1:0] rs1_addr = instruction_i[19:15];
  wire [REG_BITS-1:0] rs2_addr = instruction_i[24:20];

  wire [XLEN-1:0] load_offset = {{XLEN-12{i_immediate[11]}}, i_immediate[11:0]};
  // wire [XLEN-1:0] load_offset_add = load_offset + rs1_i;
  wire [XLEN-1:0] store_offset = {{XLEN-12{s_immediate[11]}}, s_immediate[11:0]};
  // wire [XLEN-1:0] store_offset_add = store_offset + rs1_i;

  wire [XLEN-1:0] op2_immediate = funct3 == 3'b011 ? {20'b0, i_immediate} : load_offset;

  localparam LINK_REGISTER = 5'h01;
  localparam LINK_REGISTER_ALT = 5'h05;

  wire rd_link = (rd_addr == LINK_REGISTER) | (rd_addr == LINK_REGISTER_ALT);
  wire rs1_link = (rs1_addr == LINK_REGISTER) | (rs1_addr == LINK_REGISTER_ALT);
  wire rd_rs1_eq = rd_addr == rs1_addr;

  reg  push_ras;
  initial push_ras = 0;
  reg  pop_ras;
  initial pop_ras = 0;

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

  // Difference between AUIPC and LUI is bit 5
  wire [XLEN-1:0] upper_immediate = opcode[5] ? {u_immediate, 12'b0} : {u_immediate, 12'b0} + pc_data_i;

  initial uepc_o = 0;
  always @(posedge clk_i)
    if (interrupt_trigger_i)
      uepc_o <= pc_data_i;

  reg [5:0] instruction_encoding;
  initial instruction_encoding = 0;
  localparam R_TYPE = 6'b000001; // Register-register operations
  localparam I_TYPE = 6'b000010; // Immediate operations
  localparam S_TYPE = 6'b000100; // Stores
  localparam U_TYPE = 6'b001000; // Upper immediates
  localparam B_TYPE = 6'b010000; // Branches
  localparam J_TYPE = 6'b100000; // Jumps

  localparam STAGE4_ALU = 3'b001;
  localparam STAGE4_MEM = 3'b010;
  localparam STAGE4_MUL = 3'b100;

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

  // TODO -- this is all sorts of buggy
  always @(*) begin
    case (opcode[6:2])
      default: processing_jump = 0;
      OP_JAL: processing_jump = 1;
      OP_JALR: processing_jump = 1;
      OP_B: processing_jump = 1;
      OP_SYS: processing_jump = 1;
    endcase
  end

  always @(posedge clk_i) begin

    if (clear_i) begin
      immediate_valid_o <= 1'b0;
      jal_jump_o <= 1'b0;
      jalr_o <= 1'b0;
      branch_o <= 1'b0;
      branch_condition_o <= 3'b0;
      memory_write_o <= 1'b0;
      link_o <= 1'b0;
      mret_o <= 1'b0;
    end else if (data_ready_i) begin

      pop_ras_o <= pop_ras;
      push_ras_o <= push_ras;

      pc_data_o <= pc_data_i;

      if (instruction_encoding == R_TYPE | instruction_encoding == B_TYPE)
        immediate_valid_o <= 1'b0;
      else
        immediate_valid_o <= 1'b1;

      // This one we do have to be careful about resetting, since the branch is conditional
      if (instruction_encoding == B_TYPE)
        branch_o <= 1'b1;
      else
        branch_o <= 1'b0;

      if (opcode[6:2] == OP_S)
        memory_write_o <= 1'b1;
      else
        memory_write_o <= 1'b0;

      if (opcode[6:2] == OP_S | opcode[6:2] == OP_L)
        stage4_path_o <= STAGE4_MEM;
      else if (opcode[6:2] == OP_A & funct7[0])
        stage4_path_o <= STAGE4_MUL;
      else
        stage4_path_o <= STAGE4_ALU;

      if (opcode[6:2] == OP_JAL | opcode[6:2] == OP_JALR)
        link_o <= 1'b1;
      else
        link_o <= 1'b0;

      if (opcode[6:2] == OP_SYS)
        mret_o <= 1'b1;
      else
        mret_o <= 1'b0;

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
            alu_operation_o <= {funct7[5] & (opcode[6:2] == OP_A), funct3};
          end
        I_TYPE:
          begin
            rs1_addr_o <= rs1_addr;
            rs2_addr_o <= 0;
            rd_addr_o <= rd_addr;
            // Immediates are always sign-extended
            immediate_o <= load_offset;
            word_size_o <= funct3;

            // One bit is needed to distinguish between JALR/MRET and L/AI
            if (opcode[5]) begin
              jalr_o <= 1'b1; // no need to reset because this will be cleared
              alu_operation_o <= 4'b0000;
              link_data_o <= pc_data_i + 32'h04;
            end else begin
              alu_operation_o <= {funct7[5] & (funct3 == 3'b101), funct3};
            end
            
          end
        S_TYPE:
          begin
            rs1_addr_o <= rs1_addr;
            rs2_addr_o <= rs2_addr;
            rd_addr_o <= 0;
            immediate_o <= store_offset;
            word_size_o <= funct3;
          end
        U_TYPE:
          begin
            rs1_addr_o <= 0;
            rs2_addr_o <= 0;
            rd_addr_o <= rd_addr;
            alu_operation_o <= 4'b0000;
            // Difference between AUIPC and LUI is bit 5
            immediate_o <= upper_immediate;
          end
        J_TYPE:
          begin
            rs1_addr_o <= 0;
            rs2_addr_o <= 0;
            rd_addr_o <= rd_addr;
            jal_jump_o <= 1'b1;
            pc_jal_data_o <= j_immediate + pc_data_i;
            link_data_o <= pc_data_i + 32'h04;
          end
        B_TYPE:
          begin
            rs1_addr_o <= rs1_addr;
            rs2_addr_o <= rs2_addr;
            rd_addr_o <= 0;
            immediate_o <= b_immediate; 
            alu_operation_o <= 4'b0000;
            branch_condition_o <= funct3;
          end
      endcase

    end else if (clear_branch_stall_i) 
      branch_o <= 1'b0;
  end

  `ifdef FORMAL

    reg  timeValid_f;
    initial timeValid_f = 0;
    always @(posedge clk_i) timeValid_f <= 1;

    always @(*)
      assume(clear_i == ~timeValid_f);

    always @(posedge clk_i) begin

      // just a sanity check clear test
      if (timeValid_f & $past(timeValid_f) & $past(clear_i)) begin
        assert(immediate_valid_o == 1'b0);
        assert(jal_jump_o == 1'b0);
        assert(jalr_o == 1'b0);
        assert(branch_o == 1'b0);
        assert(branch_condition_o == 3'b0);
        assert(memory_write_o == 1'b0);
        assert(link_o == 1'b0);
        assert(mret_o == 1'b0);
      end

      if (timeValid_f & $past(timeValid_f) & $past(data_ready_i)) begin
        
      end

    end

  `endif

endmodule

`endif // RV32IM_DECODE_GUARD
