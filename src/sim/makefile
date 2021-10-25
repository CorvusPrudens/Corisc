
CC = g++
VERILATOR = -Wall -cc -O3 --x-assign fast --x-initial fast --noassert
ELF_UTIL = ../util/read_elf
RCC = ~/Applications/riscv/bin/riscv32-unknown-elf-gcc
RLD = /home/corvus/Applications/riscv/bin/riscv32-unknown-elf-ld
LDSCRIPT = rv32i.lds
EXAMPLES = examples
TARGET = startup
BUILD = build

.PHONY: all compile_example clean

all: $(ELF_UTIL) $(BUILD) compile_example
	

$(BUILD):
	mkdir $(BUILD)

compile_example: $(EXAMPLES)/$(TARGET).c
	$(RCC) -c $(EXAMPLES)/$(TARGET).c -o $(BUILD)/$(TARGET)
	$(RLD) -T$(LDSCRIPT) $(BUILD)/$(TARGET) -o $(BUILD)/$(TARGET)_linked --print-memory-usage
	$(ELF_UTIL) $(BUILD)/$(TARGET)_linked -o $(BUILD)/exec.hex

$(ELF_UTIL): $(ELF_UTIL).cpp
	$(CC) -std=c++17 -O3 $(ELF_UTIL).cpp -o $(ELF_UTIL) -I../util

clean:
	if [ -f "$(ELF_UTIL)" ]; then rm $(ELF_UTIL); fi
	if [ -d "$(BUILD)" ]; then rm -rf $(BUILD); fi