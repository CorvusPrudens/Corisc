#include <stddef.h>
// #include "test.c"
extern void *_estack;

// void __libc_init_array();
// int main();
void function();

void __attribute__((naked, noreturn)) entry()
{
  asm("lw sp, _estack");
  // __libc_init_array();
  // function();
  for (;;);
}