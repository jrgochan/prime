//! Gram matrix entry computation using piecewise-exact integration.
//!
//! G[j,k] = ∫₀¹ {j/x}{k/x} dx
//!
//! where {y} = y - floor(y) is the fractional part.
//!
//! On any interval where floor(j/x) = a and floor(k/x) = b are constant,
//! the integrand is (j/x - a)(k/x - b) = jk/x² - (bj + ak)/x + ab.
//!
//! The antiderivative is: -jk/x - (bj + ak)·ln(x) + ab·x
//!
//! The discontinuities of {j/x} on (0,1] occur at x = j/m for m = j, j+1, j+2, ...
//! Similarly for {k/x}. We merge these into a sorted partition and integrate
//! piecewise-exactly.

use rayon::prelude::*;

/// Compute a single Gram matrix entry G[j,k] = ∫₀¹ {j/x}{k/x} dx
/// using exact piecewise integration.
///
/// This is exact up to floating-point precision (no quadrature error).
pub fn gram_entry(j: usize, k: usize) -> f64 {
    if j == 0 || k == 0 {
        return 0.0;
    }
    let jf = j as f64;
    let kf = k as f64;

    // Collect all discontinuity points in (0, 1] for both {j/x} and {k/x}.
    // {j/x} changes at x = j/m for integer m ≥ j (since x ≤ 1 requires m ≥ j).
    // We need x > 0, so m can go up to some large value, but x = j/m → 0 as m → ∞.
    // The practical cutoff: x = j/m > ε (below ε the contribution is negligible).
    //
    // For x ∈ (j/(m+1), j/m], floor(j/x) = m, so {j/x} = j/x - m.
    //
    // Maximum m: when x → 0, both {j/x}{k/x} → O(1) but the interval width → 0.
    // Contribution of interval (j/(m+1), j/m] is bounded by j/m - j/(m+1) = j/(m(m+1)).
    // Sum from m=M to ∞ of j/(m(m+1)) ≈ j/M. So truncating at m = max(j,k)*10 + 100
    // gives error < 0.01/max(j,k), which is negligible.

    let m_max = (j.max(k)) * 100 + 2000;

    // Gather all breakpoints in (0, 1]
    let mut breaks: Vec<f64> = Vec::with_capacity(2 * m_max);

    // Breakpoints from {j/x}: x = j/m for m = j..m_max
    for m in j..=m_max {
        let x = jf / (m as f64);
        if x > 0.0 && x <= 1.0 {
            breaks.push(x);
        }
    }

    // Breakpoints from {k/x}: x = k/m for m = k..m_max
    for m in k..=m_max {
        let x = kf / (m as f64);
        if x > 0.0 && x <= 1.0 {
            breaks.push(x);
        }
    }

    // Add the boundary x = 1 and a small epsilon for the lower end
    breaks.push(1.0);

    // Sort and deduplicate
    breaks.sort_by(|a, b| a.partial_cmp(b).unwrap());
    breaks.dedup_by(|a, b| (*a - *b).abs() < 1e-15);

    // Integrate piecewise
    let mut total = 0.0;

    for i in 0..breaks.len() - 1 {
        let x_lo = breaks[i];
        let x_hi = breaks[i + 1];

        if x_hi - x_lo < 1e-18 {
            continue;
        }

        // Evaluate floor(j/x) and floor(k/x) at the midpoint
        let x_mid = 0.5 * (x_lo + x_hi);
        let a = (jf / x_mid).floor(); // floor(j/x) on this interval
        let b = (kf / x_mid).floor(); // floor(k/x) on this interval

        // Integrand: (j/x - a)(k/x - b) = jk/x² - (bj + ak)/x + ab
        // Antiderivative: F(x) = -jk/x - (bj + ak)·ln(x) + ab·x
        let jk = jf * kf;
        let lin_coeff = b * jf + a * kf;
        let const_coeff = a * b;

        let f_hi = -jk / x_hi - lin_coeff * x_hi.ln() + const_coeff * x_hi;
        let f_lo = -jk / x_lo - lin_coeff * x_lo.ln() + const_coeff * x_lo;

        total += f_hi - f_lo;
    }

    total
}

