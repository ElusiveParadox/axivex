# AXIVEX Phase I build/test entry points
SHELL := /bin/bash
IVERILOG ?= iverilog
VVP      ?= vvp
RTL      := rtl/mac_unit.v rtl/processing_element.v rtl/systolic_array_4x4.v rtl/input_buffers.v \
            rtl/skew_scheduler.v rtl/array_controller.v rtl/output_buffer.v \
            rtl/matrix_data_interface.v rtl/axivex_top.v
VEC      := reference/test_vectors
BUILD    := build
IFLAGS   := -g2012 -Wall

.PHONY: fixtures all test test-mac test-pe test-outbuf mutation test-array test-top test-random test-python vectors lint wave synth bench clean

all: test

$(BUILD):
	mkdir -p $(BUILD) reports/waveforms reports/benchmarks

vectors:
	python3 reference/matrix_model.py

test: test-python test-mac test-pe test-outbuf test-array test-top test-random lint
	@echo "=== make test: ALL PASSED ==="

test-python:
	cd reference && python3 -m unittest -q test_matrix_model

test-mac: | $(BUILD)
	$(IVERILOG) $(IFLAGS) -o $(BUILD)/mac.out rtl/mac_unit.v tb/tb_mac_unit.sv
	$(VVP) $(BUILD)/mac.out | tee $(BUILD)/mac.log | grep -q "TEST_RESULT: PASS" && tail -3 $(BUILD)/mac.log | head -2

test-pe: | $(BUILD)
	$(IVERILOG) $(IFLAGS) -o $(BUILD)/pe.out rtl/mac_unit.v rtl/processing_element.v tb/tb_processing_element.sv
	$(VVP) $(BUILD)/pe.out | tee $(BUILD)/pe.log | grep -q "TEST_RESULT: PASS" && tail -3 $(BUILD)/pe.log | head -2

test-outbuf: | $(BUILD)
	$(IVERILOG) $(IFLAGS) -o $(BUILD)/outbuf.out rtl/output_buffer.v tb/tb_output_buffer.sv
	$(VVP) $(BUILD)/outbuf.out | tee $(BUILD)/outbuf.log | grep -q "TEST_RESULT: PASS" && tail -3 $(BUILD)/outbuf.log | head -2

test-array: | $(BUILD)
	$(IVERILOG) $(IFLAGS) -o $(BUILD)/array.out rtl/mac_unit.v rtl/processing_element.v rtl/systolic_array_4x4.v tb/tb_systolic_array.sv
	$(VVP) $(BUILD)/array.out | tee $(BUILD)/array.log | grep -q "TEST_RESULT: PASS" && tail -3 $(BUILD)/array.log | head -2

# directed vectors + scenarios (reset, busy, back-to-back, held start); cross-checked in Python
test-top: | $(BUILD)
	$(IVERILOG) $(IFLAGS) -o $(BUILD)/top.out $(RTL) tb/tb_axivex_top.sv
	$(VVP) $(BUILD)/top.out +VEC=$(VEC)/directed.txt +OUT=$(BUILD)/directed_rtl.txt \
	    +SCEN | tee $(BUILD)/top_scen.log | grep -E "tb_axivex_top:|TEST_RESULT|ERROR|FAIL"
	grep -q "TEST_RESULT: PASS" $(BUILD)/top_scen.log
	$(VVP) $(BUILD)/top.out +VEC=$(VEC)/directed.txt +OUT=$(BUILD)/directed_rtl.txt \
	    +TRACE=$(BUILD)/directed_trace.txt +TRACE_N=100 > $(BUILD)/top_dir.log
	grep -q "TEST_RESULT: PASS" $(BUILD)/top_dir.log
	python3 reference/comparison/compare_rtl.py --vec $(VEC)/directed.txt --rtl $(BUILD)/directed_rtl.txt \
	    --trace $(BUILD)/directed_trace.txt

# >= 100 seeded random transactions (seed recorded in $(VEC)/random_meta.json)
test-random: | $(BUILD)
	$(IVERILOG) $(IFLAGS) -o $(BUILD)/top.out $(RTL) tb/tb_axivex_top.sv
	$(VVP) $(BUILD)/top.out +VEC=$(VEC)/random.txt +OUT=$(BUILD)/random_rtl.txt | tee $(BUILD)/top_rand.log | grep -E "tb_axivex_top:|TEST_RESULT"
	grep -q "TEST_RESULT: PASS" $(BUILD)/top_rand.log
	python3 reference/comparison/compare_rtl.py --vec $(VEC)/random.txt --rtl $(BUILD)/random_rtl.txt
	@cat $(VEC)/random_meta.json; echo

lint:
	verilator --lint-only -Wall --top-module axivex_top $(RTL)
	@echo "verilator lint: clean"

# VCD for the first directed transaction set + GTKWave save file
wave: | $(BUILD)
	$(IVERILOG) $(IFLAGS) -o $(BUILD)/top.out $(RTL) tb/tb_axivex_top.sv
	$(VVP) $(BUILD)/top.out +VEC=$(VEC)/directed.txt +VCD=reports/waveforms/axivex_directed.vcd | tail -2
	@echo "open with: gtkwave reports/waveforms/axivex_directed.vcd reports/waveforms/axivex.gtkw"

synth:
	bash scripts/run_synthesis.sh

bench:
	python3 scripts/perf_report.py

clean:
	rm -rf $(BUILD)

# Refresh the committed RTL output used by the Digital Twin cross-validation tests
fixtures: test-top
	cp $(BUILD)/directed_rtl.txt reference/comparison/fixtures/rtl_directed_results.txt
	cp $(BUILD)/directed_trace.txt reference/comparison/fixtures/rtl_directed_trace.txt
	cp $(BUILD)/random_rtl.txt reference/comparison/fixtures/rtl_random_results.txt 2>/dev/null || true

mutation:
	python3 scripts/mutation_test.py
