#ifndef UTILS_H
#define UTILS_H

#include "Vrv32i.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "sram16.h"
#include "spi_flash.h"

#include <GL/glew.h>
#include <GLFW/glfw3.h>

void LoadProgram(const char* filename, uint8_t* rambuff);

void tick(Vrv32i *tb, VerilatedVcdC *tfp, Sram16& sram, Flash& flash, uint8_t* disBuff, unsigned logicStep);

void updatePixels(uint8_t* disBuff, uint32_t* glBuff, int width, int height);

void updateDisBuff(uint8_t* disBuff, int cs, int sdi, int sck, int dc);

void writeFrame(uint8_t* frame, const char* path, int width, int height);

#define NOTE_ON 0x90
#define NOTE_OFF 0x80
#define CC 0xB0
#define PITCH 0xE0
#define CC_EFFECT 91
#define CC_VOL 11
#define CC_PORT 5
#define CC_VIB 1
#define CC_DISPLAY 3
#define ROOT 36

extern int endExecution;
extern int currentFrame;

void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods);

#endif