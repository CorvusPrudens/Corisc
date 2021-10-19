# perform formal tests for all files

SRC = ..

COMMON_DIR = $(SRC)/common
LATTICE_DIR = $(SRC)/lattice
RV32I_DIR = $(SRC)/rv32i

COMMON_SBY = $(COMMON_DIR)/%.sby
# LATTICE_V = $(LATTICE_DIR)/%.v
# RV32I_V = $(RV32I_DIR)/%.v

$(COMMON_SBY): $(COMMON_DIR)/%.v
	python3 gensby.py $< -p

COMMON_CLEAN = $(COMMON_DIR)/%_clean

$(COMMON_CLEAN): $(COMMON_DIR)/%.v
	rm $<

all: $(addsuffix .sby, $(basename $(wildcard $(COMMON_DIR)/*.v)))

clean: $(addsuffix _clean, $(basename $(wildcard $(COMMON_DIR)/*.v)))