import { useState } from "react";
import { useSimulation } from "./engine-hook";
import ControlBar from "./components/ControlBar";
import Overview from "./pages/Overview";
import MatrixInput from "./pages/MatrixInput";
import Mesh from "./pages/Mesh";
import Clock from "./pages/Clock";
import Registers from "./pages/Registers";
import Results from "./pages/Results";
import Architecture from "./pages/Architecture";

const TABS = ["Overview", "Matrix input", "Mesh", "Clock", "Registers & waveforms", "Results", "Architecture"] as const;
type Tab = (typeof TABS)[number];

export default function App() {
  const ctx = useSimulation();
  const [tab, setTab] = useState<Tab>("Overview");
  return (
    <div className="app">
      <header>
        <span className="logo">AXIVEX</span><span className="sub">Digital Twin · 4×4 systolic array · behavioural model of the RTL</span>
      </header>
      <nav>{TABS.map((t) => <button key={t} className={t === tab ? "active" : ""} onClick={() => setTab(t)}>{t}</button>)}</nav>
      <ControlBar ctx={ctx} />
      <main>
        {tab === "Overview" && <Overview ctx={ctx} />}
        {tab === "Matrix input" && <MatrixInput ctx={ctx} />}
        {tab === "Mesh" && <Mesh ctx={ctx} />}
        {tab === "Clock" && <Clock ctx={ctx} />}
        {tab === "Registers & waveforms" && <Registers ctx={ctx} />}
        {tab === "Results" && <Results ctx={ctx} />}
        {tab === "Architecture" && <Architecture ctx={ctx} />}
      </main>
    </div>
  );
}
