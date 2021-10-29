`ifndef CRC_M
`define CRC_M

// crc-32 / posix
// polynomial: 0x04C11DB7
// output xor: 0xFFFFFFFF

module crc(
    input wire clk_i,
    input wire spi_clk,
    input wire clk_en_i,
    input wire en_i,
    input wire data_i,
    input wire reset_i,
    output wire data_o
);

    reg [31:0] shift = 32'b0;
    assign data_o = (shift ^ 32'hFFFFFFFF) == 32'b0;
    wire xorbit = shift[31];

    reg input_reg;
    always @(posedge clk_i) begin
        input_reg <= data_i;
    end

    always @(posedge clk_i) begin

        if (reset_i) begin
            shift <= 32'b0;
        end else if (clk_en_i & en_i) begin 

            // NOTE -- this could almost certainly be generated, but
            // I don't really know how to do that with verilog
            shift[0] <= input_reg ^ xorbit;
            shift[1] <= shift[0] ^ xorbit;
            shift[2] <= shift[1] ^ xorbit;
            shift[3] <= shift[2];
            shift[4] <= shift[3] ^ xorbit;
            shift[5] <= shift[4] ^ xorbit;
            shift[6] <= shift[5];
            shift[7] <= shift[6] ^ xorbit;

            shift[8] <= shift[7] ^ xorbit;
            shift[9] <= shift[8];
            shift[10] <= shift[9] ^ xorbit;
            shift[11] <= shift[10] ^ xorbit;
            shift[12] <= shift[11] ^ xorbit;
            shift[13] <= shift[12];
            shift[14] <= shift[13];
            shift[15] <= shift[14];

            shift[16] <= shift[15] ^ xorbit;
            shift[17] <= shift[16];
            shift[18] <= shift[17];
            shift[19] <= shift[18];
            shift[20] <= shift[19];
            shift[21] <= shift[20];
            shift[22] <= shift[21] ^ xorbit;
            shift[23] <= shift[22] ^ xorbit;

            shift[24] <= shift[23];
            shift[25] <= shift[24];
            shift[26] <= shift[25] ^ xorbit;
            shift[27] <= shift[26];
            shift[28] <= shift[27];
            shift[29] <= shift[28];
            shift[30] <= shift[29];
            shift[31] <= shift[30];

        end
    end

endmodule

`endif
