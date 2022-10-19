`ifndef RV32IM_DIV
`define RV32IM_DIV

module rv32im_div #(parameter WIDTH=4) (
    input wire clk_i,
    input wire clear_i,
    input wire start,          // start signal
    output reg busy = 0,           // calculation in progress
    output reg valid = 0,          // quotient and remainder are valid
    output reg dbz = 0,            // divide by zero flag
    input wire [WIDTH-1:0] x,  // dividend
    input wire [WIDTH-1:0] y,  // divisor
    output reg [WIDTH-1:0] q = 0,  // quotient
    output reg [WIDTH-1:0] r = 0   // remainder
    );

    localparam WIDTH_M1 = WIDTH-1;

    reg [WIDTH-1:0] y1;
    initial y1 = 0;            // copy of divisor
    reg [WIDTH-1:0] q1, q1_next;
    initial q1 = 0;
    initial q1_next = 0;   // intermediate quotient
    reg [WIDTH:0] ac, ac_next;
    initial ac = 0;
    initial ac_next = 0;     // accumulator (1 bit wider)
    reg [$clog2(WIDTH)-1:0] i;
    initial i = 0;     // iteration counter

    always @(*) begin
        if (ac >= {1'b0,y1}) begin
            ac_next = ac - y1;
            {ac_next, q1_next} = {ac_next[WIDTH-1:0], q1, 1'b1};
        end else begin
            {ac_next, q1_next} = {ac, q1} << 1;
        end
    end

    always @(posedge clk_i) begin
        if (clear_i) begin
            valid <= 0;
            busy <= 0;
        end else if (start) begin
            valid <= 0;
            i <= 0;
            if (y == 0) begin  // catch divide by zero
                busy <= 0;
                dbz <= 1;
            end else begin  // initialize values
                busy <= 1;
                dbz <= 0;
                y1 <= y;
                {ac, q1} <= {{WIDTH{1'b0}}, x, 1'b0};
            end
        end else if (busy) begin
            if (i == WIDTH_M1[$clog2(WIDTH)-1:0]) begin  // we're done
                busy <= 0;
                valid <= 1;
                q <= q1_next;
                r <= ac_next[WIDTH:1];  // undo final shift
            end else begin  // next iteration
                i <= i + 1;
                ac <= ac_next;
                q1 <= q1_next;
            end
        end else begin
            valid <= 1'b0;
        end
    end
endmodule

`endif // RV32IM_DIV
