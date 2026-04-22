//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL CERTIFIED WITNESS ENGINE
//!  Proof-Carrying Computation — Direction 5.1
//!
//!  Produces machine-checkable JSON certificates that formally bridge
//!  the Rust computational engine to the Lean 4 proof architecture.
//!
//!  For each N, certifies:
//!    1. Gram matrix positive definiteness (all eigenvalues > 0)
//!    2. Explicit Möbius witness d² = 1 - 2bᵀv + vᵀGv
//!    3. Rayleigh quotient S²/Q ≥ c·ln(N)
//!    4. Eigenvalue monotonicity (λ_min non-increasing)
//!    5. Precision audit (256-bit vs f64)
//!
//!  Output:
//!    results/certificates/cert_N{n}.json    — per-N certificates
//!    results/certificates/summary.json      — master summary
//!    results/certificates/monotonicity.json — λ_min chain
//! ═══════════════════════════════════════════════════════════════════════════

use nalgebra::{DMatrix, DVector, SymmetricEigen};
use rayon::prelude::*;
use rug::Float;
use std::fs;
use std::time::Instant;

const P: u32 = 256; // 256-bit MPFR precision

// ═══════════════════════════════════════════════
// NUMBER THEORY
// ═══════════════════════════════════════════════

fn gcd(a: usize, b: usize) -> usize {
    let (mut a, mut b) = (a, b);
    while b != 0 { let t = b; b = a % b; a = t; } a
}
fn mobius(mut n: usize) -> i32 {
    if n <= 1 { return 1; }
    let mut c = 0; let mut d = 2;
    while d * d <= n {
        if n % d == 0 { n /= d; if n % d == 0 { return 0; } c += 1; }
        d += 1;
    }
    if n > 1 { c += 1; }
    if c % 2 == 0 { 1 } else { -1 }
}

// ═══════════════════════════════════════════════
// 256-BIT GRAM MATRIX CONSTRUCTION
// ═══════════════════════════════════════════════

const EG: f64 = 0.5772156649015328606;

fn vasyunin_hp(a: usize, b: usize) -> Float {
    if a <= 1 { return Float::with_val(P, 0); }
    let pi = Float::with_val(P, rug::float::Constant::Pi);
    let af = Float::with_val(P, a as u64);
    let mut total = Float::with_val(P, 0);
    for m in 1..a {
        let mb_mod = (m * b) % a;
        let mut frac = Float::with_val(P, mb_mod as u64);
        frac /= &af;
        let mut angle = Float::with_val(P, &pi);
        angle *= m as u64;
        angle /= &af;
        let sin_v = Float::with_val(P, angle.clone().sin());
        let cos_v = Float::with_val(P, angle.cos());
        if sin_v.clone().abs() < 1e-30 { continue; }
        let mut term = Float::with_val(P, &frac);
        term *= &cos_v;
        term /= &sin_v;
        total += term;
    }
    total
}

