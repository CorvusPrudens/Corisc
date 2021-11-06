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
  uint8_t channel;
  uint8_t type;
  uint8_t data[3];
} MidiMessage;

// TODO -- this functionality could totally be done in hardware if necessary
uint8_t MidiFetch();
// To be defined in the application
extern void MidiNoteOff(MidiMessage* message);
extern void MidiNoteOn(MidiMessage* message);
extern void MidiCC(MidiMessage* message);
extern void MidiPitchBend(MidiMessage* message);

#endif