# AXIVEX microarchitecture

Module map (all in `rtl/`, Verilog-2001, 9 modules):

```
axivex_top
 |- matrix_data_interface   start edge detect, accept/reject
 |- input_buffers           latch A,B on accept
 |- array_controller        FSM + cycle_count
 |- skew_scheduler          row/column injection (combinational)
 |- systolic_array_4x4      generate 4x4 mesh
 |   '- processing_element x16
 |       '- mac_unit        signed multiply + sign-extended add
 '- output_buffer           capture on result_valid, count, duplicate check
```

## processing_element

State: `a_out,b_out` (INT8), `a/b_valid_out`, `a/b_last_out`, `acc` (INT32), `result` (INT32), `result_valid`.

Per clock (synchronous, priority reset/clear):

1. `rst_n==0` or `clear_acc`: all registers (including the forwarding pipeline) <- 0.
2. Otherwise forward `a_in -> a_out`, `b_in -> b_out` and valid/last metadata; `result_valid <= 0`.
3. If `a_valid_in & b_valid_in`: `acc <= acc + a_in*b_in`; if also `a_last_in & b_last_in`: `result <= acc + a_in*b_in; result_valid <= 1`.

Both operands must be valid to accumulate, so a lone valid operand is ignored (unit-tested). In the aligned schedule
`a_valid == b_valid` always holds; the top-level monitor asserts this at all 16 PEs every cycle.

Mesh wiring (`systolic_array_4x4`): A link `(i,j)` index `i*5+j`, B link `(i,j)` index `i*4+j`; PE(i,j) reads
link (i,j) and drives link (i,j+1) (A) / (i+1,j) (B). Edge outputs terminate in unused wires (Verilator `UNUSEDSIGNAL` waived locally).

## skew_scheduler

For lane *n*, `diff = cycle_count - n` is computed with a borrow bit; `in_window = run & !borrow & (diff < 4)`,
`k = diff[1:0]`. Row lane *n* selects `A[n][k]`; column lane *n* selects `B[k][n]`. Outside the window data is 0.

## array_controller

Two-process FSM. `cycle_count` is cleared in CLEAR, increments in RUN (0..9) and continues (saturating at 15) in
RETIRE, so the final count (10) is visible in waveforms. RETIRE exits when the output buffer reports
`all_captured_next` (every element is either captured or pulsing this cycle): this is what makes DONE appear
exactly one cycle after the last result pulse and not one later.

## output_buffer

Per element: `valid` bit + 32-bit data written when that PE's `result_valid` is high; `clear` (accept) has priority.
`capture_count` adds the population count of this cycle's pulses (several PEs finish together). `capture_error` latches if a pulse
hits an already valid element. `all_valid` is the AND of the valid bits (used as `c_valid`).

## Resource view (Yosys)

See `reports/utilization/`. Flattened xc7 mapping: 16 DSP48E1, 1399 FDRE, 202 LUT2-6, 6 CARRY4 (+259 IBUF, 517 OBUF for the packed
ports). Without flattening: 16 DSP48E1, 2158 FDRE, 625 LUT2 and 136 CARRY4. The drop in flip-flops and carry chains after
flattening is an observed Yosys result; it is consistent with the accumulator being absorbed into the DSP48E1, but that
has not been confirmed in a netlist inspection. Vivado will map differently.