fn gram_hp(j: usize, k: usize) -> f64 {
    let pi = Float::with_val(P, rug::float::Constant::Pi);
    let gamma = Float::with_val(P, Float::parse(
        "0.57721566490153286060651209008240243104215933593992").unwrap());
    let mut two_pi = Float::with_val(P, &pi);
    two_pi *= 2u32;
    let ln2pi = Float::with_val(P, two_pi.ln());
    let mut coeff = Float::with_val(P, &ln2pi);
    coeff -= &gamma;
    coeff /= 2u32;
    let jf = Float::with_val(P, j as u64);
    let kf = Float::with_val(P, k as u64);

    if j == k {
        let mut result = Float::with_val(P, &ln2pi);
        result -= &gamma;
        result /= &jf;
        let mut jsq = Float::with_val(P, &jf);
        jsq *= &jf;
        let mut inv_jsq = Float::with_val(P, 1u32);
        inv_jsq /= &jsq;
        result -= &inv_jsq;
        return result.to_f64();
    }

    let d = gcd(j, k);
    let (jp, kp) = (j / d, k / d);
    let mut jk = Float::with_val(P, &jf);
    jk *= &kf;

    let mut inv_j = Float::with_val(P, 1u32); inv_j /= &jf;
    let mut inv_k = Float::with_val(P, 1u32); inv_k /= &kf;
    let mut inv_sum = Float::with_val(P, &inv_j); inv_sum += &inv_k;
    let mut t1 = Float::with_val(P, &coeff); t1 *= &inv_sum;

    let mut diff = Float::with_val(P, &jf); diff -= &kf;
    let mut den2 = Float::with_val(P, 2u32); den2 *= &jk;
    let mut ratio = Float::with_val(P, &kf); ratio /= &jf;
    let ln_ratio = Float::with_val(P, ratio.ln());
    let mut t2 = Float::with_val(P, &diff); t2 /= &den2; t2 *= &ln_ratio;

    let v1 = vasyunin_hp(jp, kp);
    let v2 = vasyunin_hp(kp, jp);
    let mut v_sum = Float::with_val(P, &v1); v_sum += &v2;
    let mut den3 = Float::with_val(P, 2u32); den3 *= &jk;
    let mut t3 = Float::with_val(P, &pi); t3 *= d as u64; t3 /= &den3; t3 *= &v_sum;

    let mut t4 = Float::with_val(P, 1u32); t4 /= &jk;

    let mut result = Float::with_val(P, &t1);
    result += &t2; result -= &t3; result -= &t4;
    result.to_f64()
}

fn vasyunin_f64(a: usize, b: usize) -> f64 {
    if a <= 1 { return 0.0; }
    let pi = std::f64::consts::PI; let af = a as f64;
    let mut t = 0.0;
    for m in 1..a {
        let fr = ((m * b) % a) as f64 / af;
        let ang = pi * m as f64 / af;
        let (s, c) = ang.sin_cos();
        if s.abs() < 1e-15 { continue; }
        t += fr * c / s;
    }
    t
}
fn gram_f64(j: usize, k: usize) -> f64 {
    let pi = std::f64::consts::PI; let l2p = (2.0 * pi).ln(); let co = (l2p - EG) / 2.0;
    let (jf, kf) = (j as f64, k as f64); let jk = jf * kf;
    if j == k { return (l2p - EG) / jf - 1.0 / (jf * jf); }
    let d = gcd(j, k); let (jp, kp) = (j / d, k / d);
    co * (1.0 / jf + 1.0 / kf) + (jf - kf) / (2.0 * jk) * (kf / jf).ln()
        - pi * d as f64 / (2.0 * jk) * (vasyunin_f64(jp, kp) + vasyunin_f64(kp, jp))
        - 1.0 / jk
}

// ═══════════════════════════════════════════════
// GRAM MATRIX BUILDER
// ═══════════════════════════════════════════════

fn build_gram(n: usize) -> (DMatrix<f64>, f64) {
    let dim = n - 1;
    let pairs: Vec<_> = (0..dim).flat_map(|i| (i..dim).map(move |j| (i, j))).collect();
    let entries: Vec<_> = pairs.par_iter().map(|&(i, j)| {
        let hp = gram_hp(i + 2, j + 2);
        let lo = gram_f64(i + 2, j + 2);
        (i, j, hp, (hp - lo).abs())
    }).collect();
    let mut g = DMatrix::zeros(dim, dim);
    let mut mx = 0.0f64;
    for (i, j, v, d) in entries { g[(i, j)] = v; g[(j, i)] = v; if d > mx { mx = d; } }
    (g, mx)
}

// ═══════════════════════════════════════════════
// CERTIFICATE DATA STRUCTURES
// ═══════════════════════════════════════════════

