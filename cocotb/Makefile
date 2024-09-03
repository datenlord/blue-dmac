ROOT_DIR = $(abspath ../)
BACKEND_DIR = $(ROOT_DIR)/backend
TB_DIR = $(abspath ./)
include $(ROOT_DIR)/Makefile.base
VBUILD_DIR = $(BACKEND_DIR)/build 
VSRC_DIR = $(BACKEND_DIR)/verilog

TARGET = RawDmaController
TOP_MODULE = mk$(TARGET)
TOP_FILE = $(TOP_MODULE).v
VLOG_FILE = $(TB_DIR)/$(TOP_FILE)

TB_CASE = dma_straddle
TB_FILE = $(TB_CASE)_tb.py
DATE = $(shell date "+%Y%m%d")
LOG_FILE = $(TB_DIR)/log/$(DATE)_$(TOP_MODULE).log

verilog:
	cd $(BACKEND_DIR) && make verilog

prepare:
	rm -rf $(VLOG_FILE)
	bluetcl $(BACKEND_DIR)/listVlogFiles.tcl -bdir $(VBUILD_DIR) -vdir $(VSRC_DIR) $(TOP_MODULE) $(TOP_MODULE) | grep -i '\.v' | xargs -I {} cat {} >> $(VLOG_FILE)
	sed -i '1i `timescale 1ns/1ps' $(VLOG_FILE)

run:
	cd $(TB_DIR)
	mkdir -p log
	python3 $(TB_FILE) 2>&1 | tee $(LOG_FILE)

cocotb:clean verilog prepare run

clean:
	cd $(BACKEND_DIR) && make clean
	cd $(TB_DIR) && rm -rf $(VLOG_FILE) __pycache__ .pytest_cache sim_build *.log 
	