# TODO -- we need to set up dead code stripping
UNAME := $(shell uname)
ifeq ($(UNAME), Linux)
NPROC = $$(nproc)
else
NPROC = 4
endif

CC = g++
BUILD = build
TRACE_FILE = $(BUILD)/trace.vcd
VERILATION = $(BUILD)/verilation
VERILATOR = verilator 
VERILATOR_FLAGS = -j -Wall -cc -O3 --x-assign fast --x-initial fast --noassert -Wno-UNUSED -Wno-UNSIGNED -CFLAGS "-O3" --Mdir $(VERILATION)
VERILATOR_FLAGS_TRACE = -j -Wall -cc --trace --trace-max-array 64 -Wno-UNUSED -Wno-UNSIGNED -CFLAGS "-O3" --Mdir $(VERILATION)
VERILOG_INCLUDES = \
-I../rv32i \
-I../rv32i/include \
-I../lattice \
-I../common
MICROCODE = ../rv32i/include/microcode.hex

ifeq ($(BOOTLOADER), 1)
VERILOG_DEFS = \
-DSIM \
-DMICROCODE_PATH=\"$(MICROCODE)\" \
-DPROGRAM_PATH=\"$(PROGRAM)\" \
-DBOOTLOADER

CPP_FLAGS = -DBOOTLOADER
else
VERILOG_DEFS = \
-DSIM \
-DMICROCODE_PATH=\"$(MICROCODE)\" \
-DPROGRAM_PATH=\"$(PROGRAM)\" 
endif
TARGET = rv32i

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

CPP_FLAGS += \
-std=c++17 \
-DTRACE_FILE=\"$(TRACE_FILE)\"

RISCV_SOURCES = \
examples/test.c \
examples/startup.c

BOOTLOADER_SOURCES = \
examples/bootloader.c \
examples/startup.c

RISCV_INCLUDES = \
-I./examples \
-I./examples/include

RISCV_FLAGS = -Wunused-function

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

all: $(ELF_UTIL) $(VERILATION) $(MICROCODE)
	$(MAKE) verilate PROGRAM=$(BUILD)/$(RISCV_TARGET).hex
	$(MAKE) -j$(NPROC) $(BUILD)/$(TARGET) CLOCK_COUNT="-DCLOCK_COUNT=14318180"
	$(MAKE) -j$(NPROC) $(BUILD)/$(RISCV_TARGET).hex 

trace: $(ELF_UTIL) $(VERILATION) $(MICROCODE)
	$(MAKE) verilate_trace PROGRAM=$(BUILD)/$(RISCV_TARGET).hex
	$(MAKE) -j$(NPROC) $(BUILD)/$(TARGET) TRACE="-DTRACE"
	$(MAKE) -j$(NPROC) $(BUILD)/$(RISCV_TARGET).hex

debug: $(ELF_UTIL) $(VERILATION) $(MICROCODE)
	$(MAKE) verilate_debug PROGRAM=$(BUILD)/$(RISCV_TARGET).hex
	$(MAKE) -j$(NPROC) $(BUILD)/$(TARGET) DEBUG=1
	$(MAKE) -j$(NPROC) $(BUILD)/$(RISCV_TARGET).hex

boot: $(ELF_UTIL) $(VERILATION) $(MICROCODE)
	$(MAKE) verilate_trace PROGRAM=$(BUILD)/$(BOOTLOADER_TARGET).hex BOOTLOADER=1
	$(MAKE) -j$(NPROC) $(BUILD)/$(TARGET) CLOCK_COUNT="-DCLOCK_COUNT=14318180" BOOTLOADER=1
	$(MAKE) -j$(NPROC) $(BUILD)/$(BOOTLOADER_TARGET).hex 

boot_trace: $(ELF_UTIL) $(VERILATION) $(MICROCODE)
	$(MAKE) verilate_trace PROGRAM=$(BUILD)/$(BOOTLOADER_TARGET).hex BOOTLOADER=1
	$(MAKE) -j$(NPROC) $(BUILD)/$(TARGET) TRACE="-DTRACE" BOOTLOADER=1
	$(MAKE) -j$(NPROC) $(BUILD)/$(BOOTLOADER_TARGET).hex