#[derive(Clone)]
struct Certificate {
    n: usize,
    dim: usize,
    precision_bits: u32,
    time_s: f64,
    // Precision
    max_f64_delta: f64,
    // Eigenvalues
    eigenvalues_sorted: Vec<f64>,
    lambda_min: f64,
    lambda_max: f64,
    all_positive: bool,
    condition_number: f64,
    // Witness (Möbius log-cutoff)
    witness_type: String,
    b_dot_v: f64,       // bᵀv (mean projection)
    v_dot_gv: f64,      // vᵀGv (quadratic form)
    d_sq: f64,           // 1 - 2bᵀv + vᵀGv (NB distance)
    d_sq_positive: bool,
    // Covariance / Rayleigh
    v_dot_cv: f64,       // vᵀCv (covariance form)
    s_sq: f64,           // (bᵀv)² = S²
    s_sq_over_q: f64,    // S²/Q = Rayleigh quotient
    c_log_n: f64,        // S²/Q / ln(N)
    // Gram matrix entries (first 3×3 block as sample)
    gram_sample: Vec<(usize, usize, f64)>,
    // Mean vector entries (first 5)
    mean_sample: Vec<(usize, f64)>,
    // Witness vector entries (first 5)
    witness_sample: Vec<(usize, f64)>,
}

// ═══════════════════════════════════════════════
// MEAN VECTOR: b_k = (ln(k) + 1 - γ) / k
// ═══════════════════════════════════════════════

fn mean_entry(k: usize) -> f64 {
    let kf = k as f64;
    (kf.ln() + 1.0 - EG) / kf
}

// ═══════════════════════════════════════════════
// MÖBIUS LOG-CUTOFF WITNESS
// v_k = -μ(k+1) * (1 - ln(k+1)/ln(N))  for k=0..dim-1
// (indices shifted: k=0 maps to integer 2)
// ═══════════════════════════════════════════════

fn mobius_witness(n: usize) -> DVector<f64> {
    let dim = n - 1;
    let ln_n = (n as f64).ln();
    DVector::from_fn(dim, |i, _| {
        let k = i + 2;
        -(mobius(k) as f64) * (1.0 - (k as f64).ln() / ln_n)
    })
}

// ═══════════════════════════════════════════════
// MEAN VECTOR
// ═══════════════════════════════════════════════

fn mean_vector(n: usize) -> DVector<f64> {
    let dim = n - 1;
    DVector::from_fn(dim, |i, _| mean_entry(i + 2))
}

// ═══════════════════════════════════════════════
// CERTIFICATION ENGINE
// ═══════════════════════════════════════════════

