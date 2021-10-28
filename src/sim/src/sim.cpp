#include <cstring>

#ifndef TARGET
#define TARGET top
#endif

#define CLOCK_NS (1000.0/14.31818)*10.0 // 14.31818 MHz to period w/ 100ps precision
#define CLOCK_PS CLOCK_NS * 10.0 // Apparently 10ps is gtkwave's thing
#define CLK_I clk_i

#include "Vrv32i.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include "uart.h"

void tick(Vrv32i *tb, VerilatedVcdC *tfp, unsigned logicStep)
{
  tb->eval();

  #ifdef TRACE
    if (tfp) tfp->dump(logicStep * CLOCK_PS - CLOCK_PS*0.2);
  #endif

  tb->CLK_I = 1;
  tb->eval();

  // do things with simulated components

  #ifdef TRACE
    if (tfp) tfp->dump(logicStep * CLOCK_PS);
  #endif
  tb->CLK_I = 0;
  tb->eval();

  // do some more things

  #ifdef TRACE
    if (tfp){
      tfp->dump(logicStep * CLOCK_PS + CLOCK_PS*0.5);
      tfp->flush();
    }
  #endif
}

int main(int argc, char** argv) 
{
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);

  Vrv32i *tb = new Vrv32i;
  VerilatedVcdC* tfp = new VerilatedVcdC;

  unsigned logicStep = 0;

  #ifdef TRACE
    tb->trace(tfp, 99);
    tfp->open("trace.vcd");
  #endif

  unsigned clock_count = 1000;
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

  for (size_t i = 0; i < clock_count; i++)
  {
    go = messageManagerStatic(status, &sendword, out);
    status = uart(tb, go, sendword, &out);
    tick(tb, tfp, ++logicStep);
  }

  tb->final();
  delete tb;
  delete tfp;
}