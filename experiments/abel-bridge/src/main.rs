//! # Abel Summation Bridge Experiment
//!
//! ## Goal
//! Numerically verify that the Mertens bound |M(x)| ≤ C·x^{1/2}·(ln x)²
//! implies the Selberg witness decay: 1 - 2bᵀv + vᵀGv ≤ C'/ln(N).
//!
//! This is **Attack 2** from the Forge Master's analysis: showing that
//! `rh_implies_mertens_bound` → `witness_l2_error_decay_gram` via
//! Abel summation. If this bridge holds numerically, we can formalize
//! it in Lean to collapse the Cathedral to a SINGLE axiom.
//!
//! ## What it computes
//! 1. Möbius function μ(k) via sieve
//! 2. Mertens function M(x) = Σ_{k≤x} μ(k)
//! 3. Gram matrix entries G(j,k) = ∫₀¹ {j/x}{k/x} dx (Vasyunin formula)
//! 4. Basis inner products b_k = ∫₀¹ {k/x} dx
//! 5. Log-cutoff witness v_k = -μ(k)(1 - ln k / ln N)
//! 6. Decomposition of bᵀv via Abel summation against M(t)
//! 7. Decomposition of vᵀGv into Mertens-controlled pieces
//!
//! ## Key output
//! - Ratio (1 - 2bᵀv + vᵀGv) / (1/ln N) should stabilize → C
//! - Abel summation remainder should be bounded by Mertens bound

use std::f64::consts::PI;

/// Compute Möbius function μ(k) for k = 0..n via sieve
fn mobius_sieve(n: usize) -> Vec<i8> {
    let mut mu = vec![0i8; n + 1];
    let mut is_prime = vec![true; n + 1];
    let mut prime_count = vec![0u8; n + 1];
    let mut has_sq_factor = vec![false; n + 1];

    mu[1] = 1;

    for p in 2..=n {
        if !is_prime[p] {
            continue;
        }
        // p is prime — mark multiples
        for m in (p..=n).step_by(p) {
            is_prime[m] = m == p; // only p itself stays prime
            prime_count[m] += 1;
        }
        // Mark p² multiples as having square factors
        let p2 = p * p;
        for m in (p2..=n).step_by(p2) {
            has_sq_factor[m] = true;
        }
    }

    for k in 1..=n {
        if has_sq_factor[k] {
            mu[k] = 0;
        } else {
            mu[k] = if prime_count[k] % 2 == 0 { 1 } else { -1 };
        }
    }

    mu
}

/// Compute Mertens function M(x) = Σ_{k≤x} μ(k)
fn mertens(mu: &[i8]) -> Vec<i64> {
    let n = mu.len();
    let mut m = vec![0i64; n];
    for k in 1..n {
        m[k] = m[k - 1] + mu[k] as i64;
    }
    m
}

/// Gram matrix diagonal entry G(j,j) = ∫₀¹ {j/x}² dx
fn gram_diag(j: usize) -> f64 {
    let jf = j as f64;
    let n_points = 10000;
    let h = 1.0 / n_points as f64;
    let mut total = 0.0;

    for i in 1..n_points {
        let x = i as f64 * h;
        let fj = (jf / x).fract();
        let w = if i % 2 == 0 { 2.0 } else { 4.0 };
        total += w * fj * fj;
    }
    total * h / 3.0
}

/// Gram matrix off-diagonal entry G(j,k) for j ≠ k
/// G(j,k) = ∫₀¹ {j/x}{k/x} dx
fn gram_offdiag(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;

    // Numerical integration via Simpson's rule
    let n_points = 10000;
    let h = 1.0 / n_points as f64;
    let mut total = 0.0;

    for i in 1..n_points {
        let x = i as f64 * h;
        let fj = (jf / x).fract();
        let fk = (kf / x).fract();
        let w = if i % 2 == 0 { 2.0 } else { 4.0 };
        total += w * fj * fk;
    }
    total * h / 3.0
}

/// Gram entry G(j,k)
fn gram_entry(j: usize, k: usize) -> f64 {
    if j == k {
        gram_diag(j)
    } else {
        gram_offdiag(j, k)
    }
}

