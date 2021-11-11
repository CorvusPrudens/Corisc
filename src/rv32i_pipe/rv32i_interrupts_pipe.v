
module rv32i_interrupts_pipe
  #(
    parameter XLEN = 32,
    parameter ILEN = 32,
    parameter INT_VECT_LEN = 8
  )
  (
    input wire clk_i,
    input wire clear_interrupt_i,
    input wire [INT_VECT_LEN-1:0] interrupt_vector_i,
    output wire [INT_VECT_LEN-1:0] interrupt_vector_o,
    input wire [INT_VECT_LEN-1:0] interrupt_mask_i,
    output wire [INT_VECT_LEN-1:0] interrupt_mask_o,
    input wire interrupt_mask_write_i,
    output reg [XLEN-1:0] interrupt_vector_offset_o,
    output reg [1:0] interrupt_state_o,
    input wire interrupt_advance_i
  );

  reg [INT_VECT_LEN-1:0] interrupt_mask = 0;
  assign interrupt_mask_o = interrupt_mask;
  wire [INT_VECT_LEN-1:0] interrupt_masked = interrupt_vector_i & interrupt_mask;
  reg [INT_VECT_LEN-1:0] interrupt_vector = 0;
  assign interrupt_vector_o = interrupt_handling;
  wire [XLEN-1:0] interrupt_vector_offset_full;

  always @(posedge clk_i) begin
    if (interrupt_mask_write_i)
      interrupt_mask <= interrupt_mask_i;
    
    if (clear_interrupt_i)
      interrupt_vector <= (interrupt_vector ^ interrupt_handling) | interrupt_masked;
    else
      interrupt_vector <= interrupt_vector | interrupt_masked;
  end

  reg [INT_VECT_LEN-1:0] interrupt_handling = 0;
  wire [INT_VECT_LEN-1:0] interrupt_vector_low;

  assign interrupt_vector_low[0] = interrupt_vector[0];
  genvar i;
  generate
    for (i = 1; i < INT_VECT_LEN; i = i + 1) begin
      assign interrupt_vector_low[i] = interrupt_vector[i] & (interrupt_vector[i-1:0] == 0);
    end
  endgenerate  

  always @(posedge clk_i) begin
    case (interrupt_state_o)
      2'b00: 
        begin
          if (interrupt_vector_low != 0) begin
            interrupt_handling <= interrupt_vector_low;
            interrupt_state_o <= interrupt_state_o + 1'b1;
          end
        end
      2'b01:
        begin
          if (interrupt_advance_i) begin
            interrupt_state_o <= interrupt_state_o + 1'b1;
            interrupt_vector_offset_o <= interrupt_vector_offset_full;
          end
        end
      2'b10:
        begin
          if (clear_interrupt_i) begin
            interrupt_handling <= 0;
            interrupt_state_o <= 0;
          end
        end
      default: ;
    endcase
  end

  // // Frustrating that this language doesn't support a proper parametric one-hot to binary decoder
  // // Generated with onehot2bin.py
  // reg [2:0] interrupt_vector_offset;
  // always @(*) begin
  //   case (interrupt_handling)
  //     8'h01: interrupt_vector_offset = 3'h0;
  //     8'h02: interrupt_vector_offset = 3'h1;
  //     8'h04: interrupt_vector_offset = 3'h2;
  //     8'h08: interrupt_vector_offset = 3'h3;
  //     8'h10: interrupt_vector_offset = 3'h4;
  //     8'h20: interrupt_vector_offset = 3'h5;
  //     8'h40: interrupt_vector_offset = 3'h6;
  //     8'h80: interrupt_vector_offset = 3'h7;
  //     default: interrupt_vector_offset = 0;
  //   endcase
  // end
  localparam OFFSET_LEN = $clog2(INT_VECT_LEN);

  // may or may not be synthesizeable this way
  reg [OFFSET_LEN-1:0] interrupt_vector_offset;
  
  integer j;
  always @(*) begin
    interrupt_vector_offset = 0;
    for (j = INT_VECT_LEN - 1; j > -1; j = j - 1)
      if (interrupt_handling == (1 << j))
        interrupt_vector_offset = j[OFFSET_LEN-1:0];
  end

  assign interrupt_vector_offset_full = {{(XLEN-OFFSET_LEN)-2{1'b0}}, interrupt_vector_offset, 2'b0};

endmodule
