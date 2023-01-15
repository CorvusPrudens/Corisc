`ifndef SHARED_REG_GUARD
`define SHARED_REG_GUARD

`include "mux.v"

module shared_reg #(
        parameter WIDTH = 8,
        parameter WRITERS = 2
    ) (
        input wire clk_i,
        input wire [WRITERS-1:0] we_i,
        input wire [WRITERS*WIDTH - 1:0] data_i,
        output wire [WIDTH-1:0] data_o
    );

    reg  [WIDTH-1:0] data;
    wire [WIDTH-1:0] wdata_mux;

    assign data_o = data;

    mux #(
        .NUM_VECS(WRITERS),
        .VEC_BITS(WIDTH),
        .PRIORITY(1)
    ) MUX (
        .select_i(we_i),
        .vectors_i(data_i),
        .vector_o(wdata_mux)
    );

    wire write = |we_i;

    always @(posedge clk_i) begin
        if (write)
            data <= wdata_mux;
    end

endmodule

`endif // SHARED_REG_GUARD
