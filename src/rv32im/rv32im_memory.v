`ifndef RV32IM_MEMORY_GUARD
`define RV32IM_MEMORY_GUARD

module rv32im_memory
  #(
    parameter XLEN = 32
  )
  (
    input wire clk_i,
    input wire rst_i,

    input wire clear_i,
    input wire data_ready_i,

    input wire [XLEN-1:0] data_i,
    output reg [XLEN-1:0] data_o,
    input wire [XLEN-1:0] addr_i,
    input wire [1:0] word_size_i,
    input wire write_i,
    output reg busy_o,

    output reg err_o,

    // Wishbone Master signals
    input wire [XLEN-1:0] master_dat_i,
    output reg [XLEN-1:0] master_dat_o,
    input wire ack_i,
    output reg [XLEN-1:2] adr_o, // XLEN sized address space with byte granularity
                                  // NOTE -- the slave will only have a port as large as its address space
    output wire cyc_o,
    // input wire stall_i,
    input wire err_i,
    output reg [3:0] sel_o,
    output reg stb_o,
    output reg we_o

  );

  // Works for simple one-master busses
  assign cyc_o = stb_o;

  // NOTE -- misaligned addresses are silently ignored atm
  // NOTE -- sel doesn't actually set the bit position for reads 
  // (i.e. 4'b1000 means put a byte with offset 3 in the lowest 8 bits)
  reg [3:0] sel;
  always @(*) begin
    case (word_size_i)
      default: sel = 4'b0001 << addr_i[1:0]; // byte
      2'b01: sel = addr_i[1] ? 4'b1100 : 4'b0011; // half-word
      2'b10: sel = 4'b1111; // word
    endcase
  end

  always @(posedge clk_i) begin
    if (rst_i | clear_i) begin
      stb_o <= 1'b0;
      sel_o <= 0;
      we_o <= 1'b0;
      busy_o <= 1'b0;
      err_o <= 1'b0;
    end else if (data_ready_i & ~stb_o) begin
      busy_o <= 1'b1;
      adr_o <= addr_i[XLEN-1:2];
      sel_o <= sel;
      stb_o <= 1'b1;
      master_dat_o <= data_i;
      we_o <= write_i;
    end else if (ack_i) begin
      // transaction complete
      stb_o <= 1'b0;
      busy_o <= 1'b0;
      we_o <= 1'b0;
      data_o <= master_dat_i;
    end else if (err_i) begin
      stb_o <= 1'b0;
      busy_o <= 1'b0;
      we_o <= 1'b0;
      err_o <= 1'b1;
    end
  end

  // TODO -- need to get a wishbone bus going here...
  // It will have two masters (arbitrated between instruction cache and the regular processor) and as many slaves as
  // the user wants
  // The memory map would be configured similar to before, where start and end addresses are indicated


endmodule

`endif // RV32I_MEMORY_PIPE_GUARD
