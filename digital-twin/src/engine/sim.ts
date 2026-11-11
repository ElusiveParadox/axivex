/**
 * Cycle-accurate behavioural model of the AXIVEX RTL.
 *
 * One call to step() is exactly one rising clock edge of axivex_top. Values
 * visible *during* a cycle come from view(); registers update in step().
 * Mapping to the RTL:
 *   step() PE update        processing_element.v
 *   view() lanes            skew_scheduler.v
 *   step() output capture   output_buffer.v
 *   step() controller       array_controller.v
 *   start handling          matrix_data_interface.v + input_buffers.v
 * No React code is imported here.
 */
import {
  K, LAST_CYCLE, M, N, NUM_PE,
  S_CLEAR, S_DONE, S_IDLE, S_RETIRE, S_RUN,
  type CycleView, type Lane, type Matrix, type PEInputs, type PERegs, type Sim,
  type StartRequest, type StateCode, type TraceRow,
} from "./types";
import { validateMatrix } from "./reference";

const ZERO_PE: PERegs = {
  aOut: 0, bOut: 0, aValidOut: false, bValidOut: false, aLastOut: false, bLastOut: false,
  acc: 0, result: 0, resultValid: false,
};

const zeroMatrix = (): Matrix => Array.from({ length: 4 }, () => [0, 0, 0, 0]);

/** Wrap to signed 32 bits like the RTL accumulator. */
const wrap32 = (v: number): number => v | 0;

export function createSim(): Sim {
  return {
    state: S_IDLE, cycleCount: 0, cycle: 0,
    aMat: zeroMatrix(), bMat: zeroMatrix(),
    pes: Array.from({ length: NUM_PE }, () => ({ ...ZERO_PE })),
    cData: Array<number>(NUM_PE).fill(0),
    cValidBits: Array<boolean>(NUM_PE).fill(false),
    captureCount: 0, captureError: false, startRejected: 0, doneCount: 0,
  };
}

/** Synchronous reset (rst_n low for one edge). */
export function resetSim(): Sim {
  return createSim();
}

export const isBusy = (s: Sim): boolean => s.state === S_CLEAR || s.state === S_RUN || s.state === S_RETIRE;

/** skew_scheduler: row lane i presents A[i][t-i], column lane j presents B[t-j][j]. */
export function schedulerLanes(s: Sim): { rows: Lane[]; cols: Lane[] } {
  const run = s.state === S_RUN;
  const rows: Lane[] = [];
  const cols: Lane[] = [];
  for (let n = 0; n < 4; n++) {
    const k = s.cycleCount - n;
    const valid = run && k >= 0 && k < K;
    rows.push({ valid, last: valid && k === K - 1, data: valid ? s.aMat[n][k] : 0 });
    cols.push({ valid, last: valid && k === K - 1, data: valid ? s.bMat[k][n] : 0 });
  }
  return { rows, cols };
}

/** Inputs of every PE this cycle: scheduler on the west/north edge, neighbour registers elsewhere. */
export function peInputs(s: Sim): PEInputs[] {
  const { rows, cols } = schedulerLanes(s);
  const out: PEInputs[] = [];
  for (let i = 0; i < M; i++) {
    for (let j = 0; j < N; j++) {
      const west = j === 0 ? null : s.pes[i * N + j - 1];
      const north = i === 0 ? null : s.pes[(i - 1) * N + j];
      const aIn = west ? west.aOut : rows[i].data;
      const bIn = north ? north.bOut : cols[j].data;
      out.push({
        aIn, bIn,
        aValid: west ? west.aValidOut : rows[i].valid,
        bValid: north ? north.bValidOut : cols[j].valid,
        aLast: west ? west.aLastOut : rows[i].last,
        bLast: north ? north.bLastOut : cols[j].last,
        product: aIn * bIn,
      });
    }
  }
  return out;
}

export function view(s: Sim): CycleView {
  const { rows, cols } = schedulerLanes(s);
  const pes = peInputs(s);
  const firing = pes.map((p) => p.aValid && p.bValid);
  return {
    state: s.state, cycleCount: s.cycleCount, cycle: s.cycle,
    busy: isBusy(s), done: s.state === S_DONE, cValid: s.cValidBits.every(Boolean),
    rowLanes: rows, colLanes: cols, pes, regs: s.pes, firing,
    activeCount: firing.filter(Boolean).length,
    completedCount: s.cValidBits.filter(Boolean).length,
  };
}

