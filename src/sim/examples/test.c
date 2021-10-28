#include "defs.h"

char* string = "Hello, world!";

void OPT_Os write_string(const char* str)
{
  for (const char* i = str; *i != 0; i++)
    UART = *i;
}

int32_t OPT_Os fib(int32_t term)
{
  if (term < 2)
    return term;
  else
    return fib(term - 1) + fib(term - 2);
}

int main() 
{
  volatile uint8_t temp;
  while (1)
  {
    if ((UART_STATUS & 0b1000) == 0)
    {
      temp = UART;
      UART = temp;
    }
  }
  
}