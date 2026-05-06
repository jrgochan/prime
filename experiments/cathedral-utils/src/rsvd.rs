//! # Randomized SVD for Partial Eigendecomposition
//!
//! Implements the Halko-Martinsson-Tropp (2011) randomized SVD algorithm
//! for extracting the bottom-k eigenvalues and eigenvectors of a symmetric
//! positive-definite matrix.
//!
//! ## Algorithm
//!
//! 1. Draw random matrix Ω ∈ ℝ^{N × (k+p)}
//! 2. Form Y = A · Ω  (k+p matrix-vector products)
//! 3. QR factorize: Y = Q · R
//! 4. Form B = Q^T · A · Q  (k+p more matvecs)
//! 5. Eigendecompose B (small, instant)
//! 6. Map eigenvectors back: v_i = Q · u_i
//!
//! ## Complexity
//!
//! - Time: O(2(k+p) × cost_of_matvec + N·(k+p)²)
//! - Memory: O(N × (k+p))
//!
//! ## References
//!
//! - Halko, N., Martinsson, P.G., and Tropp, J.A. (2011).
//!   "Finding structure with randomness: Probabilistic algorithms for
//!   constructing approximate matrix decompositions."

/// Result of a randomized eigendecomposition.
#[derive(Debug, Clone)]
pub struct RsvdResult {
    /// Eigenvalues (sorted ascending).
    pub eigenvalues: Vec<f64>,
    /// Eigenvectors (each inner Vec is one eigenvector of length dim).
    pub eigenvectors: Vec<Vec<f64>>,
    /// Oversampling parameter used.
    pub oversampling: usize,
    /// Number of matvecs performed.
    pub matvecs: usize,
}

/// Simple deterministic PRNG (xoshiro256**) for reproducible random projections.
///
/// We use a custom PRNG to avoid adding a `rand` dependency.
struct Rng {
    s: [u64; 4],
}

