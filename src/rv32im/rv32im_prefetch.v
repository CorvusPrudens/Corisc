`ifndef RV32IM_PREFETCH_GUARD
`define RV32IM_PREFETCH_GUARD

// Simple prefetch for a non-pipelined setup

module rv32im_prefetch 
    #(
        parameter XLEN = 32,
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
        output reg interrupt_pc_write,

        output reg initialized,
        output reg save_uepc
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

    reg [1:0] vtable_sm;
    reg [1:0] prefetch_sm;

    wire pursue_vtable = (~vtable_lookup_init | (handle_interrupt & ~interrupt_handled)) & (prefetch_sm == 0);

    always @(posedge clk_i) begin
        if (reset_i) begin
            vtable_sm <= 0;
            prefetch_sm <= 0;

            ctrl_req_o <= 1'b0;
            stb_o <= 1'b0;
            data_ready_o <= 1'b0;
            vtable_lookup_init <= 1'b0;
            interrupt_pc_write <= 1'b0;
            initialized <= 1'b0;
            interrupt_handled <= 1'b0;
        end else begin
            case (vtable_sm)
                2'b00: 
                begin
                    if (advance_i & pursue_vtable) begin
                        stb_o <= 1'b1;
                        ctrl_req_o <= 1'b1;
                        adr_o <= vtable_addr[XLEN-1:2] + vtable_offset[XLEN-1:2];
                        vtable_sm <= vtable_sm + 1'b1;
                        save_uepc <= 1'b1;
                    end
                end
                2'b01:
                begin
                    if (ack_i & ctrl_grant_i) begin
                        stb_o <= 1'b0;
                        ctrl_req_o <= 1'b0;
                        interrupt_handled <= 1'b1;
                        interrupt_pc_o <= master_dat_i;
                        interrupt_pc_write <= 1'b1;
                        vtable_lookup_init <= 1'b1;
                        vtable_sm <= vtable_sm + 1'b1;
                    end
                    save_uepc <= 1'b0;
                end
                default:
                begin
                    interrupt_handled <= 1'b0;
                    interrupt_pc_write <= 1'b0;
                    vtable_sm <= 0;
                end
            endcase

            case (prefetch_sm)
                2'b00:
                begin
                    if (advance_i & ~pursue_vtable) begin
                        ctrl_req_o <= 1'b1;
                        stb_o <= 1'b1;
                        adr_o <= program_counter_i[XLEN-1:2];
                        data_ready_o <= 1'b0;
                        interrupt_pc_write <= 1'b0;
                        initialized <= 1'b1;
                        prefetch_sm <= prefetch_sm + 1'b1;
                    end
                end
                2'b01:
                begin
                    if (ack_i & ctrl_grant_i) begin
                        instruction_o <= master_dat_i;
                        ctrl_req_o <= 1'b0;
                        stb_o <= 1'b0;
                        data_ready_o <= 1'b1;
                        prefetch_sm <= prefetch_sm + 1'b1;
                    end
                end
                default:
                begin
                    data_ready_o <= 1'b0;
                    interrupt_pc_write <= 1'b0;
                    interrupt_handled <= 1'b0;
                    prefetch_sm <= 0;
                end
            endcase
        end
    end

endmodule

`endif // RV32IM_PREFETCH_GUARD
