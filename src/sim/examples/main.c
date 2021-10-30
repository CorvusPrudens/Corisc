
#include "defs.h"
#include "gpu.h"

char* hey = "Hello, world!"; 

void OPT_Os main()
{
  GpuInit();
  SetGpuClear(0, 0);
  DrawString(hey, 32, 32);
}