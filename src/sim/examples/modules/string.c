#include "string.h"
#include "defs.h"

void OPT_Os write_string(const char* str)
{
  for (const char* i = str; *i != 0; i++)
    UART = *i;
  UART = (uint8_t) 0;
}