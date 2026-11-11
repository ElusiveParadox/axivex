/** AXIVEX Digital Twin: shared types. The engine mirrors rtl/ cycle by cycle. */
export const M = 4;
export const N = 4;
export const K = 4;
export const NUM_PE = M * N;
/** Last RUN-state cycle_count value: K + M + N - 3. */
export const LAST_CYCLE = K + M + N - 3;
/** RUN window length: K + M + N - 2. */
export const RUN_CYCLES = LAST_CYCLE + 1;

export const INT8_MIN = -128;
export const INT8_MAX = 127;

export type Matrix = number[][];

/** Controller states, encoded exactly as array_controller.v. */
export const S_IDLE = 0;
export const S_CLEAR = 1;
export const S_RUN = 2;
export const S_RETIRE = 3;
export const S_DONE = 4;
export type StateCode = 0 | 1 | 2 | 3 | 4;
export const STATE_NAMES = ["IDLE", "CLEAR", "RUN", "RETIRE", "DONE"] as const;

/** Registered state of one processing element (processing_element.v). */
export interface PERegs {
  aOut: number;
  bOut: number;
  aValidOut: boolean;
  bValidOut: boolean;
  aLastOut: boolean;
  bLastOut: boolean;
  acc: number;
  result: number;
  resultValid: boolean;
}

/** Combinational inputs of one PE during the current cycle. */
export interface PEInputs {
  aIn: number;
  bIn: number;
  aValid: boolean;
  bValid: boolean;
  aLast: boolean;
  bLast: boolean;
  /** a_in * b_in (computed whether or not valid, as in the RTL mac_unit) */
  product: number;
}

export interface Lane {
  data: number;
  valid: boolean;
  last: boolean;
}

export interface Sim {
  state: StateCode;
  cycleCount: number;
  /** Cycles since the start cycle (start cycle = 0; CLEAR = 1; DONE = 13). */
  cycle: number;
  aMat: Matrix;
  bMat: Matrix;
  pes: PERegs[];
  /** output_buffer.c_flat / valid bits, index i*4+j */
  cData: number[];
  cValidBits: boolean[];
  captureCount: number;
  captureError: boolean;
  startRejected: number;
  doneCount: number;
}

/** Everything visible during one cycle: registers plus combinational values. */
export interface CycleView {
  state: StateCode;
  cycleCount: number;
  cycle: number;
  busy: boolean;
  done: boolean;
  cValid: boolean;
  rowLanes: Lane[];
  colLanes: Lane[];
  pes: PEInputs[];
  regs: PERegs[];
  /** PEs with A and B valid this cycle (a MAC fires at the coming edge) */
  firing: boolean[];
  activeCount: number;
  completedCount: number;
}

/** One row of the cycle trace; field order matches the RTL trace CSV. */
export interface TraceRow {
  c: number;
  st: StateCode;
  cnt: number;
  busy: boolean;
  done: boolean;
  cv: boolean;
  pes: { a: number; b: number; av: boolean; bv: boolean; last: boolean; acc: number; rv: boolean }[];
}

export interface StartRequest {
  A: Matrix;
  B: Matrix;
}
