#ifndef VOICE_H
#define VOICE_H

#include "defs.h"
#include "midi.h"

#define NUM_VOICES 7

typedef struct {
  uint8_t volume;
  uint8_t lastMidiNote;
  uint16_t tempFreq;

  uint16_t bendDepth;

  uint16_t vibrato;
  uint16_t vibratoCycles;

  uint8_t effect;

  uint16_t portDepth;
  uint16_t portAccum;
  uint16_t portStep;
  uint16_t portFinalFreq;
  uint16_t portNextFreq;
  int16_t portDirection; // a direction of 0 indicates inactive
  uint16_t portPrevNote;
} VoiceData;

extern VoiceData voices[NUM_VOICES];

extern uint8_t voice_midi_map[NUM_VOICES];
extern uint8_t voice_adc_map[NUM_VOICES];

void VoiceInit();
void VoiceProcess();

#endif // VOICE_H