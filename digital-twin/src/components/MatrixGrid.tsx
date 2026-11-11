import type { Matrix } from "../engine";

interface Props {
  title: string;
  M: Matrix;
  editable?: boolean;
  onChange?: (m: Matrix) => void;
  highlight?: (i: number, j: number) => string;
}

export default function MatrixGrid({ title, M, editable, onChange, highlight }: Props) {
  return (
    <div className="matrix">
      <div className="matrix-title">{title}</div>
      <div className="matrix-grid">
        {M.map((row, i) =>
          row.map((v, j) =>
            editable ? (
              <input key={`${i}-${j}`} className={`cell ${Number.isInteger(v) && v >= -128 && v <= 127 ? "" : "bad"}`}
                type="number" value={Number.isNaN(v) ? "" : v}
                onChange={(e) => {
                  const nv = e.target.value === "" ? NaN : Number(e.target.value);
                  onChange?.(M.map((r, ri) => r.map((x, cj) => (ri === i && cj === j ? nv : x))));
                }} />
            ) : (
              <div key={`${i}-${j}`} className={`cell ro ${highlight?.(i, j) ?? ""}`}>{v}</div>
            ),
          ),
        )}
      </div>
    </div>
  );
}