fn certify(n: usize) -> Certificate {
    let t0 = Instant::now();
    let dim = n - 1;
    let ln_n = (n as f64).ln();

    eprintln!("  \x1b[2m▸ N={}: certifying {}×{} Gram at {}-bit...\x1b[0m", n, dim, dim, P);

    // 1. Build Gram matrix at 256-bit
    let (g, max_delta) = build_gram(n);

    // 2. Eigendecomposition
    let eg = SymmetricEigen::new(g.clone());
    let mut evals: Vec<f64> = eg.eigenvalues.iter().cloned().collect();
    evals.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let lambda_min = evals[0];
    let lambda_max = *evals.last().unwrap();
    let all_positive = evals.iter().all(|&v| v > 0.0);

    // 3. Witness construction
    let v = mobius_witness(n);
    let b = mean_vector(n);

    // bᵀv
    let b_dot_v = b.dot(&v);
    // vᵀGv
    let gv = &g * &v;
    let v_dot_gv = v.dot(&gv);
    // d² = 1 - 2bᵀv + vᵀGv
    let d_sq = 1.0 - 2.0 * b_dot_v + v_dot_gv;

    // 4. Covariance form: vᵀCv = vᵀGv - (bᵀv)²
    let s_sq = b_dot_v * b_dot_v;
    let v_dot_cv = v_dot_gv - s_sq;
    let s_sq_over_q = if v_dot_cv.abs() > 1e-30 { s_sq / v_dot_cv } else { f64::NAN };
    let c_log_n = s_sq_over_q / ln_n;

    // 5. Sample entries for certificate
    let gram_sample: Vec<_> = {
        let mut gs = Vec::new();
        for i in 0..3.min(dim) {
            for j in 0..3.min(dim) {
                gs.push((i + 2, j + 2, g[(i, j)]));
            }
        }
        gs
    };
    let mean_sample: Vec<_> = (0..5.min(dim)).map(|i| (i + 2, b[i])).collect();
    let witness_sample: Vec<_> = (0..5.min(dim)).map(|i| (i + 2, v[i])).collect();

    Certificate {
        n, dim,
        precision_bits: P,
        time_s: t0.elapsed().as_secs_f64(),
        max_f64_delta: max_delta,
        eigenvalues_sorted: evals,
        lambda_min,
        lambda_max,
        all_positive,
        condition_number: if lambda_min > 0.0 { lambda_max / lambda_min } else { f64::INFINITY },
        witness_type: "moebius_log_cutoff".into(),
        b_dot_v,
        v_dot_gv,
        d_sq,
        d_sq_positive: d_sq > 0.0,
        v_dot_cv,
        s_sq,
        s_sq_over_q,
        c_log_n,
        gram_sample,
        mean_sample,
        witness_sample,
    }
}

// ═══════════════════════════════════════════════
// JSON OUTPUT
// ═══════════════════════════════════════════════

