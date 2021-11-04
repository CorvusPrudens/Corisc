`ifndef RV32I_MICROCODE_GUARD
`define RV32I_MICROCODE_GUARD

module rv32i_microcode
  (
    input wire clk_i,
    input wire [4:0] microcode_addr_i,
    output reg [31:0] microcode_o
  );

  always @(*) begin
    case (microcode_addr_i)
      default: microcode_o = 32'h0;
      // fetch (offset: 0 words)
      6'h00: microcode_o = 32'h00000905;
      6'h01: microcode_o = 32'h00001105;
      // op_lb (offset: 0 words)
      6'h02: microcode_o = 32'h00000000;
      6'h03: microcode_o = 32'h00208409;
      // op_lh (offset: 2 words)
      6'h04: microcode_o = 32'h00000000;
      6'h05: microcode_o = 32'h08008409;
      // op_lw (offset: 4 words)
      6'h06: microcode_o = 32'h00000000;
      6'h07: microcode_o = 32'h04000009;
      6'h08: microcode_o = 32'h02408409;
      // op_fence (offset: 7 words)
      6'h09: microcode_o = 32'h00000400;
      // op_ai (offset: 8 words)
      6'h0A: microcode_o = 32'h00004000;
      6'h0B: microcode_o = 32'h0000C400;
      // op_auipc (offset: 10 words)
      6'h0C: microcode_o = 32'h0001A400;
      // op_sb (offset: 11 words)
      6'h0D: microcode_o = 32'h00000000;
      6'h0E: microcode_o = 32'h00800412;
      // op_sh (offset: 13 words)
      6'h0F: microcode_o = 32'h00000000;
      6'h10: microcode_o = 32'h00000412;
      // op_sw (offset: 15 words)
      6'h11: microcode_o = 32'h00000000;
      6'h12: microcode_o = 32'h00000012;
      6'h13: microcode_o = 32'h03000412;
      // op_a (offset: 18 words)
      6'h14: microcode_o = 32'h00000000;
      6'h15: microcode_o = 32'h00008400;
      // op_lui (offset: 20 words)
      6'h16: microcode_o = 32'h0000A400;
      // op_b (offset: 21 words)
      6'h17: microcode_o = 32'h00000000;
      6'h18: microcode_o = 32'h10080400;
      // op_jalr (offset: 23 words)
      6'h19: microcode_o = 32'h00000000;
      6'h1A: microcode_o = 32'h40148500;
      // op_jal (offset: 25 words)
      6'h1B: microcode_o = 32'h00000000;
      6'h1C: microcode_o = 32'h20128500;
      // op_mret (offset: 27 words)
      6'h1D: microcode_o = 32'h00000000;
      6'h1E: microcode_o = 32'h80000580;
      // pseudo_op_interrupt (offset: 29 words)
      6'h1F: microcode_o = 32'h00000340;
      6'h20: microcode_o = 32'h00000700;
    endcase
  end

endmodule
`endif // RV32I_MICROCODE_GUARD
