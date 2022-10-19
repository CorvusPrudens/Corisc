`ifndef WB_DECODE
`define WB_DECODE

module wb_decode #(
        parameter XLEN = 32
    )
    (
        input wire [1:0] address,
        input wire byte_access,
        input wire half_access,
        
        input wire [XLEN-1:0] encoded_i,
        output wire [XLEN-1:0] decoded_o
    );

    // FEMTORV Inspired
    wire [15:0] half_data = address[1] ? encoded_i[31:16] : encoded_i[15:0];
    wire  [7:0] byte_data = address[0] ? half_data[15:8]  : half_data[7:0];

    assign decoded_o =
        byte_access ? {24'b0, byte_data} :
        half_access ? {16'b0, half_data} :
        encoded_i;

endmodule

`endif // WB_ENCODE_DECODE
