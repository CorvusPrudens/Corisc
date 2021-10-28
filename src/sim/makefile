
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
MICROCODE = ../rv32i/include/microcode.hex

ELF_UTIL = ../util/read_elf
RCC = riscv32-unknown-elf-gcc
RLD = riscv32-unknown-elf-ld
ROBJ = riscv32-unknown-elf-objdump
LDSCRIPT = ../util/rv32i.lds
BOOT_LDSCRIPT = ../util/rv32i_boot.lds
EXAMPLES = examples
TEST_TARGET = startup


CPP_SOURCES = src/sim.cpp \
src/modules/spi_flash.cpp \
src/modules/sram16.cpp \
${VERILATOR_INCL}/include/verilated.cpp \
${VERILATOR_INCL}/include/verilated_vcd_c.cpp 

CPP_INCLUDES = \
-Isrc \
-Isrc/modules \
-I$(BUILD) \
-I${VERILATOR_INCL}/include 

CPP_FLAGS = \
-std=c++17

EXAMPLE_CPP_SOURCES = examples/test.c \
examples/startup.c

BOOTLOADER_CPP_SOURCES = examples/bootloader.c \
examples/startup.c

BOOTLOADER_FLAGS =

EXAMPLE_CPP_INCLUDES = \
-I./examples \
-I./examples/include

LINKER_FLAGS = 

.PHONY: all compile_example clean verilate \
	compile verilate_trace compile_trace trace \
	debug verilate_debug compile_debug compile_bootloader

all: $(ELF_UTIL) $(BUILD) compile_example verilate compile

trace: $(ELF_UTIL) $(BUILD) compile_example verilate_trace compile_trace

debug: $(ELF_UTIL) $(BUILD) compile_example verilate_debug compile_debug

boot: $(ELF_UTIL) $(BUILD) compile_bootloader verilate_trace compile_trace

$(BUILD):
	mkdir $(BUILD)

compile_example: $(EXAMPLES)/$(TEST_TARGET).c
	$(RCC) -c $(EXAMPLE_CPP_SOURCES) $(EXAMPLE_CPP_INCLUDES)
	$(RLD) $(LINKER_FLAGS) -T$(LDSCRIPT) *.o -o $(BUILD)/$(TEST_TARGET)_linked --print-memory-usage -Map $(BUILD)/$(TEST_TARGET)_map
	rm *.o
	$(ELF_UTIL) $(BUILD)/$(TEST_TARGET)_linked -o $(BUILD)/program.hex

compile_bootloader: $(EXAMPLES)/bootloader.c
	$(RCC) $(BOOTLOADER_FLAGS) -c $(BOOTLOADER_CPP_SOURCES) $(EXAMPLE_CPP_INCLUDES)
	$(RLD) $(LINKER_FLAGS) -T$(BOOT_LDSCRIPT) *.o -o $(BUILD)/$(TEST_TARGET)_linked --print-memory-usage -Map $(BUILD)/$(TEST_TARGET)_map
	rm *.o
	$(ELF_UTIL) -b $(BUILD)/$(TEST_TARGET)_linked -o $(BUILD)/program.hex

$(ELF_UTIL): $(ELF_UTIL).cpp
	$(CC) $(CPP_FLAGS) -O3 $(ELF_UTIL).cpp -o $(ELF_UTIL) -I../util

verilate: src/sim.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILOG_INCLUDES) ../rv32i/$(TARGET).v -DSIM
	$(MAKE) -f V$(TARGET).mk -C $(BUILD)

compile:
	$(CC) $(CPP_FLAGS) -O3 -c $(CPP_SOURCES) $(CPP_INCLUDES)
	$(CC) *.o $(BUILD)/Vrv32i__ALL.o -o $(BUILD)/run
	rm *.o
	cp $(MICROCODE) $(BUILD)

verilate_trace:
	$(VERILATOR) $(VERILATOR_FLAGS_TRACE) $(VERILOG_INCLUDES) ../rv32i/$(TARGET).v -DSIM
	$(MAKE) OPT_FAST="-O3 -march=native" -f V$(TARGET).mk -C $(BUILD)

compile_trace:
	$(CC) $(CPP_FLAGS) -O3 -c $(CPP_SOURCES) $(CPP_INCLUDES) -DTRACE
	$(CC) *.o $(BUILD)/V$(TARGET)__ALL.o -o $(BUILD)/run
	rm *.o
	cp $(MICROCODE) $(BUILD)

verilate_debug:
	$(VERILATOR) $(VERILATOR_FLAGS_TRACE) $(VERILOG_INCLUDES) ../rv32i/$(TARGET).v -DSIM
	$(MAKE) OPT_GLOBAL="-O0" -f V$(TARGET).mk -C $(BUILD) -CFLAGS="-g"

compile_debug:
	$(CC) $(CPP_FLAGS) -O0 -c -g $(CPP_SOURCES) $(CPP_INCLUDES) -DTRACE
	$(CC) *.o $(BUILD)/V$(TARGET)__ALL.o -o $(BUILD)/run
	rm *.o
	cp $(MICROCODE) $(BUILD)

assembly: compile_example
	$(RCC) -S $(EXAMPLE_CPP_SOURCES) $(EXAMPLE_CPP_INCLUDES)
	mv *.s $(BUILD)
	$(ROBJ) -D -s $(BUILD)/$(TEST_TARGET)_linked > $(BUILD)/$(TEST_TARGET).txt

boot_assembly:
	$(RCC) $(BOOTLOADER_FLAGS) -S $(BOOTLOADER_CPP_SOURCES) $(EXAMPLE_CPP_INCLUDES)
	mv *.s $(BUILD)
	$(ROBJ) -D -s $(BUILD)/$(TEST_TARGET)_linked > $(BUILD)/$(TEST_TARGET).txt

run:
	cd $(BUILD); ./run

view:
	gtkwave $(BUILD)/trace.vcd

clean:
	if test -n "$$(find . -maxdepth 1 -name '*.o' -print -quit)"; then rm *.o; fi
	if [ -d "$(BUILD)" ]; then rm -rf $(BUILD); fi

clean_all: clean
	if [ -f "$(ELF_UTIL)" ]; then rm $(ELF_UTIL); fi