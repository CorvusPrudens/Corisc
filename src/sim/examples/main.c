
#include "defs.h"
#include "gpu.h"
#include "string.h"

const char* hey = "Hello, there! How's it going?";
const char* str2 = "I feel nice... I think I'm ready to make some pretty pictures ^.^";

uint8_t xpos = 16;

void OPT_Os FrameCallback()
{
  uint8_t ypos = 16;
  for (int i = 0; i < 10; i++)
  {
    DrawString(hey, xpos + (i << 2), ypos);
    ypos += 6;
  }
  xpos++;
    
}

void OPT_Os main()
{
  GpuInit(&FrameCallback);

  while (1)
  {
    GpuProcess();
  }
}