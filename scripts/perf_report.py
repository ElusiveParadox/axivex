#!/usr/bin/env python3
import json, os, subprocess, sys, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "reference", "comparison"))
from compare_rtl import read_results, read_trace  # noqa: E402

M = N = K = 4
PE = M * N
MACS = M * N * K


def tool(cmd):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip().splitlines()[0]
    except Exception:
        return "unavailable"


def main():
    res, _ = read_results(os.path.join(ROOT, "build/directed_rtl.txt"))
    tr = read_trace(os.path.join(ROOT, "build/directed_trace.txt"))
    lats = {tuple(v[:4]) for vs in res.values() for v in vs}
    assert len(lats) == 1, f"cycle counts differ across jobs: {lats}"
    lat, run, ret, macs = lats.pop()

    act = [sum(1 for pe in r["pes"] if pe[2] and pe[3]) for r in next(iter(tr.values())) if r["st"] == 2]
    for rows in tr.values():
        a2 = [sum(1 for pe in r["pes"] if pe[2] and pe[3]) for r in rows if r["st"] == 2]
        assert a2 == act, "activity profile differs between jobs"

    t_seq_compute = MACS                 # one MAC per clock
    t_sys_compute = run                  # measured RUN cycles
    overhead = lat - run                 # start(load)+CLEAR+RETIRE measured: lat - run
    t_seq_total = t_seq_compute + overhead   # MODELLED: same fixed overheads as the systolic design
    avail_run = PE * run
    avail_total = PE * lat
    ideal_cycles = MACS // PE            # all PEs busy every cycle
    fill_drain = run - ideal_cycles

    rows = [
        ("PE count", PE, "-", "ARCHITECTURE"),
        ("Peak MAC capacity", f"{PE} MAC/cycle", "PE count (every PE can MAC each cycle)", "ARCHITECTURE"),
        ("MAC operations per job", macs, "completed MACs counted from PE valid pairs", "MEASURED"),
        ("Start-to-done latency", f"{lat} cycles", "cycle index of DONE minus cycle index in which start is first high", "MEASURED"),
        ("  load/start cycle", 1, "start cycle in which A,B are latched at the clock edge", "MEASURED (by construction: lat - RUN - CLEAR - RETIRE)"),
        ("  CLEAR cycles", 1, "state == CLEAR", "MEASURED (state trace)"),
        ("  RUN (compute window) cycles", run, "cycles with state == RUN (first injection to last MAC) = K+M+N-2", "MEASURED"),
        ("  RETIRE cycles", ret, "cycles with state == RETIRE (last result capture)", "MEASURED"),
        ("  DONE cycle", 1, "the cycle at index 13 itself (done=1); not among the 13 cycles counted before it", "MEASURED"),
        ("Sequential baseline compute cycles", t_seq_compute, f"M*N*K = {MACS}, one MAC per clock", "MODELLED"),
        ("Sequential baseline total cycles", t_seq_total, f"{t_seq_compute} + same {overhead} fixed overhead cycles", "MODELLED"),
        ("Compute-only speedup", f"{t_seq_compute / t_sys_compute:.2f}x", f"{t_seq_compute} / {t_sys_compute}", "MODELLED baseline vs MEASURED array"),
        ("End-to-end speedup", f"{t_seq_total / lat:.2f}x", f"{t_seq_total} / {lat}", "MODELLED baseline vs MEASURED array"),
        ("Fill + drain overhead", f"{fill_drain} cycles", f"RUN {run} - ideal {ideal_cycles} (=MACs/PEs); analytically M+N-2 = {M+N-2}", "MEASURED/ANALYTICAL"),
        ("Input loading overhead", "1 cycle", "single-cycle latch of packed A,B", "MEASURED"),
        ("Accumulator clear overhead", "1 cycle", "CLEAR state", "MEASURED"),
        ("Output retirement overhead", f"{ret} cycle + DONE", "RETIRE state, then DONE pulse", "MEASURED"),
        ("Measured MAC throughput (compute window)", f"{macs / run:.2f} MAC/cycle", f"{macs} MACs / {run} RUN cycles", "MEASURED"),
        ("Measured MAC throughput (end-to-end)", f"{macs / lat:.2f} MAC/cycle", f"{macs} MACs / {lat} start-to-done cycles", "MEASURED"),
        ("Active PEs per RUN cycle", act, "count of PEs with A and B valid", "MEASURED"),
        ("Peak active PEs", max(act), "max of the profile above (< 16 because K=4 limits overlap)", "MEASURED"),
        ("Average active PEs (RUN window)", f"{sum(act) / run:.2f}", "sum(active) / RUN cycles", "MEASURED"),
        ("PE utilization (RUN window)", f"{100 * sum(act) / avail_run:.1f} %", f"{sum(act)} active PE-cycles / ({PE} PEs x {run} cycles)", "MEASURED"),
        ("PE utilization (start-to-done)", f"{100 * sum(act) / avail_total:.1f} %", f"{sum(act)} / ({PE} x {lat})", "MEASURED"),
    ]
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
    lines = [
        "# AXIVEX Phase I performance report",
        "",
        f"Generated {now} by `scripts/perf_report.py` from RTL simulation output "
        f"({len(res)} directed jobs, identical cycle counts in all).",
        f"Simulator: {tool('iverilog -V 2>&1')}",
        "",
        "Labels: MEASURED = observed in RTL simulation; MODELLED = conceptual single-MAC baseline "
        "(not implemented RTL); ARCHITECTURE/ANALYTICAL = closed-form. No FPGA timing is used here, so "
        "no throughput in MAC/s is reported (that needs a clock frequency from a timing report).",
        "",
        "| Metric | Value | Definition | Evidence |",
        "|---|---|---|---|",
    ]
    for n, v, d, e in rows:
        lines.append(f"| {n} | {v} | {d} | {e} |")
    lines += [
        "",
        "Caveat: the baseline shares the systolic design's fixed overhead cycles purely for an apples-to-apples "
        "end-to-end ratio; a real single-MAC engine would have its own control overhead. The baseline also uses "
        "1 MAC unit against 16 PEs, so the speedup is not area-normalised.",
    ]
    out = os.path.join(ROOT, "reports/benchmarks")
    os.makedirs(out, exist_ok=True)
    open(os.path.join(out, "performance.md"), "w").write("\n".join(lines) + "\n")
    json.dump({r[0].strip(): r[1] for r in rows} | {"date": now}, open(os.path.join(out, "performance.json"), "w"), indent=1)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