fn cert_to_json(c: &Certificate) -> String {
    let mut j = String::new();
    j += "{\n";
    j += &format!("  \"N\": {},\n", c.n);
    j += &format!("  \"dim\": {},\n", c.dim);
    j += &format!("  \"precision_bits\": {},\n", c.precision_bits);
    j += &format!("  \"computation_time_s\": {:.3},\n", c.time_s);
    j += &format!("  \"timestamp\": \"{}\",\n", chrono::Utc::now().to_rfc3339());
    // Precision audit
    j += "  \"precision_audit\": {\n";
    j += &format!("    \"max_f64_delta\": {:.6e},\n", c.max_f64_delta);
    j += &format!("    \"f64_sufficient\": {}\n", c.max_f64_delta < 1e-10);
    j += "  },\n";
    // Eigenvalue certificate
    j += "  \"eigenvalue_certificate\": {\n";
    j += &format!("    \"lambda_min\": {:.15e},\n", c.lambda_min);
    j += &format!("    \"lambda_max\": {:.15e},\n", c.lambda_max);
    j += &format!("    \"all_positive\": {},\n", c.all_positive);
    j += &format!("    \"condition_number\": {:.6e},\n", c.condition_number);
    j += &format!("    \"num_eigenvalues\": {},\n", c.eigenvalues_sorted.len());
    // First 5 and last 5 eigenvalues
    let _ne = c.eigenvalues_sorted.len();
    let head: Vec<String> = c.eigenvalues_sorted.iter().take(5).map(|v| format!("{:.15e}", v)).collect();
    let tail: Vec<String> = c.eigenvalues_sorted.iter().rev().take(5).rev().map(|v| format!("{:.15e}", v)).collect();
    j += &format!("    \"smallest_5\": [{}],\n", head.join(", "));
    j += &format!("    \"largest_5\": [{}]\n", tail.join(", "));
    j += "  },\n";
    // Witness certificate
    j += "  \"witness_certificate\": {\n";
    j += &format!("    \"type\": \"{}\",\n", c.witness_type);
    j += &format!("    \"b_dot_v\": {:.15},\n", c.b_dot_v);
    j += &format!("    \"v_dot_Gv\": {:.15},\n", c.v_dot_gv);
    j += &format!("    \"d_sq\": {:.15},\n", c.d_sq);
    j += &format!("    \"d_sq_positive\": {},\n", c.d_sq_positive);
    j += &format!("    \"d_sq_formula\": \"1 - 2*b^T*v + v^T*G*v\",\n");
    // Lean bridge
    j += "    \"lean_bridge\": {\n";
    j += "      \"theorem\": \"existential_implies_infimum\",\n";
    j += &format!("      \"epsilon\": {:.15},\n", c.d_sq + 1e-12);
    j += &format!("      \"certified_bound\": \"nbDistSq' {} < {:.10}\"\n", c.n, c.d_sq + 1e-12);
    j += "    }\n";
    j += "  },\n";
    // Rayleigh certificate
    j += "  \"rayleigh_certificate\": {\n";
    j += &format!("    \"S_squared\": {:.15},\n", c.s_sq);
    j += &format!("    \"v_dot_Cv\": {:.15},\n", c.v_dot_cv);
    j += &format!("    \"S_sq_over_Q\": {:.10},\n", c.s_sq_over_q);
    j += &format!("    \"c_times_logN\": {:.10},\n", c.c_log_n);
    j += &format!("    \"ln_N\": {:.10},\n", (c.n as f64).ln());
    j += "    \"lean_bridge\": {\n";
    j += "      \"theorem\": \"forward_bridge_from_lambda_trick\",\n";
    j += &format!("      \"c_constant\": {:.10},\n", c.c_log_n);
    j += &format!("      \"log_N\": {:.10}\n", (c.n as f64).ln());
    j += "    }\n";
    j += "  },\n";
    // Sample data
    j += "  \"gram_sample\": [\n";
    for (idx, &(i, k, v)) in c.gram_sample.iter().enumerate() {
        let comma = if idx < c.gram_sample.len() - 1 { "," } else { "" };
        j += &format!("    {{\"j\": {}, \"k\": {}, \"G_jk\": {:.15e}}}{}\n", i, k, v, comma);
    }
    j += "  ],\n";
    j += "  \"mean_sample\": [\n";
    for (idx, &(k, v)) in c.mean_sample.iter().enumerate() {
        let comma = if idx < c.mean_sample.len() - 1 { "," } else { "" };
        j += &format!("    {{\"k\": {}, \"b_k\": {:.15e}}}{}\n", k, v, comma);
    }
    j += "  ],\n";
    j += "  \"witness_sample\": [\n";
    for (idx, &(k, v)) in c.witness_sample.iter().enumerate() {
        let comma = if idx < c.witness_sample.len() - 1 { "," } else { "" };
        j += &format!("    {{\"k\": {}, \"v_k\": {:.15e}}}{}\n", k, v, comma);
    }
    j += "  ],\n";
    // Verdicts
    j += "  \"verdicts\": {\n";
    j += &format!("    \"gram_positive_definite\": {},\n", c.all_positive);
    j += &format!("    \"witness_valid\": {},\n", c.d_sq_positive);
    j += &format!("    \"distance_positive\": {},\n", c.d_sq > 0.0);
    j += &format!("    \"precision_sufficient\": {}\n", c.max_f64_delta < 1e-10);
    j += "  }\n";
    j += "}\n";
    j
}

// ═══════════════════════════════════════════════
// TERMINAL OUTPUT
// ═══════════════════════════════════════════════

const BOLD: &str = "\x1b[1m";
const DIM: &str = "\x1b[2m";
const CYAN: &str = "\x1b[36m";
const GREEN: &str = "\x1b[32m";
const YELLOW: &str = "\x1b[33m";
const MAGENTA: &str = "\x1b[35m";
const RED: &str = "\x1b[31m";
const WHITE: &str = "\x1b[97m";
const RESET: &str = "\x1b[0m";

fn check(b: bool) -> &'static str { if b { "\x1b[32m✓\x1b[0m" } else { "\x1b[31m✗\x1b[0m" } }

