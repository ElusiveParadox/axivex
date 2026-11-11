import type { Ctx } from "../engine-hook";
import { STATE_NAMES } from "../engine";

export default function ControlBar({ ctx }: { ctx: Ctx }) {
  const { sim, dispatch, playing, speedMs, canPrev, inputError } = ctx;
  const started = ctx.historyLength > 1;
  return (
    <div className="controlbar">
      <div className="ctl-group">
        <button disabled={!!inputError || playing} onClick={() => dispatch({ type: "start" })} title="Reset and run from the start">Start</button>
        <button disabled={!playing} onClick={() => dispatch({ type: "pause" })}>Pause</button>
        <button disabled={playing || !started} onClick={() => dispatch({ type: "resume" })}>Resume</button>
        <button disabled={!!inputError || playing} onClick={() => dispatch({ type: "next" })} title="Advance exactly one clock edge">Next clock</button>
        <button disabled={!canPrev || playing} onClick={() => dispatch({ type: "prev" })} title="Step back through recorded snapshots">Prev clock</button>
        <button disabled={!!inputError || playing} onClick={() => dispatch({ type: "runAll" })}>Run to DONE</button>
        <button onClick={() => dispatch({ type: "reset" })}>Reset</button>
      </div>
      <label className="ctl-speed">
        Speed
        <input type="range" min={80} max={1500} step={20} value={1580 - speedMs}
          onChange={(e) => dispatch({ type: "speed", ms: 1580 - Number(e.target.value) })} />
        <span>{speedMs} ms/clock</span>
      </label>
      <div className="ctl-readout">
        <span>cycle <b>{sim.cycle}</b></span>
        <span>state <b className={`st st-${STATE_NAMES[sim.state]}`}>{STATE_NAMES[sim.state]}</b></span>
        <span>cycle_count <b>{sim.cycleCount}</b></span>
      </div>
      {inputError && <div className="err">Input error: {inputError}</div>}
    </div>
  );
}
