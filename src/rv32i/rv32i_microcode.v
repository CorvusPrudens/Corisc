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
      // vtable_lookup (offset: 0 words)
      7'h00: microcode_o = 32'h00000240;
      7'h01: microcode_o = 32'h00000300;
      7'h02: microcode_o = 32'h00000700;
      // fetch (offset: 0 words)
      7'h03: microcode_o = 32'h00000105;
      7'h04: microcode_o = 32'h00000904;
      7'h05: microcode_o = 32'h00001005;
      // op_lb (offset: 0 words)
      7'h06: microcode_o = 32'h00000000;
      7'h07: microcode_o = 32'h00000008;
      7'h08: microcode_o = 32'h00208409;
      // op_lh (offset: 3 words)
      7'h09: microcode_o = 32'h00000000;
      7'h0A: microcode_o = 32'h00000008;
      7'h0B: microcode_o = 32'h08008409;
      // op_lw (offset: 6 words)
      7'h0C: microcode_o = 32'h00000000;
      7'h0D: microcode_o = 32'h00000009;
      7'h0E: microcode_o = 32'h06000008;
      7'h0F: microcode_o = 32'h02408409;
      // op_fence (offset: 10 words)
      7'h10: microcode_o = 32'h00000400;
      // op_ai (offset: 11 words)
      7'h11: microcode_o = 32'h00004000;
      7'h12: microcode_o = 32'h00004000;
      7'h13: microcode_o = 32'h0000C400;
      // op_auipc (offset: 14 words)
      7'h14: microcode_o = 32'h0001A400;
      // op_sb (offset: 15 words)
      7'h15: microcode_o = 32'h00000000;
      7'h16: microcode_o = 32'h00000010;
      7'h17: microcode_o = 32'h00800412;
      // op_sh (offset: 18 words)
      7'h18: microcode_o = 32'h00000000;
      7'h19: microcode_o = 32'h00000010;
      7'h1A: microcode_o = 32'h00000412;
      // op_sw (offset: 21 words)
      7'h1B: microcode_o = 32'h00000000;
      7'h1C: microcode_o = 32'h00000010;
      7'h1D: microcode_o = 32'h00000012;
      7'h1E: microcode_o = 32'h03000412;
      // op_a (offset: 25 words)
      7'h1F: microcode_o = 32'h00000000;
      7'h20: microcode_o = 32'h00000000;
      7'h21: microcode_o = 32'h00008400;
      // op_lui (offset: 28 words)
      7'h22: microcode_o = 32'h0000A400;
      // op_b (offset: 29 words)
      7'h23: microcode_o = 32'h00000000;
      7'h24: microcode_o = 32'h00000000;
      7'h25: microcode_o = 32'h10080400;
      // op_jalr (offset: 32 words)
      7'h26: microcode_o = 32'h00000000;
      7'h27: microcode_o = 32'h40148500;
      // op_jal (offset: 34 words)
      7'h28: microcode_o = 32'h00000000;
      7'h29: microcode_o = 32'h20128500;
      // op_mret (offset: 36 words)
      7'h2A: microcode_o = 32'h00000000;
      7'h2B: microcode_o = 32'h80000580;
    endcase
  end

endmodule
`endif // RV32I_MICROCODE_GUARD