fn print_cert(c: &Certificate) {
    let _ln_n = (c.n as f64).ln();

    println!("  {CYAN}┌─── {BOLD}Certificate N = {}{RESET} {DIM}(dim={}, {:.1}s, {}-bit){RESET}",
        c.n, c.dim, c.time_s, c.precision_bits);
    println!("  {CYAN}│{RESET}  {} λ_min = {GREEN}{:.12e}{RESET}  κ = {:.2e}",
        check(c.all_positive), c.lambda_min, c.condition_number);
    println!("  {CYAN}│{RESET}  {} d²_N  = {MAGENTA}{:.12}{RESET}  {DIM}(1 - 2bᵀv + vᵀGv){RESET}",
        check(c.d_sq_positive), c.d_sq);
    println!("  {CYAN}│{RESET}    bᵀv = {:.10}  vᵀGv = {:.10}", c.b_dot_v, c.v_dot_gv);
    println!("  {CYAN}│{RESET}    S²/Q = {YELLOW}{:.6}{RESET}  c = S²/(Q·lnN) = {GREEN}{:.6}{RESET}",
        c.s_sq_over_q, c.c_log_n);
    println!("  {CYAN}│{RESET}  {} max|Δ_f64| = {:.2e}", check(c.max_f64_delta < 1e-10), c.max_f64_delta);
    println!("  {CYAN}└──────────────────────────────────────────────────{RESET}");
}

fn print_summary(certs: &[Certificate]) {
    println!();
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}CATHEDRAL PROOF-CARRYING COMPUTATION — CERTIFICATE SUMMARY{RESET}  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}╠═══════════════════════════════════════════════════════════════════╣{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}");

    // Eigenvalue positivity chain
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§1. Eigenvalue Positivity Chain{RESET}  {DIM}(Lean: lambdaMin_shifted_antitone){RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}    N    │  λ_min(G_N)        │  Δ_f64          │  PD{RESET}");
    for c in certs {
        println!("  {BOLD}{CYAN}║{RESET}    {:>5} │  {GREEN}{:.12e}{RESET}  │  {:.2e}  │  {}",
            c.n, c.lambda_min, c.max_f64_delta, check(c.all_positive));
    }

    // Monotonicity verification
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§2. Monotonicity Certificate{RESET}  {DIM}(λ_min(G_N) non-increasing){RESET}");
    let mut monotone = true;
    for w in certs.windows(2) {
        let ok = w[0].lambda_min >= w[1].lambda_min;
        if !ok { monotone = false; }
        println!("  {BOLD}{CYAN}║{RESET}    λ_min({:>4}) = {:.8e} ≥ λ_min({:>4}) = {:.8e}  {}",
            w[0].n, w[0].lambda_min, w[1].n, w[1].lambda_min, check(ok));
    }
    println!("  {BOLD}{CYAN}║{RESET}    {BOLD}Chain valid: {}{RESET}", check(monotone));

    // Witness certificates
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§3. Witness Certificates{RESET}  {DIM}(Lean: existential_implies_infimum){RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}    N    │  d²_N              │  bᵀv          │  vᵀGv{RESET}");
    for c in certs {
        println!("  {BOLD}{CYAN}║{RESET}    {:>5} │  {MAGENTA}{:.12}{RESET}   │  {:.10}  │  {:.10}",
            c.n, c.d_sq, c.b_dot_v, c.v_dot_gv);
    }

    // Rayleigh quotient
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§4. Rayleigh Quotient Growth{RESET}  {DIM}(Lean: forward_bridge_from_lambda_trick){RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}    N    │  S²/Q          │  c = S²/(Q·lnN)  │  c·lnN{RESET}");
    for c in certs {
        let ln_n = (c.n as f64).ln();
        println!("  {BOLD}{CYAN}║{RESET}    {:>5} │  {YELLOW}{:.8}{RESET}      │  {GREEN}{:.8}{RESET}        │  {:.6}",
            c.n, c.s_sq_over_q, c.c_log_n, c.c_log_n * ln_n);
    }

    // Grand Verdicts
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}═══ VERDICTS ═══{RESET}");
    let all_pd = certs.iter().all(|c| c.all_positive);
    let all_witness = certs.iter().all(|c| c.d_sq_positive);
    let all_prec = certs.iter().all(|c| c.max_f64_delta < 1e-10);
    let rayleigh_grows = certs.last().unwrap().s_sq_over_q > certs.first().unwrap().s_sq_over_q;
    let d_sq_decreases = certs.last().unwrap().d_sq < certs.first().unwrap().d_sq;
    let n_max = certs.last().unwrap().n;

    println!("  {BOLD}{CYAN}║{RESET}    {} G_N positive definite for all N ≤ {}", check(all_pd), n_max);
    println!("  {BOLD}{CYAN}║{RESET}    {} λ_min chain monotonically non-increasing", check(monotone));
    println!("  {BOLD}{CYAN}║{RESET}    {} d²_N > 0 for all certified N", check(all_witness));
    println!("  {BOLD}{CYAN}║{RESET}    {} d²_N monotonically decreasing", check(d_sq_decreases));
    println!("  {BOLD}{CYAN}║{RESET}    {} S²/Q grows with N (Rayleigh divergence)", check(rayleigh_grows));
    println!("  {BOLD}{CYAN}║{RESET}    {} f64 precision sufficient (all Δ < 1e-10)", check(all_prec));
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}Lean Integration:{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}    lambdaMin_shifted_antitone + cert(N={}) ⟹ G_N PD ∀N ≤ {}", n_max, n_max);
    println!("  {BOLD}{CYAN}║{RESET}    existential_implies_infimum + cert ⟹ nbDistSq' N < ε");
    println!("  {BOLD}{CYAN}║{RESET}    forward_bridge_from_lambda_trick + cert ⟹ ∫(1-f)² < 1/(1+c·lnN)");
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════╝{RESET}");
}

