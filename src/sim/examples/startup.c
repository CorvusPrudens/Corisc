#include <stddef.h>
#include <stdint.h>
// #include "test.c"
extern void *_estack;

uint8_t word;
uint8_t word2;

// void __libc_init_array();
// int main();
void function();

void __attribute__((naked, noreturn)) entry()
{
  asm("la sp, _estack");
  word = 32;
  word2 = word;
  // __libc_init_array();
  // function();
  for (;;);
}