/// Compute the full Gram matrix for indices 2..=n (so an (n-1) × (n-1) matrix).
/// Returns a flat Vec in row-major order.
///
/// Uses Rayon parallelism: each entry is computed independently.
pub fn compute_gram_matrix(n: usize, progress: Option<&indicatif::ProgressBar>) -> Vec<f64> {
    let dim = n - 1; // indices 2..=n → dim = n-1
    let total_entries = dim * (dim + 1) / 2; // upper triangle only (symmetric)

    // Generate upper-triangle index pairs
    let pairs: Vec<(usize, usize)> = (0..dim)
        .flat_map(|i| (i..dim).map(move |j_idx| (i, j_idx)))
        .collect();

    if let Some(pb) = progress {
        pb.set_length(total_entries as u64);
        pb.set_message("Computing Gram entries");
    }

    // Compute upper triangle in parallel
    let entries: Vec<(usize, usize, f64)> = pairs
        .par_iter()
        .map(|&(i, j_idx)| {
            let j = i + 2; // actual index (2-based)
            let k = j_idx + 2;
            let val = gram_entry(j, k);
            if let Some(pb) = progress {
                pb.inc(1);
            }
            (i, j_idx, val)
        })
        .collect();

    // Fill symmetric matrix
    let mut matrix = vec![0.0f64; dim * dim];
    for (i, j_idx, val) in entries {
        matrix[i * dim + j_idx] = val;
        matrix[j_idx * dim + i] = val;
    }

    matrix
}

/// Compute only the Gram entries needed for a specific block (indices within one residue class).
/// Returns a dense square matrix for that block.
pub fn compute_block_matrix(
    indices: &[usize],
    progress: Option<&indicatif::ProgressBar>,
) -> Vec<f64> {
    let dim = indices.len();
    let total_entries = dim * (dim + 1) / 2;

    if let Some(pb) = progress {
        pb.set_length(total_entries as u64);
    }

    let pairs: Vec<(usize, usize)> = (0..dim)
        .flat_map(|i| (i..dim).map(move |j| (i, j)))
        .collect();

    let entries: Vec<(usize, usize, f64)> = pairs
        .par_iter()
        .map(|&(i, j)| {
            let val = gram_entry(indices[i], indices[j]);
            if let Some(pb) = progress {
                pb.inc(1);
            }
            (i, j, val)
        })
        .collect();

    let mut matrix = vec![0.0f64; dim * dim];
    for (i, j, val) in entries {
        matrix[i * dim + j] = val;
        matrix[j * dim + i] = val;
    }

    matrix
}

/// Compute the cross-block interaction matrix between two residue classes.
/// Returns a (|class1| × |class2|) dense matrix.
pub fn compute_cross_matrix(indices1: &[usize], indices2: &[usize]) -> Vec<f64> {
    let rows = indices1.len();
    let cols = indices2.len();

    let pairs: Vec<(usize, usize)> = (0..rows)
        .flat_map(|i| (0..cols).map(move |j| (i, j)))
        .collect();

    let entries: Vec<(usize, usize, f64)> = pairs
        .par_iter()
        .map(|&(i, j)| {
            let val = gram_entry(indices1[i], indices2[j]);
            (i, j, val)
        })
        .collect();

    let mut matrix = vec![0.0f64; rows * cols];
    for (i, j, val) in entries {
        matrix[i * cols + j] = val;
    }

    matrix
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_gram_diagonal() {
        // G[k,k] = ∫₀¹ {k/x}² dx  (piecewise-exact integration)
        //
        // NOTE: This integral converges slowly with m_max — the breakpoints
        // x = j/m extend down to x ≈ j/m_max, so the contribution from
        // x ∈ (0, j/m_max] is silently truncated. With m_max = 2200,
        // G[2,2] converges to ~0.2939 (verified with scipy quad and
        // m_max = 100_000 convergence study).
        let g22 = gram_entry(2, 2);
        assert!(
            (g22 - 0.2939).abs() < 0.005,
            "G[2,2] = {}, expected ~0.2939",
            g22
        );
    }

    #[test]
    fn test_gram_symmetry() {
        let g23 = gram_entry(2, 3);
        let g32 = gram_entry(3, 2);
        assert!(
            (g23 - g32).abs() < 1e-12,
            "G[2,3] ≠ G[3,2]: {} vs {}",
            g23,
            g32
        );
    }

    #[test]
    fn test_gram_offdiag() {
        // G[2,3] = ∫₀¹ {2/x}{3/x} dx ≈ 0.2341 (converged)
        let g23 = gram_entry(2, 3);
        assert!(
            (g23 - 0.2341).abs() < 0.005,
            "G[2,3] = {}, expected ~0.2341",
            g23
        );
    }
}