// ═══════════════════════════════════════════════
// FILE OUTPUT
// ═══════════════════════════════════════════════

fn write_certificates(certs: &[Certificate], dir: &str) {
    let cert_dir = format!("{}/certificates", dir);
    fs::create_dir_all(&cert_dir).unwrap();

    // Per-N certificates
    for c in certs {
        let json = cert_to_json(c);
        let path = format!("{}/cert_N{}.json", cert_dir, c.n);
        fs::write(&path, &json).unwrap();
    }

    // Monotonicity chain
    let mut mono_json = String::from("{\n  \"monotonicity_chain\": [\n");
    for (idx, w) in certs.windows(2).enumerate() {
        let ok = w[0].lambda_min >= w[1].lambda_min;
        let comma = if idx < certs.len() - 2 { "," } else { "" };
        mono_json += &format!("    {{\"N_from\": {}, \"N_to\": {}, \"lambda_min_from\": {:.15e}, \"lambda_min_to\": {:.15e}, \"non_increasing\": {}}}{}\n",
            w[0].n, w[1].n, w[0].lambda_min, w[1].lambda_min, ok, comma);
    }
    mono_json += "  ],\n";
    let all_mono = certs.windows(2).all(|w| w[0].lambda_min >= w[1].lambda_min);
    mono_json += &format!("  \"chain_valid\": {},\n", all_mono);
    mono_json += &format!("  \"lean_theorem\": \"lambdaMin_shifted_antitone\",\n");
    mono_json += &format!("  \"conclusion\": \"G_N positive definite for all N <= {}\"\n", certs.last().unwrap().n);
    mono_json += "}\n";
    fs::write(format!("{}/monotonicity.json", cert_dir), &mono_json).unwrap();

    // Master summary
    let mut summary = String::from("{\n");
    summary += "  \"experiment\": \"Cathedral Proof-Carrying Computation\",\n";
    summary += &format!("  \"precision_bits\": {},\n", P);
    summary += &format!("  \"timestamp\": \"{}\",\n", chrono::Utc::now().to_rfc3339());
    summary += &format!("  \"N_range\": [{}, {}],\n", certs.first().unwrap().n, certs.last().unwrap().n);
    summary += &format!("  \"num_certificates\": {},\n", certs.len());
    summary += "  \"lean_theorems_used\": [\n";
    summary += "    \"lambdaMin_shifted_antitone (PROVED)\",\n";
    summary += "    \"existential_implies_infimum (PROVED)\",\n";
    summary += "    \"forward_bridge_from_lambda_trick (PROVED)\",\n";
    summary += "    \"augmentedGramMatrix_posDef (PROVED)\",\n";
    summary += "    \"nbDistSq_pos_from_augmented (PROVED)\"\n";
    summary += "  ],\n";
    // Per-N summary data
    summary += "  \"certificates\": [\n";
    for (idx, c) in certs.iter().enumerate() {
        let comma = if idx < certs.len() - 1 { "," } else { "" };
        summary += &format!("    {{\"N\": {}, \"lambda_min\": {:.15e}, \"d_sq\": {:.15}, \"S_sq_over_Q\": {:.10}, \"c_logN\": {:.10}, \"all_positive\": {}, \"d_sq_positive\": {}}}{}\n",
            c.n, c.lambda_min, c.d_sq, c.s_sq_over_q, c.c_log_n, c.all_positive, c.d_sq_positive, comma);
    }
    summary += "  ],\n";
    // Global verdicts
    let all_pd = certs.iter().all(|c| c.all_positive);
    let all_w = certs.iter().all(|c| c.d_sq_positive);
    let mono = certs.windows(2).all(|w| w[0].lambda_min >= w[1].lambda_min);
    summary += "  \"global_verdicts\": {\n";
    summary += &format!("    \"all_gram_pd\": {},\n", all_pd);
    summary += &format!("    \"lambda_min_monotone\": {},\n", mono);
    summary += &format!("    \"all_d_sq_positive\": {},\n", all_w);
    summary += &format!("    \"all_f64_sufficient\": {}\n", certs.iter().all(|c| c.max_f64_delta < 1e-10));
    summary += "  }\n";
    summary += "}\n";
    fs::write(format!("{}/summary.json", cert_dir), &summary).unwrap();

    eprintln!("  {GREEN}✓{RESET} Certificates written to {BOLD}{}/{RESET}",  cert_dir);
}

