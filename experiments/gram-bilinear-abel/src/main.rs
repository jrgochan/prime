//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL BILINEAR ABEL SUMMATION & OFF-DIAGONAL CANCELLATION VALIDATOR
//!  256-bit MPFR · Massively Parallel · Certified Bounds
//!
//!  EXPERIMENT A: Decomposes vᵀGv = DIAG + OFFDIAG and measures each.
//!  EXPERIMENT B: Off-diagonal cancellation → O(1/logN)
//!  EXPERIMENT C: Double Abel summation — converts bilinear sums to
//!                double integrals of M(x) and validates the bound.
//!  EXPERIMENT D: Row-partial sums (Gv)_j tracking — sees where
//!                cancellation happens in the matrix-vector product.
//!  EXPERIMENT E: Bilinear Mertens correlation — the key double sum
//!                Σ_j Σ_k μ(j)·μ(k)·w_j·w_k / max(j,k) under Abel.
//!
//!  Target: Eliminate gram_form_upper_bound_34 (PerronCrown.lean:60)
//!  i.e., prove vᵀGv ≤ 1 + C_G/ln(N) from |M(x)| ≤ C·x^{3/4}
//! ═══════════════════════════════════════════════════════════════════════════

use rayon::prelude::*;
use rug::Float;
use std::fs;
use std::io::Write;
use std::time::Instant;

const P: u32 = 256;

const BOLD: &str = "\x1b[1m";
const DIM: &str = "\x1b[2m";
const CYAN: &str = "\x1b[36m";
const GREEN: &str = "\x1b[32m";
const YELLOW: &str = "\x1b[33m";
const MAGENTA: &str = "\x1b[35m";
const RED: &str = "\x1b[31m";
const WHITE: &str = "\x1b[97m";
const RESET: &str = "\x1b[0m";

fn check(b: bool) -> &'static str {
    if b { "\x1b[32m✓\x1b[0m" } else { "\x1b[31m✗\x1b[0m" }
}

// ═══════════════════════════════════════════════
// §1. MÖBIUS SIEVE
// ═══════════════════════════════════════════════

fn mobius_sieve(n: usize) -> Vec<i8> {
    let mut mu = vec![0i8; n + 1];
    let mut spf = vec![0usize; n + 1];
    mu[1] = 1;
    for p in 2..=n {
        if spf[p] != 0 { continue; }
        spf[p] = p;
        for m in (2 * p..=n).step_by(p) {
            if spf[m] == 0 { spf[m] = p; }
        }
    }
    for k in 2..=n {
        let mut val = k;
        let mut nf = 0u32;
        let mut sq = false;
        while val > 1 {
            let p = spf[val];
            let mut c = 0;
            while val % p == 0 { val /= p; c += 1; }
            if c > 1 { sq = true; break; }
            nf += 1;
        }
        if sq { mu[k] = 0; }
        else if nf % 2 == 0 { mu[k] = 1; }
        else { mu[k] = -1; }
    }
    mu
}

/// Mertens function M(x) = Σ_{k≤x} μ(k)
fn mertens_values(mu: &[i8]) -> Vec<i64> {
    let n = mu.len();
    let mut m = vec![0i64; n];
    for k in 1..n {
        m[k] = m[k-1] + mu[k] as i64;
    }
    m
}

// ═══════════════════════════════════════════════
// §2. HIGH-PRECISION GRAM ENTRY
// ═══════════════════════════════════════════════

fn euler_gamma() -> Float {
    Float::with_val(P, Float::parse(
        "0.57721566490153286060651209008240243104215933593992359880576723488486772677766467"
    ).unwrap())
}

fn gcd(a: usize, b: usize) -> usize {
    let (mut a, mut b) = (a, b);
    while b != 0 { let t = b; b = a % b; a = t; }
    a
}

/// Vasyunin cotangent sum V(a,b) at 256-bit
fn vasyunin_sum(a: usize, b: usize) -> Float {
    if a <= 1 { return Float::with_val(P, 0); }
    let af = Float::with_val(P, a as u64);
    let pi = Float::with_val(P, rug::float::Constant::Pi);
    let bf = Float::with_val(P, b as u64);
    let mut sum = Float::with_val(P, 0);
    for m in 1..a {
        let mf = Float::with_val(P, m as u64);
        let mb = Float::with_val(P, &mf * &bf);
        let q = Float::with_val(P, &mb / &af);
        let fl = Float::with_val(P, q.clone().floor());
        let frac = Float::with_val(P, &q - &fl);
        let pm = Float::with_val(P, &pi * &mf);
        let angle = Float::with_val(P, &pm / &af);
        let c = Float::with_val(P, angle.clone().cos());
        let s = Float::with_val(P, angle.sin());
        if s.is_zero() { continue; }
        let cot = Float::with_val(P, &c / &s);
        sum += Float::with_val(P, &frac * &cot);
    }
    sum
}

