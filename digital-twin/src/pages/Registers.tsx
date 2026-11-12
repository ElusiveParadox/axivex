import { useState } from "react";
import type { Ctx } from "../engine-hook";
import Wave from "../components/Wave";
import { STATE_NAMES } from "../engine";

export default function Registers({ ctx }: { ctx: Ctx }) {
  const [sel, setSel] = useState(0);
  const { view: v, rows } = ctx;
  const r = v.regs[sel];
  const inp = v.pes[sel];
  const labels = rows.map((x) => String(x.c));
  const waves = [
    { name: "state", kind: "bus" as const, values: rows.map((x) => STATE_NAMES[x.st].slice(0, 3)) },
    { name: "a_in", kind: "bus" as const, values: rows.map((x) => (x.pes[sel].av ? x.pes[sel].a : "·")) },
    { name: "b_in", kind: "bus" as const, values: rows.map((x) => (x.pes[sel].bv ? x.pes[sel].b : "·")) },
    { name: "valid (A&B)", kind: "bit" as const, values: rows.map((x) => x.pes[sel].av && x.pes[sel].bv) },
    { name: "last", kind: "bit" as const, values: rows.map((x) => x.pes[sel].last) },
    { name: "acc", kind: "bus" as const, values: rows.map((x) => x.pes[sel].acc) },
    { name: "result_valid", kind: "bit" as const, values: rows.map((x) => x.pes[sel].rv) },
  ];
  return (
    <div>
      <div className="panel">
        <h3>Select PE</h3>
        <div className="selgrid">
          {Array.from({ length: 16 }, (_, p) => (
            <button key={p} className={p === sel ? "sel" : ""} onClick={() => setSel(p)}>({Math.floor(p / 4)},{p % 4})</button>
          ))}
        </div>
      </div>
      <div className="two">
        <div className="panel">
          <h3>Register monitor: PE({Math.floor(sel / 4)},{sel % 4})</h3>
          <table><tbody>
            <tr><th>A register (a_out)</th><td>{r.aOut}</td><th>A valid reg</th><td>{+r.aValidOut}</td><th>A last reg</th><td>{+r.aLastOut}</td></tr>
            <tr><th>B register (b_out)</th><td>{r.bOut}</td><th>B valid reg</th><td>{+r.bValidOut}</td><th>B last reg</th><td>{+r.bLastOut}</td></tr>
            <tr><th>Accumulator</th><td>{r.acc}</td><th>Result register</th><td>{r.result}</td><th>result_valid</th><td>{+r.resultValid}</td></tr>
            <tr><th>a_in (this cycle)</th><td>{inp.aIn}</td><th>b_in (this cycle)</th><td>{inp.bIn}</td><th>product</th><td>{inp.product}</td></tr>
          </tbody></table>
        </div>
        <div className="panel">
          <h3>Per-cycle trace: this PE</h3>
          <div className="scroll short"><table><thead><tr><th>cycle</th><th>a_in</th><th>b_in</th><th>Av</th><th>Bv</th><th>last</th><th>acc</th><th>rv</th></tr></thead>
            <tbody>{rows.map((x) => { const q = x.pes[sel]; return (
              <tr key={x.c} className={x.c === ctx.sim.cycle ? "cur" : ""}><td>{x.c}</td><td>{q.a}</td><td>{q.b}</td><td>{+q.av}</td><td>{+q.bv}</td><td>{+q.last}</td><td>{q.acc}</td><td>{+q.rv}</td></tr>); })}</tbody></table></div>
        </div>
      </div>
      <div className="panel">
        <h3>Waveform timeline (cycles recorded so far)</h3>
        {rows.length === 0 ? <div className="muted">Step the clock to record cycles.</div> :
          <div className="scroll"><Wave signals={waves} labels={labels} cursor={rows.length - 1} /></div>}
      </div>
    </div>
  );
}
