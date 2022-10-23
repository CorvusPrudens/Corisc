`ifndef QSPI_GUARD
`define QSPI_GUARD

module qspi #(
        parameter CLK_DIV = 1
    )
    (
        input wire clk_i,
        input wire start_i,
        input wire we_i,

        input wire [7:0] data_i,
        output wire [7:0] data_o,
        output wire busy_o,

        output wire sck_o,

        `ifndef SIM
        inout wire io0, // MOSI
        inout wire io1, // MISO
        inout wire io2, // write protect
        inout wire io3, // hold
        `else
        input wire io0_sim_i,
        input wire io1_sim_i,
        input wire io2_sim_i,
        input wire io3_sim_i,

        output wire io0_sim_o,
        output wire io1_sim_o,
        output wire io2_sim_o,
        output wire io3_sim_o,
        `endif

        input wire enable_qspi_i
    );

    reg  [8:0] shifter_in;
    reg  [7:0] shifter_out;
    reg  [2:0] counter;
    wire [3:0] counter_p1 = {1'b0, counter} + 1'b1;
    reg  [7:0] qpi_data_in;
    reg  [7:0] qpi_data_out;

    assign data_o = enable_qspi_i ? qpi_data_in : shifter_in[8:1];

    wire io0_data_o = qpi_data_out[0];
    wire io1_data_o = qpi_data_out[1];
    wire io2_data_o = qpi_data_out[2];
    wire io3_data_o = qpi_data_out[3];

    wire io0_out = enable_qspi_i ? io0_data_o : shifter_out[7];
    wire io1_out = io1_data_o;
    wire io2_out = enable_qspi_i ? io2_data_o : 1'b1;
    wire io3_out = enable_qspi_i ? io2_data_o : 1'b1;

    wire io0_dir = enable_qspi_i ? we_i : 1'b1;
    wire io1_dir = enable_qspi_i ? we_i : 1'b0;
    wire io2_dir = enable_qspi_i ? we_i : 1'b1;
    wire io3_dir = enable_qspi_i ? we_i : 1'b1;

    `ifndef SIM
    assign io0 = io0_dir ? io0_out : 1'bz;
    assign io1 = io1_dir ? io1_out : 1'bz;
    assign io2 = io2_dir ? io2_out : 1'bz;
    assign io3 = io3_dir ? io3_out : 1'bz;

    wire [3:0] nibble_in = {io3, io2, io1, io0};
    `else
    assign io0_sim_o = io0_out;
    assign io1_sim_o = io1_out;
    assign io2_sim_o = io2_out;
    assign io3_sim_o = io3_out;

    wire [3:0] nibble_in = {io3_sim_i, io2_sim_i, io1_sim_i, io0_sim_i};
    `endif

    reg [1:0] spi_sm;
    wire   clk_active = |spi_sm;
    assign busy_o     = clk_active | start_i;
    assign sck_o      = clk_active & clk_i;

    always @(negedge clk_i) begin
        case (spi_sm)
            default:
                if (start_i) begin
                    shifter_out <= data_i;

                    qpi_data_out <= data_i;
                end
            2'b01:
            begin
                shifter_out <= {shifter_out[6:0], 1'b0};

                qpi_data_out[3:0] <= qpi_data_out[7:4];
            end
        endcase
    end

    always @(posedge clk_i) begin
        case (spi_sm)
            default:
            begin
                if (start_i) begin
                    // counter <= counter_p1;
                    counter <= 0;
                    // shifter <= {data_i[6:0], 1'b0};
                    // qpi_data_out <= data_i;
                    spi_sm <= 1;
                end
            end
            2'b01:
            begin

                counter <= counter_p1[2:0];

                if (enable_qspi_i & counter_p1[1])
                    spi_sm <= 0;
                else if (counter_p1[3])
                    spi_sm <= 0;

                `ifndef SIM
                shifter_in <= {shifter_in[7:0], io1};
                `else
                shifter_in <= {shifter_in[7:0], io1_sim_i};
                `endif

                if (counter[0])
                    qpi_data_in[7:4] <= nibble_in;
                else
                    qpi_data_in[3:0] <= nibble_in;
            end
        endcase


        // if (start_i) begin
        //     counter <= counter + 1'b1;
        //     shifter <= data_i;
        //     qpi_data_out <= data_i;
        // end else if (busy_o) begin

        //     if (enable_qspi_i && counter == 3'b010)
        //         counter <= 0;
        //     else
        //         counter <= counter + 1'b1;

        //     `ifndef SIM
        //     shifter <= {shifter[6:0], io1};
        //     `else
        //     shifter <= {shifter[6:0], io1_sim_i};
        //     `endif

        //     if (counter[0])
        //         qpi_data_in[7:4] <= nibble_in;
        //     else
        //         qpi_data_in[3:0] <= nibble_in;

        // end
    end

endmodule
`endif // QSPI_GUARD
