#ifndef SRAM16_H
#define SRAM16_H

#include <cstdlib>
#include <cstdint>

class Sram16 {

  public:
    Sram16();
    ~Sram16() {}

    /** All enable inputs are active-low
     * 
     */
    void Tick(
      uint16_t input, 
      uint16_t* output, 
      uint16_t address,
      uint8_t write_enable, 
      uint8_t chip_enable, 
      uint8_t upper_byte_enable, 
      uint8_t lower_byte_enable, 
      uint8_t output_enable
    );

    void RandomFill(size_t startAddr, size_t length);

    uint16_t& operator[](size_t index) { return memory[index]; }

    private:
      uint16_t memory[65536];
};

#endif // SRAM16_H