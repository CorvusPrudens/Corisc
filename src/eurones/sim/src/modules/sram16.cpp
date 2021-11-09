#include "sram16.h"

Sram16::Sram16()
{
  RandomFill(0, sizeof(memory) / sizeof(memory[0]));
}

void Sram16::Tick(
  uint16_t input, 
  uint16_t* output, 
  uint16_t address,
  uint8_t write_enable, 
  uint8_t chip_enable, 
  uint8_t upper_byte_enable, 
  uint8_t lower_byte_enable, 
  uint8_t output_enable
)
{
  if (!chip_enable)
  {
    if (!write_enable)
    {
      uint16_t original = memory[address];
      if (!upper_byte_enable)
        original = (original & 0x00FF) | (input & 0xFF00);
      if (!lower_byte_enable)
        original = (original & 0xFF00) | (input & 0x00FF);
      memory[address] = original;
    }

    if (!output_enable)
    {
      *output = memory[address];
    }
    else
    {
      *output = std::rand() & 65535;
    }
  }
  else
  {
    *output = std::rand() & 65535;
  }
}

void Sram16::RandomFill(size_t startAddr, size_t length)
{
    for (int i = startAddr; i < startAddr + length; i++)
    {
        uint8_t random = std::rand() & 65535;
        memory[i] = random;
    }
}