#!/usr/bin/env python3

import argparse
import re
import sys


def parse_vcd(path):
    ids, names, changes, cur = {}, {}, {}, 0
    scope = []
    with open(path) as f:
        lines = f.read().split("\n")
    i, header = 0, True
    ts = 1
    while i < len(lines):
        ln = lines[i].strip(); i += 1
        if header:
            if ln.startswith("$scope"):
                scope.append(ln.split()[2])
            elif ln.startswith("$upscope"):
                scope.pop()
            elif ln.startswith("$var"):
                t = ln.split()
                code, nm = t[3], t[4]
                full = ".".join(scope + [nm])
                ids.setdefault(code, []).append(full)
                names[full] = code
                changes.setdefault(code, [])
            elif ln.startswith("$timescale"):
                m = re.search(r"(\d+)\s*(\w+)", ln if "$end" in ln else ln + " " + lines[i])
            elif ln.startswith("$enddefinitions"):
                header = False
            continue
        if not ln or ln.startswith("$"):
            continue
        if ln[0] == "#":
            cur = int(ln[1:])
        elif ln[0] in "01xzXZ" and len(ln) >= 2:
            changes[ln[1:]].append((cur, ln[0]))
        elif ln[0] in "bB":
            v, code = ln[1:].split()
            changes[code].append((cur, v))
    return names, changes


def sample(changes_list, t):
    val = None
    for tt, v in changes_list:
        if tt <= t:
            val = v
        else:
            break
    return val


def to_int(v, signed_bits=0):
    if v is None or any(c in v for c in "xzXZ"):
        return None
    n = int(v, 2)
    if signed_bits and n >= 1 << (signed_bits - 1):
        n -= 1 << signed_bits
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("vcd")
    ap.add_argument("--txn", type=int, default=0)
    ap.add_argument("--png")
    ap.add_argument("--md")
    a = ap.parse_args()
    names, ch = parse_vcd(a.vcd)

    def sig(n):
        return ch[names["tb_axivex_top." + n]]

    clk = sig("clk")
    falls = [t for t, v in clk if v == "0" and t > 0]
    st, cnt = sig("dut.u_ctrl.state"), sig("dut.u_ctrl.cycle_count")
    busy, done, cval = sig("busy"), sig("done"), sig("c_valid")
    pav, pbv, pacc, prv = sig("pe_av"), sig("pe_bv"), sig("pe_acc"), sig("pe_rv")

    starts = [t for t in falls if to_int(sample(st, t)) == 1]
    if a.txn >= len(starts):
        sys.exit("transaction index out of range")
    t0 = starts[a.txn]
    idx0 = falls.index(t0)
    rows = []
    for c in range(1, 14):
        t = falls[idx0 + c - 1]
        av = to_int(sample(pav, t)); bv = to_int(sample(pbv, t))
        accv = sample(pacc, t); rv = to_int(sample(prv, t))
        accs = [to_int(accv[-(p + 1) * 32: len(accv) - p * 32] if len(accv) >= (p + 1) * 32 else accv.rjust(512, "0")[-(p + 1) * 32: 512 - p * 32], 32)
                for p in range(16)]
        rows.append(dict(c=c, t=t, st=to_int(sample(st, t)), cnt=to_int(sample(cnt, t)),
                         busy=to_int(sample(busy, t)), done=to_int(sample(done, t)), cv=to_int(sample(cval, t)),
                         active=bin(av & bv).count("1"), rv=[p for p in range(16) if (rv >> p) & 1],
                         acc=accs))
    names_st = {0: "IDLE", 1: "CLEAR", 2: "RUN", 3: "RETIRE", 4: "DONE"}
    out = []
    out.append("| cycle | state | cnt | busy | done | c_valid | active PEs | PE results this cycle | acc PE(0,0) | acc PE(0,3) | acc PE(3,0) | acc PE(3,3) |")
    out.append("|---:|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|")
    for r in rows:
        rv = ", ".join(f"({p // 4},{p % 4})" for p in r["rv"]) or "-"
        out.append(f"| {r['c']} | {names_st[r['st']]} | {r['cnt']} | {r['busy']} | {r['done']} | {r['cv']} | {r['active']} | {rv} | "
                   f"{r['acc'][0]} | {r['acc'][3]} | {r['acc'][12]} | {r['acc'][15]} |")
    table = "\n".join(out)
    print(table)
    if a.md:
        with open(a.md, "w") as f:
            f.write(table + "\n")
    if a.png:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        xs = [r["c"] for r in rows]
        fig, ax = plt.subplots(6, 1, figsize=(11, 10), sharex=True)
        ax[0].step(xs, [r["st"] for r in rows], where="post"); ax[0].set_ylabel("FSM state")
        ax[0].set_yticks(range(5)); ax[0].set_yticklabels(["IDLE", "CLEAR", "RUN", "RETIRE", "DONE"])
        ax[1].step(xs, [r["cnt"] for r in rows], where="post", color="tab:green"); ax[1].set_ylabel("cycle_count")
        for k, nm in (("busy", "busy"), ("done", "done"), ("cv", "c_valid")):
            ax[2].step(xs, [r[k] + {"busy": 0, "done": 1.5, "cv": 3}[k] for r in rows], where="post", label=nm)
        ax[2].set_ylabel("busy/done/c_valid"); ax[2].legend(loc="upper left", ncol=3, fontsize=8); ax[2].set_yticks([])
        ax[3].bar(xs, [r["active"] for r in rows], color="tab:orange"); ax[3].set_ylabel("active PEs")
        for p, lab in ((0, "PE(0,0)"), (3, "PE(0,3)"), (12, "PE(3,0)"), (15, "PE(3,3)")):
            ax[4].step(xs, [r["acc"][p] for r in rows], where="post", label=lab)
        ax[4].set_ylabel("accumulator"); ax[4].legend(fontsize=8, ncol=4)
        ax[5].eventplot([[r["c"] for r in rows if p in r["rv"]] for p in range(16)], lineoffsets=range(16), colors="k")
        ax[5].set_ylabel("PE index\nresult_valid"); ax[5].set_xlabel("cycle since start (start cycle = 0)")
        for x in ax: x.grid(alpha=.3)
        fig.suptitle("AXIVEX transaction waveform (data parsed from VCD)")
        fig.tight_layout(); fig.savefig(a.png, dpi=110)


if __name__ == "__main__":
    main()
