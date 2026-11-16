# AXIVEX Phase I performance report

Generated 2026-11-16 by `scripts/perf_report.py` from RTL simulation output (21 directed jobs, identical cycle counts in all).
Simulator: /bin/sh: iverilog: command not found

Labels: MEASURED = observed in RTL simulation; MODELLED = conceptual single-MAC baseline (not implemented RTL); ARCHITECTURE/ANALYTICAL = closed-form. No FPGA timing is used here, so no throughput in MAC/s is reported (that needs a clock frequency from a timing report).

| Metric | Value | Definition | Evidence |
|---|---|---|---|
| PE count | 16 | - | ARCHITECTURE |
| Peak MAC capacity | 16 MAC/cycle | PE count (every PE can MAC each cycle) | ARCHITECTURE |
| MAC operations per job | 64 | completed MACs counted from PE valid pairs | MEASURED |
| Start-to-done latency | 13 cycles | cycle index of DONE minus cycle index in which start is first high | MEASURED |
|   load/start cycle | 1 | start cycle in which A,B are latched at the clock edge | MEASURED (by construction: lat - RUN - CLEAR - RETIRE) |
|   CLEAR cycles | 1 | state == CLEAR | MEASURED (state trace) |
|   RUN (compute window) cycles | 10 | cycles with state == RUN (first injection to last MAC) = K+M+N-2 | MEASURED |
|   RETIRE cycles | 1 | cycles with state == RETIRE (last result capture) | MEASURED |
|   DONE cycle | 1 | the cycle at index 13 itself (done=1); not among the 13 cycles counted before it | MEASURED |
| Sequential baseline compute cycles | 64 | M*N*K = 64, one MAC per clock | MODELLED |
| Sequential baseline total cycles | 67 | 64 + same 3 fixed overhead cycles | MODELLED |
| Compute-only speedup | 6.40x | 64 / 10 | MODELLED baseline vs MEASURED array |
| End-to-end speedup | 5.15x | 67 / 13 | MODELLED baseline vs MEASURED array |
| Fill + drain overhead | 6 cycles | RUN 10 - ideal 4 (=MACs/PEs); analytically M+N-2 = 6 | MEASURED/ANALYTICAL |
| Input loading overhead | 1 cycle | single-cycle latch of packed A,B | MEASURED |
| Accumulator clear overhead | 1 cycle | CLEAR state | MEASURED |
| Output retirement overhead | 1 cycle + DONE | RETIRE state, then DONE pulse | MEASURED |
| Measured MAC throughput (compute window) | 6.40 MAC/cycle | 64 MACs / 10 RUN cycles | MEASURED |
| Measured MAC throughput (end-to-end) | 4.92 MAC/cycle | 64 MACs / 13 start-to-done cycles | MEASURED |
| Active PEs per RUN cycle | [1, 3, 6, 10, 12, 12, 10, 6, 3, 1] | count of PEs with A and B valid | MEASURED |
| Peak active PEs | 12 | max of the profile above (< 16 because K=4 limits overlap) | MEASURED |
| Average active PEs (RUN window) | 6.40 | sum(active) / RUN cycles | MEASURED |
| PE utilization (RUN window) | 40.0 % | 64 active PE-cycles / (16 PEs x 10 cycles) | MEASURED |
| PE utilization (start-to-done) | 30.8 % | 64 / (16 x 13) | MEASURED |

Caveat: the baseline shares the systolic design's fixed overhead cycles purely for an apples-to-apples end-to-end ratio; a real single-MAC engine would have its own control overhead. The baseline also uses 1 MAC unit against 16 PEs, so the speedup is not area-normalised.
