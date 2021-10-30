#include "defs.h"
// #include "test.c"
extern void *_estack;
extern void *_sidata, *_sdata, *_edata;
extern void *_sisdata, *_ssdata, *_esdata;
extern void *_sbss, *_ebss;

void entry();
int main();
void systick();
void default_handler();

void * MEM_VECTOR_TABLE vector_table[] = {
  &entry,
  &systick,
  &default_handler,
  &default_handler,
  &default_handler,
  &default_handler,
};

volatile uint32_t counter = 0;

void OPT_Os INTERRUPT systick()
{
  counter++;
}

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

// TODO -- -O2 or higher causes this to fail
// TODO -- should be set to OPT_Os, but we'll need a memcpy and memset def
void OPT_O1 initialize_data()
{
  void **pSource, **pDest;
	for (pSource = &_sidata, pDest = &_sdata; pDest != &_edata; pSource++, pDest++)
		*pDest = *pSource;

  for (pSource = &_sisdata, pDest = &_ssdata; pDest != &_esdata; pSource++, pDest++)
		*pDest = *pSource;

	for (pDest = &_sbss; pDest != &_ebss; pDest++)
		*pDest = 0;
}

void __attribute__((naked, noreturn)) entry()
{
  asm("la sp, _estack");

  initialize_data();

  // __libc_init_array();
  main();
  for (;;);
}