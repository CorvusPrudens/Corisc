`ifndef WB_ENCODE_DECODE
`define WB_ENCODE_DECODE

module wb_encode_decode #(
        parameter XLEN = 32
    )
    (
        input wire [3:0] sel_i,
        input wire [XLEN-1:0] master_dat_i,
        input wire [XLEN-1:0] unencoded_output_i,

        output wire [XLEN-1:0] input_decoded_o,
        output wire [XLEN-1:0] master_dat_o
    );

    // FEMTORV Inspired

    wire mem_halfwordAccess = (sel_i == 4'b1100) || (sel_i == 4'b0011);
    wire mem_byteAccess = ~mem_halfwordAccess || (sel_i != 4'b1111);

    wire [1:0] loadstore_addr;
    assign loadstore_addr[0] = (sel_i == 4'b0010) || (sel_i == 4'b1000);
    assign loadstore_addr[1] = (sel_i == 4'b1100);

    assign input_decoded_o =
         mem_byteAccess ? {24'b0,     LOAD_byte} :
     mem_halfwordAccess ? {16'b0, LOAD_halfword} :
                          master_dat_i ;

    wire [15:0] LOAD_halfword =
                loadstore_addr[1] ? master_dat_i[31:16] : master_dat_i[15:0];

    wire  [7:0] LOAD_byte =
                loadstore_addr[0] ? LOAD_halfword[15:8] : LOAD_halfword[7:0];

    assign master_dat_o[ 7: 0] = unencoded_output_i[7:0];
    assign master_dat_o[15: 8] = loadstore_addr[0] ? unencoded_output_i[7:0]  : unencoded_output_i[15: 8];
    assign master_dat_o[23:16] = loadstore_addr[1] ? unencoded_output_i[7:0]  : unencoded_output_i[23:16];
    assign master_dat_o[31:24] = loadstore_addr[0] ? unencoded_output_i[7:0]  :
                                loadstore_addr[1] ? unencoded_output_i[15:8] : unencoded_output_i[31:24];


    // wire shift8  = sel_i == 4'b0010;
    // wire shift16 = (sel_i == 4'b0100) || (sel_i == 4'b1100);
    // wire shift24 = sel_i == 4'b1000;
    // wire shift0 = ~(shift8 | shift16 | shift24);

    // {* onehot *}
    // wire [3:0] shift_state = {shift24, shift16, shift8, shift0};

    // always @(*) begin
    //     case (shift_state)
    //     default: input_decoded_o = master_dat_i;
    //     // 4'b0001: input_decoded_o = master_dat_i;
    //     4'b0010: input_decoded_o = {8'b0,  master_dat_i[XLEN-1:8]};
    //     4'b0100: input_decoded_o = {16'b0, master_dat_i[XLEN-1:16]};
    //     4'b1000: input_decoded_o = {24'b0, master_dat_i[XLEN-1:24]};
    //     endcase
    // end

    // always @(*) begin
    //     case (shift_state)
    //     default: master_dat_o = unencoded_output_i;
    //     // 4'b0001: master_dat_o = unencoded_output_i;
    //     4'b0010: master_dat_o = {unencoded_output_i[(XLEN-1)-8:0], 8'b0};
    //     4'b0100: master_dat_o = {unencoded_output_i[(XLEN-1)-16:0], 16'b0};
    //     4'b1000: master_dat_o = {unencoded_output_i[(XLEN-1)-24:0], 24'b0};
    //     endcase
    // end

endmodule

`endif // WB_ENCODE_DECODE
