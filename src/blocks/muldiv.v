`ifndef MULDIV_GUARD
`define MULDIV_GUARD

module muldiv(
        input wire clk_i,
        input wire reset_i,
        input wire [31:0] operand1_i,
        input wire [31:0] operand2_i,
        output wire [31:0] result_o,
        input wire [2:0] funct3,
        input wire start_i,
        output wire valid_o
    );

    // verilator lint_off UNDRIVEN
    wire isDivide  = funct3[2];
    wire divide_busy = |quotient_msk; // ALU is busy if division is in progress.

    reg divide_started = 0;
    reg divide_done = 0;

    ////////////////////////////////////////////////////////////
    // Divide
    ////////////////////////////////////////////////////////////
    reg [31:0] dividend = 0;
    reg [62:0] divisor = 0;
    reg [31:0] quotient = 0;
    reg [31:0] quotient_msk = 0;

    wire divstep_do = divisor <= {31'b0, dividend};

    wire [31:0] dividendN     = divstep_do ? dividend - divisor[31:0] : dividend;
    wire [31:0] quotientN     = divstep_do ? quotient | quotient_msk  : quotient;

    wire div_sign = ~funct3[0] & (funct3[1] ? operand1_i[31] :
                        (operand1_i[31] != operand2_i[31]) & |operand2_i);

    // TODO -- double check that this state management works as expected (i.e. should the
    // // first block yield to the second after one cycle?)
    // always @(posedge clk_i) begin
    //     if (isDivide & start_i) begin
    //         dividend <=   ~funct3[0] & operand1_i[31] ? -operand1_i : operand1_i;
    //         divisor  <= {(~funct3[0] & operand2_i[31] ? -operand2_i : operand2_i), 31'b0};
    //         quotient <= 0;
    //         quotient_msk <= 1 << 31;
    //         divide_started <= 1'b1;
    //     end else begin
    //         dividend     <= dividendN;
    //         divisor      <= divisor >> 1;
    //         quotient     <= quotientN;
    //         quotient_msk <= quotient_msk >> 1;
    //     end
    // end

    reg  [31:0] divResult = 0;
    // always @(posedge clk_i) divResult <= funct3[1] ? dividendN : quotientN;

    reg signed [65:0] product;

    wire is_mul = funct3[1:0] == 2'b00;
    wire is_mulh = |funct3[1:0];

    assign result_o =
     (  is_mul    ?  product[31: 0] : 32'b0) | // 0:MUL
     (  is_mulh   ?  product[63:32] : 32'b0) | // 1:MULH, 2:MULHSU, 3:MULHU
     (  funct3[2] ?  div_sign ? -divResult : divResult : 32'b0); // 4:DIV, 5:DIVU, 6:REM, 7:REMU

    assign valid_o = isDivide ? ~divide_busy : o_done;

    // verilator lint_on UNDRIVEN
    ////////////////////////////////////////////////////////////
    // Multiply
    ////////////////////////////////////////////////////////////
    // funct3: 1->MULH, 2->MULHSU  3->MULHU
    wire isMULH   = funct3[1:0] == 2'b01;
    wire isMULHSU = funct3[1:0] == 2'b10;

    wire sign1 =  operand1_i[31] &  isMULH;
    wire sign2 =  operand2_i[31] & (isMULH | isMULHSU);

    wire signed [32:0] signed1 = {sign1,  operand1_i};
    wire signed [32:0] signed2 = {sign2,  operand2_i};
    // wire signed [63:0] multiply = signed1 * signed2;

    parameter LGNA = 6;
    parameter [LGNA:0] NA = 33;
    parameter [0:0]  OPT_SIGNED = 1'b1;
    //
    wire i_stb = start_i & ~isDivide;
    reg o_busy, o_done;

    reg [LGNA-1:0] count = 0;
    reg [NA-1:0] p_a = 0;
    reg [NA-1:0] p_b = 0;
    reg [NA+NA-1:0] partial = 0;

    reg almost_done = 0;

    wire pre_done;
    assign pre_done = count == 0;
    always @(posedge clk_i)
        almost_done <= ~reset_i & o_busy & pre_done;

    always @(posedge clk_i) begin
        if (reset_i) begin
            o_done <= 0;
            o_busy <= 0;
        end else if (!o_busy && i_stb) begin
            o_done <= 0;
            o_busy <= 1;
        end else if (o_busy && almost_done) begin
            o_done <= 1;
            o_busy <= 0;
        end else
            o_done <= 0;
    end

    wire [NA-1:0] pwire;
    assign pwire = (p_b[0] ? p_a : 0);

    always @(posedge clk_i) begin
        if (!o_busy) begin
            count <= NA[LGNA-1:0]-1;
            partial <= 0;
            p_a <= signed1;
            p_b <= signed2;
        end else begin
            p_b <= (p_b >> 1);
            partial[NA-2:0] <= partial[NA-1:1];
            if (pre_done)
                partial[NA*2-1:NA-1] <= {1'b0, partial[NA*2-1:NA]} +
                    {1'b0, pwire[NA-1], ~pwire[NA-2:0]};
            else
                partial[NA*2-1:NA-1] <= {1'b0,partial[NA*2-1:NA]} +
                    {1'b0, !pwire[NA-1], pwire[NA-2:0]};
            count <= count - 1;
        end
    end

    always @(posedge clk_i)
        if (almost_done)
            product <= partial[NA*2-1:0] + {1'b1,{(NA-2){1'b0}},1'b1, {(NA){1'b0}}};

endmodule

`endif // MULDIV_GUARD
