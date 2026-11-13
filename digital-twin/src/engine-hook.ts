import { useEffect, useReducer } from "react";
import {
  S_DONE, S_IDLE, computeStats, createSim, referenceMatmul, step, traceRow, validateMatrix, view,
  type Matrix, type Sim, type TraceRow,
} from "./engine";
import { EXAMPLES } from "./data/examples";

interface State {
  A: Matrix;
  B: Matrix;
  history: Sim[];
  idx: number;
  playing: boolean;
  speedMs: number;
}

type Action =
  | { type: "next" } | { type: "tick" } | { type: "prev" } | { type: "reset" }
  | { type: "start" } | { type: "pause" } | { type: "resume" } | { type: "runAll" }
  | { type: "setA"; A: Matrix } | { type: "setB"; B: Matrix } | { type: "setBoth"; A: Matrix; B: Matrix }
  | { type: "speed"; ms: number };

const fresh = (): Sim[] => [createSim()];

function advance(s: State): State {
  const err = validateMatrix(s.A, "A") ?? validateMatrix(s.B, "B");
  if (s.idx < s.history.length - 1) return { ...s, idx: s.idx + 1 };
  const cur = s.history[s.idx];
  if (s.history.length === 1) {
    if (err) return { ...s, playing: false };
    return { ...s, history: [...s.history, step(cur, { A: s.A, B: s.B })], idx: s.idx + 1 };
  }
  if (cur.state === S_IDLE) return { ...s, playing: false };
  return { ...s, history: [...s.history, step(cur)], idx: s.idx + 1 };
}

function reducer(s: State, a: Action): State {
  switch (a.type) {
    case "next": return advance(s);
    case "tick": {
      if (s.history[s.idx].state === S_DONE && s.idx === s.history.length - 1) return { ...s, playing: false };
      const n = advance(s);
      return n.history[n.idx].state === S_DONE ? { ...n, playing: false } : n;
    }
    case "prev": return { ...s, idx: Math.max(0, s.idx - 1), playing: false };
    case "reset": return { ...s, history: fresh(), idx: 0, playing: false };
    case "start": return { ...s, history: fresh(), idx: 0, playing: true };
    case "pause": return { ...s, playing: false };
    case "resume": return { ...s, playing: true };
    case "runAll": {
      let n: State = s.history.length === 1 ? advance({ ...s }) : { ...s, idx: s.history.length - 1 };
      for (let g = 0; g < 64 && n.history[n.idx].state !== S_DONE && n.history[n.idx].state !== S_IDLE; g++) n = advance(n);
      return { ...n, playing: false };
    }
    case "setA": return { ...s, A: a.A, history: fresh(), idx: 0, playing: false };
    case "setB": return { ...s, B: a.B, history: fresh(), idx: 0, playing: false };
    case "setBoth": return { ...s, A: a.A, B: a.B, history: fresh(), idx: 0, playing: false };
    case "speed": return { ...s, speedMs: a.ms };
  }
}

export function useSimulation() {
  const [s, dispatch] = useReducer(reducer, undefined, (): State => ({
    A: EXAMPLES[0].A, B: EXAMPLES[0].B, history: fresh(), idx: 0, playing: false, speedMs: 500,
  }));

  useEffect(() => {
    if (!s.playing) return;
    const id = setInterval(() => dispatch({ type: "tick" }), s.speedMs);
    return () => clearInterval(id);
  }, [s.playing, s.speedMs]);

  const sim = s.history[s.idx];
  const cycleView = view(sim);
  const rows: TraceRow[] = s.history.slice(0, s.idx + 1).filter((x) => x.state !== S_IDLE).map(traceRow);
  const complete = sim.state === S_DONE || (s.history.length > 1 && sim.state === S_IDLE);
  const ref = referenceMatmul(s.A, s.B);
  const hwC: number[][] | null = sim.cValidBits.every(Boolean)
    ? [0, 1, 2, 3].map((i) => [0, 1, 2, 3].map((j) => sim.cData[i * 4 + j]))
    : null;
  return {
    A: s.A, B: s.B, sim, view: cycleView, rows, ref, hwC, complete,
    stats: computeStats(rows),
    playing: s.playing, speedMs: s.speedMs, idx: s.idx, historyLength: s.history.length,
    canPrev: s.idx > 0,
    inputError: validateMatrix(s.A, "A") ?? validateMatrix(s.B, "B"),
    dispatch,
  };
}
export type Ctx = ReturnType<typeof useSimulation>;