$(BUILD):
	mkdir -p $@

$(VERILATION): $(BUILD)
	mkdir -p $@

$(MICROCODE): $(MICROCODE:.hex=.py)
	cd $(dir $(MICROCODE)); python3 $(notdir $(MICROCODE:.hex=.py))

$(ELF_UTIL): $(ELF_UTIL).cpp
	$(CC) $(OPT) $(CPP_FLAGS) $< -o $@ -I../util

$(BUILD)/%.o: %.cpp makefile | $(BUILD)
	mkdir -p $(@D)
	$(CC) $(OPT) $(CPP_FLAGS) $(CLOCK_COUNT) $(CPP_INCLUDES) $(TRACE) -c $< -o $@ 

$(BUILD)/%.or: %.c makefile | $(BUILD)
	mkdir -p $(@D)
	$(RCC) $(RISCV_FLAGS) $(RISCV_INCLUDES) -c $< -o $@
	$(RCC) $(RISCV_FLAGS) $(RISCV_INCLUDES) -S $< -o $@.s

$(BUILD)/%.ob: %.c makefile | $(BUILD)
	mkdir -p $(@D)
	$(RCC) $(RISCV_FLAGS) $(RISCV_INCLUDES) -c $< -o $@
	$(RCC) $(RISCV_FLAGS) $(RISCV_INCLUDES) -S $< -o $@.s

$(BUILD)/$(TARGET): $(SORTED_OBJECTS) makefile
	$(CC) $(SORTED_OBJECTS) $(VERILATION)/V$(TARGET)__ALL.o -o $@

$(BUILD)/$(RISCV_TARGET).hex: $(SORTED_RISCV) $(LDSCRIPT) makefile
	$(RLD) $(LINKER_FLAGS) -T$(LDSCRIPT) $(SORTED_RISCV) \
		-o $(BUILD)/$(RISCV_TARGET).elf --print-memory-usage -Map $(BUILD)/$(RISCV_TARGET).map
	$(ELF_UTIL) $(BUILD)/$(RISCV_TARGET).elf -o $@
	$(ROBJ) -D -s $(BUILD)/$(RISCV_TARGET).elf > $(BUILD)/$(RISCV_TARGET).obj

$(BUILD)/$(BOOTLOADER_TARGET).hex: $(SORTED_BOOT) $(BOOT_LDSCRIPT) makefile
	$(RLD) $(LINKER_FLAGS) -T$(BOOT_LDSCRIPT) $(SORTED_BOOT) \
		-o $(BUILD)/$(BOOTLOADER_TARGET).elf --print-memory-usage -Map $(BUILD)/$(BOOTLOADER_TARGET).map
	$(ELF_UTIL) -b $(BUILD)/$(BOOTLOADER_TARGET).elf -o $@
	$(ROBJ) -D -s $(BUILD)/$(BOOTLOADER_TARGET).elf > $(BUILD)/$(BOOTLOADER_TARGET).obj

verilate: $(CPP_SOURCES) $(RISCV_SOURCES) $(BOOTLOADER_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILOG_INCLUDES) ../rv32i/$(TARGET).v $(VERILOG_DEFS)
	$(MAKE) -j$(NPROC) -f V$(TARGET).mk -C $(VERILATION)

verilate_trace: $(CPP_SOURCES) $(RISCV_SOURCES) $(BOOTLOADER_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS_TRACE) $(VERILOG_INCLUDES) ../rv32i/$(TARGET).v $(VERILOG_DEFS)
	$(MAKE) -j$(NPROC) OPT_FAST="-O3 -march=native" -f V$(TARGET).mk -C $(VERILATION)

verilate_debug: $(CPP_SOURCES) $(RISCV_SOURCES) $(BOOTLOADER_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS_TRACE) $(VERILOG_INCLUDES) ../rv32i/$(TARGET).v $(VERILOG_DEFS) -CFLAGS "-g"
	$(MAKE) OPT_GLOBAL="-O0" -f V$(TARGET).mk -C $(VERILATION) 

run:
	./$(BUILD)/$(TARGET)

view:
	gtkwave $(TRACE_FILE)

clean:
	rm -rf $(BUILD)

clean_all: clean
	rm -f $(ELF_UTIL)