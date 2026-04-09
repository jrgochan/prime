// ═══════════════════════════════════════════════════════════════════════
//  ATTACK 8: THE VARIATIONAL WITNESS
//  The Cathedral — Can we bypass matrix inversion entirely?
//
//  Tests explicit witness vectors against the Rayleigh quotient:
//    Q_N = (bᵀv)² / (vᵀCv)   where C = G - bbᵀ
//
//  If Q_N / ln(N) → constant > 0 for ANY test vector,
//  that vector is an algebraic witness to the Riemann Hypothesis.
//
//  Three test vectors:
//    v₁ = -μ(k)                      (Raw Möbius)
//    v₂ = -μ(k)(1 - k/N)            (Linear cutoff)
//    v₃ = -μ(k)(1 - ln(k)/ln(N))    (Log cutoff)
//
//  NO MATRIX INVERSION. NO CONDITION NUMBER ISSUES.
//  Direct quadratic form evaluation only.
// ═══════════════════════════════════════════════════════════════════════

use std::collections::HashMap;
use std::sync::Mutex;
use std::time::Instant;
use rayon::prelude::*;

// ─── Arithmetic ───────────────────────────────────────────────────

fn gcd(a: usize, b: usize) -> usize {
    let (mut a, mut b) = (a, b);
    while b != 0 { let t = b; b = a % b; a = t; }
    a
}

fn mobius_sieve(n: usize) -> Vec<i32> {
    let mut mu = vec![0i32; n + 1];
    mu[1] = 1;
    let mut is_prime = vec![true; n + 1];
    let mut primes = Vec::new();
    for i in 2..=n {
        if is_prime[i] { primes.push(i); mu[i] = -1; }
        for &p in &primes {
            if i * p > n { break; }
            is_prime[i * p] = false;
            if i % p == 0 { mu[i * p] = 0; break; }
            else { mu[i * p] = -mu[i]; }
        }
    }
    mu
}

// ─── Vasyunin sum with memoization ────────────────────────────────

/// V(a, b) = Σ_{m=1}^{a-1} {mb/a} · cot(πm/a)
/// Uses f64 trig (sufficient since we're not inverting any matrix)
fn vasyunin_sum_f64(a: usize, b: usize) -> f64 {
    if a <= 1 { return 0.0; }
    let pi = std::f64::consts::PI;
    let af = a as f64;
    let mut total = 0.0;
    for m in 1..a {
        let mb_mod_a = (m * b) % a;
        let frac = mb_mod_a as f64 / af;
        let angle = pi * m as f64 / af;
        let (sin_v, cos_v) = angle.sin_cos();
        if sin_v.abs() < 1e-15 { continue; }
        total += frac * cos_v / sin_v;
    }
    total
}

type VCache = Mutex<HashMap<(usize, usize), f64>>;

fn vasyunin_cached(a: usize, b: usize, cache: &VCache) -> f64 {
    // Check cache first
    if let Ok(guard) = cache.lock() {
        if let Some(&val) = guard.get(&(a, b)) {
            return val;
        }
    }
    let val = vasyunin_sum_f64(a, b);
    if let Ok(mut guard) = cache.lock() {
        guard.insert((a, b), val);
    }
    val
}

// ─── Vasyunin Gram entry (f64, exact formula) ─────────────────────

const EULER_GAMMA: f64 = 0.5772156649015328606;

fn gram_entry_f64(j: usize, k: usize, cache: &VCache) -> f64 {
    let pi = std::f64::consts::PI;
    let ln2pi = (2.0 * pi).ln();
    let coeff = (ln2pi - EULER_GAMMA) / 2.0;
    let jf = j as f64;
    let kf = k as f64;
    let jk = jf * kf;

    if j == k {
        return (ln2pi - EULER_GAMMA) / jf - 1.0 / (jf * jf);
    }

    let d = gcd(j, k);
    let jp = j / d;
    let kp = k / d;

    let term1 = coeff * (1.0 / jf + 1.0 / kf);
    let term2 = (jf - kf) / (2.0 * jk) * (kf / jf).ln();
    let v1 = vasyunin_cached(jp, kp, cache);
    let v2 = vasyunin_cached(kp, jp, cache);
    let term3 = pi * d as f64 / (2.0 * jk) * (v1 + v2);
    let term4 = 1.0 / jk;

    term1 + term2 - term3 - term4
}

// ─── Mean vector (closed form) ────────────────────────────────────

fn mean_entry(k: usize) -> f64 {
    let kf = k as f64;
    (kf.ln() + 1.0 - EULER_GAMMA) / kf
}

// ─── On-the-fly quadratic form evaluation ─────────────────────────

