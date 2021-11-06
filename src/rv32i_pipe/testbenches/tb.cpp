// TODO -- each testbench should have it's own cpp file so we can make 
// unit tests!! This is going to be absolutely critical for projects
// of this complexity

#ifndef TRACE_FILE
#define TRACE_FILE "trace.vcd"
#endif

#ifndef CLOCK_COUNT
#define CLOCK_COUNT 32
#endif

#define STR(str) #str
#define STRING(str) STR(str)

#ifndef TARGET
#define TARGET decode_tb
#endif

#define CLOCK_NS (1000.0/14.31818)*10.0 // 14.31818 MHz to period w/ 100ps precision
#define CLOCK_PS CLOCK_NS * 100.0 // Apparently 1ps is gtkwave's thing

#define INCLUDE_STR STRING(TARGET) ## ".h"

#include INCLUDE_STR
#include "verilated.h"
#include "verilated_vcd_c.h"

void tick(TARGET* tb, VerilatedVcdC* tfp)
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

  TARGET *tb = new TARGET;
  VerilatedVcdC* tfp = new VerilatedVcdC;

  tb->trace(tfp, 99);
  tfp->open(TRACE_FILE);

  for (int i = 0; i < CLOCK_COUNT; i++)
    tick(tb, tfp);
  
  delete tb;
  delete tfp;
}