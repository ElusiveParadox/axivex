#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
VEC=${1:-reference/test_vectors/directed.txt}
VCD=${2:-reports/waveforms/axivex_directed.vcd}
mkdir -p build reports/waveforms
iverilog -g2012 -Wall -o build/top.out rtl/*.v tb/tb_axivex_top.sv
vvp build/top.out +VEC="$VEC" +OUT=build/sim_results.txt +VCD="$VCD" +SCEN
