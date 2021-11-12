
module audiotable
  #(parameter memWidth_p = 5, parameter dataFile_p = "./nes/pulseprom.hex")
  (
    input wire clk_i,
    input wire [(memWidth_p - 1):0] addr_i,
    output reg [15:0] data_o
  );

  wire read = 1'b1;

  reg [15:0] rom [0:((1<<memWidth_p) - 1)];
  initial $readmemh(dataFile_p, rom);

  always @(posedge clk_i) begin
    if (read) data_o <= rom[addr_i];
  end

endmodule
