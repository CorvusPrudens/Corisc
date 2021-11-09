#include <cstdio>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include "utils.h"

#include "Veurones.h"
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

void tick(Veurones *tb, VerilatedVcdC *tfp, Sram16& sram, Flash& flash, uint8_t* disBuff, unsigned logicStep)
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

int currentChan = 0;
int endExecution = 0;
int currentCCval = 0;
int currentCCchan = 0;
int currentFrame = 0;
int buttPressed = 0;

void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods) {
  #define SCALE_LEN 18
  static int keyToNote[] = {
    // index indicates semitones
    GLFW_KEY_A, GLFW_KEY_W, GLFW_KEY_S, GLFW_KEY_E,
    GLFW_KEY_D, GLFW_KEY_F, GLFW_KEY_T, GLFW_KEY_G,
    GLFW_KEY_Y, GLFW_KEY_H, GLFW_KEY_U, GLFW_KEY_J,
    GLFW_KEY_K, GLFW_KEY_O, GLFW_KEY_L, GLFW_KEY_P,
    GLFW_KEY_SEMICOLON, GLFW_KEY_APOSTROPHE
  };
  #define NUM_INSTRUMENTS 7
  static int instruments[] = {
    GLFW_KEY_1, GLFW_KEY_2, GLFW_KEY_3, GLFW_KEY_4,
    GLFW_KEY_5, GLFW_KEY_6, GLFW_KEY_7
  };
  #define NUM_CC 9
  static int kpToCC[] = {
    GLFW_KEY_KP_1, GLFW_KEY_KP_2, GLFW_KEY_KP_3, GLFW_KEY_KP_4,
    GLFW_KEY_KP_5, GLFW_KEY_KP_6, GLFW_KEY_KP_7, GLFW_KEY_KP_8,
    GLFW_KEY_KP_9,
  };
  #define CC_LIST 5
  static int ccList[] = {
    CC_EFFECT, CC_VOL, CC_VIB, CC_PORT, CC_DISPLAY
  };
  if (action == GLFW_PRESS) {
    for (int i = 0; i < SCALE_LEN; i++) {
      if (key == keyToNote[i]) {
        int tempmess[] = {NOTE_ON | currentChan, i + ROOT, 64};
        // addMessage(tempmess, 3);
        break;
      }
    }
    for (int i = 0; i < NUM_INSTRUMENTS; i++) {
      if (key == instruments[i]) {
        currentChan = i;
        break;
      }
    }
    for (int i = 0; i < NUM_CC; i++) {
      if (key == kpToCC[i]) {
        int tempmess[] = {CC | currentChan, ccList[currentCCchan], i*(int)(127.0/9)};
        // addMessage(tempmess, 3);
        break;
      }
    }
    if (key == GLFW_KEY_ESCAPE) {
      endExecution = 1;
    } else if (key == GLFW_KEY_UP) {
      if (currentCCval < 7) currentCCval++;
      int tempmess[] = {CC | currentChan, ccList[currentCCchan], currentCCval << 4};
      // addMessage(tempmess, 3);
    } else if (key == GLFW_KEY_DOWN) {
      if (currentCCval > 0) currentCCval--;
      int tempmess[] = {CC | currentChan, ccList[currentCCchan], currentCCval << 4};
      // addMessage(tempmess, 3);
    } else if (key == GLFW_KEY_RIGHT) {
      currentCCchan = (currentCCchan + 1) % CC_LIST;
    } else if (key == GLFW_KEY_LEFT) {
      currentCCchan = (currentCCchan - 1) % CC_LIST;
    } else if (key == GLFW_KEY_P) {
      printf("Current frame: %d", currentFrame);
    } else if (key == GLFW_KEY_9) {
      int tempmess[] = {PITCH | currentChan, 127, 0};
      // addMessage(tempmess, 3);
    } else if (key == GLFW_KEY_0) {
      int tempmess[] = {PITCH | currentChan, 0, 0};
      // addMessage(tempmess, 3);
    } else if (key == GLFW_KEY_B) {
      buttPressed = 1;
    }
  } else if (action == GLFW_RELEASE) {
    for (int i = 0; i < SCALE_LEN; i++) {
      if (key == keyToNote[i]) {
        // release certain note
        int tempmess[] = {NOTE_ON | currentChan, i + ROOT, 0};
        // addMessage(tempmess, 3);
        break;
      }
    }
    if (key == GLFW_KEY_9 || key == GLFW_KEY_0) {
      int tempmess[] = {PITCH | currentChan, 64, 0};
      // addMessage(tempmess, 3);
    } else if (key == GLFW_KEY_B) {
      buttPressed = 0;
    }
  }
}