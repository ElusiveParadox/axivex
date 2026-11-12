import type { Ctx } from "../engine-hook";
import { STATE_NAMES } from "../engine";

export default function Overview({ ctx }: { ctx: Ctx }) {
  const { sim, view, stats, hwC, ref, complete } = ctx;
  const pass = hwC ? JSON.stringify(hwC) === JSON.stringify(ref) : null;
  const status = sim.state === 0 && ctx.historyLength === 1 ? "Idle: no job started" : view.done ? "Complete" : view.busy ? "Computing" : "Idle";
  return (
    <div>
      <div className="hero">
        <div className="wordmark">AXIVEX</div>
        <div className="tagline">Parallel Intelligence. Engineered in Hardware.</div>
        <p className="muted">Digital Twin: a cycle-accurate behavioural model of the AXIVEX RTL (4×4 output-stationary systolic array).
          It is a software model driven by the same schedule, arithmetic and controller contract as the Verilog; it does not execute an FPGA bitstream.</p>
      </div>
      <div className="cards">
        <div className="card"><h4>Processing elements</h4><div className="big">16</div><div className="muted">4 × 4 mesh, one accumulator per PE</div></div>
        <div className="card"><h4>Input precision</h4><div className="big">INT8</div><div className="muted">signed two's complement, A and B</div></div>
        <div className="card"><h4>Accumulation</h4><div className="big">INT32</div><div className="muted">full-width, no truncation</div></div>
        <div className="card"><h4>Dataflow</h4><div className="big">OS</div><div className="muted">output-stationary: A east, B south, C stays</div></div>
      </div>
      <div className="cards">
        <div className="card"><h4>Controller state</h4><div className={`big st st-${STATE_NAMES[sim.state]}`}>{STATE_NAMES[sim.state]}</div></div>
        <div className="card"><h4>Clock cycle</h4><div className="big">{sim.cycle}</div><div className="muted">0 = start cycle; DONE appears at 13</div></div>
        <div className="card"><h4>Computation status</h4><div className="big sm">{status}</div><div className="muted">{view.completedCount}/16 results captured</div></div>
        <div className="card"><h4>Last transaction result</h4>
          <div className="big sm">{pass === null ? "—" : pass ? "PASS" : "FAIL"}</div>
          <div className="muted">{complete && pass !== null ? `${stats.totalCycles} cycles start-to-done, ${stats.runCycles} compute` : "run a job to see the result"}</div></div>
      </div>
      <div className="panel">
        <h3>Quick start</h3>
        <ol>
          <li>Matrix input: edit A and B or load an example.</li>
          <li>Press <b>Start</b> (auto-plays) or <b>Next clock</b> (one clock edge per press), then open <b>Mesh</b>.</li>
          <li>Results compares the model output with an independent reference matrix product.</li>
        </ol>
      </div>
    </div>
  );
}
