#include <cstring>

#include "Vtop.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

void tick(Vtop *tb, VerilatedVcdC *tfp, unsigned logicStep)
{
  tb->eval();

  #ifdef TRACE
    if (tfp) tfp->dump(logicStep * CLOCK_NS - CLOCK_NS*0.2);
  #endif

  tb->CLK_I = 1;
  tb->eval();

  // do things with simulated components

  #ifdef TRACE
    if (tfp) tfp->dump(logicStep * CLOCK_NS);
  #endif
  tb->CLK_I = 0;
  tb->eval();

  // do some more things

  #ifdef TRACE
    if (tfp){
      tfp->dump(logicStep * CLOCK_NS + CLOCK_NS*0.5);
      tfp->flush();
    }
  #endif
}

int main(int argc, char** argv) 
{
  Verilated::commandArgs(argc, argv);

  Vtop *tb = new Vtop;
  unsigned logicStep = 0;

  #ifdef TRACE
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    tb->trace(tfp, 99);
    tfp->open("trace.vcd");
  #endif

  unsigned clock_count = 100;
  if (argc >= 2) {
    clock_count = atoi(argv[1]);
  }

  for (size_t i = 0; i < clock_count; i++)
  {
    tick(tb, nullptr, logicstep++);
  }

}