/// Compute vᵀGv by iterating over all pairs, computing G(i,j) on-the-fly.
/// No matrix storage needed!
fn quad_form_on_fly(v: &[f64], n: usize, cache: &VCache) -> f64 {
    // Diagonal terms
    let diag: f64 = (0..n).into_par_iter().map(|i| {
        let g_ii = gram_entry_f64(i + 1, i + 1, cache);
        v[i] * v[i] * g_ii
    }).sum();

    // Off-diagonal terms (symmetric, count twice)
    let offdiag: f64 = (0..n).into_par_iter().map(|i| {
        let mut row_sum = 0.0;
        for j in (i+1)..n {
            let g_ij = gram_entry_f64(i + 1, j + 1, cache);
            row_sum += v[i] * v[j] * g_ij;
        }
        row_sum
    }).sum();

    diag + 2.0 * offdiag
}

// ─── Test a witness vector ────────────────────────────────────────

fn test_witness(name: &str, v: &[f64], b: &[f64], n: usize, cache: &VCache) -> (f64, f64, f64) {
    let t0 = Instant::now();

    // bᵀv
    let bt_v: f64 = b.iter().zip(v.iter()).map(|(bi, vi)| bi * vi).sum();
    let s = bt_v * bt_v; // numerator

    // vᵀGv
    let vtgv = quad_form_on_fly(v, n, cache);

    // vᵀCv = vᵀGv - (bᵀv)² since C = G - bbᵀ
    let vtcv = vtgv - s;

    let q = if vtcv > 0.0 { s / vtcv } else { f64::NAN };
    let ln_n = (n as f64).ln();
    let q_over_ln = if ln_n > 0.0 { q / ln_n } else { 0.0 };

    eprintln!("    {} ({:.1}s): bᵀv={:.6}, S={:.6}, vᵀCv={:.6e}, Q={:.6}, Q/ln={:.6}",
        name, t0.elapsed().as_secs_f64(), bt_v, s, vtcv, q, q_over_ln);

    (q, q_over_ln, vtcv)
}

// ─── Main experiment ──────────────────────────────────────────────

fn experiment(n: usize, mu: &[i32], cache: &VCache) -> (f64, f64, f64, f64, f64, f64) {
    let ln_n = (n as f64).ln();
    let t_total = Instant::now();

    println!("\n{}", "━".repeat(78));
    println!("  N = {:5}  │  ln(N) = {:.4}  │  ln(ln(N)) = {:.4}  │  {} threads",
             n, ln_n, ln_n.ln(), rayon::current_num_threads());
    println!("{}", "━".repeat(78));

    // Mean vector
    let b: Vec<f64> = (1..=n).map(mean_entry).collect();

    // Count squarefree numbers (where μ(k) ≠ 0)
    let sqfree_count = (1..=n).filter(|&k| mu[k] != 0).count();
    println!("  Squarefree: {}/{} ({:.1}%)", sqfree_count, n, 100.0 * sqfree_count as f64 / n as f64);

    // Build three test vectors
    let v_raw: Vec<f64> = (1..=n).map(|k| -mu[k] as f64).collect();
    let v_linear: Vec<f64> = (1..=n).map(|k| {
        -mu[k] as f64 * (1.0 - k as f64 / n as f64)
    }).collect();
    let v_log: Vec<f64> = (1..=n).map(|k| {
        -mu[k] as f64 * (1.0 - (k as f64).ln() / ln_n)
    }).collect();

    // Norms
    let norm_raw: f64 = v_raw.iter().map(|x| x * x).sum::<f64>().sqrt();
    let norm_lin: f64 = v_linear.iter().map(|x| x * x).sum::<f64>().sqrt();
    let norm_log: f64 = v_log.iter().map(|x| x * x).sum::<f64>().sqrt();
    println!("  ‖v‖: raw={:.4} linear={:.4} log={:.4}", norm_raw, norm_lin, norm_log);

    // Test all three
    println!("  Computing Rayleigh quotients...");
    let (q1, ql1, vtcv1) = test_witness("Raw Möbius    ", &v_raw, &b, n, cache);
    let (q2, ql2, vtcv2) = test_witness("Linear cutoff ", &v_linear, &b, n, cache);
    let (q3, ql3, vtcv3) = test_witness("Log cutoff    ", &v_log, &b, n, cache);

    // bᵀv values
    let btv_raw: f64 = b.iter().zip(v_raw.iter()).map(|(bi, vi)| bi * vi).sum();
    let btv_lin: f64 = b.iter().zip(v_linear.iter()).map(|(bi, vi)| bi * vi).sum();
    let btv_log: f64 = b.iter().zip(v_log.iter()).map(|(bi, vi)| bi * vi).sum();

    let elapsed = t_total.elapsed().as_secs_f64();

    println!("\n  ┌─ VARIATIONAL WITNESS RESULTS (N={}) {}┐", n, "─".repeat(20));
    println!("  │  {:20} Q = {:12.6}  Q/ln = {:10.6}  bᵀv = {:10.6}  vᵀCv = {:10.3e}  │",
             "Raw Möbius", q1, ql1, btv_raw, vtcv1);
    println!("  │  {:20} Q = {:12.6}  Q/ln = {:10.6}  bᵀv = {:10.6}  vᵀCv = {:10.3e}  │",
             "Linear cutoff", q2, ql2, btv_lin, vtcv2);
    println!("  │  {:20} Q = {:12.6}  Q/ln = {:10.6}  bᵀv = {:10.6}  vᵀCv = {:10.3e}  │",
             "Log cutoff", q3, ql3, btv_log, vtcv3);
    println!("  └─ Total: {:.1}s {}┘", elapsed, "─".repeat(50));

    (ql1, ql2, ql3, vtcv1, vtcv2, vtcv3)
}

