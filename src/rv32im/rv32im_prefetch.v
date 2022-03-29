`ifndef RV32IM_PREFETCH_GUARD
`define RV32IM_PREFETCH_GUARD

// Simple prefetch for a non-pipelined setup

module rv32im_prefetch 
    #(
        parameter XLEN = 32
        parameter ILEN = 32
    ) (
        input wire clk_i,
        input wire reset_i,
        input wire [XLEN-1:0] program_counter_i,

        input wire advance_i,
        output reg data_ready_o,

        output reg [ILEN-1:0] instruction_o,

        // Arbitration signals
        output reg ctrl_req_o,
        input wire ctrl_grant_i,

        // Wishbone Master signals
        input wire [XLEN-1:0] master_dat_i,
        input wire ack_i,
        output reg [XLEN-3:0] adr_o, // XLEN sized address space with byte granularity
                                    // NOTE -- the slave will only have a port as large as its address space
        output wire cyc_o,
        // input wire stall_i,
        input wire err_i,
        output wire [3:0] sel_o,
        output reg stb_o,

        input wire interrupt_trigger_i,
        input wire [XLEN-1:0] vtable_addr,
        input wire [XLEN-1:0] vtable_offset,

        output reg [XLEN-1:0] interrupt_pc_o,
        output reg interrupt_pc_write
    );

    assign sel_o = 4'b1111;
    assign cyc_o = stb_o;

    reg handle_interrupt;
    reg interrupt_handled;
    reg vtable_lookup_init;

    always @(posedge clk_i) begin
        if (interrupt_handled)
            handle_interrupt <= 1'b0;
        else if (interrupt_trigger_i)
            handle_interrupt <= 1'b1;
    end

    wire pursue_vtable = ~vtable_lookup_init | (handle_interrupt & ~interrupt_handled);

    always @(posedge clk_i) begin
        if (reset_i) begin
            ctrl_req_o <= 1'b0;
            stb_o <= 1'b0;
            data_ready_o <= 1'b0;
            vtable_lookup_init <= 1'b0;
        end else if (pursue_vtable) begin

            // load from vtable routine
            if (((advance_i & handle_interrupt) | ~vtable_lookup_init) & !stb_o) begin
                stb_o <= 1'b1;
                adr_o <= vtable_addr[XLEN-1:2] + vtable_offset[XLEN-1:2];
            end else if (ack_i & ctrl_grant_i) begin
                stb_o <= 1'b0;
                interrupt_handled = 1'b1;
                interrupt_pc_o <= master_dat_i;
                interrupt_pc_write <= 1'b1;
                vtable_lookup_init <= 1'b1;
            end
            
        end else if (advance_i & !stb_o) begin
            stb_o <= 1'b1;
            adr_o <= program_counter_i[XLEN-1:2];
            data_ready_o <= 1'b0;
        end else if (ack_i & ctrl_grant_i) begin
            instruction_o <= master_dat_i;
            ctrl_req_o <= 1'b0;
            stb_o <= 1'b0;
            data_ready_o <= 1'b1;
        end else
            data_ready_o <= 1'b0;
    end

endmodule

`endif // RV32IM_PREFETCH_GUARD