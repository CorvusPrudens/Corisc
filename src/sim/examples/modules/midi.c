#include "midi.h"
#include "serial.h"

MidiMessage currentMessage;

uint8_t packet_offset = 0;
uint8_t data_valid = 0;

void MidiParse(MidiMessage* message);

uint8_t OPT_O3 MidiFetch()
{
  while (!uart_rx_empty())
  {
    uint8_t packet = UART;
    if (packet & STATUS)
    {
      currentMessage.channel = packet & 0xF;
      currentMessage.type = packet >> 4;
      data_valid = 0;
      packet_offset = 0;
    }
    else if (data_valid)
    {
      currentMessage.data[packet_offset++] = packet;
      if (packet_offset == 2)
      {
        // call midi parser
        MidiParse(&currentMessage);
        data_valid = 0;
      }
    }
  }
}

inline void OPT_O3 MidiParse(MidiMessage* message)
{
  switch (message->type)
  {
    case NOTE_OFF:
      MidiNoteOff(message);
      break;
    case NOTE_ON:
      MidiNoteOn(message);
      break;
    case CC:
      MidiCC(message);
      break;
    case PITCH_BEND:
      MidiPitchBend(message);
      break;
  }
}