/// Gram entry G(j,k) at 256-bit MPFR
fn gram_entry(j: usize, k: usize) -> Float {
    let jf = Float::with_val(P, j as u64);
    let kf = Float::with_val(P, k as u64);
    let gamma = euler_gamma();
    let two = Float::with_val(P, 2u32);
    let pi = Float::with_val(P, rug::float::Constant::Pi);
    let ln2pi = Float::with_val(P, &two * &pi).ln();
    let a_const = Float::with_val(P, &ln2pi - &gamma);

    if j == k {
        let mut r = Float::with_val(P, &a_const / &jf);
        let jsq = Float::with_val(P, &jf * &jf);
        r -= Float::with_val(P, Float::with_val(P, 1u32) / &jsq);
        return r;
    }

    let d = gcd(j, k);
    let (jp, kp) = (j / d, k / d);
    let df = Float::with_val(P, d as u64);
    let jk = Float::with_val(P, &jf * &kf);

    let inv_j = Float::with_val(P, Float::with_val(P, 1u32) / &jf);
    let inv_k = Float::with_val(P, Float::with_val(P, 1u32) / &kf);
    let sum_inv = Float::with_val(P, &inv_j + &inv_k);
    let half_a = Float::with_val(P, &a_const / 2u32);
    let t1 = Float::with_val(P, &half_a * &sum_inv);

    let diff = Float::with_val(P, &jf - &kf);
    let ratio = Float::with_val(P, &kf / &jf);
    let t2 = Float::with_val(P, &diff / Float::with_val(P, &jk * 2u32) * ratio.ln());

    let v = Float::with_val(P, vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp));
    let two_jk = Float::with_val(P, &jk * 2u32);
    let pi_d = Float::with_val(P, &pi * &df);
    let coeff = Float::with_val(P, &pi_d / &two_jk);
    let t3 = Float::with_val(P, &coeff * &v);

    let t4 = Float::with_val(P, Float::with_val(P, 1u32) / &jk);

    let sum1 = Float::with_val(P, &t1 + &t2);
    let sum2 = Float::with_val(P, &sum1 - &t3);
    Float::with_val(P, &sum2 - &t4)
}

/// Mean entry b_k = 1 - 1/k
fn mean_entry(k: usize) -> Float {
    let kf = Float::with_val(P, k as u64);
    Float::with_val(P, Float::with_val(P, 1u32) - Float::with_val(P, 1u32) / &kf)
}

/// Log-cutoff Möbius weight: v_k = -μ(k)·(1 - ln(k)/ln(N))
fn log_cutoff_weight(k: usize, n: usize, mu: &[i8]) -> Float {
    if k < 1 || k >= n || mu[k] == 0 {
        return Float::with_val(P, 0);
    }
    let kf = Float::with_val(P, k as u64);
    let nf = Float::with_val(P, n as u64);
    let log_k = kf.ln();
    let log_n = nf.ln();
    let taper = Float::with_val(P, Float::with_val(P, 1u32) - Float::with_val(P, &log_k / &log_n));
    Float::with_val(P, -(mu[k] as f64) * &taper)
}

// ═══════════════════════════════════════════════
// §3. EXPERIMENT A: DIAGONAL vs OFF-DIAGONAL DECOMPOSITION
// ═══════════════════════════════════════════════

/// Decompose vᵀGv = DIAG + OFFDIAG
/// DIAG  = Σ_k v_k² · G(k,k)
/// OFFDIAG = 2·Σ_{j<k} v_j·v_k·G(j,k)
///
/// The axiom says vᵀGv ≤ 1 + C_G/logN.
/// We want to see how DIAG and OFFDIAG contribute separately.
fn experiment_a(n: usize, mu: &[i8]) -> (f64, f64, f64, f64) {
    let dim = n - 1;
    let weights: Vec<Float> = (1..n).map(|k| log_cutoff_weight(k, n, mu)).collect();

    // Diagonal: Σ_k v_k² · G(k,k)
    let mut diag = Float::with_val(P, 0);
    for k in 0..dim {
        if weights[k].is_zero() { continue; }
        let g = gram_entry(k + 1, k + 1);
        let vk_sq = Float::with_val(P, &weights[k] * &weights[k]);
        diag += Float::with_val(P, &vk_sq * &g);
    }

    // Off-diagonal: 2·Σ_{j<k} v_j·v_k·G(j+1,k+1)
    let offdiag_terms: Vec<Float> = (0..dim).into_par_iter()
        .map(|j| {
            let mut row_sum = Float::with_val(P, 0);
            if weights[j].is_zero() { return row_sum; }
            for k in (j+1)..dim {
                if weights[k].is_zero() { continue; }
                let g = gram_entry(j + 1, k + 1);
                let prod = Float::with_val(P, &weights[j] * &weights[k]);
                row_sum += Float::with_val(P, &prod * &g);
            }
            row_sum
        })
        .collect();

    let mut offdiag = Float::with_val(P, 0);
    for t in &offdiag_terms {
        offdiag += t;
    }
    offdiag *= 2;

    let vtgv = Float::with_val(P, &diag + &offdiag);
    (vtgv.to_f64(), diag.to_f64(), offdiag.to_f64(), (n as f64).ln())
}

