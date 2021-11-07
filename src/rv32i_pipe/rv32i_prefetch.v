`ifndef RV32I_PREFETCH_GUARD
`define RV32I_PREFETCH_GUARD

module rv32i_prefetch
  #(
    XLEN = 32,
    ILEN = 32,
    PROGRAM_PATH = "program.hex"
  )
  (
    input wire clk_i,
    input wire advance_i,
    input wire [XLEN-1:0] pc_i,
    input wire pc_write_i,
    output reg [XLEN-1:0] pc_o,
    output reg [XLEN-1:0] instruction_o
  );

  reg [ILEN-1:0] memory [31:0];
  initial $readmemh(PROGRAM_PATH, memory);

  reg [XLEN-1:0] program_counter = 0;

  always @(posedge clk_i) begin
    if (advance_i) begin
      if (pc_write_i) begin
        instruction_o <= memory[pc_i[6:2]];
        pc_o <= pc_i;
        program_counter <= pc_i + 3'b100;
      end else begin
        instruction_o <= memory[program_counter[6:2]];
        pc_o <= program_counter;
        program_counter <= program_counter + 3'b100;
      end
    end
  end

endmodule

`endif // RV32I_PREFETCH_GUARD