#ifndef FLASH_H
#define FLASH_H

#include "defs.h"

uint8_t flash_write(uint8_t* data, size_t len, uint16_t page);
uint8_t flash_read(uint8_t* buffer, size_t len, uint16_t page);

#endif