# Contributing to AXIVEX

1. Keep synthesizable RTL (`rtl/`), testbenches (`tb/`), reference model (`reference/`), the Digital Twin
   (`digital-twin/`) and documentation (`docs/`) separate.
2. Any RTL change must keep `make test` green. Behaviour changes must also update the Digital Twin engine
   (`digital-twin/src/engine/sim.ts`) and refresh the committed RTL fixtures with `make fixtures`; the
   Vitest cross-validation will fail otherwise.
3. Run `make mutation` after touching RTL or testbenches: surviving non-equivalent mutants mean a test gap.
4. Never commit invented results. Synthesis, timing and power numbers must come from tool reports saved
   under `reports/` together with tool version, part and constraints.
5. Style: Verilog-2001 for RTL, nonblocking assignments in clocked blocks, explicit signed/width handling,
   synchronous active-low `rst_n`.
