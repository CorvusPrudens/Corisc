`ifndef WB_ENCODE
`define WB_ENCODE

module wb_encode #(
        parameter XLEN = 32
    )
    (
        input wire [3:0] sel_i,
        input wire [XLEN-1:0] unencoded_i,
        output wire [XLEN-1:0] encoded_o
    );

    // FEMTORV Inspired
    wire [1:0] addr;
    assign     addr[0] = (sel_i == 4'b0010) || (sel_i == 4'b1000);
    assign     addr[1] = (sel_i == 4'b1100) || (sel_i == 4'b0100);

    assign encoded_o[ 7: 0] = unencoded_i[7:0];
    assign encoded_o[15: 8] = addr[0] ? unencoded_i[7:0]  : unencoded_i[15: 8];
    assign encoded_o[23:16] = addr[1] ? unencoded_i[7:0]  : unencoded_i[23:16];
    assign encoded_o[31:24] = addr[0] ? unencoded_i[7:0]  :
                              addr[1] ? unencoded_i[15:8] : unencoded_i[31:24];

endmodule

`endif // WB_ENCODE