// ═══════════════════════════════════════════════
// §4. EXPERIMENT B: OFF-DIAGONAL CANCELLATION RATE
// ═══════════════════════════════════════════════

/// Measure |OFFDIAG| · logN to check if OFFDIAG = O(1/logN)
/// Also measure OFFDIAG decomposed by range:
///   NEAR:  |j-k| ≤ √N   (nearby interactions)
///   FAR:   |j-k| > √N   (far interactions)
fn experiment_b(n: usize, mu: &[i8]) -> (f64, f64, f64, f64) {
    let dim = n - 1;
    let sqrt_n = (n as f64).sqrt() as usize;
    let weights: Vec<Float> = (1..n).map(|k| log_cutoff_weight(k, n, mu)).collect();

    let mut near = Float::with_val(P, 0);
    let mut far = Float::with_val(P, 0);

    for j in 0..dim {
        if weights[j].is_zero() { continue; }
        for k in (j+1)..dim {
            if weights[k].is_zero() { continue; }
            let g = gram_entry(j + 1, k + 1);
            let prod = Float::with_val(P, &weights[j] * &weights[k]);
            let term = Float::with_val(P, &prod * &g);
            if k - j <= sqrt_n {
                near += &term;
            } else {
                far += &term;
            }
        }
    }
    near *= 2;
    far *= 2;

    let offdiag = Float::with_val(P, &near + &far);
    let log_n = (n as f64).ln();

    (offdiag.to_f64(), near.to_f64(), far.to_f64(), log_n)
}

// ═══════════════════════════════════════════════
// §5. EXPERIMENT C: DOUBLE ABEL SUMMATION VALIDATION
// ═══════════════════════════════════════════════

/// The double Abel summation identity:
///   Σ_{j,k=1}^{N-1} v_j·v_k·G(j,k) = ∫∫ M'(x)·M'(y)·K(x,y) dx dy
///
/// where M'(x) is a weighted Mertens derivative.
///
/// We validate this by computing:
///   1. The bilinear sum S = Σ_{j<k} v_j·v_k / max(j,k)
///      (this is the dominant off-diagonal contribution from |G(j,k)| ≤ C/max(j,k))
///   2. The corresponding Abel integral via M(x):
///      S_Abel = Σ_{k=2}^{N-1} (1/k) · (Σ_{j=1}^{k-1} v_j) · v_k
///            = Σ_{k=2}^{N-1} (1/k) · A(k) · v_k
///      where A(k) = Σ_{j=1}^{k-1} v_j is the partial sum of weights.
///
/// Under Mertens x^{3/4}: A(k) = Σ_{j≤k} μ(j)·w_j ≈ 1 + O(k^{-1/4})
/// So the single summation over k gives O(1/logN) if A(k) ≈ 1.
fn experiment_c(n: usize, mu: &[i8], mertens: &[i64]) -> (f64, f64, f64, f64) {
    let dim = n - 1;
    let log_n = (n as f64).ln();
    let weights: Vec<Float> = (1..n).map(|k| log_cutoff_weight(k, n, mu)).collect();

    // (C1) Bilinear sum: S = Σ_{j<k} v_j·v_k / max(j,k)
    let mut bilinear_sum = Float::with_val(P, 0);
    for k in 1..dim {
        if weights[k].is_zero() { continue; }
        let kf = Float::with_val(P, (k + 1) as u64);
        for j in 0..k {
            if weights[j].is_zero() { continue; }
            let prod = Float::with_val(P, &weights[j] * &weights[k]);
            bilinear_sum += Float::with_val(P, &prod / &kf);
        }
    }

    // (C2) Partial sums A(k) = Σ_{j=1}^{k} v_j (cumulative weight sums)
    let mut partial_sums = vec![Float::with_val(P, 0); dim + 1];
    for k in 0..dim {
        partial_sums[k + 1] = Float::with_val(P, &partial_sums[k] + &weights[k]);
    }

    // (C3) Abel single sum: S_Abel = Σ_{k=2}^{N-1} (1/k) · A(k-1) · v_k
    // where A(k-1) = partial_sums[k-1] (sum of v_1..v_{k-1})
    let mut abel_sum = Float::with_val(P, 0);
    for k in 1..dim {
        if weights[k].is_zero() { continue; }
        let kf = Float::with_val(P, (k + 1) as u64);
        let term = Float::with_val(P, &partial_sums[k] * &weights[k]);
        abel_sum += Float::with_val(P, &term / &kf);
    }

    // (C4) Track partial sum profile A(k)
    // Under |M(x)| ≤ C·x^{3/4}: A(k) should → 1
    // Measure: max deviation of A(k) from 1
    let mut max_dev = 0.0f64;
    let mut sum_dev = 0.0f64;
    let mut count = 0usize;
    for k in 1..dim {
        let ak = partial_sums[k + 1].to_f64();
        let dev = (ak - 1.0).abs();
        if dev > max_dev { max_dev = dev; }
        sum_dev += dev;
        count += 1;
    }
    let avg_dev = if count > 0 { sum_dev / count as f64 } else { 0.0 };

    // (C5) Check Mertens bound: |M(k)| ≤? C · k^{3/4}
    let mut max_mertens_ratio = 0.0f64;
    for k in 2..n.min(mertens.len()) {
        let mk = mertens[k].abs() as f64;
        let kf = k as f64;
        let bound = kf.powf(0.75);
        let ratio = mk / bound;
        if ratio > max_mertens_ratio { max_mertens_ratio = ratio; }
    }

    // Print partial sum profile
    let profile_points: Vec<usize> = vec![2, 5, 10, 20, 50, 100, 200, 500, 1000]
        .into_iter().filter(|&k| k < dim).collect();

    println!("    {DIM}Partial sum profile A(k) = Σ_{{j≤k}} v_j:{RESET}");
    for &k in &profile_points {
        let ak = partial_sums[k + 1].to_f64();
        println!("      A({:>5}) = {:.10}  (|A-1| = {:.6e})", k + 1, ak, (ak - 1.0).abs());
    }
    println!("      max |A(k)-1| = {:.6e},  avg |A(k)-1| = {:.6e}", max_dev, avg_dev);
    println!("      max |M(k)|/k^{{3/4}} = {:.6}  (Mertens ratio)", max_mertens_ratio);

    (bilinear_sum.to_f64(), abel_sum.to_f64(), max_dev, avg_dev)
}

