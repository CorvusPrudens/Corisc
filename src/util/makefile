# perform formal tests for all files

SRC = ..

FORMAL = formal

COMMON_DIR = $(SRC)/common
LATTICE_DIR = $(SRC)/lattice
RV32I_DIR = $(SRC)/rv32i

COMMON_SBY = $(COMMON_DIR)/%_sby
LATTICE_SBY = $(LATTICE_DIR)/%_sby
RV32I_SBY = $(RV32I_DIR)/%_sby

COMMON_FORMAL = $(COMMON_DIR)/%_formal
LATTICE_FORMAL = $(LATTICE_DIR)/%_formal
RV32I_FORMAL = $(RV32I_DIR)/%_formal

COMMON_CLEAN = $(COMMON_DIR)/%_clean
LATTICE_CLEAN = $(LATTICE_DIR)/%_clean
RV32I_CLEAN = $(RV32I_DIR)/%_clean

$(COMMON_SBY): $(COMMON_DIR)/%.v
	python3 gensby.py $< -p -f

$(LATTICE_SBY): $(LATTICE_DIR)/%.v
	python3 gensby.py $< -p -f

$(RV32I_SBY): $(RV32I_DIR)/%.v
	python3 gensby.py $< -p -f

$(COMMON_FORMAL): $(COMMON_DIR)/%.sby
	sby -f -d $(COMMON_DIR)/$(FORMAL) $<

$(LATTICE_FORMAL): $(LATTICE_DIR)/%.sby
	sby -f -d $(LATTICE_DIR)/$(FORMAL) $<

$(RV32I_FORMAL): $(RV32I_DIR)/%.sby
	sby -f -d $(RV32I_DIR)/$(FORMAL) $<

$(COMMON_CLEAN): $(COMMON_DIR)/%.sby
	rm $<

$(LATTICE_CLEAN): $(LATTICE_DIR)/%.sby
	rm $<

$(RV32I_CLEAN): $(RV32I_DIR)/%.sby
	rm $<

all: $(addsuffix _sby, $(basename $(wildcard $(COMMON_DIR)/*.v))) \
	$(addsuffix _sby, $(basename $(wildcard $(LATTICE_DIR)/*.v))) \
	$(addsuffix _sby, $(basename $(wildcard $(RV32I_DIR)/*.v))) \
	test
	
test: $(addsuffix _formal, $(basename $(wildcard $(COMMON_DIR)/*.sby))) \
	$(addsuffix _formal, $(basename $(wildcard $(LATTICE_DIR)/*.sby))) \
	$(addsuffix _formal, $(basename $(wildcard $(RV32I_DIR)/*.sby)))

clean_dirs:
		@ if [ -d "$(COMMON_DIR)/$(FORMAL)" ]; then rm -r $(COMMON_DIR)/$(FORMAL); fi
		@ if [ -d "$(LATTICE_DIR)/$(FORMAL)" ]; then rm -r $(LATTICE_DIR)/$(FORMAL); fi
		@ if [ -d "$(RV32I_DIR)/$(FORMAL)" ]; then rm -r $(RV32I_DIR)/$(FORMAL); fi

clean: $(addsuffix _clean, $(basename $(wildcard $(COMMON_DIR)/*.sby))) \
	$(addsuffix _clean, $(basename $(wildcard $(LATTICE_DIR)/*.sby))) \
	$(addsuffix _clean, $(basename $(wildcard $(RV32I_DIR)/*.sby))) \
	clean_dirs