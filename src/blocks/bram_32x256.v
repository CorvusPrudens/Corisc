`ifndef BRAM_32X256_GAURD
`define BRAM_32X256_GAURD

`ifdef SIM
`include "bitwise_mux.v"
`endif

module bram_32x256(
        input wire clk_i,
        input wire [7:0] raddr_i,
        output wire [31:0] rdata_o,
        input wire read_en_i,

        input wire [7:0] waddr_i,
        input wire [31:0] wdata_i,
        input wire [31:0] wmask_i,
        input wire write_en_i
    );

    `ifndef SIM

    SB_RAM40_4K #(
        .WRITE_MODE(0)
    ) bram1(
        .RDATA(rdata_o[15:0]),
        .RADDR(raddr_i),
        .RCLK(clk_i),
        .RCLKE(1'b1),
        .RE(read_en_i),
        .WADDR(waddr_i),
        .WCLK(clk_i),
        .WDATA(wdata_i),
        .WE(write_en_i),
        .MASK(wmask_i[15:0])
    );

    SB_RAM40_4K #(
        .WRITE_MODE(0)
    ) bram2(
        .RDATA(rdata_o[31:16]),
        .RADDR(raddr_i),
        .RCLK(clk_i),
        .RCLKE(1'b1),
        .RE(read_en_i),
        .WADDR(waddr_i),
        .WCLK(clk_i),
        .WDATA(wdata_i),
        .WE(write_en_i),
        .MASK(wmask_i[31:16])
    );

    `else

    reg [31:0] bram [0:255];
    reg [31:0] data_out = 0;
    wire [31:0] bram_write_mux;

    assign rdata_o = data_out;

    bitwise_mux #(
        .LENGTH(32)
    ) BITWISE_MUX (
        .data1_i(wdata_i),
        .data2_i(bram[waddr_i]),
        .select(wmask_i),
        .data_o(bram_write_mux)
    );

    always @(posedge clk_i) begin
        if (read_en_i)
            data_out <= bram[raddr_i];

        if (write_en_i)
            bram[waddr_i] <= bram_write_mux;
    end

    `endif

endmodule

`endif // BRAM_32X256_GAURD

 