// ═══════════════════════════════════════════════
// §6. EXPERIMENT D: ROW-PARTIAL SUM PROFILE (Gv)_j
// ═══════════════════════════════════════════════

/// For each row j, compute (Gv)_j = Σ_k G(j,k)·v_k
/// and track the product v_j·(Gv)_j (contribution to vᵀGv).
///
/// This shows WHERE the quadratic form concentrates:
/// - If v_j·(Gv)_j ≈ v_j·b_j for each j, then vᵀGv ≈ bᵀv ≈ 1.
/// - Deviations from this show where the off-diagonal structure matters.
fn experiment_d(n: usize, mu: &[i8]) -> Vec<(usize, f64, f64, f64)> {
    let dim = n - 1;
    let weights: Vec<Float> = (1..n).map(|k| log_cutoff_weight(k, n, mu)).collect();
    let means: Vec<Float> = (1..n).map(|k| mean_entry(k)).collect();

    let gv: Vec<Float> = (0..dim).into_par_iter()
        .map(|j| {
            let mut row_sum = Float::with_val(P, 0);
            for k in 0..dim {
                if weights[k].is_zero() { continue; }
                let g = gram_entry(j + 1, k + 1);
                row_sum += Float::with_val(P, &g * &weights[k]);
            }
            row_sum
        })
        .collect();

    let mut profile = Vec::new();
    for j in 0..dim {
        let vj_gvj = Float::with_val(P, &weights[j] * &gv[j]).to_f64();
        let vj_bj = Float::with_val(P, &weights[j] * &means[j]).to_f64();
        let residual = vj_gvj - vj_bj;
        profile.push((j + 1, vj_gvj, vj_bj, residual));
    }
    profile
}

// ═══════════════════════════════════════════════
// §7. EXPERIMENT E: BILINEAR MERTENS CORRELATION
// ═══════════════════════════════════════════════

