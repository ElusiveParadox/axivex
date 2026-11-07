#!/usr/bin/env python3
"""AXIVEX golden reference model and test-vector generator.

The reference computes C[i][j] = sum_k A[i][k]*B[k][j] directly with Python
integers. It contains no scheduling, skew or pipeline logic.

Vector file format (text, one transaction per line, whitespace separated):
    name  A[0][0] A[0][1] ... A[3][3]  B[0][0] ... B[3][3]  C[0][0] ... C[3][3]
All values are signed decimal integers, row-major (index i*4+j).
"""
import argparse
import json
import os
import random

N = 4
INT8_MIN, INT8_MAX = -128, 127
INT32_MIN, INT32_MAX = -(1 << 31), (1 << 31) - 1


def matmul_ref(A, B):
    m, k_dim, n = len(A), len(A[0]), len(B[0])
    C = [[0] * n for _ in range(m)]
    for i in range(m):
        for j in range(n):
            for k in range(k_dim):
                C[i][j] += int(A[i][k]) * int(B[k][j])
    return C


def check_int8(M):
    for row in M:
        for v in row:
            if not INT8_MIN <= v <= INT8_MAX:
                raise ValueError(f"value {v} outside signed INT8")


def flat(M):
    return [v for row in M for v in row]


def unflat(v):
    return [list(v[r * N:(r + 1) * N]) for r in range(N)]


def const(v):
    return [[v] * N for _ in range(N)]


def identity():
    return [[1 if i == j else 0 for j in range(N)] for i in range(N)]


def directed_cases():
    seq = [[(i * N + j + 1) for j in range(N)] for i in range(N)]
    neg = [[-(i * N + j + 1) for j in range(N)] for i in range(N)]
    mixed_a = [[3, -7, 12, -1], [-5, 9, -2, 8], [6, -11, 4, -3], [-9, 2, -6, 10]]
    mixed_b = [[-4, 5, 1, -8], [7, -3, 9, 2], [-6, 12, -5, 3], [11, -1, 4, -10]]
    diag_a = [[(i + 2) * (1 if i == j else 0) for j in range(N)] for i in range(N)]
    diag_b = [[(-(j + 3)) * (1 if i == j else 0) for j in range(N)] for i in range(N)]
    sparse_a = [[0, 0, 5, 0], [0, 0, 0, 0], [-3, 0, 0, 0], [0, 7, 0, 0]]
    sparse_b = [[0, 2, 0, 0], [0, 0, 0, -4], [1, 0, 0, 0], [0, 0, 6, 0]]
    alt_a = [[(127 if (i + j) % 2 == 0 else -128) for j in range(N)] for i in range(N)]
    alt_b = [[(-1 if (i + j) % 2 == 0 else 1) * (100 + i + j) for j in range(N)] for i in range(N)]
    near_max_a = [[127 - ((i + j) % 3) for j in range(N)] for i in range(N)]
    near_max_b = [[126 + ((i * j) % 2) for j in range(N)] for i in range(N)]
    near_min_a = [[-128 + ((i + j) % 3) for j in range(N)] for i in range(N)]
    near_min_b = [[-127 - ((i * j) % 2) for j in range(N)] for i in range(N)]
    impulse_a = [[0] * N for _ in range(N)]
    impulse_a[1][2] = 9
    impulse_b = [[0] * N for _ in range(N)]
    impulse_b[2][3] = -13
    corner_a = [[0] * N for _ in range(N)]
    corner_a[3][3] = -128
    corner_b = [[0] * N for _ in range(N)]
    corner_b[3][3] = -128
    return [
        ("identity_x_seq", identity(), seq),
        ("seq_x_identity", seq, identity()),
        ("zero_x_seq", const(0), seq),
        ("seq_x_zero", seq, const(0)),
        ("all_ones", const(1), const(1)),
        ("positive_seq", seq, seq),
        ("negative_seq", neg, neg),
        ("neg_x_pos", neg, seq),
        ("mixed_signs", mixed_a, mixed_b),
        ("diagonal", diag_a, diag_b),
        ("sparse", sparse_a, sparse_b),
        ("alternating_extremes", alt_a, alt_b),
        ("near_int8_max", near_max_a, near_max_b),
        ("near_int8_min", near_min_a, near_min_b),
        ("max_x_max", const(127), const(127)),
        ("min_x_min", const(-128), const(-128)),
        ("min_x_max", const(-128), const(127)),
        ("max_x_min", const(127), const(-128)),
        ("minus_one_all", const(-1), const(-1)),
        ("impulse_inner", impulse_a, impulse_b),
        ("corner_min_min", corner_a, corner_b),
    ]


def random_cases(seed, count):
    rng = random.Random(seed)
    out = []
    for t in range(count):
        A = [[rng.randint(INT8_MIN, INT8_MAX) for _ in range(N)] for _ in range(N)]
        B = [[rng.randint(INT8_MIN, INT8_MAX) for _ in range(N)] for _ in range(N)]
        out.append((f"rand_s{seed}_{t:03d}", A, B))
    return out


def write_vectors(path, cases):
    with open(path, "w") as f:
        for name, A, B in cases:
            check_int8(A)
            check_int8(B)
            C = matmul_ref(A, B)
            row = flat(A) + flat(B) + flat(C)
            f.write(name + " " + " ".join(str(v) for v in row) + "\n")


def read_vectors(path):
    out = []
    with open(path) as f:
        for line in f:
            tok = line.split()
            if not tok:
                continue
            v = [int(x) for x in tok[1:]]
            assert len(v) == 48, f"bad line for {tok[0]}"
            out.append((tok[0], unflat(v[:16]), unflat(v[16:32]), unflat(v[32:48])))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "test_vectors"))
    ap.add_argument("--seed", type=int, default=20261116)
    ap.add_argument("--count", type=int, default=128)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    directed = directed_cases()
    rand = random_cases(args.seed, args.count)
    write_vectors(os.path.join(args.out, "directed.txt"), directed)
    write_vectors(os.path.join(args.out, "random.txt"), rand)
    with open(os.path.join(args.out, "directed.json"), "w") as f:
        json.dump([{"name": n, "A": A, "B": B, "C": matmul_ref(A, B)} for n, A, B in directed], f, indent=1)
    with open(os.path.join(args.out, "random_meta.json"), "w") as f:
        json.dump({"seed": args.seed, "count": args.count, "range": [INT8_MIN, INT8_MAX]}, f)
    print(f"wrote {len(directed)} directed and {len(rand)} random vectors (seed {args.seed}) to {args.out}")


if __name__ == "__main__":
    main()
