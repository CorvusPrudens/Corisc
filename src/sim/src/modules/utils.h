#ifndef UTILS_H
#define UTILS_H

void LoadProgram(const char* filename, uint8_t* rambuff);

void tick(Vrv32i *tb, VerilatedVcdC *tfp, Sram16& sram, Flash& flash, unsigned logicStep);

#endif