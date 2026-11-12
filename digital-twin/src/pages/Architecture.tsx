import { useState } from "react";
import type { Ctx } from "../engine-hook";
import { K, STATE_NAMES } from "../engine";

export default function Architecture({ ctx }: { ctx: Ctx }) {
  const [i, setI] = useState(2);
  const [j, setJ] = useState(1);
  return (
    <div>
      <div className="panel">
        <h3>Output-stationary dataflow</h3>
        <p>C[i][j] is owned by PE(i,j). Operands stream through the array; the running sum never leaves the PE.
          A moves east along each row, B moves south along each column; every hop is a register.</p>
      </div>
      <div className="panel">
        <h3>When do A and B reach PE(i,j)?</h3>
        <div className="btnrow">
          row i: {[0, 1, 2, 3].map((x) => <button key={x} className={x === i ? "sel" : ""} onClick={() => setI(x)}>{x}</button>)}
          col j: {[0, 1, 2, 3].map((x) => <button key={x} className={x === j ? "sel" : ""} onClick={() => setJ(x)}>{x}</button>)}
        </div>
        <table><thead><tr><th>k</th><th>A[{i}][k] injected (west edge) at t = i+k</th><th>B[k][{j}] injected (north edge) at t = j+k</th><th>Both at PE({i},{j}) at t = i+j+k</th></tr></thead>
          <tbody>{Array.from({ length: K }, (_, k) => (
            <tr key={k} className={ctx.sim.state === 2 && ctx.sim.cycleCount === i + j + k ? "cur" : ""}>
              <td>{k}</td><td>{i + k} (then {j} hops east)</td><td>{j + k} (then {i} hops south)</td><td><b>{i + j + k}</b>{k === K - 1 ? "  ← last MAC; result_valid next cycle" : ""}</td></tr>))}</tbody></table>
        <p className="muted">Row highlighted when the live simulation is at that cycle_count.</p>
      </div>
      <div className="two">
        <div className="panel"><h3>Processing element</h3>
          <p>Registers: a_out, b_out (forwarded operands), valid/last metadata, acc (INT32), result + result_valid. On a valid A/B pair:
            acc ← acc + A×B. If both last flags are set the same sum is written to result and result_valid pulses once.</p></div>
        <div className="panel"><h3>MAC unit</h3>
          <p>Combinational: signed 8×8 → 16-bit product, sign-extended to 32 bits, added to the accumulator. Zero-extension or an unsigned multiply would corrupt negative products.</p></div>
        <div className="panel"><h3>Skew scheduler</h3>
          <p>Row i delays A by i cycles, column j delays B by j cycles, so matching k terms meet. Last markers travel with the operand rather than as one global pulse.</p></div>
        <div className="panel"><h3>Accumulator behaviour</h3>
          <p>Cleared in the CLEAR state; updated only when both operands are valid; holds its value afterwards. Max |sum| for K=4 is 65536, far inside INT32.</p></div>
      </div>
      <div className="panel">
        <h3>Controller FSM (live)</h3>
        <div className="fsm">{STATE_NAMES.map((n, s) => (
          <span key={n} className={`node ${ctx.sim.state === s ? "active" : ""}`}>{n}</span>))}</div>
        <p className="muted">IDLE → CLEAR (1 cycle) → RUN (10 cycles) → RETIRE (1 cycle) → DONE (1-cycle pulse) → IDLE, or → CLEAR directly if a new start arrives in the DONE cycle.</p>
      </div>
    </div>
  );
}
