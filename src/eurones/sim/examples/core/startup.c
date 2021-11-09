#include "defs.h"

extern void *_estack;
extern void *_sidata, *_sdata, *_edata;
extern void *_sbss, *_ebss;

void entry();
int main();

#ifndef BOOTLOADER
void ApuHandler();
void GpuHandler();
#endif
void default_handler();

void * MEM_VECTOR_TABLE vector_table[] = {
  &entry,
  #ifndef BOOTLOADER
  &ApuHandler,
  &GpuHandler,
  #else
  &default_handler,
  &default_handler,
  #endif
  &default_handler,
  &default_handler,
  &default_handler,
};

void OPT_Os INTERRUPT default_handler()
{

}

// void * OPT_O3 memcpy(void* dest, const void* src, unsigned int count)
// {
//   uint8_t* dest_ = (uint8_t*) dest;
//   uint8_t* src_ = (uint8_t*) src_;
//   for (unsigned int i = 0; i < count; i++)
//     *dest_++ = *src_++;
//   return dest;
// }

// void * OPT_O3 memset(void * dest, int value, unsigned int count)
// {
//   uint8_t* dest_ = (uint8_t*) dest;
//   for (unsigned int i = 0; i < count; i++)
//     *(uint8_t*)dest_++ = (uint8_t)value;
//   return dest;
// }

void OPT_O1 initialize_data()
{
  // Casting to uint32_t facilitates faster reads and writes
  uint32_t **pSource, **pDest;
	for (pSource = (uint32_t**)&(_sidata), pDest =  (uint32_t**)&_sdata; pDest !=  (uint32_t**)&_edata; pSource++, pDest++)
		*pDest = *pSource;

	for (pDest =  (uint32_t**)&_sbss; pDest !=  (uint32_t**)&_ebss; pDest++)
		*pDest = 0;
}

void __attribute__((naked, noreturn)) entry()
{
  asm("la sp, _estack");

  // initialize_data();

  main();
  for (;;);
}