#ifndef MIDI_H
#define MIDI_H

#include "defs.h"

#define NOTE_OFF   0x8
#define NOTE_ON    0x9
#define POLY_PRES  0xA
#define CC         0xB
#define PC         0xC
#define CH_PRES    0xD
#define PITCH_BEND 0xE

#define CC_EFFECT 91
#define CC_VOL    11
#define CC_VIB    1
#define CC_PORT   5
#define CC_SCREEN 3

#define STATUS 0x80

#define NOTE_OFF_LEN   3
#define NOTE_ON_LEN    3
#define CC_LEN         3
#define PITCH_BEND_LEN 3

#define CC_MODWHEEL 1

#define NUM_CHANS 7

typedef struct {
  uint8_t volume;
  uint8_t lastNote;
  uint16_t tempFreq;

  uint16_t bendDepth;

  uint16_t vibrato;
  uint16_t vibratoCycles;

  uint16_t portDepth;
  uint16_t portAccum;
  uint16_t portStep;
  uint16_t portFinalFreq;
  uint16_t portNextFreq;
  uint16_t portDirection; // a direction of 0 indicates inactive
  uint16_t portPrevNote;
} ChannelData;

extern ChannelData channels[NUM_CHANS];

#endif