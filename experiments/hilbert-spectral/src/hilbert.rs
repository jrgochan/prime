// hilbert-spectral/src/hilbert.rs
//
// Hilbert matrix spectral analysis — 512-bit MPFR precision
//
// The discrete Hilbert matrix H_N has entries:
//   H(m,n) = 1/(m-n)  for m ≠ n,  H(m,m) = 0
//
// Its operator norm ‖H_N‖ → π as N → ∞ (Schur, 1911).
// This is the fundamental constant underlying the Montgomery-Vaughan
// Hilbert inequality used in the Cathedral proof.

use rug::Float;
use rayon::prelude::*;

const PREC: u32 = 512;

/// 512-bit π reference value.
pub fn pi_512() -> Float {
    Float::with_val(PREC, rug::float::Constant::Pi)
}

/// Power iteration to estimate largest singular value of the
/// antisymmetric Hilbert kernel H(m,n) = 1/(m-n).
///
/// Uses 512-bit MPFR arithmetic throughout.
/// Returns (estimated norm, iterations).
pub fn power_iteration_norm_mpfr(n: usize, max_iter: usize, tol: f64) -> (Float, usize) {
    // Initialize vector: v_i = sin(i+1) (deterministic, not axis-aligned)
    let mut v: Vec<Float> = (0..n)
        .map(|i| {
            let x = Float::with_val(PREC, i as f64 + 1.0);
            x.sin()
        })
        .collect();

    // Normalize
    let norm_v = vec_norm(&v);
    for vi in v.iter_mut() {
        *vi /= &norm_v;
    }

    let mut lambda = Float::with_val(PREC, 0.0);

    for iter in 0..max_iter {
        // w = H^T H v  (done as two matrix-vector products: u = Hv, w = H^T u)
        // For antisymmetric H: H^T = -H, so H^T H = -H(-H) = H² ... wait
        // Actually H^T H v = H^T (Hv). Since H is antisymmetric, H^T = -H.
        // So H^T H = -H · H = -(H²). But H^T H is positive semidefinite...
        // Actually for antisymmetric H: (H^T H)_{ij} = Σ_k H_{ki} H_{kj} = Σ_k (-H_{ik})(H_{kj})
        // Let's just compute the singular values via |Hv|.

        // Step 1: u = H · v
        let u: Vec<Float> = (0..n)
            .into_par_iter()
            .map(|i| {
                let mut sum = Float::with_val(PREC, 0.0);
                for j in 0..n {
                    if i != j {
                        let denom = Float::with_val(PREC, i as i64 - j as i64);
                        let mut term = v[j].clone();
                        term /= &denom;
                        sum += term;
                    }
                }
                sum
            })
            .collect();

        // Step 2: w = H^T · u = -H · u (antisymmetric)
        let w: Vec<Float> = (0..n)
            .into_par_iter()
            .map(|i| {
                let mut sum = Float::with_val(PREC, 0.0);
                for j in 0..n {
                    if i != j {
                        let denom = Float::with_val(PREC, j as i64 - i as i64); // -H = H^T
                        let mut term = u[j].clone();
                        term /= &denom;
                        sum += term;
                    }
                }
                sum
            })
            .collect();

        // eigenvalue estimate = |w|
        let new_lambda = vec_norm(&w);

        // Normalize w -> v
        let inv_lambda = Float::with_val(PREC, 1.0) / &new_lambda;
        let new_v: Vec<Float> = w.into_iter().map(|wi| {
            let mut r = wi;
            r *= &inv_lambda;
            r
        }).collect();

        // Check convergence
        let rel_change = if new_lambda > 1e-15 {
            let mut diff = new_lambda.clone();
            diff -= &lambda;
            diff.abs().to_f64() / new_lambda.to_f64()
        } else {
            1.0
        };

        v = new_v;
        lambda = new_lambda;

        if rel_change < tol {
            // lambda is eigenvalue of H^T H, so ‖H‖ = sqrt(lambda)
            let norm = lambda.sqrt();
            return (norm, iter + 1);
        }
    }

    let norm = lambda.sqrt();
    (norm, max_iter)
}

/// Compute row sums of the MV kernel in 512-bit MPFR.
/// R_n = Σ_{m=1, m≠n}^N 1/|log(m) - log(n)|
///
/// This is trivially parallel — each row is independent.
pub fn mv_row_sum_mpfr(n_1idx: usize, n_max: usize) -> Float {
    let log_n = Float::with_val(PREC, n_1idx as f64).ln();
    let mut sum = Float::with_val(PREC, 0.0);
    for m in 1..=n_max {
        if m != n_1idx {
            let log_m = Float::with_val(PREC, m as f64).ln();
            let mut diff = log_m;
            diff -= &log_n;
            diff = diff.abs();
            let term = Float::with_val(PREC, 1.0) / diff;
            sum += term;
        }
    }
    sum
}

/// Compute the Schur test bound (max row sum) for the antisymmetric
/// Hilbert kernel H(m,n) = 1/(m-n) on {1, ..., N}.
///
/// R_i = Σ_{j≠i} 1/|i-j| = Σ_{k=1}^{i-1} 1/k + Σ_{k=1}^{N-i} 1/k
///     = H(i-1) + H(N-i)
/// where H(k) = harmonic number.
pub fn schur_bound_harmonic(n: usize) -> Float {
    // Max row sum is at i = N/2 (middle), where R = 2·H(N/2)
    // Actually compute all row sums and take max
    let mut max_r = Float::with_val(PREC, 0.0);
    for i in 1..=n {
        let mut r = Float::with_val(PREC, 0.0);
        // H(i-1) + H(N-i)
        for k in 1..i {
            r += Float::with_val(PREC, 1.0) / Float::with_val(PREC, k);
        }
        for k in 1..=(n - i) {
            r += Float::with_val(PREC, 1.0) / Float::with_val(PREC, k);
        }
        if r > max_r {
            max_r = r;
        }
    }
    max_r
}

/// Compute log-separation δ_n = min_{m≠n} |log(m) - log(n)| in MPFR.
/// For n ≥ 2, this is log(n/(n-1)) or log((n+1)/n).
pub fn log_separation_mpfr(n: usize) -> Float {
    if n == 1 {
        Float::with_val(PREC, 2u32).ln() // log(2/1) = log(2)
    } else {
        // δ_n = min(log(n/(n-1)), log((n+1)/n))
        // For n ≥ 2: log(n/(n-1)) > log((n+1)/n), so δ_n = log(1 + 1/n)
        let ratio = Float::with_val(PREC, n as f64 + 1.0) / Float::with_val(PREC, n as f64);
        ratio.ln()
    }
}

fn vec_norm(v: &[Float]) -> Float {
    let mut s = Float::with_val(PREC, 0.0);
    for vi in v {
        let mut sq = vi.clone();
        sq *= vi;
        s += sq;
    }
    s.sqrt()
}
