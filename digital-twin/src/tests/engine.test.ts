import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  K, M, N, RUN_CYCLES, S_DONE, S_IDLE, S_RUN, STATE_NAMES,
  computeStats, createSim, referenceMatmul, runTransaction, step, traceRow, unflatten, validateMatrix, view,
  type Matrix, type Sim, type TraceRow,
} from "../engine";

const REF = resolve(__dirname, "../../../reference");
const readLines = (p: string) => readFileSync(resolve(REF, p), "utf8").split("\n").filter((l) => l.trim());

interface Vec { name: string; A: Matrix; B: Matrix; C: Matrix }
function readVectors(file: string): Vec[] {
  return readLines(file).map((l) => {
    const t = l.trim().split(/\s+/);
    const v = t.slice(1).map(Number);
    return { name: t[0], A: unflatten(v.slice(0, 16)), B: unflatten(v.slice(16, 32)), C: unflatten(v.slice(32, 48)) };
  });
}

function readRtlTrace(file: string): Map<string, TraceRow[]> {
  const out = new Map<string, TraceRow[]>();
  for (const l of readLines(file)) {
    const t = l.trim().split(/\s+/);
    const n = t.slice(1).map(Number);
    const row: TraceRow = {
      c: n[0], st: n[1] as TraceRow["st"], cnt: n[2], busy: !!n[3], done: !!n[4], cv: !!n[5],
      pes: Array.from({ length: 16 }, (_, p) => {
        const q = n.slice(6 + 7 * p, 6 + 7 * p + 7);
        return { a: q[0], b: q[1], av: !!q[2], bv: !!q[3], last: !!q[4], acc: q[5], rv: !!q[6] };
      }),
    };
    out.set(t[0], [...(out.get(t[0]) ?? []), row]);
  }
  return out;
}

/** Bounded stepping so a broken engine fails the test instead of hanging it. */
function stepToDone(s: Sim, seen?: string[]): Sim {
  for (let n = 0; n < 100; n++) {
    if (s.state === S_DONE) return s;
    seen?.push(STATE_NAMES[s.state]);
    s = step(s);
  }
  throw new Error("engine never reached DONE");
}

const directed = readVectors("test_vectors/directed.txt");
const random = readVectors("test_vectors/random.txt");

describe("engine vs Python reference", () => {
  it("matches the Python-computed C for every directed vector", () => {
    let sim: Sim | undefined;
    for (const v of directed) {
      const tx = runTransaction(v.A, v.B, sim);
      sim = tx.sim;
      expect(tx.C, v.name).toEqual(v.C);
    }
  });

  it("matches the Python-computed C for all seeded random vectors", () => {
    expect(random.length).toBeGreaterThanOrEqual(100);
    let sim: Sim | undefined;
    for (const v of random) {
      const tx = runTransaction(v.A, v.B, sim);
      sim = tx.sim;
      expect(tx.C, v.name).toEqual(v.C);
    }
  });

  it("the TypeScript reference agrees with the Python vectors", () => {
    for (const v of [...directed, ...random]) expect(referenceMatmul(v.A, v.B), v.name).toEqual(v.C);
  });
});

describe("engine vs Verilog RTL (recorded testbench trace)", () => {
  const rtl = readRtlTrace("comparison/fixtures/rtl_directed_trace.txt");

  it("fixture covers every directed vector", () => {
    expect([...rtl.keys()]).toEqual(directed.map((d) => d.name));
  });

  it("reproduces every traced field of every cycle, back-to-back like the RTL run", () => {
    let sim: Sim | undefined;
    for (const v of directed) {
      const tx = runTransaction(v.A, v.B, sim);
      sim = tx.sim;
      const exp = rtl.get(v.name)!;
      expect(tx.rows.length, v.name).toBe(exp.length);
      tx.rows.forEach((row, idx) => expect(row, `${v.name} cycle ${idx + 1}`).toEqual(exp[idx]));
    }
  });

  it("reproduces the RTL cycle counts from the results file", () => {
    for (const l of readLines("comparison/fixtures/rtl_directed_results.txt")) {
      const t = l.split(/\s+/);
      const [lat, run, ret, macs] = t.slice(1, 5).map(Number);
      const v = directed.find((d) => d.name === t[0])!;
      const tx = runTransaction(v.A, v.B);
      const s = computeStats(tx.rows);
      expect(s.totalCycles).toBe(lat);
      expect(s.runCycles).toBe(run);
      expect(tx.rows.filter((r) => r.st === 3).length).toBe(ret);
      expect(s.totalMacs).toBe(macs);
      expect(t.slice(5).map(Number)).toEqual(tx.C.flat());
    }
  });
});

