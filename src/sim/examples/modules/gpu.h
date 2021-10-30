#ifndef GPU_H
#define GPU_H

#include "defs.h"

extern volatile uint16_t MEM_GPU FrameBuffer[512];
extern volatile uint32_t MEM_GPU RequestBuffer[256];
extern volatile uint16_t MEM_GPU SpriteBuffer[1024];
extern volatile uint16_t MEM_GPU CharacterBuffer[1024];

#define GPU_CLEAR_ENABLE *((volatile uint16_t*) 0x00004000)
#define GPU_CLEAR_WORD *((volatile uint16_t*) 0x00004002)

#define CHAR_WIDTH 4

typedef struct {
  uint16_t* location;
  int16_t index;
  uint8_t width;
  uint8_t frames;
  uint8_t loaded;
} SpriteSource;

typedef struct {
  SpriteSource* source;
  uint8_t enable_text;
  uint8_t vertical_flip;
  uint8_t horizontal_flip;
  uint8_t color;
  uint8_t xpos;
  uint8_t ypos;
  uint8_t frame;
} SpriteInfo;

void GpuHandler();
void GpuInit();
void DrawSprite(SpriteInfo* info);
void ClearSprites(); // maybe we should also have a `ClearSprite(SpriteSource* src)` function too
void ClearRequests();
void DrawChar(char c, uint8_t xpos, uint8_t ypos);
void DrawString(char* s, uint8_t xpos, uint8_t ypos);
void SetGpuClear(uint8_t enable, uint16_t clear_word);
// void WriteRequest(GpuRequest* req);

extern volatile uint32_t* request_ptr;
extern volatile uint16_t* sprite_ptr;

#endif