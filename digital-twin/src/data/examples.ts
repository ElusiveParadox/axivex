import type { Matrix } from "../engine";

export interface Example { name: string; A: Matrix; B: Matrix }

const seq: Matrix = [[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12], [13, 14, 15, 16]];
export const IDENTITY: Matrix = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]];
export const ZERO: Matrix = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]];
const fill = (v: number): Matrix => Array.from({ length: 4 }, () => Array<number>(4).fill(v));

export const EXAMPLES: Example[] = [
  { name: "Sample: sequence x sequence", A: seq, B: seq },
  { name: "Identity x sequence", A: IDENTITY, B: seq },
  {
    name: "Mixed signs",
    A: [[3, -7, 12, -1], [-5, 9, -2, 8], [6, -11, 4, -3], [-9, 2, -6, 10]],
    B: [[-4, 5, 1, -8], [7, -3, 9, 2], [-6, 12, -5, 3], [11, -1, 4, -10]],
  },
  { name: "INT8 minimum x minimum", A: fill(-128), B: fill(-128) },
  { name: "INT8 minimum x maximum", A: fill(-128), B: fill(127) },
  {
    name: "Sparse",
    A: [[0, 0, 5, 0], [0, 0, 0, 0], [-3, 0, 0, 0], [0, 7, 0, 0]],
    B: [[0, 2, 0, 0], [0, 0, 0, -4], [1, 0, 0, 0], [0, 0, 6, 0]],
  },
  { name: "All ones", A: fill(1), B: fill(1) },
];

export function randomMatrix(): Matrix {
  return Array.from({ length: 4 }, () => Array.from({ length: 4 }, () => Math.floor(Math.random() * 256) - 128));
}
