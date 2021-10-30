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

void tick(Vrv32i *tb, VerilatedVcdC *tfp, Sram16& sram, Flash& flash, uint8_t* disBuff, unsigned logicStep)
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
  updateDisBuff(disBuff, tb->DIS_CS, tb->DIS_SDI, tb->DIS_SCK, tb->DIS_DC);

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

void updatePixels(uint8_t* disBuff, uint32_t* glBuff, int width, int height) {
  for (int y = 0; y < height; y++){
    for (int x = 0; x < width; x++){
      int index = x + (y/8)*128;
      int bitpos = y % 8;

      if ((disBuff[index] & (1 << bitpos)) > 0){
        glBuff[x + y*width] = 0xFF00FFFF; // yellow to match current display
      } else {
        glBuff[x + y*width] = 0xFF000000;
      }
    }
  }
}

void updateDisBuff(uint8_t* disBuff, int cs, int sdi, int sck, int dc) {
  static int inbuff = 0;
  static int bitpos = 7;
  static int rising = 0;
  static int prevClkPos = 0;
  static int currentAddr = 0;
  static int counter1 = 0;
  static int counter2 = 0;

  if (cs == 0 && dc == 1) {
    if (prevClkPos == 0 && sck == 1) {
      if (sdi == 1) {
        inbuff |= (1 << bitpos);
      }

      prevClkPos = 1;
      bitpos -= 1;
      if (bitpos == -1) {
        bitpos = 7;
        disBuff[currentAddr++] = (uint8_t)inbuff;
        if (currentAddr == 1024) {
          currentAddr = 0;
        }
        inbuff = 0;
      }
    } else if (sck == 0) {
      prevClkPos = 0;
    }
  }
}

static inline void fileValid(FILE* f, const char* path) {
  if (f == NULL) {
    printf("Error: unable to open file \"%s\"", path);
    exit(1);
  }
}

void writeFrame(uint8_t* frame, const char* path, int width, int height) {
  FILE* file = fopen(path, "ab");
  fileValid(file, path);
  fwrite(frame, sizeof(uint8_t), width*(height/8), file);
  fclose(file);
}