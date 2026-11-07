import unittest
import matrix_model as mm


class ModelTests(unittest.TestCase):
    def test_identity(self):
        B = [[i * 4 + j - 8 for j in range(4)] for i in range(4)]
        self.assertEqual(mm.matmul_ref(mm.identity(), B), B)

    def test_known_small(self):
        A = [[1, 2], [3, 4]]
        B = [[5, 6], [7, 8]]
        self.assertEqual(mm.matmul_ref(A, B), [[19, 22], [43, 50]])

    def test_extremes_fit_int32(self):
        C = mm.matmul_ref(mm.const(-128), mm.const(-128))
        self.assertTrue(all(v == 4 * 16384 for r in C for v in r))
        for _, A, B in mm.directed_cases():
            for r in mm.matmul_ref(A, B):
                for v in r:
                    self.assertTrue(mm.INT32_MIN <= v <= mm.INT32_MAX)

    def test_non_square(self):
        A = [[1, 2, 3]]
        B = [[1], [10], [100]]
        self.assertEqual(mm.matmul_ref(A, B), [[321]])

    def test_random_reproducible(self):
        self.assertEqual(mm.random_cases(7, 5), mm.random_cases(7, 5))
        self.assertNotEqual(mm.random_cases(7, 5), mm.random_cases(8, 5))

    def test_random_in_range(self):
        for _, A, B in mm.random_cases(3, 50):
            mm.check_int8(A)
            mm.check_int8(B)

    def test_out_of_range_rejected(self):
        with self.assertRaises(ValueError):
            mm.check_int8([[128]])

    def test_roundtrip(self):
        import tempfile, os
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "v.txt")
            mm.write_vectors(p, mm.directed_cases())
            back = mm.read_vectors(p)
            for (n, A, B), (n2, A2, B2, C2) in zip(mm.directed_cases(), back):
                self.assertEqual((n, A, B, mm.matmul_ref(A, B)), (n2, A2, B2, C2))


if __name__ == "__main__":
    unittest.main()