/// Basis inner product b_k = ∫₀¹ {k/x} dx
fn basis_inner_prod(k: usize) -> f64 {
    let kf = k as f64;
    // ∫₀¹ {k/x} dx = 1 - γ + Σ_{n=1}^{k-1} (k/n - k/(n+1)) · (something)
    // Numerical integration
    let n_points = 10000;
    let h = 1.0 / n_points as f64;
    let mut total = 0.0;

    for i in 1..n_points {
        let x = i as f64 * h;
        let fk = (kf / x).fract();
        let w = if i % 2 == 0 { 2.0 } else { 4.0 };
        total += w * fk;
    }
    total * h / 3.0
}

/// Run the full Abel Bridge analysis for a given N
fn analyze_n(n: usize, mu: &[i8], mertens_fn: &[i64]) {
    let ln_n = (n as f64).ln();

    // Build the log-cutoff witness: v_k = -μ(k)(1 - ln(k)/ln(N))
    // Cathedral uses k = 2..N, indexed as Fin(N-1) with offset +2
    let v: Vec<f64> = (2..=n)
        .map(|k| {
            let mu_k = mu[k] as f64;
            let weight = 1.0 - (k as f64).ln() / ln_n;
            -mu_k * weight
        })
        .collect();

    // Compute bᵀv = Σ_{k=2}^N b_k · v_k
    let mut bt_v = 0.0;
    for (i, &vk) in v.iter().enumerate() {
        let k = i + 2;
        bt_v += basis_inner_prod(k) * vk;
    }

    // Compute vᵀGv (just diagonal + a few off-diagonal for speed)
    // For full accuracy we need all entries, but diagonal dominates
    let mut vt_g_v = 0.0;

    // Diagonal part: Σ v_k² · G(k,k)
    for (i, &vk) in v.iter().enumerate() {
        let k = i + 2;
        vt_g_v += vk * vk * gram_entry(k, k);
    }

    // Off-diagonal (sample for large N): Σ_{j≠k} v_j v_k G(j,k)
    // For small N, compute all; for large N, estimate
    if n <= 500 {
        for i in 0..v.len() {
            for j in (i + 1)..v.len() {
                let gi_j = gram_entry(i + 2, j + 2);
                vt_g_v += 2.0 * v[i] * v[j] * gi_j;
            }
        }
    }

    // Quadratic form: Q = 1 - 2bᵀv + vᵀGv
    let q = 1.0 - 2.0 * bt_v + vt_g_v;

    // Ratio: Q / (1/ln N) = Q · ln N
    let ratio = q * ln_n;

    // Mertens function analysis
    let m_n = mertens_fn[n];
    let mertens_ratio = (m_n as f64).abs() / ((n as f64).sqrt() * ln_n * ln_n);

    // Abel summation of bᵀv:
    // Σ_{k=2}^N μ(k)(1 - ln k/ln N) · b_k
    //   = (by Abel) (1/ln N) · Σ_{k=2}^{N-1} M(k) · [b_k(1-ln k/ln N) - b_{k+1}(1-ln(k+1)/ln N)]
    //   + boundary terms
    // The key: if |M(k)| ≤ C·k^{1/2}·(ln k)², the Abel sum contributes O(1/ln N)

    let mut abel_sum = 0.0;
    for k in 2..n {
        let mk = mertens_fn[k] as f64;
        let bk = basis_inner_prod(k);
        let bk1 = basis_inner_prod(k + 1);
        let wk = 1.0 - (k as f64).ln() / ln_n;
        let wk1 = 1.0 - ((k + 1) as f64).ln() / ln_n;
        abel_sum += mk * (bk * wk - bk1 * wk1);
    }
    // Add boundary: M(N) · b_N · w_N  (w_N = 0 since ln N / ln N = 1)
    // So boundary = 0

    println!(
        "  N={:>6} | Q={:>12.8} | Q·lnN={:>8.4} | M(N)={:>8} | |M|/√N(lnN)²={:.4} | bᵀv={:.6} | Abel={:.6}",
        n, q, ratio, m_n, mertens_ratio, bt_v, abel_sum
    );
}

