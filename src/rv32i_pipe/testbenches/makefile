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
-I..

CPP_SOURCES = tb.cpp \
${VERILATOR_INCL}/include/verilated.cpp \
${VERILATOR_INCL}/include/verilated_vcd_c.cpp  

CPP_INCLUDES = \
-I$(VERILATION) \
-I${VERILATOR_INCL}/include 

decode: $(VERILATION)
	$(MAKE) verilate TARGET=decode_tb

$(VERILATION): $(BUILD)
	mkdir -p $@

verilate: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(TARGET)
	$(MAKE) -j$(NPROC) -f V$(TARGET).mk -C $(VERILATION)