
#include "defs.h"

const char* test = ("Hello, world!");

uint8_t arr[14];

int main()
{
  for (int i = 0; i < 14; i++)
    arr[i] = (uint8_t) test[i];

  for (int i = 0; i < 14; i++)
    UART = arr[i];
}