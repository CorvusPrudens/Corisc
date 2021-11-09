
#include "defs.h"
#include "gpu.h"
#include "serial.h"
#include "apu.h"
#include "voice.h"

const char* hey = "Hello, there! How's it going?";
const char* str2 = "I feel nice... I think I'm ready to make some pretty pictures ^.^";

uint16_t downwell[] = {
  // Bitmap 0 (0, 0)
  0x0000, 0x0000, 0x0000, 0x4600, 0xE700, 0x7700, 0x3BC0, 0x0FE0, 0x17E0,
  0x1F20, 0x0FE0, 0x0400, 0x0000, 0x0000, 0x0000, 0x0000,
  // Bitmap 1 (1, 0)
  0x0000, 0x0000, 0x0000, 0x6000, 0x3000, 0x3700, 0x17C0, 0x09E0, 0x0FE0,
  0x1F20, 0x1FE0, 0x1800, 0x0000, 0x0000, 0x0000, 0x0000,
  // Bitmap 2 (2, 0)
  0x0000, 0x0000, 0x0000, 0x3000, 0x3800, 0x1BC0, 0x1BE0, 0x0A70, 0x05F0,
  0x0790, 0x0FF0, 0x0C00, 0x0800, 0x0000, 0x0000, 0x0000,
  // Bitmap 3 (3, 0)
  0x0000, 0x0000, 0x0000, 0x0800, 0x1800, 0x1DE0, 0x0DF0, 0x07B8, 0x0678,
  0x07C8, 0x0F78, 0x0E00, 0x0C00, 0x0000, 0x0000, 0x0000,
  // Bitmap 4 (0, 1)
  0x0000, 0x0000, 0x0000, 0x0000, 0x1800, 0x1BC0, 0x1BE0, 0x0F70, 0x0CF0,
  0x1F90, 0x3EF0, 0x7C00, 0x7800, 0x0000, 0x0000, 0x0000,
  // Bitmap 5 (1, 1)
  0x0000, 0x0000, 0x0000, 0x0000, 0x1300, 0x1BC0, 0x1FE0, 0x0CF0, 0x37F0,
  0xFF90, 0xFCF0, 0xC000, 0x0000, 0x0000, 0x0000, 0x0000,
  // Bitmap 6 (2, 1)
  0x0000, 0x0000, 0x0000, 0x0000, 0x0600, 0x2780, 0x33C0, 0x1FE0, 0xDFE0,
  0xE720, 0x9FE0, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
  // Bitmap 7 (3, 1)
  0x0000, 0x0000, 0x0000, 0x0C00, 0x0E00, 0x1700, 0x3F80, 0xBFC0, 0xDE40,
  0x0FC0, 0x0640, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
  // Bitmap 8 (0, 2)
  0x0000, 0x0000, 0x0C00, 0x0E00, 0x0700, 0x0380, 0xAFC0, 0xBFE0, 0x7E60,
  0x37E0, 0x0E60, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
  // Bitmap 9 (1, 2)
  0x0000, 0x0000, 0x0600, 0x0600, 0x0300, 0x6380, 0x2FC0, 0x1FE0, 0x3F20,
  0x37E0, 0x3720, 0x0300, 0x0000, 0x0000, 0x0000, 0x0000,
  // Bitmap 10 (2, 2)
  0x0000, 0x0000, 0x0180, 0x01C0, 0x31C0, 0x38E0, 0x0FE0, 0x1FF0, 0x1F90,
  0x3BF0, 0x3B90, 0x3180, 0x0180, 0x0000, 0x0000, 0x0000,
  // Bitmap 11 (3, 2)
  0x0000, 0x00C0, 0x00C0, 0x0060, 0x1860, 0x14F0, 0x0FF0, 0x0FF8, 0x1FC8,
  0x1DF8, 0x3CC8, 0x38C0, 0x30C0, 0x00C0, 0x0000, 0x0000,
  // Bitmap 12 (0, 3)
  0x0000, 0x00C0, 0x00C0, 0x00C0, 0x00E0, 0x11E0, 0x17E0, 0x0FF0, 0x1F90,
  0x1BF0, 0x7990, 0x61C0, 0x00C0, 0x00C0, 0x0000, 0x0000,
  // Bitmap 13 (1, 3)
  0x0000, 0x0000, 0x0180, 0x0180, 0x0380, 0xE7C0, 0xFFC0, 0xBFE0, 0x0F20,
  0x1FE0, 0x0F20, 0x0600, 0x0400, 0x0000, 0x0000, 0x0000,
  // Bitmap 14 (2, 3)
  0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
  0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
  // Bitmap 15 (3, 3)
  0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
  0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
};

SpriteSource downwell_src = {
  (uint16_t*) &downwell,
  0,
  16,
  14,
  0
};

SpriteInfo downwell_info = {
  &downwell_src,
  0,
  0,
  0,
  0,
  16,
  16,
  0,
};

uint8_t xpos = 16;
uint16_t tick = 0;

void OPT_Os FrameCallback()
{
  DrawString(hey, xpos++, 32);
  DrawSprite(&downwell_info);
  downwell_info.xpos++;
  if (tick++ & 1)
  {
    UART = downwell_info.frame++;
  }
    
  if (downwell_info.frame >= downwell_info.source->frames)
    downwell_info.frame = 0;
}

uint16_t freq = 0;

void OPT_Os MusicCallback()
{
  VoiceProcess();
}

int OPT_Os SimpleCalc(int a, int b)
{
  a += 20;
  b += a;
  return b;
}

void OPT_Os main()
{
  // VoiceInit();
  // GpuInit(&FrameCallback);
  // ApuInit(&MusicCallback);

  // while (1)
  // {
  //   GpuProcess();
  // }
  int temp = SimpleCalc(10, 20);
}