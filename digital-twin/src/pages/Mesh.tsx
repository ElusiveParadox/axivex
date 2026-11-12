import type { Ctx } from "../engine-hook";
import PECell from "../components/PECell";
import { STATE_NAMES } from "../engine";

export default function Mesh({ ctx }: { ctx: Ctx }) {
  const { view: v, sim } = ctx;
  return (
    <div>
      <div className="panel slim">
        <b className={`st st-${STATE_NAMES[sim.state]}`}>{STATE_NAMES[sim.state]}</b> · cycle {sim.cycle} · cycle_count {sim.cycleCount} ·
        active PEs {v.activeCount} · results captured {v.completedCount}/16
        <span className="legend"><i className="lg firing" /> MAC fires this cycle <i className="lg completed" /> result captured <i className="lg flow" /> operand in transit</span>
      </div>
      <div className="mesh">
        <div className="corner">A↓ / B→</div>
        {v.colLanes.map((l, j) => (
          <div key={`b${j}`} className={`lane top ${l.valid ? "on" : ""}`}>B col {j}<b>{l.valid ? l.data : "—"}</b>{l.last && <em>last</em>}</div>
        ))}
        {[0, 1, 2, 3].map((i) => (
          <div key={`row${i}`} className="mesh-row">
            <div className={`lane left ${v.rowLanes[i].valid ? "on" : ""}`}>A row {i}<b>{v.rowLanes[i].valid ? v.rowLanes[i].data : "—"}</b>{v.rowLanes[i].last && <em>last</em>}</div>
            {[0, 1, 2, 3].map((j) => (
              <PECell key={j} i={i} j={j} v={v} completed={sim.cValidBits[i * 4 + j]} />
            ))}
          </div>
        ))}
      </div>
      <p className="muted">A moves east, B moves south, one registered hop per clock. Each PE keeps its own accumulator (output-stationary): partial sums never travel.
        PE(i,j) sees A[i][k] and B[k][j] together at cycle_count = i+j+k.</p>
    </div>
  );
}
