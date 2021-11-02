#include "apu.h"
#include "defs.h"

uint32_t MusicCounter;
static void (*MusicCallback)();

static void EnableAll();

// The setup and teardown cost definitely sucks, but we'll have to deal with it for now
void INTERRUPT OPT_Os ApuHandler()
{
  MusicCounter++;
  (*MusicCallback)();
}

void OPT_Os ApuInit(void (*callback)())
{
  MusicCounter = 0;
  MusicCallback = callback;
  EnableAll();
  SilenceAll();
  // 1000 Hz interrupt rate
  TIMER_COMPARE = 14318;
  TIMER_STATE = 1;
  INTERRUPT_MASK |= TIMER_INT_BIT;
}

void OPT_Os Set2a03Pulse(uint16_t pitch, uint8_t volume, uint8_t duty, uint8_t index)
{
  volatile uint8_t* pulse = index ? PULSE2_CONF : PULSE1_CONF;
  uint8_t temp = *pulse & 0b00110000;
  temp |= volume & 0b1111;
  temp |= duty << 6;
  *pulse = temp;
  pulse += 2;
  *pulse++ = pitch;
  temp = *pulse & 0b11111000;
  temp |= (pitch >> 8) & 0b0111;
  *pulse = temp;
}

void OPT_Os SetVrc6Pulse(uint16_t pitch, uint8_t volume, uint8_t duty, uint8_t index)
{
  volatile uint8_t* pulse = index ? PULSE4_CONF : PULSE3_CONF;
  uint8_t temp = *pulse & 0b10000000;
  temp |= volume & 0b1111;
  temp |= (duty << 6) & 0b10000000;
  *pulse++ = temp;
  *pulse++ = pitch;
  temp = *pulse & 0b11110000;
  temp |= (pitch >> 8) & 0b1111;
  *pulse = temp;
}

void OPT_Os SetTriangle(uint16_t pitch, uint8_t volume)
{
  if (volume) 
  {
    *APU_STAT |= 0b0100;
    *TRI_TIMERL = pitch;
    uint8_t temp = *TRI_TIMERH & 0b11111000;
    temp |= (pitch >> 8) & 0b0111;
    *TRI_TIMERH = temp;
  } else 
  {
    *APU_STAT &= 0b11111011;
  }
}

void OPT_Os SetSaw(uint16_t pitch, uint8_t volume)
{
  *SAW_VOL = volume;
  *SAW_TIMERL = pitch;
  uint8_t temp = *SAW_TIMERH & 0b11110000;
  temp |= (pitch >> 8) & 0b00001111;
  *SAW_TIMERH = temp;
}

void OPT_Os SetNoise(uint8_t pitch, uint8_t volume, uint8_t type)
{
  uint8_t temp = *NOISE_CONF & 0b11110000;
  temp |= volume & 0b11110000;
  *NOISE_CONF = temp;
  *NOISE_TIMER = (type << 8) | (pitch & 0b1111);
}

// This actually excludes the Triangle, since the enable is how volume is controlled
inline void OPT_Os EnableAll()
{
  *APU_STAT = 0b00001011;
  *PULSE3_TIMERH |= 0b10000000;
  *PULSE4_TIMERH |= 0b10000000;
  *SAW_TIMERH |= 0b10000000;
}

inline void OPT_Os SilenceAll()
{
  *PULSE1_CONF &= 0b11110000;
  *PULSE2_CONF &= 0b11110000;
  *NOISE_CONF &= 0b11110000;
  *APU_STAT &= 0b11101011;

  *PULSE3_CONF &= 0b11110000;
  *PULSE4_CONF &= 0b11110000;
  *SAW_VOL &= 0b11000000;
}