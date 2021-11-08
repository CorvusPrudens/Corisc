// TODO -- each testbench should have it's own cpp file so we can make 
// unit tests!! This is going to be absolutely critical for projects
// of this complexity

#ifndef TRACE_FILE
#define TRACE_FILE "trace.vcd"
#endif

#ifndef CLOCK_COUNT
#define CLOCK_COUNT 64
#endif

#ifndef TARGET
#define TARGET Vdecode_tb
#endif

#ifndef TARGET_HEADER
#define TARGET_HEADER "Vdecode_tb.h"
#endif

#define CLOCK_NS (1000.0/14.31818)*10.0 // 14.31818 MHz to period w/ 100ps precision
#define CLOCK_PS CLOCK_NS * 100.0 // Apparently 1ps is gtkwave's thing

#include TARGET_HEADER
#include "verilated.h"
#include "verilated_vcd_c.h"

void tick(TARGET* tb, VerilatedVcdC* tfp, size_t logicStep)
{
  tb->eval();

  if (tfp) tfp->dump(logicStep * CLOCK_PS - CLOCK_PS*0.2);

  tb->clk_i = 1;
  tb->eval();

  if (tfp) tfp->dump(logicStep * CLOCK_PS);

  tb->clk_i = 0;
  tb->eval();

  if (tfp){
    tfp->dump(logicStep * CLOCK_PS + CLOCK_PS*0.5);
    tfp->flush();
  }
}

int main(int argc, char** argv) 
{
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);
  size_t logicStep = 0;

  TARGET *tb = new TARGET;
  VerilatedVcdC* tfp = new VerilatedVcdC;

  tb->trace(tfp, 99);
  tfp->open(TRACE_FILE);

  tb->reset_i = 1;
  tick(tb, tfp, ++logicStep);
  tb->reset_i = 0;

  for (int i = 0; i < CLOCK_COUNT; i++)
    tick(tb, tfp, ++logicStep);

  // tb->reset_i = 1;
  // tick(tb, tfp, ++logicStep);
  // tb->reset_i = 0;

  // for (int i = 0; i < 10; i++)
  //   tick(tb, tfp, ++logicStep);
  
  delete tb;
  delete tfp;
}