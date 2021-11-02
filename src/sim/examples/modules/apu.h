#ifndef APU_H
#define APU_H

#include "defs.h"

#define PULSE1_CONF (volatile uint8_t*) 0x4000
#define PULSE1_SWEEP (volatile uint8_t*) 0x4001
#define PULSE1_TIMERL (volatile uint8_t*) 0x4002
#define PULSE1_TIMERH (volatile uint8_t*) 0x4003
// #define PULSE1_TIMER (volatile uint16_t*) 0x4002

#define PULSE2_CONF (volatile uint8_t*) 0x4004
#define PULSE2_SWEEP (volatile uint8_t*) 0x4005
#define PULSE2_TIMERL (volatile uint8_t*) 0x4006
#define PULSE2_TIMERH (volatile uint8_t*) 0x4007
// #define PULSE2_TIMER (volatile uint16_t*) 0x4006

#define TRI_CONF (volatile uint8_t*) 0x4008
#define TRI_TIMERL (volatile uint8_t*) 0x400A
#define TRI_TIMERH (volatile uint8_t*) 0x400B
// #define TRI_TIMER (volatile uint16_t*) 0x400A

#define NOISE_CONF (volatile uint8_t*) 0x400C
#define NOISE_TIMER (volatile uint8_t*) 0x400E
#define NOISE_LEN (volatile uint8_t*) 0x400F

#define DMC_CONF (volatile uint8_t*) 0x4010
#define DMC_LOAD (volatile uint8_t*) 0x4011
#define DMC_ADDR (volatile uint8_t*) 0x4012
#define DMC_LEN (volatile uint8_t*) 0x4013

#define APU_STAT (volatile uint8_t*) 0x4015

#define PULSE3_CONF (volatile uint8_t*) 0x9000
#define PULSE3_TIMERL (volatile uint8_t*) 0x9001
#define PULSE3_TIMERH (volatile uint8_t*) 0x9002

#define VRC6_FREQ (volatile uint8_t*) 0x9003

#define PULSE4_CONF (volatile uint8_t*) 0xA000
#define PULSE4_TIMERL (volatile uint8_t*) 0xA001
#define PULSE4_TIMERH (volatile uint8_t*) 0xA002

#define SAW_VOL (volatile uint8_t*) 0xB000
#define SAW_TIMERL (volatile uint8_t*) 0xB001
#define SAW_TIMERH (volatile uint8_t*) 0xB002

extern uint32_t MusicCounter;
void ApuHandler();

void ApuInit(void (*callback)());
void Set2a03Pulse(uint16_t pitch, uint8_t volume, uint8_t duty, uint8_t index);
void SetVrc6Pulse(uint16_t pitch, uint8_t volume, uint8_t duty, uint8_t index);
void SetTriangle(uint16_t pitch, uint8_t volume);
void SetSaw(uint16_t pitch, uint8_t volume);
void SetNoise(uint8_t pitch, uint8_t volume, uint8_t type);
void SilenceAll();
// void SetDcm(); // TODO -- need to figure this one out

#endif // APU_H