#ifndef AUDIO_H
#define AUDIO_H

#include <sndfile.h>
#include <cstdlib>
#define BUFFER_LEN 1024
#define SAMPLE_RATE 44100

extern int countedFrames;

SNDFILE* create_wav(const char* fname, int numFrames);

SNDFILE* open_wav(const char* fname, int numFrames);

void close_wave(SNDFILE* file);

void read_frame(SNDFILE* file, int16_t* frame);

void post_process(int16_t* buff, int numFrames);

// void audioProcess(SNDFILE* file, int16_t sample) {
//   static int16_t buff[BUFFER_LEN];
//   static float audiostep = (14318180) / (float) SAMPLE_RATE;
//   static int audiotick = 0;
//   static float audiopos = 0;
//   static float buffAcc = 0;
//   static int accSteps = 0;
//
//   buffAcc += sample;
//   accSteps += 1;
//   if (audiotick++ > audiopos*audiostep) {
//     audiopos += 1;
//     if ((int)audiopos % BUFFER_LEN == 0) {
//       sf_write_short(file, buff, BUFFER_LEN);
//     }
//     buff[(int)audiopos % BUFFER_LEN] = (int16_t)(buffAcc/accSteps);
//     // buff[audiopos % BUFFER_LEN] = sample;
//     buffAcc = 0;
//     accSteps = 0;
//   }
// }

void audioProcess(int16_t* file, int16_t sample);

void write_audio_buffer(SNDFILE* file, int16_t* buff, int numFrames);

#endif // AUDIO_H