
#include "defs.h"
// #include "string.h"
#include "flash.h"


// uint8_t flash_buffer[256];
uint8_t* progmem_ptr;

void OPT_Os load_progmem(uint8_t* start_addr, uint16_t start_page, size_t num_pages)
{
  for (int page = start_page; page < start_page + num_pages; page++)
  {
    flash_read(start_addr, FLASH_PAGE_LEN, page);
    start_addr += FLASH_PAGE_LEN;
  }
}

int OPT_Os main()
{
  uint16_t page_addr = 0x3000;

  load_progmem((uint8_t*) MEM_PROGMEM_ADDR, page_addr, 256);

  // write_string("Completed program setup!\n");
}