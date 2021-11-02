#include "gpu.h"
#include "string.h"

volatile uint8_t newframe;

static void (*FrameCallback)();

volatile uint32_t* request_ptr = GPU_REQUEST_BUFFER;
volatile uint16_t* sprite_ptr = GPU_SPRITE_BUFFER;

uint16_t request_index;
uint16_t sprite_index;

const size_t request_end = 1024;
const size_t sprite_end = 1024;

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

void GpuEndFrame();
void GpuBeginFrame();

void OPT_Os INTERRUPT GpuHandler()
{
  newframe = 1;
}

static void OPT_O3 WriteRequest(SpriteInfo* req)
{
  if ((size_t) request_index < request_end && req->source->loaded)
  {
    // We really need to get multiplication / division in here
    uint16_t frame_offset = 0;
    for (uint16_t i = 0; i < req->frame; i++)
      frame_offset += req->source->width;

    // if (!req->enable_text)
    //   UART = frame_offset;
    // uint16_t frame_offset = req->source->width * req->frame;
    
    uint32_t request = (req->source->index + frame_offset) << 8;
    request |= req->color;
    request |= req->horizontal_flip << 1;
    request |= req->vertical_flip << 2;
    request |= req->enable_text << 3;
    request |= req->source->width << 4;
    request |= req->xpos << 16;
    request |= req->ypos << 24;

    request_ptr[request_index++] = request;
  }
}

static void OPT_O3 LoadSprite(SpriteSource* sprite)
{
  if (sprite_index + sprite->width - 1 < sprite_end)
  {
    sprite->index = sprite_index;
    uint16_t frame_offset = 0;
    for (uint16_t f = 0; f < sprite->frames; f++)
    {
      for (uint16_t i = 0; i < sprite->width; i++)
        sprite_ptr[sprite_index++] = sprite->location[i + frame_offset];
      frame_offset += sprite->width;
    }
    sprite->loaded = 1;
  }
  else
  {
    sprite->loaded = 0;
  }
}

void OPT_Os GpuInit(void (*callback)())
{
  FrameCallback = callback;
  ClearRequests();
  ClearSprites();
  SetGpuClear(1, 0);
  INTERRUPT_MASK |= GPU_INT_BIT;
}

void GpuProcess()
{
  if (newframe)
  {
    newframe = 0;
    GpuBeginFrame();
    (*FrameCallback)();
    GpuEndFrame();
  }
}

// Hm.. this wouldn't indicate if a sprite is loaded!
inline void OPT_Os ClearSprites()
{
  sprite_index = 0;
}

inline void OPT_Os ClearRequests()
{
  request_index = 0;
}

void OPT_O3 DrawSprite(SpriteInfo* info)
{
  if (info->source->loaded == 0)
    LoadSprite(info->source);
  WriteRequest(info);
}

inline void OPT_O3 DrawChar(char c, uint8_t xpos, uint8_t ypos)
{
  text_source.index = c;
  text_info.xpos = xpos;
  text_info.ypos = ypos;
  WriteRequest(&text_info);
}

void OPT_O3 DrawString(const char* s, uint8_t xpos, uint8_t ypos)
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

void OPT_Os GpuBeginFrame()
{
  ClearRequests();
}

void OPT_Os GpuEndFrame()
{
  const uint32_t end_request = 0x0000FF00;
  request_ptr[request_index] = end_request;
}