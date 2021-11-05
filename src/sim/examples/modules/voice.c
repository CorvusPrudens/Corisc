#include "voice.h"
#include "apu.h"

#define CV_MODE 0
#define MIDI_MODE 1

VoiceData voices[NUM_VOICES];
uint8_t voice_midi_map[NUM_VOICES]; // index -> voice, stored value -> associated midi channel
int8_t voice_midi_map_reverse[16]; // index -> midi channel, stored value -> associated voice (or -1 if unbound)
uint8_t voice_adc_map[NUM_VOICES];
uint8_t voice_mode[NUM_VOICES];

static inline void OPT_O3 apply_voice_data(uint8_t voice)
{
  VoiceData* data = &voices[voice];
  (*voice_setters[voice])(data->tempFreq, data->volume, data->effect);
}

void OPT_Os VoiceInit()
{
  for (unsigned i = 0; i < NUM_VOICES; i++)
  {
    voice_midi_map[i] = i;
    voice_midi_map_reverse[i] = i;
    voice_adc_map[i] = i;
    voice_mode[i] = 0;
  }
  for (unsigned i = NUM_VOICES; i < 16; i++)
    voice_midi_map_reverse[i] = -1;
}

void OPT_O3 VoiceProcess()
{
  MidiFetch();
  for (unsigned i = 0; i < NUM_VOICES; i++)
    apply_voice_data(i);
}

static inline uint8_t OPT_O3 check_mode(uint8_t voice)
{
  if (voice < 0)
    return 0;
  return voice_mode[voice];
}

void OPT_O3 MidiNoteOff(MidiMessage* message)
{
  int8_t voice = voice_midi_map_reverse[message->channel];
  if (check_mode(voice))
  {
    voices[voice].volume = 0;
  }
}

void OPT_O3 MidiNoteOn(MidiMessage* message)
{
  int8_t voice = voice_midi_map_reverse[message->channel];
  if (check_mode(voice))
  {
    voices[voice].tempFreq = (*voice_midi_getters[voice])(message->data[0]);
    voices[voice].volume = message->data[1] >> 4;
  }
}

void OPT_O3 MidiCC(MidiMessage* message)
{
  int8_t voice = voice_midi_map_reverse[message->channel];
  if (check_mode(voice))
  {
    switch (message->data[0])
    {
      case CC_EFFECT:
      {

      }
      break;
      case CC_VOL:
      {

      }
      break;
      case CC_VIB:
      {

      }
      break;
      case CC_PORT:
      {

      }
      break;
      case CC_SCREEN:
      {

      }
      break;
    }
  }
}

void OPT_O3 MidiPitchBend(MidiMessage* message)
{
  int8_t voice = voice_midi_map_reverse[message->channel];
  if (check_mode(voice))
  {

  }
}