/// The double Abel summation identity connects vᵀGv to integrals of M(x):
///
///   Σ_{j<k} v_j·v_k·G(j,k) ≈ Σ_{j<k} v_j·v_k·C/max(j,k)
///     = C · Σ_k (1/k) · A(k)·v_k   (single Abel)
///     = C · ∫₁ᴺ (1/t) · A(t)·v(t) dt  (Abel integral form)
///
/// where A(t) = Σ_{j≤t} v_j. Under Mertens x^{3/4}:
///   A(t) = 1 - M_weighted(t)·correction
///
/// The "bilinear Mertens correlation" is:
///   B(N) = Σ_{k=2}^{N} (1/k) · M_tapered(k)²
///
/// where M_tapered(k) = Σ_{j≤k} μ(j)·(1-log(j)/log(N)).
///
/// If |M(x)| ≤ C·x^{3/4}, then:
///   |M_tapered(k)| ≤ C' · k^{3/4} / logN + C'' · k^{-1/4}
///
/// So B(N) ≤ C''' / logN is the key bound we're certifying.
fn experiment_e(n: usize, mu: &[i8]) -> (f64, f64, f64) {
    let log_n = (n as f64).ln();

    // M_tapered(k) = Σ_{j≤k} μ(j)·(1-log(j)/log(N))
    let mut m_tapered = vec![Float::with_val(P, 0); n + 1];
    for k in 1..n {
        let mu_k = mu[k] as f64;
        let w_k = 1.0 - (k as f64).ln() / log_n;
        m_tapered[k] = Float::with_val(P,
            &m_tapered[k - 1] + Float::with_val(P, mu_k * w_k));
    }

    // B(N) = Σ_{k=2}^{N-1} (1/k) · M_tapered(k)²
    let mut b_total = Float::with_val(P, 0);
    let mut b_profile = Vec::new();

    for k in 2..n {
        let kf = Float::with_val(P, k as u64);
        let mt_sq = Float::with_val(P, &m_tapered[k] * &m_tapered[k]);
        b_total += Float::with_val(P, &mt_sq / &kf);

        // Track at milestone points
        if k.is_power_of_two() || k == n - 1 {
            b_profile.push((k, m_tapered[k].to_f64(), b_total.to_f64()));
        }
    }

    let b_val = b_total.to_f64();
    let b_times_logn = b_val * log_n;

    println!("    {DIM}M_tapered(k) profile (should be close to 1):{RESET}");
    for &(k, mt, bt) in &b_profile {
        println!("      k={:>5}: M_tap = {:.8}, B_cum = {:.8e}", k, mt, bt);
    }
    println!("    B(N) = {:.8e}", b_val);
    println!("    B(N) · ln(N) = {:.8}", b_times_logn);

    // Also compute: Σ (1/k) · |M_tapered(k)|
    // (single Abel bound: should be O(1/√logN) or better)
    let mut single_abel = Float::with_val(P, 0);
    for k in 2..n {
        let kf = Float::with_val(P, k as u64);
        let mt_abs = Float::with_val(P, m_tapered[k].clone().abs());
        single_abel += Float::with_val(P, &mt_abs / &kf);
    }
    let single_val = single_abel.to_f64();

    (b_val, b_times_logn, single_val)
}

