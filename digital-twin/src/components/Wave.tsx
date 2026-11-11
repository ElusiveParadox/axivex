export interface WaveSignal {
  name: string;
  kind: "bit" | "bus";
  values: (number | boolean | string)[];
}

/** Minimal SVG timeline: one column per clock cycle, drawn from recorded trace rows. */
export default function Wave({ signals, labels, cursor }: { signals: WaveSignal[]; labels: string[]; cursor: number }) {
  const colW = 46, rowH = 30, left = 110, n = labels.length;
  const width = left + n * colW + 10, height = 22 + signals.length * rowH;
  return (
    <svg className="wave" width={width} height={height} role="img" aria-label="signal timeline">
      {labels.map((l, i) => (
        <text key={i} x={left + i * colW + colW / 2} y={12} textAnchor="middle" className="wave-tick">{l}</text>
      ))}
      {cursor >= 0 && <rect x={left + cursor * colW} y={16} width={colW} height={height - 16} className="wave-cursor" />}
      {signals.map((s, r) => {
        const y0 = 22 + r * rowH;
        return (
          <g key={s.name}>
            <text x={4} y={y0 + 18} className="wave-name">{s.name}</text>
            {s.values.map((v, i) => {
              const x = left + i * colW;
              if (s.kind === "bit") {
                const hi = !!v;
                const yy = hi ? y0 + 6 : y0 + 22;
                return <line key={i} x1={x} x2={x + colW} y1={yy} y2={yy} className={hi ? "wave-hi" : "wave-lo"} />;
              }
              return (
                <g key={i}>
                  <rect x={x + 2} y={y0 + 5} width={colW - 4} height={18} rx={4} className="wave-bus" />
                  <text x={x + colW / 2} y={y0 + 18} textAnchor="middle" className="wave-val">{String(v)}</text>
                </g>
              );
            })}
          </g>
        );
      })}
    </svg>
  );
}
