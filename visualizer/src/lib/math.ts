/**
 * Mathematical utilities for Cathedral visualizations.
 * Computes Gram matrix entries, fractional parts, and covariance data.
 */

/** Fractional part {x} = x - floor(x) */
export function frac(x: number): number {
  return x - Math.floor(x);
}

/**
 * Gram matrix entry G_{j,k} = ∫₀¹ {j/x}{k/x} dx
 * Computed via numerical integration (Simpson's rule)
 */
export function gramEntry(j: number, k: number, numPoints: number = 2000): number {
  const n = numPoints % 2 === 0 ? numPoints : numPoints + 1;
  const h = 1.0 / n;
  let sum = 0;

  for (let i = 1; i < n; i++) {
    const x = i * h;
    const val = frac(j / x) * frac(k / x);
    sum += val * (i % 2 === 0 ? 2 : 4);
  }
  // Endpoints: at x=0, the function oscillates wildly, so we skip it
  // At x=1, {j/1}{k/1} = {j}{k}
  sum += frac(j) * frac(k);

  return (h / 3) * sum;
}

/**
 * Compute the NxN Gram matrix.
 * Returns a flat Float64Array for efficiency.
 */
export function computeGramMatrix(N: number): Float64Array {
  const matrix = new Float64Array(N * N);
  for (let j = 0; j < N; j++) {
    for (let k = j; k < N; k++) {
      const val = gramEntry(j + 1, k + 1, 1000);
      matrix[j * N + k] = val;
      matrix[k * N + j] = val;
    }
  }
  return matrix;
}

/**
 * Compute the sawtooth covariance data:
 * C(j) = G_{j, j+1} - 1/4, for j from 1 to maxJ
 */
export function computeSawtoothData(maxJ: number): { j: number; covariance: number; naiveBound: number }[] {
  const data: { j: number; covariance: number; naiveBound: number }[] = [];
  for (let j = 1; j <= maxJ; j++) {
    const g = gramEntry(j, j + 1, 2000);
    data.push({
      j,
      covariance: g - 0.25,
      naiveBound: 1 / (4 * j),
    });
  }
  return data;
}

/**
 * Compute the off-diagonal excess sum:
 * S(n) = Σ_{i≠j} (G_{ij} - 1/4)
 */
export function computeOffDiagSum(maxN: number): { n: number; sum: number; bound: number }[] {
  const data: { n: number; sum: number; bound: number }[] = [];
  // Precompute incrementally
  let runningSum = 0;
  const entries: number[][] = [];

  for (let n = 2; n <= maxN; n++) {
    // Add the new row/column contributions
    entries[n - 1] = [];
    for (let k = 0; k < n - 1; k++) {
      const g = gramEntry(n, k + 1, 500);
      entries[n - 1][k] = g;
      runningSum += 2 * (g - 0.25); // symmetric
    }
    data.push({ n, sum: runningSum, bound: 3 * n });
  }
  return data;
}