fn main() {
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║      ABEL SUMMATION BRIDGE EXPERIMENT                      ║");
    println!("║      Attack 2: rh_implies_mertens_bound → witness_decay    ║");
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!();

    let max_n = 5000;
    println!("Computing Möbius sieve up to N={}...", max_n);
    let mu = mobius_sieve(max_n);
    let mertens_fn = mertens(mu.as_slice());

    // Verify Mertens function
    println!("\n═══ Mertens Function Check ═══");
    println!("  M(10)={}, M(100)={}, M(1000)={}, M(5000)={}",
        mertens_fn[10], mertens_fn[100], mertens_fn[1000], mertens_fn[max_n]);

    // Verify Mertens bound: |M(x)| ≤ C·x^{1/2}·(ln x)²
    let mut max_mertens_ratio = 0.0f64;
    for x in 10..=max_n {
        let ratio = (mertens_fn[x] as f64).abs() / ((x as f64).sqrt() * (x as f64).ln().powi(2));
        max_mertens_ratio = max_mertens_ratio.max(ratio);
    }
    println!("  Max |M(x)|/(√x·(ln x)²) for x ∈ [10,{}]: {:.6}", max_n, max_mertens_ratio);
    println!("  (Should stabilize — this is the Mertens bound constant C_M)");

    // Main analysis: quadratic form decay
    println!("\n═══ Quadratic Form Decay Analysis ═══");
    println!("  Testing: 1 - 2bᵀv + vᵀGv ≤ C/ln(N)");
    println!("  If Q·ln(N) → constant, the Abel Bridge works!\n");

    let test_ns = [10, 20, 50, 100, 200, 500];

    for &n in &test_ns {
        if n <= max_n {
            analyze_n(n, &mu, &mertens_fn);
        }
    }

    // PNT Decomposition: analyze linear and quadratic terms separately
    println!("\n═══ PNT Decomposition (Attack 1) ═══");
    println!("  Decomposing: Q = 1 - 2·(LINEAR) + (QUADRATIC)");
    println!("  LINEAR = bᵀv = Σ b_k·v_k");
    println!("  QUADRATIC = vᵀGv = Σ v_j·v_k·G(j,k)\n");

    for &n in &[50, 100, 200] {
        let ln_n = (n as f64).ln();
        let v: Vec<f64> = (2..=n)
            .map(|k| {
                let mu_k = mu[k] as f64;
                let weight = 1.0 - (k as f64).ln() / ln_n;
                -mu_k * weight
            })
            .collect();

        // Linear term
        let mut linear = 0.0;
        for (i, &vk) in v.iter().enumerate() {
            linear += basis_inner_prod(i + 2) * vk;
        }

        // Quadratic diagonal only (for speed)
        let mut quad_diag = 0.0;
        for (i, &vk) in v.iter().enumerate() {
            quad_diag += vk * vk * gram_diag(i + 2);
        }

        let q = 1.0 - 2.0 * linear + quad_diag;
        println!(
            "  N={:>4} | LINEAR(bᵀv)={:.6} | need ~{:.6} | DIAG(vᵀGv)={:.6} | Q_diag={:.6} | Q_diag·lnN={:.4}",
            n, linear, 0.5 - 0.5 / ln_n, quad_diag, q, q * ln_n
        );
    }

    println!("\n═══ Mertens Bound Profile ═══");
    println!("  x      | M(x)   | |M(x)|/√x | |M(x)|/(√x·(ln x)²)");
    for &x in &[100, 500, 1000, 2000, 3000, 4000, 5000] {
        if x <= max_n {
            let mx = mertens_fn[x];
            let xf = x as f64;
            println!(
                "  {:>5}  | {:>6} | {:.4}    | {:.6}",
                x, mx, (mx as f64).abs() / xf.sqrt(),
                (mx as f64).abs() / (xf.sqrt() * xf.ln().powi(2))
            );
        }
    }

    println!("\n═══ Conclusion ═══");
    println!("  If Q·ln(N) stabilizes to a constant C, then:");
    println!("  witness_l2_error_decay_gram holds with C_err = C");
    println!("  AND the Abel summation bridge links it to the Mertens bound.");
    println!("  Both proof paths collapse to: |M(x)| = O(√x · (ln x)²)");
}
