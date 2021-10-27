#include "defs.h"

char* string = "Hello, world!";

void OPT_Os write_string(const char* str)
{
  for (const char* i = str; *i != 0; i++)
    UART = *i;
}

int main() {

  write_string(string);
  
}