fn main() {
    let t_start = Instant::now();

    println!("\n{}", "═".repeat(78));
    println!("  ATTACK 8: THE VARIATIONAL WITNESS");
    println!("  Bypass matrix inversion · Direct Rayleigh quotient · f64 fast");
    println!("  Q_N = (bᵀv)² / (vᵀCv)  — Does Q/ln(N) stabilize?");
    println!("  Three vectors: Raw Möbius, Linear cutoff, Log cutoff");
    println!("{}", "═".repeat(78));

    let sizes = vec![50, 100, 200, 500, 1000, 2000, 5000, 10000];
    let max_n = *sizes.last().unwrap();
    let mu = mobius_sieve(max_n);
    let cache: VCache = Mutex::new(HashMap::new());

    let mut results: Vec<(usize, f64, f64, f64, f64, f64, f64)> = Vec::new();

    for &n in &sizes {
        let (ql1, ql2, ql3, vtcv1, vtcv2, vtcv3) = experiment(n, &mu, &cache);
        results.push((n, ql1, ql2, ql3, vtcv1, vtcv2, vtcv3));
    }

    // ─── Grand Summary Table ──────────────────────────────────────
    println!("\n\n{}", "═".repeat(78));
    println!("  GRAND SUMMARY — VARIATIONAL WITNESS");
    println!("{}", "═".repeat(78));
    println!("\n  {:>6} {:>8} {:>8} {:>12} {:>12} {:>12}",
             "N", "ln(N)", "lnln(N)", "Q/ln (Raw)", "Q/ln (Lin)", "Q/ln (Log)");
    println!("  {}", "─".repeat(68));
    for &(n, ql1, ql2, ql3, _, _, _) in &results {
        let ln_n = (n as f64).ln();
        println!("  {:>6} {:>8.4} {:>8.4} {:>12.6} {:>12.6} {:>12.6}",
                 n, ln_n, ln_n.ln(), ql1, ql2, ql3);
    }

    // Trend analysis for log cutoff
    println!("\n  ─── LOG CUTOFF TREND ANALYSIS ───");
    if results.len() >= 2 {
        let first = &results[0];
        let last = results.last().unwrap();
        let ln_ln_first = (first.0 as f64).ln().ln();
        let ln_ln_last = (last.0 as f64).ln().ln();
        let slope = (last.3 - first.3) / (ln_ln_last - ln_ln_first);
        let intercept = first.3 - slope * ln_ln_first;
        println!("  Fit: Q/ln(N) ≈ {:.2} · ln(ln(N)) + ({:.2})", slope, intercept);
        println!("  Prediction N=100,000: Q/ln ≈ {:.2}", slope * (100_000f64).ln().ln() + intercept);
        println!("  Prediction N=1,000,000: Q/ln ≈ {:.2}", slope * (1_000_000f64).ln().ln() + intercept);

        // Delta between consecutive log cutoff values
        println!("\n  ─── LOG CUTOFF DELTAS ───");
        for i in 1..results.len() {
            let prev = &results[i-1];
            let curr = &results[i];
            let delta = curr.3 - prev.3;
            println!("  N={:>5} → N={:>5}: Δ(Q/ln) = {:+.4}", prev.0, curr.0, delta);
        }
    }

    // Write JSON output
    let json_path = "results_attack8.json";
    let mut json = String::from("{\n  \"experiment\": \"variational_witness_attack8\",\n  \"results\": [\n");
    for (i, &(n, ql1, ql2, ql3, vtcv1, vtcv2, vtcv3)) in results.iter().enumerate() {
        let ln_n = (n as f64).ln();
        json += &format!("    {{\"N\": {}, \"ln_N\": {:.6}, \"ln_ln_N\": {:.6}, ", n, ln_n, ln_n.ln());
        json += &format!("\"Q_ln_raw\": {:.8}, \"Q_ln_linear\": {:.8}, \"Q_ln_log\": {:.8}, ", ql1, ql2, ql3);
        json += &format!("\"vtCv_raw\": {:.8e}, \"vtCv_linear\": {:.8e}, \"vtCv_log\": {:.8e}}}", vtcv1, vtcv2, vtcv3);
        if i + 1 < results.len() { json += ","; }
        json += "\n";
    }
    json += "  ]\n}\n";
    std::fs::write(json_path, &json).unwrap();
    println!("\n  📁 JSON results written to {}", json_path);

    let total_time = t_start.elapsed().as_secs_f64();
    println!("\n  Total runtime: {:.1}s", total_time);

    println!("\n  🏛️  If any Q/ln(N) column stabilizes to a positive constant,");
    println!("     that vector is the algebraic witness to the Riemann Hypothesis.");
    println!();
}
