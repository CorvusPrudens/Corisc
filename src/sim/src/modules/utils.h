#ifndef UTILS_H
#define UTILS_H

void LoadProgram(const char* filename, uint8_t* rambuff);

void tick(Vrv32i *tb, VerilatedVcdC *tfp, Sram16& sram, Flash& flash, uint8_t* disBuff, unsigned logicStep);

void updatePixels(uint8_t* disBuff, uint32_t* glBuff);

void updateDisBuff(uint8_t* disBuff, int cs, int sdi, int sck, int dc);

void writeFrame(uint8_t* frame, const char* path, int width, int height);

#endif