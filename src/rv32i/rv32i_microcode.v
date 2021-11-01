`ifndef RV32I_MICROCODE_GUARD
`define RV32I_MICROCODE_GUARD

module rv32i_microcode
  (
    input wire clk_i,
    input wire [4:0] microcode_addr_i,
    output reg [31:0] microcode_o
  );

  always @(microcode_addr_i) begin
    case (microcode_addr_i)
      default: microcode_o = 32'h0;
      // fetch (offset: 0 words)
      5'h00: microcode_o = 32'h00000905;
      5'h01: microcode_o = 32'h00001105;
      // op_lb (offset: 0 words)
      5'h02: microcode_o = 32'h00208409;
      // op_lh (offset: 1 words)
      5'h03: microcode_o = 32'h08008409;
      // op_lw (offset: 2 words)
      5'h04: microcode_o = 32'h04000009;
      5'h05: microcode_o = 32'h02408409;
      // op_fence (offset: 4 words)
      5'h06: microcode_o = 32'h00000400;
      // op_ai (offset: 5 words)
      5'h07: microcode_o = 32'h0000C400;
      // op_auipc (offset: 6 words)
      5'h08: microcode_o = 32'h0001A400;
      // op_sb (offset: 7 words)
      5'h09: microcode_o = 32'h00800412;
      // op_sh (offset: 8 words)
      5'h0A: microcode_o = 32'h00000412;
      // op_sw (offset: 9 words)
      5'h0B: microcode_o = 32'h00000012;
      5'h0C: microcode_o = 32'h03000412;
      // op_a (offset: 11 words)
      5'h0D: microcode_o = 32'h00008400;
      // op_lui (offset: 12 words)
      5'h0E: microcode_o = 32'h0000A400;
      // op_b (offset: 13 words)
      5'h0F: microcode_o = 32'h10080400;
      // op_jalr (offset: 14 words)
      5'h10: microcode_o = 32'h40148500;
      // op_jal (offset: 15 words)
      5'h11: microcode_o = 32'h20128500;
      // op_mret (offset: 16 words)
      5'h12: microcode_o = 32'h80000580;
      // pseudo_op_interrupt (offset: 17 words)
      5'h13: microcode_o = 32'h00000340;
      5'h14: microcode_o = 32'h00000700;
    endcase
  end

endmodule
`endif // RV32I_MICROCODE_GUARD
