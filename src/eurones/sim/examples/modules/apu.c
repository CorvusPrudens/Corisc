#include "apu.h"
#include "defs.h"

uint32_t MusicCounter;
static void (*MusicCallback)();

SetVoice voice_setters[NUM_VOICES] = {
  &Set2a03Pulse1,
  &Set2a03Pulse2,
  &SetTriangle,
  &SetNoise,
  &SetVrc6Pulse1,
  &SetVrc6Pulse2,
  &SetSaw,
};

GetVoiceMidi voice_midi_getters[NUM_VOICES] = {
  &Get2a03Midi,
  &Get2a03Midi,
  &Get2a03Midi,
  &GetNoiseMidi,
  &GetVrc6Midi,
  &GetVrc6Midi,
  &GetSawMidi,
};

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

void OPT_O3 Set2a03Pulse1(uint16_t pitch, uint8_t volume, uint8_t duty)
{
  uint8_t temp = *PULSE1_CONF & 0b00110000;
  temp |= volume & 0b1111;
  temp |= duty << 6;
  *PULSE1_CONF = temp;
  *PULSE1_TIMERL = pitch;
  temp = *PULSE1_TIMERH & 0b11111000;
  temp |= (pitch >> 8) & 0b0111;
  *PULSE1_TIMERH = temp;
}

void OPT_O3 Set2a03Pulse2(uint16_t pitch, uint8_t volume, uint8_t duty)
{
  uint8_t temp = *PULSE2_CONF & 0b00110000;
  temp |= volume & 0b1111;
  temp |= duty << 6;
  *PULSE2_CONF = temp;
  *PULSE2_TIMERL = pitch;
  temp = *PULSE2_TIMERH & 0b11111000;
  temp |= (pitch >> 8) & 0b0111;
  *PULSE2_TIMERH = temp;
}

void OPT_O3 SetVrc6Pulse1(uint16_t pitch, uint8_t volume, uint8_t duty)
{
  uint8_t temp = *PULSE3_CONF & 0b10000000;
  temp |= volume & 0b1111;
  temp |= (duty << 6) & 0b10000000;
  *PULSE3_CONF = temp;
  *PULSE3_TIMERL = pitch;
  temp = *PULSE3_TIMERH & 0b11110000;
  temp |= (pitch >> 8) & 0b1111;
  *PULSE3_TIMERH = temp;
}

void OPT_O3 SetVrc6Pulse2(uint16_t pitch, uint8_t volume, uint8_t duty)
{
  uint8_t temp = *PULSE4_CONF & 0b10000000;
  temp |= volume & 0b1111;
  temp |= (duty << 6) & 0b10000000;
  *PULSE4_CONF = temp;
  *PULSE4_TIMERL = pitch;
  temp = *PULSE4_TIMERH & 0b11110000;
  temp |= (pitch >> 8) & 0b1111;
  *PULSE4_TIMERH = temp;
}

void OPT_O3 SetTriangle(uint16_t pitch, uint8_t volume, uint8_t effect)
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

void OPT_O3 SetSaw(uint16_t pitch, uint8_t volume, uint8_t effect)
{
  *SAW_VOL = volume;
  *SAW_TIMERL = pitch;
  uint8_t temp = *SAW_TIMERH & 0b11110000;
  temp |= (pitch >> 8) & 0b00001111;
  *SAW_TIMERH = temp;
}

void OPT_O3 SetNoise(uint16_t pitch, uint8_t volume, uint8_t type)
{
  uint8_t temp = *NOISE_CONF & 0b11110000;
  temp |= volume & 0b11110000;
  *NOISE_CONF = temp;
  *NOISE_TIMER = (type << 8) | (pitch & 0b1111);
}

uint16_t OPT_O3 Get2a03Midi(uint8_t note_number)
{
  
}

uint16_t OPT_O3 GetNoiseMidi(uint8_t note_number)
{

}

uint16_t OPT_O3 GetVrc6Midi(uint8_t note_number)
{

}

uint16_t OPT_O3 GetSawMidi(uint8_t note_number)
{

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