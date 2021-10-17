`ifndef BOOT_GUARD
`define BOOT_GUARD

module boot(
    input wire clk_i,
    input wire write_i,
    input wire [7:0] data_i,
    output reg [2:0] data_o = 0
  );

  reg [3:0] security1 = 0;
  reg [3:0] security2 = 0;

  always @(posedge clk_i) begin
    if (write_i) begin
      case (data_i[5:4])
        2'b00: security1 <= data_i[3:0];
        2'b01: security2 <= data_i[3:0];
        2'b10: data_o[2:1] <= data_i[1:0];
        default:
          begin

          end
      endcase
    end else begin
      if (security1 == 4'b0101 && security2 == 4'b1010) begin
        data_o[0] <= ~data_o[0];
        security1 <= 0;
        security2 <= 0;
      end
    end
  end

endmodule
`endif // BOOT_GUARD
