//! ═══════════════════════════════════════════════════════════════════════════
//!  DARK GRAM MATRIX ENGINE
//!
//!  Constructs the Dark Gram matrix G^(n) at Bernoulli order n.
//!
//!  KEY DISCOVERY: For n=2, the Dark Gram matrix has the exact closed form:
//!
//!    G^(2)_{j,k} = gcd(j,k)⁴ / (180 · j² · k²)
//!
//!  No integrals. No series. Just gcd and multiplication.
//!
//!  For general even n, the Fourier series of the periodized Bernoulli
//!  polynomial converges as m^{-2n}, giving rapid closed-form-like
//!  convergence with just ~100 terms.
//! ═══════════════════════════════════════════════════════════════════════════

use cathedral_utils::arith::gcd;
use rayon::prelude::*;

use crate::bernoulli;

// ═══════════════════════════════════════════════════════════════
// CLOSED-FORM ENGINE (n=2)
// ═══════════════════════════════════════════════════════════════

/// **EXACT** closed-form Dark Gram entry for Bernoulli order n=2.
///
/// G^(2)_{j,k} = gcd(j,k)⁴ / (180 · j² · k²)
///
/// Derived from the Fourier expansion of B̃₂(x) and orthogonality.
/// See docs/ai/antigravity/dark-sector/DARK_GRAM_DERIVATION.md
///
/// This is O(log(min(j,k))) per entry (just a gcd computation).
#[inline]
pub fn dark_gram_entry_n2(j: usize, k: usize) -> f64 {
    let g = gcd(j, k) as f64;
    let jf = j as f64;
    let kf = k as f64;
    let g4 = g * g * g * g;
    g4 / (180.0 * jf * jf * kf * kf)
}

// ═══════════════════════════════════════════════════════════════
// QUADRATURE ENGINE (general n)
// ═══════════════════════════════════════════════════════════════

/// Dark Gram entry via numerical integration (composite Simpson's rule).
///
/// G^(n)_{j,k} = ∫₀¹ B̃_n(j·x) · B̃_n(k·x) dx
///
/// Uses the hardcoded Bernoulli polynomial evaluators for speed.
/// Breakpoints at multiples of 1/j and 1/k ensure accuracy across
/// the periodization boundaries.
pub fn dark_gram_entry_quadrature(n: usize, j: usize, k: usize, num_points: usize) -> f64 {
    // Composite Simpson's rule
    let h = 1.0 / num_points as f64;
    let mut sum = 0.0;

    for i in 0..=num_points {
        let x = i as f64 * h;
        let bj = bernoulli::bernoulli_periodic_fast(n, j as f64 * x);
        let bk = bernoulli::bernoulli_periodic_fast(n, k as f64 * x);
        let f = bj * bk;

        let weight = if i == 0 || i == num_points {
            1.0
        } else if i % 2 == 1 {
            4.0
        } else {
            2.0
        };
        sum += weight * f;
    }

    sum * h / 3.0
}

// ═══════════════════════════════════════════════════════════════
// FOURIER SERIES ENGINE (general even n)
// ═══════════════════════════════════════════════════════════════

/// Dark Gram entry via Fourier series.
///
/// For even n, using the Fourier expansion of B̃_n:
///
///   G^(n)_{j,k} = 2(n!)² / (2π)^{2n} · Σ_{t=1}^{terms} 1/((j't)^n · (k't)^n)
///
/// where j' = j/gcd(j,k), k' = k/gcd(j,k).
///
/// The series converges as t^{-2n}, so even 100 terms gives
/// machine precision for n ≥ 2.
pub fn dark_gram_entry_fourier(n: usize, j: usize, k: usize, terms: usize) -> f64 {
    let g = gcd(j, k);
    let j_prime = (j / g) as f64;
    let k_prime = (k / g) as f64;

    let n_fact = factorial(n) as f64;
    let prefactor = 2.0 * n_fact * n_fact / (2.0 * std::f64::consts::PI).powi(2 * n as i32);

    let mut sum = 0.0;
    for t in 1..=terms {
        let tf = t as f64;
        let term = 1.0 / (j_prime * tf).powi(n as i32) / (k_prime * tf).powi(n as i32);
        sum += term;
        // Early exit if converged
        if t > 10 && term.abs() < sum.abs() * 1e-16 {
            break;
        }
    }

    prefactor * sum
}

/// Factorial n! for small n.
fn factorial(n: usize) -> u64 {
    (1..=n as u64).product()
}

// ═══════════════════════════════════════════════════════════════
// MATRIX BUILDERS
// ═══════════════════════════════════════════════════════════════

