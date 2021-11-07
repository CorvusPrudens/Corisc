`ifndef RV32I_PREFETCH_GUARD
`define RV32I_PREFETCH_GUARD

module rv32i_prefetch
  #(
    parameter XLEN = 32,
    parameter ILEN = 32,
    parameter VTABLE_ADDR = 32'h00000000,
    parameter PROGRAM_PATH = "program.hex"
  )
  (
    input wire clk_i,
    input wire clear_i,
    input wire reset_i,
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
    if (reset_i) begin
      program_counter <= VTABLE_ADDR;
    end else if (advance_i) begin
      if (pc_write_i) begin
        instruction_o <= memory[pc_i[6:2]];
        pc_o <= pc_i;
        program_counter <= pc_i + 32'b100;
      end else begin
        instruction_o <= memory[program_counter[6:2]];
        pc_o <= program_counter;
        program_counter <= program_counter + 32'b100;
      end
    end
  end

endmodule

`endif // RV32I_PREFETCH_GUARD