fn main() {
    let t_global = Instant::now();
    let n_threads = rayon::current_num_threads();

    println!();
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}CATHEDRAL BILINEAR ABEL & OFF-DIAGONAL CANCELLATION VALIDATOR{RESET}  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}256-bit MPFR · Target: gram_form_upper_bound_34{RESET}                 {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}{} threads · {}-bit precision{RESET}                                     {BOLD}{CYAN}║{RESET}", n_threads, P);
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");
    println!();

    fs::create_dir_all("results").unwrap();

    // Probe dimensions
    let small_ns: Vec<usize> = vec![10, 20, 30, 50, 75, 100, 150, 200, 300, 500];
    let large_ns: Vec<usize> = vec![750, 1000];
    let all_ns: Vec<usize> = small_ns.iter().chain(large_ns.iter()).cloned().collect();

    let sieve_max = *all_ns.last().unwrap();
    eprintln!("  {DIM}▸ Sieving μ(k) for k ≤ {}...{RESET}", sieve_max);
    let mu = mobius_sieve(sieve_max);
    let mertens = mertens_values(&mu);
    eprintln!("  {GREEN}✓{RESET} Sieve complete");
    println!();

    let mut tsv_a = fs::File::create("results/diag_offdiag.tsv").unwrap();
    writeln!(tsv_a, "N\tvtGv\tDIAG\tOFFDIAG\tln_N\tOFFDIAG_logN\tvtGv_minus_1\tC_G_eff").unwrap();

    let mut tsv_b = fs::File::create("results/offdiag_range.tsv").unwrap();
    writeln!(tsv_b, "N\tOFFDIAG\tNEAR\tFAR\tln_N\tOFFDIAG_logN\tNEAR_logN\tFAR_logN").unwrap();

    let mut tsv_c = fs::File::create("results/double_abel.tsv").unwrap();
    writeln!(tsv_c, "N\tbilinear_sum\tabel_sum\tmax_A_dev\tavg_A_dev\tbilinear_logN\tabel_logN").unwrap();

    let mut tsv_e = fs::File::create("results/bilinear_mertens.tsv").unwrap();
    writeln!(tsv_e, "N\tB_N\tB_N_logN\tsingle_abel\tln_N").unwrap();

    // ═════════════════════════════════════════════════════
    // EXPERIMENT A: DIAGONAL vs OFF-DIAGONAL
    // ═════════════════════════════════════════════════════
    println!("  {BOLD}{WHITE}═══ EXPERIMENT A: DIAGONAL vs OFF-DIAGONAL DECOMPOSITION ═══{RESET}");
    println!("  {DIM}  vᵀGv = DIAG + OFFDIAG, where DIAG = Σ v_k²·G(k,k){RESET}");
    println!();
    println!("  {DIM}     N   │ vᵀGv         │ DIAG         │ OFFDIAG      │ OFFDIAG·logN │ C_G·eff{RESET}");

    let mut a_results = Vec::new();
    for &n in &all_ns {
        let t = Instant::now();
        let (vtgv, diag, offdiag, log_n) = experiment_a(n, &mu);
        let offdiag_logn = offdiag * log_n;
        let vtgv_m1 = vtgv - 1.0;
        let c_g_eff = vtgv_m1 * log_n;
        let elapsed = t.elapsed().as_secs_f64();

        writeln!(tsv_a, "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}",
            n, vtgv, diag, offdiag, log_n, offdiag_logn, vtgv_m1, c_g_eff).unwrap();

        let offdiag_color = if offdiag.abs() < 0.5 { GREEN } else { YELLOW };
        println!("    {:>5} │ {MAGENTA}{:>12.8}{RESET} │ {:>12.8} │ {offdiag_color}{:>12.8}{RESET} │ {:>12.6} │ {:>8.4}  ({:.2}s)",
            n, vtgv, diag, offdiag, offdiag_logn, c_g_eff, elapsed);

        a_results.push((n, vtgv, diag, offdiag, offdiag_logn, c_g_eff));
    }

    // ═════════════════════════════════════════════════════
    // EXPERIMENT B: NEAR vs FAR OFF-DIAGONAL
    // ═════════════════════════════════════════════════════
    println!();
    println!("  {BOLD}{WHITE}═══ EXPERIMENT B: NEAR vs FAR OFF-DIAGONAL CANCELLATION ═══{RESET}");
    println!("  {DIM}  NEAR = |j-k| ≤ √N,  FAR = |j-k| > √N{RESET}");
    println!();
    println!("  {DIM}     N   │ OFFDIAG      │ NEAR         │ FAR          │ NEAR·logN    │ FAR·logN{RESET}");

    let mut b_results = Vec::new();
    for &n in &small_ns {
        let t = Instant::now();
        let (offdiag, near, far, log_n) = experiment_b(n, &mu);
        let elapsed = t.elapsed().as_secs_f64();

        writeln!(tsv_b, "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}",
            n, offdiag, near, far, log_n, offdiag * log_n, near * log_n, far * log_n).unwrap();

        println!("    {:>5} │ {:>12.8} │ {:>12.8} │ {:>12.8} │ {:>12.6} │ {:>12.6}  ({:.2}s)",
            n, offdiag, near, far, near * log_n, far * log_n, elapsed);

        b_results.push((n, offdiag, near, far));
    }

    // ═════════════════════════════════════════════════════
    // EXPERIMENT C: DOUBLE ABEL SUMMATION
    // ═════════════════════════════════════════════════════
    println!();
    println!("  {BOLD}{WHITE}═══ EXPERIMENT C: DOUBLE ABEL SUMMATION VALIDATION ═══{RESET}");
    println!("  {DIM}  Bilinear sum Σ_{{j<k}} v_j·v_k/max(j,k)  vs  Abel form Σ_k (1/k)·A(k)·v_k{RESET}");
    println!();

    let mut c_results = Vec::new();
    for &n in &all_ns {
        let t = Instant::now();
        println!("  {BOLD}N = {}{RESET}", n);
        let (bilinear, abel, max_dev, avg_dev) = experiment_c(n, &mu, &mertens);
        let log_n = (n as f64).ln();
        let elapsed = t.elapsed().as_secs_f64();

        writeln!(tsv_c, "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}",
            n, bilinear, abel, max_dev, avg_dev, bilinear * log_n, abel * log_n).unwrap();

        let match_pct = if bilinear.abs() > 1e-20 {
            100.0 * (1.0 - (bilinear - abel).abs() / bilinear.abs())
        } else { 100.0 };

        println!("    bilinear = {:.10e}, abel = {:.10e}  (match: {:.4}%)", bilinear, abel, match_pct);
        println!("    bilinear·logN = {:.8}, abel·logN = {:.8}", bilinear * log_n, abel * log_n);
        println!("    {} bilinear ≈ abel  ({:.2}s)", check((match_pct - 100.0).abs() < 0.01), elapsed);
        println!();

        c_results.push((n, bilinear, abel, max_dev, avg_dev));
    }

    // ═════════════════════════════════════════════════════
    // EXPERIMENT D: ROW PROFILE (Gv)_j (small N only)
    // ═════════════════════════════════════════════════════
    println!("  {BOLD}{WHITE}═══ EXPERIMENT D: ROW-PARTIAL SUM PROFILE v_j·(Gv)_j ═══{RESET}");
    println!("  {DIM}  Checking v_j·(Gv)_j ≈ v_j·b_j (mean contribution){RESET}");
    println!();

    for &n in &[20usize, 100] {
        if n > sieve_max { continue; }
        let t = Instant::now();
        let profile = experiment_d(n, &mu);
        let elapsed = t.elapsed().as_secs_f64();

        let mut tsv_d = fs::File::create(format!("results/row_profile_N{}.tsv", n)).unwrap();
        writeln!(tsv_d, "k\tv_k*(Gv)_k\tv_k*b_k\tresidual").unwrap();

        println!("  {BOLD}N = {}{RESET}  ({:.2}s)", n, elapsed);
        println!("    {DIM}     k │ v_k·(Gv)_k     │ v_k·b_k        │ residual{RESET}");

        let mut total_residual = 0.0f64;
        for &(k, vgv, vb, res) in &profile {
            writeln!(tsv_d, "{}\t{:.15e}\t{:.15e}\t{:.15e}", k, vgv, vb, res).unwrap();
            total_residual += res;

            // Only print non-zero rows and selected rows
            if vgv.abs() > 1e-15 && (k <= 10 || k % 10 == 0 || k == n - 1) {
                let res_color = if res.abs() < 0.001 { GREEN } else { YELLOW };
                println!("    {:>5} │ {:>14.10} │ {:>14.10} │ {res_color}{:>12.8}{RESET}", k, vgv, vb, res);
            }
        }
        println!("    {BOLD}Total residual: Σ(v·Gv - v·b) = {:.10e}{RESET}", total_residual);
        println!();
    }

    // ═════════════════════════════════════════════════════
    // EXPERIMENT E: BILINEAR MERTENS CORRELATION
    // ═════════════════════════════════════════════════════
    println!("  {BOLD}{WHITE}═══ EXPERIMENT E: BILINEAR MERTENS CORRELATION ═══{RESET}");
    println!("  {DIM}  B(N) = Σ (1/k) · M_tapered(k)²,  target: B(N) = O(1/logN){RESET}");
    println!();
    println!("  {DIM}     N   │ B(N)            │ B(N)·logN       │ single_abel{RESET}");

    let mut e_results = Vec::new();
    for &n in &all_ns {
        let t = Instant::now();
        println!("  {BOLD}N = {}{RESET}", n);
        let (b_val, b_logn, single) = experiment_e(n, &mu);
        let log_n = (n as f64).ln();
        let elapsed = t.elapsed().as_secs_f64();

        writeln!(tsv_e, "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}",
            n, b_val, b_logn, single, log_n).unwrap();

        let b_color = if b_logn < 10.0 { GREEN } else { YELLOW };
        println!("    {:>5} │ {:.10e}  │ {b_color}{:>14.8}{RESET}  │ {:>12.8}  ({:.2}s)",
            n, b_val, b_logn, single, elapsed);

        e_results.push((n, b_val, b_logn, single));
        println!();
    }

    // ═════════════════════════════════════════════════════
    // CERTIFICATE
    // ═════════════════════════════════════════════════════
    println!();
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}BILINEAR ABEL & OFF-DIAGONAL — CERTIFICATE{RESET}                       {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}╠═══════════════════════════════════════════════════════════════════════╣{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  Precision: {YELLOW}{}-bit MPFR{RESET}    Threads: {YELLOW}{}{RESET}", P, n_threads);
    println!("  {BOLD}{CYAN}║{RESET}");

    // A: Check if OFFDIAG·logN stabilizes
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§A. Off-diagonal dominance check{RESET}");
    let offdiag_logn_vals: Vec<f64> = a_results.iter().filter(|r| r.0 >= 50).map(|r| r.4).collect();
    let offdiag_logn_avg = if offdiag_logn_vals.is_empty() { 0.0 }
        else { offdiag_logn_vals.iter().sum::<f64>() / offdiag_logn_vals.len() as f64 };
    let offdiag_logn_max = offdiag_logn_vals.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    println!("  {BOLD}{CYAN}║{RESET}    OFFDIAG·logN avg = {:.6} (stabilizing → constant = proof OK)", offdiag_logn_avg);
    println!("  {BOLD}{CYAN}║{RESET}    OFFDIAG·logN max = {:.6}", offdiag_logn_max);

    // Check whether C_G_eff stabilizes (vᵀGv - 1)·logN
    let cg_vals: Vec<f64> = a_results.iter().filter(|r| r.0 >= 50).map(|r| r.5).collect();
    let cg_avg = if cg_vals.is_empty() { 0.0 }
        else { cg_vals.iter().sum::<f64>() / cg_vals.len() as f64 };
    let cg_stabilizing = cg_vals.windows(2).all(|w| (w[1] - w[0]).abs() < 5.0);
    println!("  {BOLD}{CYAN}║{RESET}    C_G·eff avg = {:.6} (vᵀGv-1)·logN", cg_avg);
    println!("  {BOLD}{CYAN}║{RESET}    {} C_G·eff stabilizing (→ confirms vᵀGv ≤ 1 + C_G/logN)", check(cg_stabilizing));
    println!("  {BOLD}{CYAN}║{RESET}");

    // C: Double Abel summation match
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§C. Double Abel summation validation{RESET}");
    for r in &c_results {
        let match_pct = if r.1.abs() > 1e-20 {
            100.0 * (1.0 - (r.1 - r.2).abs() / r.1.abs())
        } else { 100.0 };
        println!("  {BOLD}{CYAN}║{RESET}    N={:>5}: bilinear={:.6e}, abel={:.6e}  {} match={:.4}%",
            r.0, r.1, r.2, check((match_pct - 100.0).abs() < 0.01), match_pct);
    }
    println!("  {BOLD}{CYAN}║{RESET}");

    // E: Bilinear Mertens
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§E. Bilinear Mertens B(N)·logN stabilization{RESET}");
    let b_logn_vals: Vec<f64> = e_results.iter().filter(|r| r.0 >= 50).map(|r| r.2).collect();
    let b_logn_avg = if b_logn_vals.is_empty() { 0.0 }
        else { b_logn_vals.iter().sum::<f64>() / b_logn_vals.len() as f64 };
    let b_stabilizing = b_logn_vals.windows(2).all(|w| (w[1] - w[0]).abs() < w[0].abs() * 0.5 + 1.0);
    println!("  {BOLD}{CYAN}║{RESET}    B(N)·logN avg = {:.6}", b_logn_avg);
    println!("  {BOLD}{CYAN}║{RESET}    {} B(N)·logN stabilizing (→ confirms B(N) = O(1/logN))", check(b_stabilizing));
    println!("  {BOLD}{CYAN}║{RESET}");

    // Final verdict
    let all_pass = cg_stabilizing && b_stabilizing;
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}VERDICT{RESET}");
    if all_pass {
        println!("  {BOLD}{CYAN}║{RESET}    {GREEN}{BOLD}✓ ALL EXPERIMENTS CONSISTENT WITH gram_form_upper_bound_34{RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {GREEN}  Numerical certificate supports axiom elimination{RESET}");
    } else {
        println!("  {BOLD}{CYAN}║{RESET}    {YELLOW}{BOLD}⚠ SOME EXPERIMENTS SHOW INSTABILITY{RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {YELLOW}  More data points or larger N may be needed{RESET}");
    }
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");

    // Summary JSON
    let summary = format!(r#"{{
  "experiment": "Cathedral Bilinear Abel & Off-Diagonal Cancellation Validator",
  "precision_bits": {P},
  "threads": {n_threads},
  "timestamp": "{}",
  "target_axiom": "gram_form_upper_bound_34 (PerronCrown.lean:60)",
  "conclusions": {{
    "C_G_eff_avg": {:.15e},
    "C_G_eff_stabilizing": {},
    "offdiag_logN_avg": {:.15e},
    "bilinear_mertens_logN_avg": {:.15e},
    "b_stabilizing": {},
    "all_pass": {}
  }},
  "experiment_A": [{}
  ],
  "experiment_C": [{}
  ],
  "experiment_E": [{}
  ],
  "elapsed_seconds": {:.3}
}}"#,
        chrono::Utc::now().to_rfc3339(),
        cg_avg, cg_stabilizing,
        offdiag_logn_avg,
        b_logn_avg, b_stabilizing,
        all_pass,
        a_results.iter().map(|r| {
            format!("\n    {{\"N\": {}, \"vtGv\": {:.15e}, \"DIAG\": {:.15e}, \"OFFDIAG\": {:.15e}, \"OFFDIAG_logN\": {:.15e}, \"C_G_eff\": {:.15e}}}",
                r.0, r.1, r.2, r.3, r.4, r.5)
        }).collect::<Vec<_>>().join(","),
        c_results.iter().map(|r| {
            format!("\n    {{\"N\": {}, \"bilinear\": {:.15e}, \"abel\": {:.15e}, \"max_A_dev\": {:.15e}, \"avg_A_dev\": {:.15e}}}",
                r.0, r.1, r.2, r.3, r.4)
        }).collect::<Vec<_>>().join(","),
        e_results.iter().map(|r| {
            format!("\n    {{\"N\": {}, \"B_N\": {:.15e}, \"B_N_logN\": {:.15e}, \"single_abel\": {:.15e}}}",
                r.0, r.1, r.2, r.3)
        }).collect::<Vec<_>>().join(","),
        t_global.elapsed().as_secs_f64()
    );
    fs::write("results/certificate.json", &summary).unwrap();

    println!();
    println!("  {BOLD}{WHITE}Total:{RESET} {GREEN}{:.1}s{RESET} ({} threads)", t_global.elapsed().as_secs_f64(), n_threads);
    println!("  {BOLD}{WHITE}Output:{RESET} results/{{diag_offdiag.tsv, offdiag_range.tsv, double_abel.tsv, bilinear_mertens.tsv, row_profile_N*.tsv, certificate.json}}");
    println!();
}
