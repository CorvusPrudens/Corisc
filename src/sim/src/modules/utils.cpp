#include <cstdio>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include "utils.h"

#include "Vrv32i.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "sram16.h"
#include "spi_flash.h"

void LoadProgram(const char* filename, uint8_t* rambuff)
{
  // Load in the program
  FILE* file = fopen(filename, "rb");
  if (file==NULL) {fputs ("Unable to open file!",stderr); exit (1);}

  fseek (file , 0 , SEEK_END);
  size_t program_size = ftell(file);
  rewind (file);

  uint8_t* program = (uint8_t*) malloc(program_size * sizeof(uint8_t));
  size_t bytes_read = fread(program, sizeof(uint8_t), program_size, file);
  fclose(file);

  for (size_t i = 0; i < program_size; i++)
  {
    rambuff[i] = program[i];
  }
}

void tick(Vrv32i *tb, VerilatedVcdC *tfp, Sram16& sram, Flash& flash, unsigned logicStep)
{
  tb->eval();

  #ifdef TRACE
    if (tfp) tfp->dump(logicStep * CLOCK_PS - CLOCK_PS*0.2);
  #endif

  tb->clk_i = 1;
  tb->eval();

  sram.Tick(
    tb->SRAM_O, 
    &tb->SRAM_I, 
    tb->SRAM_ADDR, 
    tb->SRAM_WE, 
    tb->SRAM_CE, 
    tb->SRAM_UB, 
    tb->SRAM_LB, 
    tb->SRAM_OE
  );
  flash.Tick(tb->FLASH_SDI, &tb->FLASH_SDO, tb->FLASH_SCK, tb->FLASH_CS);

  #ifdef TRACE
    if (tfp) tfp->dump(logicStep * CLOCK_PS);
  #endif

  tb->clk_i = 0;
  tb->eval();

  sram.Tick(
    tb->SRAM_O, 
    &tb->SRAM_I, 
    tb->SRAM_ADDR, 
    tb->SRAM_WE, 
    tb->SRAM_CE, 
    tb->SRAM_UB, 
    tb->SRAM_LB, 
    tb->SRAM_OE
  );
  flash.Tick(tb->FLASH_SDI, &tb->FLASH_SDO, tb->FLASH_SCK, tb->FLASH_CS);

  #ifdef TRACE
    if (tfp){
      tfp->dump(logicStep * CLOCK_PS + CLOCK_PS*0.5);
      tfp->flush();
    }
  #endif

}