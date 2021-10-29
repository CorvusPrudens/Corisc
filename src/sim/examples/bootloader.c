
#include "defs.h"

// uint8_t flash_buffer[256];
uint8_t* progmem_ptr;

uint8_t OPT_Os flash_write(uint8_t* data, size_t len, uint16_t page)
{
  // for now we'll just write one page at a time
  if (len > 256)
    return 1;
  // Wait if a write is ongoing
  while (FLASH_STATUS & 1) {}

  for (uint16_t i = 0; i < len; i++)
  {
    FLASH_DATA = data[i];
  }

  FLASH_PAGE = page;

  uint16_t request = 0b00001000;

  if (page < 0x1000)
    request |= 0b10000000;
  if (page < 0x3000)
    request |= 0b01000000;

  FLASH_STATUS = request;
  return 0;
}

uint8_t OPT_Os flash_read(uint8_t* buffer, size_t len, uint16_t page)
{
  // for now we'll just write one page at a time
  if (len > 256)
    return 1;
  // Wait if a write is ongoing
  while (FLASH_STATUS & 1) {}

  FLASH_PAGE = page;
  uint16_t request = 0b00000100;
  FLASH_STATUS = request;

  while (FLASH_STATUS & 1) {}

  for (uint16_t i = 0; i < len; i++)
  {
    buffer[i] = FLASH_DATA;
  }
  return 0;
}

void OPT_Os load_progmem(uint8_t* start_addr, uint16_t start_page, size_t num_pages)
{
  for (int page = start_page; page < start_page + num_pages; page++)
  {
    flash_read(start_addr, FLASH_PAGE_LEN, page);
    start_addr += FLASH_PAGE_LEN;
  }
}

void OPT_Os write_string(const char* str)
{
  for (const char* i = str; *i != 0; i++)
    UART = *i;
}

int OPT_Os main()
{
  uint16_t page_addr = 0x3000;

  load_progmem((uint8_t*) MEM_PROGMEM_ADDR, page_addr, 256);

  write_string("Completed program setup!");
}