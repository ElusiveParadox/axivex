import { K, M, N, NUM_PE, RUN_CYCLES, S_RUN, type TraceRow } from "./types";

export interface Stats {
  totalCycles: number;        // start-to-done latency: cycle index of the DONE row + 0 (13)
  runCycles: number;          // rows with state == RUN
  activePerRunCycle: number[];
  totalMacs: number;
  peakActive: number;
  avgActive: number;
  utilizationRun: number;     // percent
  utilizationTotal: number;   // percent
  macsPerCycleRun: number;
  macsPerCycleTotal: number;
  peakMacCapacity: number;
  baselineComputeCycles: number;
  computeSpeedup: number;
  fillDrainCycles: number;
}

/** All figures are derived from the trace; none are hard-coded. */
export function computeStats(rows: TraceRow[]): Stats {
  const run = rows.filter((r) => r.st === S_RUN);
  const activePerRunCycle = run.map((r) => r.pes.filter((p) => p.av && p.bv).length);
  const totalMacs = activePerRunCycle.reduce((a, b) => a + b, 0);
  const runCycles = run.length;
  const totalCycles = rows.length > 0 ? rows[rows.length - 1].c : 0;
  const baseline = M * N * K;
  return {
    totalCycles, runCycles, activePerRunCycle, totalMacs,
    peakActive: Math.max(0, ...activePerRunCycle),
    avgActive: runCycles ? totalMacs / runCycles : 0,
    utilizationRun: runCycles ? (100 * totalMacs) / (NUM_PE * runCycles) : 0,
    utilizationTotal: totalCycles ? (100 * totalMacs) / (NUM_PE * totalCycles) : 0,
    macsPerCycleRun: runCycles ? totalMacs / runCycles : 0,
    macsPerCycleTotal: totalCycles ? totalMacs / totalCycles : 0,
    peakMacCapacity: NUM_PE,
    baselineComputeCycles: baseline,
    computeSpeedup: runCycles ? baseline / runCycles : 0,
    fillDrainCycles: runCycles - baseline / NUM_PE,
  };
}

export const EXPECTED_RUN_CYCLES = RUN_CYCLES;