impl Rng {
    fn new(seed: u64) -> Self {
        // SplitMix64 seeding
        let mut s = [0u64; 4];
        let mut z = seed;
        for i in 0..4 {
            z = z.wrapping_add(0x9e3779b97f4a7c15);
            z = (z ^ (z >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
            z = (z ^ (z >> 27)).wrapping_mul(0x94d049bb133111eb);
            s[i] = z ^ (z >> 31);
        }
        Self { s }
    }

    fn next_u64(&mut self) -> u64 {
        let result = (self.s[1].wrapping_mul(5)).rotate_left(7).wrapping_mul(9);
        let t = self.s[1] << 17;
        self.s[2] ^= self.s[0];
        self.s[3] ^= self.s[1];
        self.s[1] ^= self.s[2];
        self.s[0] ^= self.s[3];
        self.s[2] ^= t;
        self.s[3] = self.s[3].rotate_left(45);
        result
    }

    /// Generate a standard normal (Gaussian) random number via Box-Muller.
    fn next_gaussian(&mut self) -> f64 {
        let u1 = (self.next_u64() as f64) / (u64::MAX as f64);
        let u2 = (self.next_u64() as f64) / (u64::MAX as f64);
        let u1 = u1.max(1e-30); // avoid log(0)
        (-2.0 * u1.ln()).sqrt() * (2.0 * std::f64::consts::PI * u2).cos()
    }
}

/// Extract bottom-k eigenvalues via randomized eigendecomposition.
///
/// # Arguments
/// - `matvec`: closure computing A·v → result
/// - `dim`: matrix dimension N
/// - `k`: number of bottom eigenvalues desired
/// - `oversampling`: extra columns for accuracy (typically 5-20, default 10)
/// - `power_iterations`: extra passes for improved accuracy (0-2, default 1)
///
/// # Returns
/// An [`RsvdResult`] with the bottom-k eigenvalues and eigenvectors.
pub fn rsvd_bottom_k<F>(
    matvec: &F,
    dim: usize,
    k: usize,
    oversampling: usize,
    power_iterations: usize,
) -> RsvdResult
where
    F: Fn(&[f64], &mut [f64]),
{
    let p = oversampling;
    let l = (k + p).min(dim);
    let mut rng = Rng::new(42_u64); // deterministic seed
    let mut total_matvecs = 0usize;

    // Step 1: Generate random Gaussian matrix Ω ∈ ℝ^{N × l}
    let mut omega: Vec<Vec<f64>> = (0..l)
        .map(|_| (0..dim).map(|_| rng.next_gaussian()).collect())
        .collect();

    // Step 2: Form Y = A · Ω
    let mut y: Vec<Vec<f64>> = Vec::with_capacity(l);
    for j in 0..l {
        let mut col = vec![0.0f64; dim];
        matvec(&omega[j], &mut col);
        total_matvecs += 1;
        y.push(col);
    }

    // Step 2b: Power iteration for improved accuracy (optional)
    // Y ← A · (A · Y) repeated power_iterations times
    for _ in 0..power_iterations {
        // QR of Y for numerical stability
        qr_in_place(&mut y, dim);

        // Y ← A · Y, then A · (A·Y)
        let mut y_new: Vec<Vec<f64>> = Vec::with_capacity(l);
        for j in 0..l {
            let mut col = vec![0.0f64; dim];
            matvec(&y[j], &mut col);
            total_matvecs += 1;
            // Apply A again
            let mut col2 = vec![0.0f64; dim];
            matvec(&col, &mut col2);
            total_matvecs += 1;
            y_new.push(col2);
        }
        y = y_new;
    }

    // Step 3: QR factorize Y = Q · R
    qr_in_place(&mut y, dim);
    let q = y; // now contains orthonormal columns

    // Step 4: Form B = Q^T · A · Q  ∈ ℝ^{l × l}
    // First compute A · Q
    let mut aq: Vec<Vec<f64>> = Vec::with_capacity(l);
    for j in 0..l {
        let mut col = vec![0.0f64; dim];
        matvec(&q[j], &mut col);
        total_matvecs += 1;
        aq.push(col);
    }

    // Then B[i,j] = q_i^T · (A · q_j)
    let mut b_mat = nalgebra::DMatrix::<f64>::zeros(l, l);
    for i in 0..l {
        for j in i..l {
            let val: f64 = q[i].iter().zip(aq[j].iter()).map(|(a, b)| a * b).sum();
            b_mat[(i, j)] = val;
            b_mat[(j, i)] = val; // symmetric
        }
    }

    // Step 5: Eigendecompose B
    let eigen = b_mat.symmetric_eigen();

    // Sort by eigenvalue ascending
    let mut indexed: Vec<(f64, usize)> = eigen
        .eigenvalues
        .iter()
        .enumerate()
        .map(|(i, &v)| (v, i))
        .collect();
    indexed.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());

    // Step 6: Take bottom k and map eigenvectors back
    let k = k.min(indexed.len());
    let eigenvalues: Vec<f64> = indexed[..k].iter().map(|(v, _)| *v).collect();

    let mut eigenvectors = Vec::with_capacity(k);
    for i in 0..k {
        let (_, orig_idx) = indexed[i];
        // v_i = Σ_j u_i[j] · q_j
        let mut v = vec![0.0f64; dim];
        for j in 0..l {
            let coeff = eigen.eigenvectors[(j, orig_idx)];
            for idx in 0..dim {
                v[idx] += coeff * q[j][idx];
            }
        }
        eigenvectors.push(v);
    }

    RsvdResult {
        eigenvalues,
        eigenvectors,
        oversampling: p,
        matvecs: total_matvecs,
    }
}

/// Modified Gram-Schmidt QR factorization in place.
///
/// Orthonormalizes the columns of the input matrix.
/// After this call, each column is a unit vector orthogonal to all previous columns.
fn qr_in_place(cols: &mut [Vec<f64>], dim: usize) {
    let l = cols.len();
    for j in 0..l {
        // Orthogonalize against previous columns
        for i in 0..j {
            let dot: f64 = cols[i].iter().zip(cols[j].iter()).map(|(a, b)| a * b).sum();
            for idx in 0..dim {
                cols[j][idx] -= dot * cols[i][idx];
            }
        }
        // Normalize
        let norm: f64 = cols[j].iter().map(|x| x * x).sum::<f64>().sqrt();
        if norm > 1e-30 {
            for idx in 0..dim {
                cols[j][idx] /= norm;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rsvd_diagonal() {
        let dim = 200;
        let eigenvalues: Vec<f64> = (1..=dim).map(|i| i as f64).collect();

        let matvec = |v: &[f64], out: &mut [f64]| {
            for i in 0..dim {
                out[i] = eigenvalues[i] * v[i];
            }
        };

        let result = rsvd_bottom_k(&matvec, dim, 5, 10, 1);

        // Bottom 5 should be approximately 1, 2, 3, 4, 5
        assert_eq!(result.eigenvalues.len(), 5);
        for (i, &lambda) in result.eigenvalues.iter().enumerate() {
            let expected = (i + 1) as f64;
            assert!(
                (lambda - expected).abs() < 0.5, // RSVD is approximate
                "eigenvalue {i}: expected {expected}, got {lambda}"
            );
        }
    }

    #[test]
    fn test_rng_deterministic() {
        let mut rng1 = Rng::new(12345);
        let mut rng2 = Rng::new(12345);
        for _ in 0..100 {
            assert_eq!(rng1.next_u64(), rng2.next_u64());
        }
    }

    #[test]
    fn test_qr_orthogonality() {
        let dim = 50;
        let l = 10;
        let mut rng = Rng::new(42);
        let mut cols: Vec<Vec<f64>> = (0..l)
            .map(|_| (0..dim).map(|_| rng.next_gaussian()).collect())
            .collect();

        qr_in_place(&mut cols, dim);

        // Check orthonormality
        for i in 0..l {
            let norm: f64 = cols[i].iter().map(|x| x * x).sum::<f64>().sqrt();
            assert!((norm - 1.0).abs() < 1e-12, "column {i} not unit: norm = {norm}");

            for j in (i + 1)..l {
                let dot: f64 = cols[i].iter().zip(cols[j].iter()).map(|(a, b)| a * b).sum();
                assert!(dot.abs() < 1e-12, "columns {i},{j} not orthogonal: dot = {dot}");
            }
        }
    }
}
