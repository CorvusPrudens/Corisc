#include "gpu.h"

volatile uint16_t MEM_GPU FrameBuffer[512];
volatile uint32_t MEM_GPU RequestBuffer[256];
volatile uint16_t MEM_GPU SpriteBuffer[1024];
volatile uint16_t MEM_GPU CharacterBuffer[1024];

volatile uint32_t* request_ptr;
volatile uint16_t* sprite_ptr;

const size_t request_end = (size_t) RequestBuffer + sizeof(RequestBuffer);
const size_t sprite_end = (size_t) SpriteBuffer + sizeof(SpriteBuffer);

SpriteSource text_source = {
  0,
  0,
  CHAR_WIDTH, // TODO -- this could easily be configurable
  1,
  1, // text is of course always loaded
};

SpriteInfo text_info = {
  &text_source,
  1,
  0,
  0,
  0,
  0,
  0,
  0,
};

void OPT_Os INTERRUPT GpuHandler()
{

}

static void OPT_O3 WriteRequest(SpriteInfo* req)
{
  if ((size_t) request_ptr < request_end)
  {
    // We really need to get multiplication / division in here
    int16_t frame_offset = 0;
    for (int16_t i = 0; i < req->frame; i++)
      frame_offset += req->source->width;
    
    int32_t request = (req->source->index + frame_offset) << 8;
    request |= req->color;
    request |= req->horizontal_flip << 1;
    request |= req->vertical_flip << 2;
    request |= req->enable_text << 3;
    request |= req->source->width << 4;
    request |= req->xpos << 16;
    request |= req->ypos << 24;

    *request_ptr++ = request;
  }
}

static void OPT_O3 LoadSprite(SpriteSource* sprite)
{
  if ((size_t) sprite_ptr + sprite->width - 1 < (size_t) sprite_end)
  {
    sprite->index = sprite_ptr - SpriteBuffer;
    int16_t frame_offset = 0;
    for (int16_t f = 0; f < sprite->frames; f++)
    {
      for (int16_t i = 0; i < sprite->width; i++)
        *sprite_ptr++ = sprite->location[i + frame_offset];
      frame_offset += sprite->width;
    }
    sprite->loaded = 1;
  }
  else
  {
    sprite->loaded = 0;
  }
}

void OPT_Os GpuInit()
{
  ClearRequests();
  ClearSprites();
  SetGpuClear(1, 0);
  INTERRUPT_MASK |= GPU_INT_BIT;
}

// Hm.. this wouldn't indicate if a sprite is loaded!
inline void OPT_Os ClearSprites()
{
  sprite_ptr = SpriteBuffer;
}

inline void OPT_Os ClearRequests()
{
  request_ptr = RequestBuffer;
}

void OPT_O3 DrawSprite(SpriteInfo* info)
{
  if (info->source->loaded == 0)
    LoadSprite(info->source);
  WriteRequest(info);
}

inline void OPT_O3 DrawChar(char c, uint8_t xpos, uint8_t ypos)
{
  text_source.index = (uint16_t) c << 2;
  text_info.xpos = xpos;
  text_info.ypos = ypos;
  WriteRequest(&text_info);
}

void OPT_O3 DrawString(char* s, uint8_t xpos, uint8_t ypos)
{
  for ( ; *s != 0; s++)
  {
    DrawChar(*s, xpos, ypos);
    xpos += CHAR_WIDTH;
  }
}

inline void OPT_Os SetGpuClear(uint8_t enable, uint16_t clear_word)
{
  GPU_CLEAR_ENABLE = enable;
  GPU_CLEAR_WORD = clear_word;
}