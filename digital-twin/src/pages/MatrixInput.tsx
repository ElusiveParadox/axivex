import type { Ctx } from "../engine-hook";
import MatrixGrid from "../components/MatrixGrid";
import { EXAMPLES, IDENTITY, ZERO, randomMatrix } from "../data/examples";

export default function MatrixInput({ ctx }: { ctx: Ctx }) {
  const { A, B, dispatch, inputError } = ctx;
  return (
    <div>
      <div className="panel">
        <h3>Matrix input (signed INT8, −128…127)</h3>
        <div className="matrices">
          <MatrixGrid title="Matrix A" M={A} editable onChange={(m) => dispatch({ type: "setA", A: m })} />
          <div className="times">×</div>
          <MatrixGrid title="Matrix B" M={B} editable onChange={(m) => dispatch({ type: "setB", B: m })} />
        </div>
        {inputError ? <div className="err">{inputError}</div> : <div className="ok">Inputs valid.</div>}
        <p className="muted">Editing a matrix resets the simulation. Packing used by the RTL: element (i,j) at index i·4+j, row-major.</p>
      </div>
      <div className="panel">
        <h3>Generate</h3>
        <div className="btnrow">
          <button onClick={() => dispatch({ type: "setA", A: IDENTITY })}>A = identity</button>
          <button onClick={() => dispatch({ type: "setB", B: IDENTITY })}>B = identity</button>
          <button onClick={() => dispatch({ type: "setA", A: ZERO })}>A = zero</button>
          <button onClick={() => dispatch({ type: "setB", B: ZERO })}>B = zero</button>
          <button onClick={() => dispatch({ type: "setA", A: randomMatrix() })}>A = random</button>
          <button onClick={() => dispatch({ type: "setB", B: randomMatrix() })}>B = random</button>
          <button onClick={() => dispatch({ type: "setBoth", A: randomMatrix(), B: randomMatrix() })}>Both random</button>
          <button onClick={() => dispatch({ type: "setBoth", A: EXAMPLES[0].A, B: EXAMPLES[0].B })}>Load sample input</button>
          <button onClick={() => dispatch({ type: "setBoth", A: ZERO, B: ZERO })}>Reset matrices</button>
        </div>
      </div>
      <div className="panel">
        <h3>Custom test examples</h3>
        <div className="btnrow">
          {EXAMPLES.map((e) => (
            <button key={e.name} onClick={() => dispatch({ type: "setBoth", A: e.A, B: e.B })}>{e.name}</button>
          ))}
        </div>
      </div>
    </div>
  );
}
