#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
cat > "$tmp/stub.tcl" <<'STUB'
foreach c {read_verilog read_xdc synth_design write_checkpoint report_utilization report_timing_summary
           opt_design place_design route_design report_timing report_clock_utilization report_power} {
    proc $c {args} "puts \"STUB $c \$args\""
}
proc version {args} {return stub}
set ::env(OUT_DIR) $::env(STUB_OUT)
source scripts/vivado/synth_impl.tcl
STUB
STUB_OUT="$tmp/out" CLK_PERIOD_NS=8 tclsh "$tmp/stub.tcl" | tail -12
echo "tcl dry-run OK"
