import type { Ctx } from "../engine-hook";
import { STATE_NAMES, S_RUN } from "../engine";

export default function Clock({ ctx }: { ctx: Ctx }) {
  const { view: v, sim, rows, stats } = ctx;
  const prevActive = rows.length >= 2 && rows[rows.length - 2].st === S_RUN
    ? rows[rows.length - 2].pes.filter((p) => p.av && p.bv).length : 0;
  let phase = "—";
  if (sim.state === 1) phase = "CLEAR: accumulators zeroed at the coming edge";
  else if (sim.state === S_RUN) phase = v.activeCount > prevActive ? "Fill (wavefront widening)" : v.activeCount === prevActive ? "Steady (peak activity)" : "Drain (wavefront narrowing)";
  else if (sim.state === 3) phase = "Retire: last PE result being captured";
  else if (sim.state === 4) phase = "Done";
  const firing = v.firing.map((f, p) => (f ? p : -1)).filter((p) => p >= 0);
  const completed = sim.cValidBits.map((c, p) => (c ? p : -1)).filter((p) => p >= 0);
  return (
    <div>
      <div className="cards">
        <div className="card"><h4>Clock cycle</h4><div className="big">{sim.cycle}</div></div>
        <div className="card"><h4>Controller state</h4><div className={`big st st-${STATE_NAMES[sim.state]}`}>{STATE_NAMES[sim.state]}</div></div>
        <div className="card"><h4>Valid operand pairs</h4><div className="big">{v.activeCount}</div></div>
        <div className="card"><h4>Completed PEs</h4><div className="big">{v.completedCount}/16</div></div>
      </div>
      <div className="panel slim"><b>Systolic phase:</b> {phase} · total clock edges elapsed in this run: {Math.max(0, ctx.idx)}</div>
      <div className="two">
        <div className="panel">
          <h3>MACs firing this cycle</h3>
          {firing.length === 0 ? <div className="muted">none</div> : (
            <table><thead><tr><th>PE</th><th>k</th><th>A</th><th>B</th><th>product</th><th>acc → next</th></tr></thead>
              <tbody>{firing.map((p) => {
                const i = Math.floor(p / 4), j = p % 4;
                const q = v.pes[p];
                return <tr key={p}><td>({i},{j})</td><td>{sim.cycleCount - i - j}</td><td>{q.aIn}</td><td>{q.bIn}</td><td>{q.product}</td><td>{v.regs[p].acc} → {v.regs[p].acc + q.product}</td></tr>;
              })}</tbody></table>
          )}
        </div>
        <div className="panel">
          <h3>Captured results</h3>
          {completed.length === 0 ? <div className="muted">none yet</div> :
            <div>{completed.map((p) => <span key={p} className="chip">C[{Math.floor(p / 4)}][{p % 4}]={sim.cData[p]}</span>)}</div>}
        </div>
      </div>
      <div className="panel">
        <h3>Cycle trace (this run)</h3>
        <div className="scroll"><table><thead><tr><th>cycle</th><th>state</th><th>cycle_count</th><th>busy</th><th>done</th><th>active PEs</th><th>results pulsing</th></tr></thead>
          <tbody>{rows.map((r) => (
            <tr key={r.c} className={r.c === sim.cycle ? "cur" : ""}>
              <td>{r.c}</td><td>{STATE_NAMES[r.st]}</td><td>{r.cnt}</td><td>{+r.busy}</td><td>{+r.done}</td>
              <td>{r.pes.filter((p) => p.av && p.bv).length}</td>
              <td>{r.pes.map((p, i) => (p.rv ? `(${Math.floor(i / 4)},${i % 4})` : "")).filter(Boolean).join(" ") || "—"}</td>
            </tr>))}</tbody></table></div>
        <div className="muted">Elapsed so far: {stats.totalCycles} cycles.</div>
      </div>
    </div>
  );
}