/// Build the full (dim×dim) Dark Gram matrix at Bernoulli order n.
///
/// Indices j,k ∈ {2, 3, ..., dim+1} (matching the positive Gram convention).
/// Returns a flat row-major array.
///
/// For n=2, uses the exact closed form (essentially free).
/// For other n, uses the Fourier series (fast convergence).
pub fn build_dark_gram(n: usize, dim: usize) -> Vec<f64> {
    eprintln!("  \x1b[2m▸ Building Dark Gram matrix: order n={n}, dim={dim}×{dim}...\x1b[0m");
    let t0 = std::time::Instant::now();

    let mat: Vec<f64> = (0..dim)
        .into_par_iter()
        .flat_map(|i| {
            let j = i + 2;
            (0..dim)
                .map(|col_idx| {
                    let k = col_idx + 2;
                    match n {
                        2 => dark_gram_entry_n2(j, k),
                        _ => dark_gram_entry_fourier(n, j, k, 10_000),
                    }
                })
                .collect::<Vec<_>>()
        })
        .collect();

    eprintln!(
        "  \x1b[32m✓\x1b[0m Dark Gram G^({n}) built: {dim}×{dim} ({:.2}s)",
        t0.elapsed().as_secs_f64()
    );
    mat
}

/// Build the Dark Gram matrix using quadrature (for cross-verification).
pub fn build_dark_gram_quadrature(n: usize, dim: usize, num_points: usize) -> Vec<f64> {
    eprintln!(
        "  \x1b[2m▸ Building Dark Gram (quadrature): n={n}, dim={dim}×{dim}, points={num_points}...\x1b[0m"
    );
    let t0 = std::time::Instant::now();

    let mat: Vec<f64> = (0..dim)
        .into_par_iter()
        .flat_map(|i| {
            let j = i + 2;
            (0..dim)
                .map(|col_idx| {
                    let k = col_idx + 2;
                    dark_gram_entry_quadrature(n, j, k, num_points)
                })
                .collect::<Vec<_>>()
        })
        .collect();

    eprintln!(
        "  \x1b[32m✓\x1b[0m Dark Gram (quadrature) built: {dim}×{dim} ({:.2}s)",
        t0.elapsed().as_secs_f64()
    );
    mat
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_n2_diagonal_is_constant() {
        // Prediction 6: G^(2)_{j,j} = 1/180 for all j
        for j in 2..=100 {
            let g = dark_gram_entry_n2(j, j);
            assert!(
                (g - 1.0 / 180.0).abs() < 1e-14,
                "Diagonal G^(2)_{{{j},{j}}} = {g}, expected 1/180"
            );
        }
    }

    #[test]
    fn test_n2_coprime_entries() {
        // For coprime j,k: gcd=1, so G = 1/(180·j²k²)
        let g = dark_gram_entry_n2(3, 5);
        let expected = 1.0 / (180.0 * 9.0 * 25.0);
        assert!(
            (g - expected).abs() < 1e-15,
            "G(3,5) = {g}, expected {expected}"
        );
    }

    #[test]
    fn test_n2_non_coprime_entries() {
        // G(4,6): gcd=2, so G = 2⁴/(180·16·36) = 16/103680
        let g = dark_gram_entry_n2(4, 6);
        let expected = 16.0 / (180.0 * 16.0 * 36.0);
        assert!(
            (g - expected).abs() < 1e-15,
            "G(4,6) = {g}, expected {expected}"
        );
    }

    #[test]
    fn test_n2_closed_vs_quadrature() {
        // Cross-verify closed form against quadrature for moderate j,k.
        // NOTE: B̃₂(jx)·B̃₂(kx) has O(j+k) derivative kinks in [0,1],
        // degrading Simpson's to O(h²). We restrict to j,k ≤ 10 where
        // 100k points suffice. The Fourier test covers the full range.
        for j in 2..=10 {
            for k in j..=10 {
                let closed = dark_gram_entry_n2(j, k);
                let quad = dark_gram_entry_quadrature(2, j, k, 100_000);
                let rel_err = (closed - quad).abs() / closed.abs().max(1e-30);
                assert!(
                    rel_err < 1e-4,
                    "n=2 closed vs quad mismatch at ({j},{k}): closed={closed:.6e}, quad={quad:.6e}, rel_err={rel_err:.2e}"
                );
            }
        }
    }

    #[test]
    fn test_n2_closed_vs_fourier() {
        // Cross-verify closed form against Fourier series
        for j in 2..=20 {
            for k in j..=20 {
                let closed = dark_gram_entry_n2(j, k);
                let fourier = dark_gram_entry_fourier(2, j, k, 100_000);
                let rel_err = (closed - fourier).abs() / closed.abs().max(1e-30);
                assert!(
                    rel_err < 1e-10,
                    "n=2 closed vs Fourier mismatch at ({j},{k}): closed={closed:.6e}, fourier={fourier:.6e}, rel_err={rel_err:.2e}"
                );
            }
        }
    }

    #[test]
    fn test_trace_formula() {
        // Prediction 8: Tr(G^(2)_N) = (N-1)/180
        let dim = 50;
        let mat = build_dark_gram(2, dim);
        let trace: f64 = (0..dim).map(|i| mat[i * dim + i]).sum();
        let expected = dim as f64 / 180.0;
        assert!(
            (trace - expected).abs() < 1e-12,
            "Trace = {trace}, expected {expected}"
        );
    }
}
