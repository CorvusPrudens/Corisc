
CC = g++
BUILD = build
VERILATOR = verilator 
VERILATOR_FLAGS = -Wall -cc -O3 --x-assign fast --x-initial fast --noassert -Wno-UNUSED -Wno-UNSIGNED -CFLAGS "-O3" --Mdir $(BUILD)
VERILATOR_FLAGS_TRACE = -Wall -cc --trace --trace-max-array 64 -Wno-UNUSED -Wno-UNSIGNED -CFLAGS "-O3" --Mdir $(BUILD)
VERILOG_INCLUDES = \
-I../rv32i \
-I../rv32i/include \
-I../lattice \
-I../common
TARGET = rv32i

ELF_UTIL = ../util/read_elf
RCC = ~/Applications/riscv/bin/riscv32-unknown-elf-gcc
RLD = /home/corvus/Applications/riscv/bin/riscv32-unknown-elf-ld
LDSCRIPT = rv32i.lds
EXAMPLES = examples
TEST_TARGET = startup


CPP_SOURCES = src/sim.cpp \
/usr/local/share/verilator/include/verilated.cpp \
/usr/local/share/verilator/include/verilated_vcd_c.cpp 

CPP_INCLUDES = \
-Isrc \
-I$(BUILD) \
-I/usr/local/share/verilator/include

.PHONY: all compile_example clean verilate compile verilate_trace compile_trace trace

all: $(ELF_UTIL) $(BUILD) compile_example verilate compile

trace: $(ELF_UTIL) $(BUILD) compile_example verilate_trace compile_trace

$(BUILD):
	mkdir $(BUILD)

compile_example: $(EXAMPLES)/$(TEST_TARGET).c
	$(RCC) -c $(EXAMPLES)/$(TEST_TARGET).c -o $(BUILD)/$(TEST_TARGET)
	$(RLD) -T$(LDSCRIPT) $(BUILD)/$(TEST_TARGET) -o $(BUILD)/$(TEST_TARGET)_linked --print-memory-usage
	$(ELF_UTIL) $(BUILD)/$(TEST_TARGET)_linked -o $(BUILD)/program.hex

$(ELF_UTIL): $(ELF_UTIL).cpp
	$(CC) -std=c++17 -O3 $(ELF_UTIL).cpp -o $(ELF_UTIL) -I../util

verilate: src/sim.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILOG_INCLUDES) ../rv32i/$(TARGET).v -DSIM
	$(MAKE) -f V$(TARGET).mk -C $(BUILD)

compile:
	$(CC) -O3 -c $(CPP_SOURCES) $(CPP_INCLUDES)
	$(CC) *.o $(BUILD)/Vrv32i__ALL.o -o $(BUILD)/run
	rm *.o
	cp microcode.hex $(BUILD)

verilate_trace:
	$(VERILATOR) $(VERILATOR_FLAGS_TRACE) $(VERILOG_INCLUDES) ../rv32i/$(TARGET).v -DSIM
	$(MAKE) -f V$(TARGET).mk -C $(BUILD)

compile_trace:
	$(CC) -O3 -c $(CPP_SOURCES) $(CPP_INCLUDES) -DTRACE
	$(CC) *.o $(BUILD)/V$(TARGET)__ALL.o -o $(BUILD)/run
	rm *.o
	cp microcode.hex $(BUILD)

run:
	cd $(BUILD); ./run

view:
	gtkwave $(BUILD)/trace.vcd

clean:
	if [ -f "$(ELF_UTIL)" ]; then rm $(ELF_UTIL); fi
	if [ -d "$(BUILD)" ]; then rm -rf $(BUILD); fi