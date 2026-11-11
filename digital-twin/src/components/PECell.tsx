import type { CycleView } from "../engine";

interface Props {
  i: number; j: number; v: CycleView; completed: boolean; selected?: boolean; onSelect?: () => void;
}

export default function PECell({ i, j, v, completed, selected, onSelect }: Props) {
  const p = i * 4 + j;
  const inp = v.pes[p];
  const regs = v.regs[p];
  const firing = v.firing[p];
  const east = j < 3 && v.pes[p + 1].aValid;
  const south = i < 3 && v.pes[p + 4].bValid;
  return (
    <div className={`pe ${firing ? "firing" : ""} ${completed ? "completed" : ""} ${selected ? "selected" : ""}`} onClick={onSelect}>
      <div className="pe-head">PE({i},{j}){regs.resultValid && <span className="tag res">RESULT</span>}</div>
      <div className="pe-row"><span>A</span><b className={inp.aValid ? "on" : "off"}>{inp.aValid ? inp.aIn : "—"}</b></div>
      <div className="pe-row"><span>B</span><b className={inp.bValid ? "on" : "off"}>{inp.bValid ? inp.bIn : "—"}</b></div>
      <div className="pe-row"><span>A×B</span><b className={firing ? "on" : "off"}>{firing ? inp.product : "—"}</b></div>
      <div className="pe-row acc"><span>ACC</span><b>{regs.acc}</b></div>
      <div className="pe-flags">
        <span className={inp.aValid ? "f on" : "f"}>Av</span>
        <span className={inp.bValid ? "f on" : "f"}>Bv</span>
        <span className={inp.aLast && inp.bLast ? "f on last" : "f"}>last</span>
        <span className={regs.resultValid ? "f on" : "f"}>rv</span>
      </div>
      {j < 3 && <div className={`arrow east ${east ? "flow" : ""}`} />}
      {i < 3 && <div className={`arrow south ${south ? "flow" : ""}`} />}
    </div>
  );
}
