# Vivado flow

Vivado is not supported on macOS. Run this on Windows 10/11 or a supported x86-64 Linux machine with a
Vivado Basic install (check AMD UG973 for the current supported-OS and license information).

    vivado -mode batch -source scripts/vivado/synth_impl.tcl
    PART=xc7a100tcsg324-1 CLK_PERIOD_NS=8 vivado -mode batch -source scripts/vivado/synth_impl.tcl

Produces `reports/vivado/*.rpt` and `run_info.txt` (tool version, part, constraints, date).
Copy those reports into `reports/utilization` / `reports/timing` when committing results.

Status in this repository: the scripts were syntax-checked with a Tcl stub harness only
(`scripts/vivado/check_tcl.sh`); Vivado itself has NOT been run for Phase I, so no Vivado
utilization, timing, Fmax or power numbers exist yet. Power estimates, if produced, are estimates.
