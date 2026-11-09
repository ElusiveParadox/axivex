#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
verilator --lint-only -Wall --top-module axivex_top rtl/*.v
echo "verilator lint clean"
