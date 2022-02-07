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

CPP_SOURCES = \
${VERILATOR_INCL}/include/verilated.cpp \
${VERILATOR_INCL}/include/verilated_vcd_c.cpp  

CPP_INCLUDES = \
-I$(VERILATION) \
-I${VERILATOR_INCL}/include 

CPP_FLAGS += \
-std=c++17 

.PHONY: decode verilate compile run

decode: $(VERILATION)
	$(MAKE) verilate TARGET=decode_tb
	$(MAKE) compile TARGET=decode_tb
	$(MAKE) run TARGET=decode_tb

$(BUILD):
	mkdir -p $@

$(VERILATION): $(BUILD)
	mkdir -p $@

verilate:
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILOG_INCLUDES) $(TARGET).v
	$(MAKE) -j$(NPROC) -f V$(TARGET).mk -C $(VERILATION)

compile: 
	$(CC) $(CPP_FLAGS) $(TARGET).cpp $(CPP_SOURCES) \
		$(VERILATION)/V$(TARGET)__all.a $(CPP_INCLUDES) \
		-DTARGET=V$(TARGET) -DTARGET_HEADER=\"V$(TARGET).h\" \
		-DTRACE_FILE=\"$(BUILD)/$(TARGET)_trace.vcd\" \
		-o $(BUILD)/$(TARGET)

run:
	./$(BUILD)/$(TARGET)

formal:
	sby -f -d $(BUILD) decode.sby

clean:
	rm -rf $(BUILD)