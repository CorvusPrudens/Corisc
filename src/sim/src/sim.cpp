#include <cstring>

#ifndef TARGET
#define TARGET top
#endif

#ifndef TRACE_FILE
#define TRACE_FILE "trace.vcd"
#endif

#ifndef CLOCK_COUNT
#define CLOCK_COUNT 30000
#endif

#ifndef PROG_BIN
#define PROG_BIN "rv32i.bin"
#endif

#define CLOCK_NS (1000.0/14.31818)*10.0 // 14.31818 MHz to period w/ 100ps precision
#define CLOCK_PS CLOCK_NS * 100.0 // Apparently 1ps is gtkwave's thing
#define CLK_I clk_i

#include "Vrv32i.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include "uart.h"
#include "spi_flash.h"
#include "sram16.h"
#include "utils.h"

Sram16 sram;
Flash flash;

int main(int argc, char** argv) 
{
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);

  Vrv32i *tb = new Vrv32i;
  VerilatedVcdC* tfp = new VerilatedVcdC;

  unsigned logicStep = 0;

  #ifdef TRACE
    tb->trace(tfp, 99);
    tfp->open(TRACE_FILE);
  #endif

  size_t clock_count = CLOCK_COUNT;
  if (argc >= 2) {
    clock_count = atoi(argv[1]);
  }

  // UART vars
  int sendword = 0;
  int status = 0;
  int go = 0;
  int out = 0;
  tb->RX = 1;
  tick(tb, tfp, ++logicStep);

  // for (int i = 0; i < 256; i++)
  // {
  //   size_t address = 0x300000 + i;
  //   flash[address] = 255 - i;
  // }

  // Bootloader verification
  #ifdef BOOTLOADER
    size_t start_addr = 0x300000;
    size_t write_len = 256 * 256;
    flash.RandomFill(start_addr, write_len);

    for (size_t i = 0; i < clock_count; i++)
    {
      go = messageManagerStatic(status, &sendword, out, false);
      status = uart(tb, go, sendword, &out);
      tick(tb, tfp, ++logicStep);
    }

    bool success = true;
    uint8_t* ram_test = (uint8_t*) sram.memory;
    for (size_t i = start_addr; i < start_addr + write_len / 2 + 16; i++)
    {
      if (*ram_test++ != flash[i])
        success = false;
    }
    if (success)
      printf("Bootloader test passed!\n");
    else
      printf("Bootloader test failed :c\n");
  #else

    LoadProgram(PROG_BIN, (uint8_t*) sram.memory);
    for (size_t i = 0; i < clock_count; i++)
    {
      go = messageManagerStatic(status, &sendword, out, true);
      status = uart(tb, go, sendword, &out);
      tick(tb, tfp, ++logicStep);
    }
  #endif

  tb->final();
  delete tb;
  delete tfp;
}