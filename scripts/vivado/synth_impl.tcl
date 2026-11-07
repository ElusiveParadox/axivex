# AXIVEX Vivado synthesis + implementation (out-of-context).
#
# Usage (Vivado on a supported Windows/Linux machine):
#   vivado -mode batch -source scripts/vivado/synth_impl.tcl
# Optional environment variables:
#   PART           target device            (default xc7a35tcpg236-1, reference part only)
#   CLK_PERIOD_NS  clock period override    (default: use constraints/axivex_artix7.xdc)
#   OUT_DIR        report directory         (default reports/vivado)
#   RUN_IMPL       1 = also place/route     (default 1)
# Reports are written only when the tool actually runs; nothing here is pre-filled.

proc env_or {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) }
    return $default
}

set part     [env_or PART xc7a35tcpg236-1]
set out_dir  [env_or OUT_DIR reports/vivado]
set run_impl [env_or RUN_IMPL 1]
set top      axivex_top
file mkdir $out_dir

set rtl [list \
    rtl/mac_unit.v rtl/processing_element.v rtl/systolic_array_4x4.v rtl/input_buffers.v \
    rtl/skew_scheduler.v rtl/array_controller.v rtl/output_buffer.v \
    rtl/matrix_data_interface.v rtl/axivex_top.v]
foreach f $rtl { read_verilog $f }

set period [env_or CLK_PERIOD_NS ""]
if {$period ne ""} {
    set xdc "$out_dir/clock_override.xdc"
    set fh [open $xdc w]
    puts $fh "create_clock -name sys_clk -period $period \[get_ports clk\]"
    close $fh
} else {
    set xdc constraints/axivex_artix7.xdc
}
read_xdc $xdc

# Out-of-context: the flat 259-in/517-out interface does not fit device pins.
synth_design -top $top -part $part -mode out_of_context
write_checkpoint -force $out_dir/post_synth.dcp
report_utilization    -file $out_dir/utilization_synth.rpt
report_timing_summary -file $out_dir/timing_synth.rpt

if {$run_impl} {
    opt_design
    place_design
    route_design
    write_checkpoint -force $out_dir/post_route.dcp
    report_utilization       -file $out_dir/utilization_impl.rpt
    report_utilization       -hierarchical -file $out_dir/utilization_impl_hier.rpt
    report_timing_summary    -file $out_dir/timing_impl.rpt
    report_timing -max_paths 5 -sort_by slack -file $out_dir/critical_paths.rpt
    report_clock_utilization -file $out_dir/clock_utilization.rpt
    report_power             -file $out_dir/power_estimate.rpt
}

set fh [open $out_dir/run_info.txt w]
puts $fh "vivado_version: [version -short]"
puts $fh "part: $part"
puts $fh "constraints: $xdc"
puts $fh "date: [clock format [clock seconds] -format %Y-%m-%d]"
close $fh
puts "AXIVEX Vivado flow finished; reports in $out_dir"
