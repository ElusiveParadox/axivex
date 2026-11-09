#!/usr/bin/env python3
import os, shutil, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RTL_FILES = ["mac_unit", "processing_element", "systolic_array_4x4", "input_buffers",
             "skew_scheduler", "array_controller", "output_buffer",
             "matrix_data_interface", "axivex_top"]

MUTANTS = [
    ("final result omits last product", "processing_element.v", "result       <= acc_next;", "result       <= acc;"),
    ("unsigned multiply", "mac_unit.v", "assign product = a * b;", "assign product = $unsigned(a) * $unsigned(b);"),
    ("zero- instead of sign-extension", "mac_unit.v", "{{EXT_W{product[PROD_W-1]}}, product}", "{{EXT_W{1'b0}}, product}"),
    ("B last marker on wrong term", "skew_scheduler.v", "assign b_last [n] = in_window && (k == 2'd3);", "assign b_last [n] = in_window && (k == 2'd2);"),
    ("B operand index off by one", "skew_scheduler.v", "b_mat[(k*4+n)*DATA_W +: DATA_W]", "b_mat[(((k+2'd1)&2'd3)*4+n)*DATA_W +: DATA_W]"),
    ("RUN window one cycle short", "axivex_top.v", ".LAST_CYCLE(9)", ".LAST_CYCLE(8)"),
    ("RETIRE exits without waiting (early done)", "array_controller.v", "S_RETIRE: if (all_captured_next)  next_state = S_DONE;", "S_RETIRE: next_state = S_DONE;"),
    ("accumulator not cleared by clear_acc", "processing_element.v", "if (!rst_n || clear_acc) begin", "if (!rst_n) begin"),
    ("output buffer not cleared on new job", "axivex_top.v", ".clear(start_accept)", ".clear(1'b0)"),
    ("A valid not forwarded east", "processing_element.v", "a_valid_out  <= a_valid_in;", "a_valid_out  <= 1'b0;"),
    ("A data forwarded with no register delay on B (b_out swapped to a_in)", "processing_element.v", "b_out        <= b_in;", "b_out        <= a_in;"),
    ("start is level- not edge-sensitive", "matrix_data_interface.v", "assign start_accept   = start_rise & ~busy;", "assign start_accept   = start & ~busy;"),
    ("controller not reset", "array_controller.v", "state       <= S_IDLE;\n            cycle_count <= {CNT_W{1'b0}};\n        end else begin", "state       <= state;\n            cycle_count <= cycle_count;\n        end else begin"),
    ("input buffers not latched (live ports)", "input_buffers.v", "end else if (load) begin", "end else begin"),
    ("result_valid sticky (never self-clears)", "processing_element.v", "            result_valid <= 1'b0;\n            if (fire) begin", "            if (fire) begin"),
    ("busy low during RUN", "array_controller.v", "(state == S_CLEAR) | (state == S_RUN) | (state == S_RETIRE)", "(state == S_CLEAR) | (state == S_RETIRE)"),
    ("DONE never returns to IDLE", "array_controller.v", "S_DONE:   next_state = start_accept ? S_CLEAR : S_IDLE;", "S_DONE:   next_state = S_DONE;"),
    ("c_valid asserted from capture of first element", "output_buffer.v", "assign all_valid         = &c_valid_bits;", "assign all_valid         = |c_valid_bits;"),
    ("duplicate capture not detected", "output_buffer.v", "if (|(result_valid & c_valid_bits)) capture_error <= 1'b1;", ""),
]

EQUIVALENT = {
    "RETIRE exits without waiting (early done)":
        "RETIRE always lasts exactly one cycle: the last PE result_valid coincides with the first RETIRE cycle, "
        "so the wait guard never has to stall. It becomes observable only if the array latency changes (Phase II).",
}


def sh(cmd, cwd, timeout=300):
    try:
        r = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout + r.stderr
    except subprocess.TimeoutExpired:
        return 124, "timeout"


def run_suite(d):
    rtl = " ".join(f"rtl/{f}.v" for f in RTL_FILES)
    steps = [
        ("pe",    f"iverilog -g2012 -o b/pe.out rtl/mac_unit.v rtl/processing_element.v tb/tb_processing_element.sv && vvp b/pe.out"),
        ("outbuf", f"iverilog -g2012 -o b/ob.out rtl/output_buffer.v tb/tb_output_buffer.sv && vvp b/ob.out"),
        ("array", f"iverilog -g2012 -o b/ar.out rtl/mac_unit.v rtl/processing_element.v rtl/systolic_array_4x4.v tb/tb_systolic_array.sv && vvp b/ar.out"),
        ("top",   f"iverilog -g2012 -o b/top.out {rtl} tb/tb_axivex_top.sv && vvp b/top.out +VEC=vec/directed.txt +SCEN"),
    ]
    for name, cmd in steps:
        rc, out = sh(cmd, d, 120)
        if rc != 0 or "TEST_RESULT: PASS" not in out:
            return name, out
    return None, ""


def main():
    survivors = []
    equiv = []
    for desc, fname, old, new in MUTANTS:
        with tempfile.TemporaryDirectory() as d:
            shutil.copytree(os.path.join(ROOT, "rtl"), os.path.join(d, "rtl"))
            shutil.copytree(os.path.join(ROOT, "tb"), os.path.join(d, "tb"))
            os.makedirs(os.path.join(d, "vec")); os.makedirs(os.path.join(d, "b"))
            shutil.copy(os.path.join(ROOT, "reference/test_vectors/directed.txt"), os.path.join(d, "vec"))
            p = os.path.join(d, "rtl", fname)
            s = open(p).read()
            if old not in s:
                print(f"[SETUP-ERROR] {desc}: pattern not found in {fname}")
                survivors.append(desc + " (pattern not found)")
                continue
            open(p, "w").write(s.replace(old, new, 1))
            where, _ = run_suite(d)
            if where:
                print(f"[KILLED  ] {desc}  (caught by {where} testbench)")
            elif desc in EQUIVALENT:
                print(f"[EQUIV   ] {desc}")
                equiv.append(desc)
            else:
                print(f"[SURVIVED] {desc}")
                survivors.append(desc)
    killed = len(MUTANTS) - len(survivors) - len(equiv)
    print(f"\n{killed}/{len(MUTANTS) - len(equiv)} non-equivalent mutants killed; {len(equiv)} equivalent")
    for e in equiv:
        print(f"  equivalent: {e}\n    reason: {EQUIVALENT[e]}")
    sys.exit(1 if survivors else 0)


if __name__ == "__main__":
    main()