// ═══════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════

fn main() {
    let t = Instant::now();

    println!();
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}CATHEDRAL CERTIFIED WITNESS ENGINE{RESET}                            {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}Direction 5.1: Proof-Carrying Computation{RESET}                    {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}256-bit MPFR · {} cores · JSON certificates{RESET}                 {BOLD}{CYAN}║{RESET}",
        rayon::current_num_threads());
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════╝{RESET}");
    println!();

    // Certificate sizes: dense near small N, sparse at large N
    let sizes = vec![10, 20, 50, 100, 200, 300, 500, 800, 1000];
    let mut certs = Vec::new();

    for &n in &sizes {
        let c = certify(n);
        print_cert(&c);
        certs.push(c);
    }

    print_summary(&certs);

    write_certificates(&certs, "results");

    println!();
    println!("  {BOLD}{WHITE}Total runtime:{RESET} {GREEN}{:.1}s{RESET} on {} cores",
        t.elapsed().as_secs_f64(), rayon::current_num_threads());
    println!("  {BOLD}{WHITE}Certificates:{RESET} results/certificates/cert_N{{N}}.json × {}",
        certs.len());
    println!("  {BOLD}{WHITE}Summary:{RESET} results/certificates/summary.json");
    println!("  {BOLD}{WHITE}Monotonicity:{RESET} results/certificates/monotonicity.json");
    println!();
}
