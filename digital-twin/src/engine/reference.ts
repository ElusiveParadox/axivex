import { INT8_MAX, INT8_MIN, type Matrix } from "./types";

/** Independent reference: C = A x B by the textbook triple loop (no scheduling). */
export function referenceMatmul(A: Matrix, B: Matrix): Matrix {
  const m = A.length;
  const kDim = A[0].length;
  const n = B[0].length;
  const C: Matrix = Array.from({ length: m }, () => Array<number>(n).fill(0));
  for (let i = 0; i < m; i++)
    for (let j = 0; j < n; j++)
      for (let k = 0; k < kDim; k++) C[i][j] += A[i][k] * B[k][j];
  return C;
}

export function isInt8(v: number): boolean {
  return Number.isInteger(v) && v >= INT8_MIN && v <= INT8_MAX;
}

export function validateMatrix(X: Matrix, name = "matrix"): string | null {
  if (X.length !== 4 || X.some((r) => r.length !== 4)) return `${name} must be 4x4`;
  for (let i = 0; i < 4; i++)
    for (let j = 0; j < 4; j++)
      if (!isInt8(X[i][j])) return `${name}[${i}][${j}] = ${X[i][j]} is not a signed INT8 (-128..127)`;
  return null;
}

export const flatten = (X: Matrix): number[] => X.flat();
export const unflatten = (v: number[]): Matrix => [0, 1, 2, 3].map((r) => v.slice(r * 4, r * 4 + 4));
