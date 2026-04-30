//! Sieve envelope optimizer for the Nyman-Beurling distance d²_N.
//!
//! Instead of fixed sieve weights, we parametrize the smooth envelope
//!   F(x) = c₁(1-x) + c₂(1-x)² + ... + c_K(1-x)^K
//! and optimize the parameters c₁,...,c_K to minimize d²_N.
//!
//! KEY INSIGHT: Since c_k depends linearly on the envelope parameters,
//! d²_N is quadratic in (c₁,...,c_K). The minimum is found by solving
//! a tiny K×K linear system — no gradient descent needed.
//!
//! Supports both Möbius (μ) and Liouville (λ) cores.

use crate::arith;
use crate::gram::GramMatrix;

// ═══════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════

/// Default number of envelope basis functions (degree of F).
pub const DEFAULT_NUM_BASIS: usize = 4;

/// The arithmetic core function to use.
#[derive(Debug, Clone, Copy)]
pub enum ArithCore {
    /// μ(d): zeros out non-squarefree integers.
    Mobius,
    /// λ(d) = (-1)^Ω(d): preserves mass on all integers.
    Liouville,
}

impl ArithCore {
    pub fn name(&self) -> &'static str {
        match self {
            ArithCore::Mobius => "Möbius",
            ArithCore::Liouville => "Liouville",
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// RESULT
// ═══════════════════════════════════════════════════════════════

/// Result of the envelope optimization for a single N.
#[derive(Debug)]
pub struct OptimResult {
    pub n: usize,
    pub core: &'static str,
    pub theta: f64,
    pub d_level: usize,
    pub num_basis: usize,
    /// Optimal envelope coefficients [c₁, ..., c_K].
    pub params: Vec<f64>,
    /// Minimum d²_N achieved.
    pub d2_min: f64,
    /// d²_N with uniform Selberg envelope F(x) = (1-x) for comparison.
    pub d2_selberg: f64,
    /// Improvement ratio: 1 - d2_min/d2_selberg.
    pub improvement: f64,
}

// ═══════════════════════════════════════════════════════════════
// LIOUVILLE TABLE
// ═══════════════════════════════════════════════════════════════

/// Compute λ(n) = (-1)^Ω(n) for n = 0..=max_n.
fn liouville_table(max_n: usize) -> Vec<i8> {
    let mut omega = vec![0u32; max_n + 1];
    for p in 2..=max_n {
        if omega[p] != 0 {
            continue;
        }
        let mut pk = p;
        while pk <= max_n {
            for m in (pk..=max_n).step_by(pk) {
                omega[m] += 1;
            }
            if pk > max_n / p {
                break;
            }
            pk *= p;
        }
    }
    (0..=max_n)
        .map(|n| if omega[n] % 2 == 0 { 1i8 } else { -1i8 })
        .collect()
}

// ═══════════════════════════════════════════════════════════════
// BASIS VECTOR CONSTRUCTION
// ═══════════════════════════════════════════════════════════════

/// Compute the ℓ-th basis vector φ_ℓ for the envelope expansion.
///
/// φ_ℓ(k) = (1/k) · Σ_{d | k, d ≤ D} w(d) · (1 - ln(d)/ln(D))^ℓ
///
/// where w(d) = μ(d) or λ(d) depending on the core.
fn basis_vector(
    n: usize,
    ell: usize,
    d_max: usize,
    log_d: f64,
    mu: &[i8],
    liou: Option<&[i8]>,
) -> Vec<f64> {
    let dim = n - 1;
    (0..dim)
        .map(|i| {
            let k = i + 2;
            let mut s = 0.0f64;
            for d in 1..=d_max.min(k) {
                if k % d != 0 || d >= mu.len() {
                    continue;
                }
                let weight = if let Some(lv) = liou {
                    lv[d] as f64
                } else {
                    if mu[d] == 0 {
                        continue;
                    }
                    mu[d] as f64
                };
                let x = (d as f64).ln() / log_d;
                let cutoff = (1.0 - x).max(0.0);
                s += weight * cutoff.powi(ell as i32);
            }
            s / k as f64
        })
        .collect()
}

// ═══════════════════════════════════════════════════════════════
// GENERAL GAUSSIAN SOLVER
// ═══════════════════════════════════════════════════════════════

/// Solve an n×n linear system via Gaussian elimination with partial pivoting.
fn solve_linear(a: &mut Vec<Vec<f64>>, b: &mut Vec<f64>) -> Vec<f64> {
    let n = b.len();

    // Forward elimination with partial pivoting
    for col in 0..n {
        // Find pivot
        let mut max_row = col;
        let mut max_val = a[col][col].abs();
        for row in (col + 1)..n {
            if a[row][col].abs() > max_val {
                max_val = a[row][col].abs();
                max_row = row;
            }
        }
        // Swap rows
        if max_row != col {
            a.swap(col, max_row);
            b.swap(col, max_row);
        }
        // Eliminate below
        let pivot = a[col][col];
        if pivot.abs() < 1e-30 {
            continue;
        }
        for row in (col + 1)..n {
            let factor = a[row][col] / pivot;
            for j in col..n {
                let val = a[col][j]; // avoid borrow conflict
                a[row][j] -= factor * val;
            }
            b[row] -= factor * b[col];
        }
    }

    // Back substitution
    let mut x = vec![0.0f64; n];
    for col in (0..n).rev() {
        if a[col][col].abs() < 1e-30 {
            continue;
        }
        x[col] = b[col];
        for j in (col + 1)..n {
            x[col] -= a[col][j] * x[j];
        }
        x[col] /= a[col][col];
    }
    x
}

// ═══════════════════════════════════════════════════════════════
// OPTIMIZER
// ═══════════════════════════════════════════════════════════════

/// Optimize the sieve envelope F(x) = Σ c_ℓ (1-x)^ℓ to minimize d²_N.
///
/// `num_basis`: number of basis functions (degree of the envelope polynomial).
///
/// The optimization reduces to a num_basis × num_basis linear system:
///   A · c = r
/// where A_{ℓm} = φ_ℓ^T G φ_m  and  r_ℓ = φ_ℓ^T b.
pub fn optimize(gram: &GramMatrix, n: usize, theta: f64, core: ArithCore, num_basis: usize) -> OptimResult {
    let dim = n - 1;
    let d_max = (n as f64).powf(theta) as usize;
    let log_d = (d_max.max(2) as f64).ln();
    let nb = num_basis;

    let mu = arith::mobius_table(d_max + 1);
    let liou_table = match core {
        ArithCore::Liouville => Some(liouville_table(d_max + 1)),
        ArithCore::Mobius => None,
    };
    let liou_ref = liou_table.as_deref();

    // Build basis vectors φ_1, ..., φ_K
    let phi: Vec<Vec<f64>> = (1..=nb)
        .map(|ell| basis_vector(n, ell, d_max, log_d, &mu, liou_ref))
        .collect();

    // Extract submatrix and b-vector
    let (sub, _) = gram.extract_submatrix(n);
    let b = arith::b_vector(dim);

    // Build the K × K matrix A where A[l][m] = φ_l^T G φ_m
    let mut a_mat = vec![vec![0.0f64; nb]; nb];
    for l in 0..nb {
        for m in l..nb {
            let mut val = 0.0f64;
            for i in 0..dim {
                for j in 0..dim {
                    val += phi[l][i] * sub[i * dim + j] * phi[m][j];
                }
            }
            a_mat[l][m] = val;
            a_mat[m][l] = val; // symmetric
        }
    }

    // Build the right-hand side r where r[l] = φ_l^T b
    let mut rhs = vec![0.0f64; nb];
    for l in 0..nb {
        rhs[l] = phi[l].iter().zip(b.iter()).map(|(p, b)| p * b).sum();
    }

    // Solve A c = r
    let mut a_copy = a_mat.clone();
    let mut rhs_copy = rhs.clone();
    let params = solve_linear(&mut a_copy, &mut rhs_copy);

    // Compute optimal d²_N = 1 - 2 r^T c + c^T A c
    let mut d2_min = 1.0f64;
    for l in 0..nb {
        d2_min -= 2.0 * rhs[l] * params[l];
        for m in 0..nb {
            d2_min += params[l] * a_mat[l][m] * params[m];
        }
    }

    // Compare with standard Selberg: F(x) = (1-x), i.e. c = [1, 0, 0, ...]
    let d2_selberg = 1.0 - 2.0 * rhs[0] + a_mat[0][0];

    let improvement = if d2_selberg > 1e-30 {
        1.0 - d2_min / d2_selberg
    } else {
        0.0
    };

    OptimResult {
        n,
        core: core.name(),
        theta,
        d_level: d_max,
        num_basis: nb,
        params,
        d2_min,
        d2_selberg,
        improvement,
    }
}

/// Run the optimizer across multiple N values and compare cores.
pub fn sweep(
    gram: &GramMatrix,
    test_ns: &[usize],
    theta: f64,
    num_basis: usize,
) -> Vec<OptimResult> {
    let mut results = Vec::new();
    for &n in test_ns {
        if n < 10 || n > gram.max_n {
            continue;
        }
        if n > 2000 {
            continue;
        }
        results.push(optimize(gram, n, theta, ArithCore::Mobius, num_basis));
        results.push(optimize(gram, n, theta, ArithCore::Liouville, num_basis));
    }
    results
}