/** Row of the cycle trace for the current cycle (same fields as the RTL trace CSV). */
export function traceRow(s: Sim): TraceRow {
  const v = view(s);
  return {
    c: s.cycle, st: s.state, cnt: s.cycleCount, busy: v.busy, done: v.done, cv: v.cValid,
    pes: v.pes.map((p, i) => ({
      a: p.aIn, b: p.bIn, av: p.aValid, bv: p.bValid,
      last: p.aLast && p.bLast, acc: s.pes[i].acc, rv: s.pes[i].resultValid,
    })),
  };
}

/**
 * Advance exactly one clock edge. `start` models a start rising edge sampled at
 * this edge: accepted (A and B latched, output buffer cleared) only if !busy,
 * otherwise counted as rejected and ignored.
 */
export function step(s: Sim, start?: StartRequest | null): Sim {
  const inputs = peInputs(s);
  const busy = isBusy(s);
  const startAccept = !!start && !busy;
  const clearAcc = s.state === S_CLEAR;

  // processing elements
  const pes: PERegs[] = s.pes.map((r, idx) => {
    if (clearAcc) return { ...ZERO_PE };
    const inp = inputs[idx];
    const next: PERegs = {
      ...r,
      aOut: inp.aIn, bOut: inp.bIn,
      aValidOut: inp.aValid, bValidOut: inp.bValid,
      aLastOut: inp.aLast, bLastOut: inp.bLast,
      resultValid: false,
    };
    if (inp.aValid && inp.bValid) {
      const accNext = wrap32(r.acc + inp.product);
      next.acc = accNext;
      if (inp.aLast && inp.bLast) {
        next.result = accNext;
        next.resultValid = true;
      }
    }
    return next;
  });

  // output buffer (clear has priority over capture, as in output_buffer.v)
  let cData = s.cData.slice();
  let cValidBits = s.cValidBits.slice();
  let captureCount = s.captureCount;
  let captureError = s.captureError;
  const allCapturedNext = s.pes.every((r, p) => s.cValidBits[p] || r.resultValid);
  if (startAccept) {
    cData = Array<number>(NUM_PE).fill(0);
    cValidBits = Array<boolean>(NUM_PE).fill(false);
    captureCount = 0;
    captureError = false;
  } else {
    s.pes.forEach((r, p) => {
      if (r.resultValid) {
        if (s.cValidBits[p]) captureError = true;
        cData[p] = r.result;
        cValidBits[p] = true;
        captureCount += 1;
      }
    });
  }

  // controller
  let state: StateCode = s.state;
  let cycleCount = s.cycleCount;
  switch (s.state) {
    case S_IDLE: if (startAccept) state = S_CLEAR; break;
    case S_CLEAR: state = S_RUN; cycleCount = 0; break;
    case S_RUN:
      cycleCount = s.cycleCount + 1;
      if (s.cycleCount === LAST_CYCLE) state = S_RETIRE;
      break;
    case S_RETIRE:
      if (s.cycleCount !== 15) cycleCount = s.cycleCount + 1;
      if (allCapturedNext) state = S_DONE;
      break;
    case S_DONE: state = startAccept ? S_CLEAR : S_IDLE; break;
  }

  let cycle = s.cycle;
  if (startAccept) cycle = 1;
  else if (s.state !== S_IDLE && s.state !== S_DONE) cycle = s.cycle + 1;

  return {
    state, cycleCount, cycle,
    aMat: startAccept ? start!.A.map((r) => r.slice()) : s.aMat,
    bMat: startAccept ? start!.B.map((r) => r.slice()) : s.bMat,
    pes, cData, cValidBits, captureCount, captureError,
    startRejected: s.startRejected + (start && busy ? 1 : 0),
    doneCount: s.doneCount + (s.state === S_DONE ? 1 : 0),
  };
}

export interface Transaction {
  rows: TraceRow[];
  sim: Sim;
  C: Matrix;
}

/**
 * Run one full job: step() with a start, then one step per cycle until the DONE
 * cycle. The returned trace contains CLEAR..DONE (cycle indices 1..13), the
 * same rows the RTL testbench dumps. `from` allows chaining jobs exactly like
 * back-to-back RTL runs.
 */
export function runTransaction(A: Matrix, B: Matrix, from?: Sim, maxCycles = 64): Transaction {
  const err = validateMatrix(A, "A") ?? validateMatrix(B, "B");
  if (err) throw new Error(err);
  let s = step(from ?? createSim(), { A, B });
  const rows: TraceRow[] = [];
  for (let n = 0; n < maxCycles; n++) {
    rows.push(traceRow(s));
    if (s.state === S_DONE) break;
    s = step(s);
  }
  if (s.state !== S_DONE) throw new Error("transaction did not complete");
  const C = [0, 1, 2, 3].map((i) => [0, 1, 2, 3].map((j) => s.cData[i * 4 + j]));
  return { rows, sim: s, C };
}
