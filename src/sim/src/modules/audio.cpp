
#include "audio.h"
#include <cstring>

int countedFrames = 0;

SNDFILE* create_wav(const char* fname, int numFrames){

	SNDFILE* file = NULL;
  SF_INFO sfInfo;

  memset(&sfInfo, 0, sizeof(SF_INFO));

  sfInfo.samplerate = SAMPLE_RATE;
	sfInfo.frames = numFrames;
	sfInfo.channels = 1;
	sfInfo.format = SF_FORMAT_WAV | SF_FORMAT_PCM_16;

  file = sf_open(fname, SFM_WRITE, &sfInfo);

  return file;
}

SNDFILE* open_wav(const char* fname, int numFrames){

	SNDFILE* file = NULL;
  SF_INFO sfInfo;

  memset(&sfInfo, 0, sizeof(SF_INFO));

  sfInfo.samplerate = SAMPLE_RATE;
	sfInfo.frames = numFrames;
	sfInfo.channels = 1;
	sfInfo.format = SF_FORMAT_WAV | SF_FORMAT_PCM_16;

  file = sf_open(fname, SFM_READ, &sfInfo);

  return file;
}

void close_wave(SNDFILE* file) {
	sf_close(file);
}

void read_frame(SNDFILE* file, int16_t* frame) {
	sf_read_short(file, frame, SAMPLE_RATE);
}

void post_process(int16_t* buff, int numFrames) {

	long avgpos = 0;
	int margin = 512;

	for (int i = margin; i < numFrames - margin; i++) {
		avgpos += buff[i + margin];
	}

	float offset = (double) avgpos / (double) (numFrames - margin*2);


	for (int i = 0; i < numFrames; i++) {
		int temp = buff[i];
		temp -= offset;
		if (temp < -32768) temp = 0;
		else if (temp > 32767) temp = 0;
		buff[i] = temp;
	}

	margin = 1024;

	float targ1 = buff[margin];
	float targ2 = buff[numFrames - margin];

	float step1 = targ1/margin;
	float step2 = targ2/margin;

	for (int i = 0; i < margin; i++) {
			buff[i] = (int16_t)(i*step1);
			buff[numFrames - i] = (int16_t)(i*step2);
	}
}

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

void audioProcess(int16_t* file, int16_t sample) {
  static float audiostep = (14318180) / (float) SAMPLE_RATE;
  static int audiotick = 0;
  static float audiopos = 0;
  static float buffAcc = 0;
  static int accSteps = 0;

  buffAcc += sample;
  accSteps += 1;
  if (audiotick++ > audiopos*audiostep) {
		file[(int)audiopos] = (int16_t)(buffAcc/accSteps);
    audiopos += 1;
    buffAcc = 0;
    accSteps = 0;
		countedFrames++;
  }
}

void write_audio_buffer(SNDFILE* file, int16_t* buff, int numFrames) {
	sf_write_short(file, buff, numFrames);
}