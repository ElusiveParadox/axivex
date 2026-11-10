#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TOP=${TOP:-axivex_top}
RTL="rtl/mac_unit.v rtl/processing_element.v rtl/systolic_array_4x4.v rtl/input_buffers.v \
rtl/skew_scheduler.v rtl/array_controller.v rtl/output_buffer.v rtl/matrix_data_interface.v rtl/axivex_top.v"
mkdir -p reports/synthesis reports/utilization

{
  echo "tool:    $(yosys -V)"
  echo "date:    $(date -u +%F)"
  echo "top:     $TOP"
  echo "sources: $RTL"
} > reports/synthesis/yosys_header.txt

echo "[1/3] generic synthesis"
yosys -q -l reports/synthesis/yosys_generic.log -p "
  read_verilog $RTL
  hierarchy -check -top $TOP
  proc; opt; check -assert
  tee -o reports/synthesis/yosys_generic_hier_stat.txt stat
  synth -flatten -top $TOP
  check -assert
  tee -o reports/synthesis/yosys_generic_flat_stat.txt stat
  write_verilog -noattr reports/synthesis/axivex_generic_netlist.v
"

echo "[2/3] Xilinx 7-series mapping (synth_xilinx -family xc7)"
yosys -q -l reports/synthesis/yosys_xc7.log -p "
  read_verilog $RTL
  hierarchy -check -top $TOP
  synth_xilinx -family xc7 -top $TOP -flatten
  check -assert
  tee -o reports/utilization/yosys_xc7_utilization.txt stat
  write_verilog -noattr reports/synthesis/axivex_xc7_netlist.v
"
echo "[3/3] xc7 mapping without flattening (per-module breakdown)"
yosys -q -l reports/synthesis/yosys_xc7_hier.log -p "
  read_verilog $RTL
  hierarchy -check -top $TOP
  synth_xilinx -family xc7 -top $TOP
  tee -o reports/utilization/yosys_xc7_utilization_hier.txt stat
"
echo "done. See reports/synthesis and reports/utilization"
