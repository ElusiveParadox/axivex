import type { Ctx } from "../engine-hook";
import MatrixGrid from "../components/MatrixGrid";

export default function Results({ ctx }: { ctx: Ctx }) {
  const { A, B, hwC, ref, stats, dispatch, complete } = ctx;
  const pass = hwC ? hwC.every((r, i) => r.every((x, j) => x === ref[i][j])) : null;
  const done = hwC !== null;
  const f = (x: number, d = 2) => x.toFixed(d);
  const metrics: [string, string, string][] = [
    ["Total transaction cycles", done ? String(stats.totalCycles) : "—", "Cycle index of the DONE cycle, start cycle = 0 (start/load 1 + CLEAR 1 + RUN 10 + RETIRE 1)"],
    ["Compute cycles", String(stats.runCycles), "Cycles in state RUN (first injection to the last MAC), analytically K+M+N−2"],
    ["Theoretical peak MAC throughput", `${stats.peakMacCapacity} MAC/cycle`, "One MAC per PE per cycle; architectural bound, not measured"],
    ["Completed MACs", String(stats.totalMacs), "Sum over RUN cycles of PEs with A and B valid, counted from this execution trace"],
    ["Measured MAC rate (compute window)", `${f(stats.macsPerCycleRun)} MAC/cycle`, "Completed MACs / RUN cycles"],
    ["Measured MAC rate (start-to-done)", done ? `${f(stats.macsPerCycleTotal)} MAC/cycle` : "—", "Completed MACs / total transaction cycles"],
    ["Active PEs per RUN cycle", `[${stats.activePerRunCycle.join(", ")}]`, "PEs with both operands valid in each RUN cycle"],
    ["Average / peak active PEs", `${f(stats.avgActive)} / ${stats.peakActive}`, "Mean and max of the profile above"],
    ["Measured PE utilization (RUN)", `${f(stats.utilizationRun, 1)} %`, "Active PE-cycles / (16 PEs × RUN cycles)"],
    ["Measured PE utilization (start-to-done)", done ? `${f(stats.utilizationTotal, 1)} %` : "—", "Active PE-cycles / (16 PEs × total cycles)"],
    ["Fill + drain overhead", `${f(stats.fillDrainCycles, 0)} cycles`, "RUN cycles − MACs/PEs (=4); analytically M+N−2"],
    ["Single-MAC baseline compute cycles", String(stats.baselineComputeCycles), "Modelled: M·N·K MACs at one per clock, not an implemented design"],
    ["Compute-only speedup vs baseline", `${f(stats.computeSpeedup)}×`, "Baseline cycles / RUN cycles; not area-normalised (16 MACs vs 1)"],
  ];
  return (
    <div>
      <div className="btnrow"><button onClick={() => dispatch({ type: "runAll" })} disabled={!!ctx.inputError}>Run to DONE</button>
        {!complete && ctx.historyLength > 1 && <span className="muted"> run in progress: metrics below are partial</span>}</div>
      <div className="matrices">
        <MatrixGrid title="Matrix A" M={A} />
        <div className="times">×</div>
        <MatrixGrid title="Matrix B" M={B} />
        <div className="times">=</div>
        <MatrixGrid title="C (hardware model)" M={hwC ?? A.map((r) => r.map(() => 0))}
          highlight={(i, j) => (hwC ? (hwC[i][j] === ref[i][j] ? "good" : "bad") : "pending")} />
        <MatrixGrid title="C (independent reference)" M={ref} />
      </div>
      <div className={`verdict ${pass === null ? "pending" : pass ? "pass" : "fail"}`}>
        {pass === null ? "Waiting for DONE (hardware-model output not valid yet)" : pass ? "PASS: all 16 elements match the reference" : "FAIL: mismatch"}
      </div>
      <div className="panel">
        <h3>Element-by-element comparison</h3>
        <table><thead><tr><th>C[i][j]</th><th>model</th><th>reference</th><th>match</th></tr></thead>
          <tbody>{ref.flatMap((r, i) => r.map((x, j) => (
            <tr key={`${i}${j}`}><td>[{i}][{j}]</td><td>{hwC ? hwC[i][j] : "—"}</td><td>{x}</td><td>{hwC ? (hwC[i][j] === x ? "✓" : "✗") : "—"}</td></tr>)))}</tbody></table>
      </div>
      <div className="panel">
        <h3>Performance (derived from this execution trace)</h3>
        <table><thead><tr><th>Metric</th><th>Value</th><th>Measurement definition</th></tr></thead>
          <tbody>{metrics.map(([n, val, d]) => <tr key={n}><td>{n}</td><td><b>{val}</b></td><td className="muted">{d}</td></tr>)}</tbody></table>
        <p className="muted">Cycle counts only. No clock frequency is assumed, so no MAC/s figure is shown.</p>
      </div>
    </div>
  );
}
