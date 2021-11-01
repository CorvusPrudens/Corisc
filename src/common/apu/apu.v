
/*
  The structure for these registers can be explained
  by the nesdev wiki. The starting address in the
  2A03 chip is 0x4000, which I've set to zero in the
  reg array <registers>.
*/

`include "audiotable.v"

module apu (
    input wire clk_i,
    input wire [5:0] addr_i,
    input wire [7:0] data_i,
    output reg [7:0] data_o,
    input wire write_i,

    output wire [15:0] master_o
  );

  parameter CLK_DIV = 3;

  reg [7:0] registers [0:33];

  always @(posedge clk_i) begin
    if (write_i) registers[addr_i] <= data_i;
    else data_o <= registers[addr_i];
  end

  reg [(CLK_DIV - 1):0] clk_acc;
  wire APUCLK;
  wire CPUCLK;

  wire en_pulse1 = registers[21][0];
  wire en_pulse2 = registers[21][1];
  wire en_tri = registers[21][2];
  wire en_noise = registers[21][3];
  wire en_dmc = registers[21][4];

  wire en_pulse3 = registers[26][7];
  wire en_pulse4 = registers[30][7];
  wire en_saw = registers[33][7];

  reg [3:0] pulse1_level;
  reg [2:0] pulse1_duty_step;
  reg [3:0] pulse2_level;
  reg [2:0] pulse2_duty_step;

  reg [3:0] tri_level;
  reg [4:0] tri_step;

  wire [3:0] noise_level;

  reg [3:0] pulse3_level;
  reg [3:0] pulse3_duty_step;
  reg [3:0] pulse4_level;
  reg [3:0] pulse4_duty_step;

  reg [7:0] saw_level_acc;
  wire [4:0] saw_level = saw_level_acc[7:3];
  reg [3:0] saw_step;
  wire [5:0] saw_rate = registers[31][5:0];


  wire [4:0] pulse_levels = pulse1_level + pulse2_level;
  // reg [7:0] tnd;

  wire [10:0] timer_pulse1 = {registers[3][2:0], registers[2]};
  wire [10:0] timer_pulse2 = {registers[7][2:0], registers[6]};
  wire [10:0] timer_tri = {registers[11][2:0], registers[10]};
  wire [3:0] pulse1_vol = registers[0][3:0];
  wire [1:0] pulse1_duty = registers[0][7:6];
  wire [3:0] pulse2_vol = registers[4][3:0];
  wire [1:0] pulse2_duty = registers[4][7:6];

  wire [3:0] noise_vol = registers[12][3:0];
  wire [3:0] noise_period = registers[14][3:0];
  wire noise_mode = registers[14][7];
  reg noise_feedback;

  wire pulse3_mode = registers[24][7];
  wire [3:0] pulse3_vol = registers[24][3:0];
  wire [2:0] pulse3_duty = registers[24][6:4];
  wire [11:0] timer_pulse3 = {registers[26][3:0], registers[25]};
  wire pulse4_mode = registers[28][7];
  wire [3:0] pulse4_vol = registers[28][3:0];
  wire [2:0] pulse4_duty = registers[28][6:4];
  wire [11:0] timer_pulse4 = {registers[30][3:0], registers[29]};
  wire [11:0] timer_saw = {registers[33][3:0], registers[32]};

  reg [10:0] acc_pulse1;
  reg [10:0] acc_pulse2;
  reg [10:0] acc_tri;
  reg [11:0] acc_noise;
  reg [11:0] acc_pulse3;
  reg [11:0] acc_pulse4;
  reg [11:0] acc_saw;

  reg [14:0] noise_shift = 15'h01;

  always @(posedge clk_i) clk_acc <= clk_acc + 1'b1;

  assign APUCLK = clk_acc[CLK_DIV - 1];
  assign CPUCLK = clk_acc[CLK_DIV - 2];

  wire [7:0] dutyTable1 [0:3];
  assign dutyTable1[0] = 8'b1000_0000;
  assign dutyTable1[1] = 8'b1100_0000;
  assign dutyTable1[2] = 8'b1111_0000;
  assign dutyTable1[3] = 8'b0011_1111;

  wire [7:0] dutyTable2 [0:3];
  assign dutyTable2[0] = 8'b1000_0000;
  assign dutyTable2[1] = 8'b1100_0000;
  assign dutyTable2[2] = 8'b1111_0000;
  assign dutyTable2[3] = 8'b0011_1111;

  reg [3:0] tritable [0:31];
  initial $readmemh("../cpu-arch/periphs/apu/triprom.hex", tritable);

  reg [11:0] noisetable [0:15];
  initial $readmemh("../cpu-arch/periphs/apu/noiseprom.hex", noisetable);

  always @(posedge APUCLK) begin

    // simplified control for testing
    if (en_pulse1) begin
      if (acc_pulse1 == 0) begin
        acc_pulse1 <= timer_pulse1;
        pulse1_duty_step <= pulse1_duty_step - 1'b1;
        pulse1_level <=
          dutyTable1[pulse1_duty][pulse1_duty_step] ? pulse1_vol : 4'b0;
      end else acc_pulse1 <= acc_pulse1 - 1'b1;
    end else pulse1_level <= 4'b0;

    if (en_pulse2) begin
      if (acc_pulse2 == 0) begin
        acc_pulse2 <= timer_pulse2;
        pulse2_duty_step <= pulse2_duty_step - 1'b1;
        pulse2_level <=
          dutyTable2[pulse2_duty][pulse2_duty_step] ? pulse2_vol : 4'b0;
      end else acc_pulse2 <= acc_pulse2 - 1'b1;
    end else pulse2_level <= 4'b0;

    if (en_pulse3) begin
      if (acc_pulse3 == 0) begin
        acc_pulse3 <= timer_pulse3;
        pulse3_duty_step <= pulse3_duty_step + 1'b1;
        if (~pulse3_mode)
          pulse3_level <= pulse3_duty_step > {1'b0, pulse3_duty} ? 4'b0 : pulse3_vol;
        else pulse3_level <= 4'hF;
      end else acc_pulse3 <= acc_pulse3 - 1'b1;
    end else begin
      pulse3_level <= 4'h0;
      acc_pulse3 <= 12'b0;
    end

    if (en_pulse4) begin
      if (acc_pulse4 == 0) begin
        acc_pulse4 <= timer_pulse4;
        pulse4_duty_step <= pulse4_duty_step + 1'b1;
        if (~pulse4_mode)
          pulse4_level <=
            pulse4_duty_step > {1'b0, pulse4_duty} ? 4'b0 : pulse4_vol;
        else pulse4_level <= 4'hF;
      end else acc_pulse4 <= acc_pulse4 - 1'b1;
    end else begin
      pulse4_level <= 4'h0;
      acc_pulse4 <= 12'b0;
    end

    if (en_saw) begin
      if (acc_saw == 0) begin
        acc_saw <= timer_saw;
        if (saw_step == 0) begin
          saw_level_acc <= 8'b0;
          saw_step <= saw_step + 1'b1;
        end else if (saw_step == 13) saw_step <= 0;
        else if (saw_step[0] == 1'b0) begin
          saw_level_acc <= saw_level_acc + {2'b0, saw_rate};
          saw_step <= saw_step + 1'b1;
        end else saw_step <= saw_step + 1'b1;
      end else acc_saw <= acc_saw - 1'b1;
    end else begin
      saw_level_acc <= 8'b0;
    end

  end

  // verilator lint_off BLKSEQ
  always @(posedge APUCLK) begin

    if (en_noise) begin
      if (acc_noise == 0) begin

        acc_noise = noisetable[noise_period];

        if (noise_mode) begin
          noise_feedback = noise_shift[6] ^ noise_shift[0];
          noise_shift = {noise_feedback, noise_shift[14:1]};
        end else begin
          noise_feedback = noise_shift[1] ^ noise_shift[0];
          noise_shift = {noise_feedback, noise_shift[14:1]};
        end
      end else acc_noise = acc_noise - 1'b1;
    end else noise_shift = 15'h01;

  end
  // verilator lint_on BLKSEQ

  // NOTE -- triangle ticks at twice APUCLK rate
  // always @(posedge CPUCLK) begin
  always @(posedge CPUCLK) begin

    if (en_tri) begin
      if (acc_tri == 0) begin
        acc_tri <= timer_tri;
        tri_step <= tri_step + 1'b1;
        tri_level <= tritable[tri_step];
      end else acc_tri <= acc_tri - 1'b1;
    end

  end

  assign noise_level = noise_shift[0] ? noise_vol : 4'b0;

  wire [15:0] mixed_pulses;
  wire [15:0] mixed_tnd;
  wire [15:0] mixed_vrc6;

  //verilator lint_off WIDTH
  wire [7:0] trimult = tri_level + tri_level + tri_level;
  wire [7:0] noisemult = noise_level + noise_level;
  wire [5:0] vrc6_sum = pulse3_level + pulse4_level + saw_level;
  //verilator lint_on WIDTH

  audiotable #(
      .memWidth_p(5),
      .dataFile_p("../cpu-arch/periphs/apu/pulseprom.hex")
    ) PULSEPROM(
      .clk_i(clk_i),
      .addr_i(pulse_levels),
      .data_o(mixed_pulses)
    );

  audiotable #(
      .memWidth_p(8),
      .dataFile_p("../cpu-arch/periphs/apu/tndprom.hex")
    ) TNDPROM(
      .clk_i(clk_i),
      .addr_i(trimult + noisemult),
      .data_o(mixed_tnd)
    );

  audiotable #(
      .memWidth_p(6),
      .dataFile_p("../cpu-arch/periphs/apu/vrc6prom.hex")
    ) VRC6PROM(
      .clk_i(clk_i),
      .addr_i(vrc6_sum),
      .data_o(mixed_vrc6)
    );

  assign master_o = mixed_pulses + mixed_tnd + mixed_vrc6;
  // assign master = mixed_tnd;
  // assign master = mixed_pulses;

endmodule
