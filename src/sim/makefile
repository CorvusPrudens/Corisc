
CC = g++
BUILD = build
VERILATION = $(BUILD)/verilation
VERILATOR = verilator 
VERILATOR_FLAGS = -j -Wall -cc -O3 --x-assign fast --x-initial fast --noassert -Wno-UNUSED -Wno-UNSIGNED -CFLAGS "-O3" --Mdir $(VERILATION)
VERILATOR_FLAGS_TRACE = -j -Wall -cc --trace --trace-max-array 64 -Wno-UNUSED -Wno-UNSIGNED -CFLAGS "-O3" --Mdir $(VERILATION)
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

RISCV_TARGET = riscv
BOOTLOADER_TARGET = bootloader

CPP_SOURCES = src/sim.cpp \
src/modules/spi_flash.cpp \
src/modules/sram16.cpp \
${VERILATOR_INCL}/include/verilated.cpp \
${VERILATOR_INCL}/include/verilated_vcd_c.cpp 

CPP_INCLUDES = \
-Isrc \
-Isrc/modules \
-I$(BUILD) \
-I$(VERILATION) \
-I${VERILATOR_INCL}/include 

CPP_FLAGS = \
-std=c++17

RISCV_SOURCES = \
examples/test.c \
examples/startup.c

BOOTLOADER_SOURCES = \
examples/bootloader.c \
examples/startup.c

RISCV_INCLUDES = \
-I./examples \
-I./examples/include

BOOTLOADER_FLAGS =

LINKER_FLAGS = 

ifeq ($(DEBUG), 1)
OPT = -O0
CPP_FLAGS += -g
else
OPT = -O3
endif

OBJECTS = $(addprefix $(BUILD)/,$(CPP_SOURCES:.cpp=.o))
vpath %.cpp $(sort $(dir $(CPP_SOURCES)))
SORTED_OBJECTS = $(sort $(OBJECTS))

RISCV_OBJECTS = $(addprefix $(BUILD)/,$(RISCV_SOURCES:.c=.or))
vpath %.c $(sort $(dir $(RISCV_SOURCES)))
SORTED_RISCV = $(sort $(RISCV_OBJECTS))

BOOTLOADER_OBJECTS = $(addprefix $(BUILD)/,$(BOOTLOADER_SOURCES:.c=.ob))
vpath %.c $(sort $(dir $(BOOTLOADER_SOURCES)))
SORTED_BOOT = $(sort $(BOOTLOADER_OBJECTS))

.PHONY: all compile_example clean verilate \
	compile verilate_trace compile_trace trace \
	debug verilate_debug compile_debug compile_bootloader

all: $(ELF_UTIL) $(VERILATION) $(BUILD)/$(RISCV_TARGET).hex verilate 
	$(MAKE) -j $(BUILD)/$(TARGET)

trace: $(ELF_UTIL) $(VERILATION) $(BUILD)/$(RISCV_TARGET).hex verilate_trace
	$(MAKE) -j $(BUILD)/$(TARGET) TRACE="-DTRACE"

debug: $(ELF_UTIL) $(VERILATION) $(BUILD)/$(RISCV_TARGET).hex verilate_debug
	$(MAKE) -j $(BUILD)/$(TARGET) DEBUG=1

boot: $(ELF_UTIL) $(VERILATION) $(BUILD)/$(BOOTLOADER_TARGET).hex verilate_trace
	$(MAKE) -j $(BUILD)/$(TARGET) TRACE="-DTRACE"

$(BUILD):
	mkdir -p $@

$(VERILATION): $(BUILD)
	mkdir -p $@

$(ELF_UTIL): $(ELF_UTIL).cpp
	$(CC) $(OPT) $(CPP_FLAGS) $< -o $@ -I../util

$(BUILD)/%.o: %.cpp makefile | $(BUILD)
	mkdir -p $(@D)
	$(CC) $(OPT) $(CPP_FLAGS) $(CPP_INCLUDES) $(TRACE) -c $< -o $@ 

$(BUILD)/%.or: %.c makefile | $(BUILD)
	mkdir -p $(@D)
	$(RCC) $(RISCV_INCLUDES) -c $< -o $@
	$(RCC) $(RISCV_INCLUDES) -S $< -o $@.s

$(BUILD)/%.ob: %.c makefile | $(BUILD)
	mkdir -p $(@D)
	$(RCC) $(BOOTLOADER_FLAGS) $(RISCV_INCLUDES) -c $< -o $@
	$(RCC) $(BOOTLOADER_FLAGS) $(RISCV_INCLUDES) -S $< -o $@.s

$(BUILD)/$(TARGET): $(SORTED_OBJECTS) $(MICROCODE) makefile
	$(CC) $(SORTED_OBJECTS) $(VERILATION)/V$(TARGET)__ALL.o -o $@
	cp $(MICROCODE) $(BUILD)

$(BUILD)/$(RISCV_TARGET).hex: $(SORTED_RISCV) makefile
	$(RLD) $(LINKER_FLAGS) -T$(LDSCRIPT) $(SORTED_RISCV) \
		-o $(BUILD)/$(RISCV_TARGET).elf --print-memory-usage -Map $(BUILD)/$(RISCV_TARGET).map
	$(ELF_UTIL) $(BUILD)/$(RISCV_TARGET).elf -o $@
	$(ROBJ) -D -s $(BUILD)/$(RISCV_TARGET).elf > $(BUILD)/$(RISCV_TARGET).obj

$(BUILD)/$(BOOTLOADER_TARGET).hex: $(SORTED_BOOT) makefile
	$(RLD) $(LINKER_FLAGS) -T$(BOOT_LDSCRIPT) $(SORTED_BOOT) \
		-o $(BUILD)/$(BOOTLOADER_TARGET).elf --print-memory-usage -Map $(BUILD)/$(BOOTLOADER_TARGET).map
	$(ELF_UTIL) -b $(BUILD)/$(BOOTLOADER_TARGET).elf -o $@
	$(ROBJ) -D -s $(BUILD)/$(BOOTLOADER_TARGET).elf > $(BUILD)/$(BOOTLOADER_TARGET).obj

verilate: src/sim.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILOG_INCLUDES) ../rv32i/$(TARGET).v -DSIM
	$(MAKE) -j -f V$(TARGET).mk -C $(VERILATION)

verilate_trace:
	$(VERILATOR) $(VERILATOR_FLAGS_TRACE) $(VERILOG_INCLUDES) ../rv32i/$(TARGET).v -DSIM
	$(MAKE) -j OPT_FAST="-O3 -march=native" -f V$(TARGET).mk -C $(VERILATION)

verilate_debug:
	$(VERILATOR) $(VERILATOR_FLAGS_TRACE) $(VERILOG_INCLUDES) ../rv32i/$(TARGET).v -DSIM
	$(MAKE) OPT_GLOBAL="-O0" -f V$(TARGET).mk -C $(VERILATION) -CFLAGS="-g"

run:
	cd $(BUILD); ./$(TARGET)

view:
	gtkwave $(BUILD)/trace.vcd

clean:
	if [ -d "$(BUILD)" ]; then rm -rf $(BUILD); fi

clean_all: clean
	if [ -f "$(ELF_UTIL)" ]; then rm $(ELF_UTIL); fi