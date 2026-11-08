#!/usr/bin/env python3
"""Compare RTL testbench output against the Python golden model.

  compare_rtl.py --vec directed.txt --rtl rtl_results.txt [--trace trace.txt]

Checks (all derived from closed-form equations, not from RTL logic):
  * every C element equals the Python reference
  * start-to-done latency = 13, RUN cycles = K+M+N-2 = 10, RETIRE = 1, MACs = 64
  * with --trace: FSM sequence, MAC events at t = i+j+k with operands
    A[i][k], B[k][j], one result pulse per PE, final accumulator = C[i][j]
Exit code is non-zero on any mismatch.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import matrix_model as mm  # noqa: E402

K = M = N = 4
EXP_RUN = K + M + N - 2
EXP_TOTAL = 1 + 1 + EXP_RUN + 1  # start + CLEAR + RUN + RETIRE -> DONE cycle index


def read_results(path):
    res = {}
    order = []
    with open(path) as f:
        for line in f:
            t = line.split()
            if not t:
                continue
            name = t[0]
            vals = [int(x) for x in t[1:]]
            res.setdefault(name, []).append(vals)
            order.append(name)
    return res, order


def check_results(vec_path, rtl_path):
    vecs = mm.read_vectors(vec_path)
    res, _ = read_results(rtl_path)
    used = {}
    bad = 0
    for name, A, B, C in vecs:
        idx = used.get(name, 0)
        used[name] = idx + 1
        if name not in res or idx >= len(res[name]):
            print(f"MISSING result for {name}")
            bad += 1
            continue
        v = res[name][idx]
        lat, run, ret, macs, got = v[0], v[1], v[2], v[3], v[4:]
        exp = mm.flat(mm.matmul_ref(A, B))
        if got != exp:
            bad += 1
            print(f"MISMATCH {name}: got {got} expected {exp}")
        if (lat, run, ret, macs) != (EXP_TOTAL, EXP_RUN, 1, M * N * K):
            bad += 1
            print(f"CYCLE MISMATCH {name}: lat/run/retire/macs = {lat}/{run}/{ret}/{macs}")
    print(f"result check: {len(vecs)} transactions, {bad} problems")
    return bad


def read_trace(path):
    tr = {}
    with open(path) as f:
        for line in f:
            t = line.split()
            if not t:
                continue
            name = t[0]
            nums = [int(x) for x in t[1:]]
            c, st, cnt, busy, done, cv = nums[:6]
            pes = [nums[6 + 7 * p: 6 + 7 * (p + 1)] for p in range(16)]
            tr.setdefault(name, []).append(dict(c=c, st=st, cnt=cnt, busy=busy, done=done, cv=cv, pes=pes))
    return tr


def check_trace(vec_path, trace_path):
    vecs = {n: (A, B, C) for n, A, B, C in mm.read_vectors(vec_path)}
    tr = read_trace(trace_path)
    bad = 0
    for name, rows in tr.items():
        if name not in vecs:
            continue
        A, B, C = vecs[name]
        states = [r["st"] for r in rows]
        exp_states = [1] + [2] * EXP_RUN + [3, 4]
        if states != exp_states:
            print(f"{name}: FSM sequence {states} != {exp_states}")
            bad += 1
            continue
        for i in range(M):
            for j in range(N):
                p = i * N + j
                fires = []
                pulses = []
                for r in rows:
                    a, b, av, bv, last, acc, rv = r["pes"][p]
                    if av and bv:
                        fires.append((r["cnt"], a, b, last))
                    if rv:
                        pulses.append(r["c"])
                exp_f = [(i + j + k, A[i][k], B[k][j], 1 if k == K - 1 else 0) for k in range(K)]
                if fires != exp_f:
                    print(f"{name}: PE({i},{j}) MAC events {fires} != {exp_f}")
                    bad += 1
                # result_valid one cycle after the last MAC: RUN cycle t -> trace row c = t+2 (+1)
                exp_pulse = [(K - 1 + i + j) + 2 + 1]
                if pulses != exp_pulse:
                    print(f"{name}: PE({i},{j}) result pulses at c={pulses} != {exp_pulse}")
                    bad += 1
                final = rows[-1]["pes"][p][5]
                if final != C[i][j]:
                    print(f"{name}: PE({i},{j}) final acc {final} != {C[i][j]}")
                    bad += 1
        # active PE per RUN cycle
        act = [sum(1 for pe in r["pes"] if pe[2] and pe[3]) for r in rows if r["st"] == 2]
        exp_act = [sum(1 for i in range(M) for j in range(N) if 0 <= t - i - j < K) for t in range(EXP_RUN)]
        if act != exp_act:
            print(f"{name}: active PEs {act} != {exp_act}")
            bad += 1
    print(f"trace check: {len(tr)} traced transactions, {bad} problems")
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--vec", required=True)
    ap.add_argument("--rtl", required=True)
    ap.add_argument("--trace")
    a = ap.parse_args()
    bad = check_results(a.vec, a.rtl)
    if a.trace:
        bad += check_trace(a.vec, a.trace)
    print("COMPARE_RESULT:", "PASS" if bad == 0 else "FAIL")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
