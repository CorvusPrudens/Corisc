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
VERILATOR_FLAGS = -j -Wall -cc --trace --trace-max-array 64 -Wno-UNUSED -Wno-UNSIGNED -CFLAGS "-O3" --Mdir $(VERILATION)
VERILOG_INCLUDES = \
-I.. \
-I../../rv32i_pipe \
-I../../common

CPP_SOURCES = \
${VERILATOR_INCL}/include/verilated.cpp \
${VERILATOR_INCL}/include/verilated_vcd_c.cpp  

CPP_INCLUDES = \
-I$(VERILATION) \
-I${VERILATOR_INCL}/include 

CPP_FLAGS += \
-std=c++17 

RCC = riscv32-unknown-elf-gcc
ROBJ = riscv32-unknown-elf-objdump

.PHONY: pipe verilate compile run

eurones: $(VERILATION)
	$(MAKE) asm
	$(MAKE) verilate TARGET=eurones
	$(MAKE) compile TARGET=eurones
	$(MAKE) run TARGET=eurones

asm: 
	$(RCC) -c eurones.s -o eurones.o
	$(ROBJ) -w -d eurones.o > $(BUILD)/eurones.txt
	rm eurones.o
	python3 quickndirty.py

$(BUILD):
	mkdir -p $@

$(VERILATION): $(BUILD)
	mkdir -p $@

verilate:
	$(VERILATOR) -DPROGRAM_PATH=\"build/eurones.hex\" $(VERILATOR_FLAGS) $(VERILOG_INCLUDES) ../$(TARGET).v
	$(MAKE) -j$(NPROC) -f V$(TARGET).mk -C $(VERILATION)

compile: 
	$(CC) $(CPP_FLAGS) $(TARGET).cpp $(CPP_SOURCES) \
		$(VERILATION)/V$(TARGET)__ALL.a $(CPP_INCLUDES) \
		-DTARGET=V$(TARGET) -DTARGET_HEADER=\"V$(TARGET).h\" \
		-DTRACE_FILE=\"$(BUILD)/$(TARGET)_trace.vcd\" \
		-o $(BUILD)/$(TARGET)

run:
	./$(BUILD)/$(TARGET)

clean:
	rm -rf $(BUILD)