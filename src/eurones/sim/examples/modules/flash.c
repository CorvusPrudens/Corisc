#include "flash.h"

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