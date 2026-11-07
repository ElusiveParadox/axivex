# AXIVEX reference constraints (Artix-7).
#
# The 100 MHz period below is an ILLUSTRATIVE target, not a claimed result.
# scripts/vivado/synth_impl.tcl can override it with  CLK_PERIOD_NS=<ns>.
#
# NO PIN ASSIGNMENTS ARE PROVIDED ON PURPOSE.
# The Phase I top level exposes A (128 b), B (128 b) and C (512 b) as flat
# vectors: 259 input and 517 output bits. That exceeds the user I/O of the
# xc7a35tcpg236-1 package, so the design is synthesized/implemented
# out-of-context (-mode out_of_context). A board demo needs a narrow
# interface (UART/serial/BRAM), planned for Phase II.
create_clock -name sys_clk -period 10.000 [get_ports clk]
