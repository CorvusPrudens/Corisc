`ifndef MUX_GUARD
`define MUX_GUARD

module mux #(
        parameter NUM_VECS = 2,
        parameter VEC_BITS = 32,

        // With priority, the vector with the lowest index
        // is given highest priority. Otherwise, a one-hot encoding
        // on the select input is expected.
        parameter PRIORITY = 0
    ) (
        input wire [NUM_VECS-1:0] select_i,
        input wire [(NUM_VECS * VEC_BITS)-1:0] vectors_i,
        output wire [VEC_BITS-1:0] vector_o
    );

    wire [VEC_BITS-1:0] vectors [NUM_VECS-1:0];

    generate

        if (NUM_VECS == 1) begin
            assign vector_o = select_i ? vectors_i : 0;
        end else begin
            if (PRIORITY == 1) begin

                // This helps verilator
                genvar n;
                for (n = 0; n < NUM_VECS; n = n + 1)
                    assign vectors[n] = vectors_i[(n+1) * VEC_BITS - 1 : n * VEC_BITS];

                reg  [VEC_BITS-1:0] muxed_data;

                integer i;
                always @(*) begin
                    muxed_data = 0;
                    for (i = NUM_VECS - 1; i > -1; i = i - 1) begin
                        if (select_i[i])
                            muxed_data = vectors[i];
                    end
                end

                assign vector_o = muxed_data;

            end else begin

                genvar j, k;
                for (j = 0; j < NUM_VECS; j = j + 1)
                    assign vectors[j] = select_i[j] ? vectors_i[(j+1) * VEC_BITS - 1 : j * VEC_BITS] : 0;

                // Turn vector bit columns into individual vectors
                wire [NUM_VECS-1:0] vector_cols [VEC_BITS-1:0];
                for (k = 0; k < VEC_BITS; k = k + 1) begin
                    for (j = 0; j < NUM_VECS; j = j + 1) begin
                        assign vector_cols[k][j] = vectors[j][k];
                    end
                end

                // And OR them
                for (k = 0; k < VEC_BITS; k = k + 1)
                    assign vector_o[k] = |vector_cols[k];

            end
        end

    endgenerate

endmodule

`endif // MUX_GUARD