describe("schedule and timing", () => {
  const A = [[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12], [13, 14, 15, 16]];
  const B = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]];

  it("PE(i,j) MACs A[i][k]*B[k][j] exactly at cycle_count = i+j+k and result pulses one cycle later", () => {
    const tx = runTransaction(A, B);
    for (let i = 0; i < M; i++)
      for (let j = 0; j < N; j++) {
        const p = i * N + j;
        const fires = tx.rows.filter((r) => r.pes[p].av && r.pes[p].bv);
        expect(fires.map((r) => r.cnt)).toEqual([0, 1, 2, 3].map((k) => i + j + k));
        fires.forEach((r, k) => {
          expect(r.pes[p].a).toBe(A[i][k]);
          expect(r.pes[p].b).toBe(B[k][j]);
          expect(r.pes[p].last).toBe(k === K - 1);
        });
        const pulses = tx.rows.filter((r) => r.pes[p].rv);
        expect(pulses.length).toBe(1);
        expect(pulses[0].c).toBe(K - 1 + i + j + 2 + 1);
      }
  });

  it("FSM sequence is CLEAR, RUN x10, RETIRE, DONE and latency is 13", () => {
    const tx = runTransaction(A, B);
    expect(tx.rows.map((r) => r.st)).toEqual([1, ...Array(RUN_CYCLES).fill(2), 3, 4]);
    expect(tx.rows[tx.rows.length - 1].c).toBe(13);
    const s = computeStats(tx.rows);
    expect(s.activePerRunCycle).toEqual([1, 3, 6, 10, 12, 12, 10, 6, 3, 1]);
    expect(s.totalMacs).toBe(64);
    expect(s.utilizationRun).toBeCloseTo(40, 10);
    expect(s.computeSpeedup).toBeCloseTo(6.4, 10);
  });

  it("step() advances exactly one clock edge: a 'previous cycle' never skips state", () => {
    let s = step(createSim(), { A, B });
    const seen: string[] = [];
    s = stepToDone(s, seen);
    expect(seen).toEqual(["CLEAR", ...Array(10).fill("RUN"), "RETIRE"]);
  });

  it("operands move one hop per cycle: A east, B south", () => {
    let s = step(createSim(), { A, B }); // CLEAR
    s = step(s);                         // RUN cycle 0: A[0][0] on row-0 lane
    expect(view(s).pes[0].aIn).toBe(A[0][0]);
    expect(view(s).pes[1].aValid).toBe(false);
    s = step(s);                         // RUN cycle 1: A[0][0] now at PE(0,1)
    expect(view(s).pes[1].aIn).toBe(A[0][0]);
    expect(view(s).pes[4].bIn).toBe(B[0][0]); // B[0][0] at PE(1,0)
  });

  it("accumulators stay local: PE accumulators only change on valid MACs", () => {
    let s = step(createSim(), { A, B });
    for (let n = 0; n < 14; n++) {
      const before = s.pes.map((p) => p.acc);
      const v = view(s);
      s = step(s);
      s.pes.forEach((p, i) => {
        if (s.state !== 1 && !v.firing[i] && v.state !== 1) expect(p.acc).toBe(before[i]);
      });
    }
  });
});

describe("controller and interface behaviour", () => {
  const A = [[1, 1, 1, 1], [1, 1, 1, 1], [1, 1, 1, 1], [1, 1, 1, 1]];
  const B = A;

  it("start while busy is rejected and does not disturb the job", () => {
    let s = step(createSim(), { A, B });
    s = step(s);
    s = step(s, { A: [[9, 9, 9, 9], [9, 9, 9, 9], [9, 9, 9, 9], [9, 9, 9, 9]], B });
    expect(s.startRejected).toBe(1);
    s = stepToDone(s);
    expect(s.cData).toEqual(Array(16).fill(4));
  });

  it("done is a single-cycle pulse and the result is held in IDLE", () => {
    let s = step(createSim(), { A, B });
    s = stepToDone(s);
    expect(view(s).done).toBe(true);
    expect(view(s).busy).toBe(false);
    s = step(s);
    expect(s.state).toBe(S_IDLE);
    expect(view(s).done).toBe(false);
    expect(view(s).cValid).toBe(true);
    expect(s.cData).toEqual(Array(16).fill(4));
  });

  it("accepting a new start clears the previous result (c_valid drops)", () => {
    let s = step(createSim(), { A, B });
    s = stepToDone(s);
    s = step(s, { A, B }); // start in the DONE cycle
    expect(view(s).cValid).toBe(false);
    expect(s.cData).toEqual(Array(16).fill(0));
  });

  it("exactly 16 results are captured, no duplicates", () => {
    const tx = runTransaction(A, B);
    expect(tx.sim.captureCount).toBe(16);
    expect(tx.sim.captureError).toBe(false);
  });

  it("consecutive jobs have no stale accumulation", () => {
    const big = [[127, 127, 127, 127], [127, 127, 127, 127], [127, 127, 127, 127], [127, 127, 127, 127]];
    const t1 = runTransaction(big, big);
    const t2 = runTransaction(A, B, t1.sim);
    expect(t2.C).toEqual(referenceMatmul(A, B));
  });

  it("reaches INT32-safe extremes: (-128)*(-128)*4 = 65536", () => {
    const m = Array.from({ length: 4 }, () => Array(4).fill(-128));
    expect(runTransaction(m, m).C.flat().every((v) => v === 65536)).toBe(true);
  });

  it("rejects non-INT8 inputs", () => {
    expect(validateMatrix([[128, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])).toMatch(/INT8/);
    expect(() => runTransaction([[200, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]], B)).toThrow();
    expect(validateMatrix([[1, 2], [3, 4]])).toMatch(/4x4/);
  });

  it("traceRow on an idle sim is quiescent", () => {
    const r = traceRow(createSim());
    expect(r.st).toBe(S_IDLE);
    expect(r.pes.every((p) => !p.av && !p.bv && p.acc === 0)).toBe(true);
    expect(S_RUN).toBe(2);
  });
});
