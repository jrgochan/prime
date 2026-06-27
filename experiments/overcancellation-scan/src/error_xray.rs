#![allow(dead_code, clippy::needless_range_loop, clippy::empty_line_after_doc_comments)]
//! # Error Matrix X-Ray: The G_V = R + E Decomposition
//!
//! ## Purpose
//!
//! For the Möbius-Fejér weights v_k = -μ(k)·(1 - logk/logN),
//! compute BOTH:
//!   vᵀG_Vv  (Vasyunin Gram matrix, exact cotangent formula)
//!   vᵀRv    (Ramanujan matrix, gcd²/(12jk))
//!
//! and track the ERROR:
//!   vᵀEv = vᵀG_Vv - vᵀRv
//!
//! Decompose E into:
//!   E_log  = (ln2π-γ)/2·(1/j+1/k) + (j-k)/(2jk)·ln(k/j)
//!   E_cot  = -πd/(2jk)·(V(j',k')+V(k',j'))
//!   E_const = -1/(jk)
//!   E_ram  = -R(j,k) = -gcd²/(12jk)
//!
//! Key question: Does (vᵀEv)·logN → constant?
//!
//! Created: May 19, 2026 — The X-Ray Session 🔬

use cathedral_utils::arith::{gcd, mobius_table};
use rayon::prelude::*;
use std::time::Instant;

const EULER_GAMMA: f64 = 0.5772156649015329;
const PI: f64 = std::f64::consts::PI;
const LN2PI: f64 = 1.8378770664093453;

// ═══════════════════════════════════════════════
// §1. MATRIX ENTRY FUNCTIONS
// ═══════════════════════════════════════════════

/// Vasyunin cotangent sum V(a,b) = Σ_{m=1}^{a-1} {mb/a}·cot(πm/a)
fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 { return 0.0; }
    let af = a as f64;
    let mut total = 0.0;
    for m in 1..a {
        let frac = ((m * b) % a) as f64 / af;
        let angle = PI * m as f64 / af;
        let (sin_v, cos_v) = angle.sin_cos();
        if sin_v.abs() < 1e-15 { continue; }
        total += frac * cos_v / sin_v;
    }
    total
}

/// Vasyunin Gram entry G_V(j,k) — exact discrete formula
fn gram_entry_vasyunin(j: usize, k: usize) -> f64 {
    let (jf, kf) = (j as f64, k as f64);
    if j == k {
        return (LN2PI - EULER_GAMMA) / kf - 1.0 / (kf * kf);
    }
    let d = gcd(j, k);
    let (jp, kp) = (j / d, k / d);
    let df = d as f64;
    let t1 = (LN2PI - EULER_GAMMA) / 2.0 * (1.0 / jf + 1.0 / kf);
    let t2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
    let t3 = PI * df / (2.0 * jf * kf) * (vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp));
    let t4 = 1.0 / (jf * kf);
    t1 + t2 - t3 - t4
}

/// Ramanujan entry R(j,k) = gcd(j,k)²/(12·j·k)
#[inline]
fn ramanujan_entry(j: usize, k: usize) -> f64 {
    let d = gcd(j, k) as f64;
    d * d / (12.0 * j as f64 * k as f64)
}

/// Error matrix entry E(j,k) = G_V(j,k) - R(j,k)
#[inline]
fn error_entry(j: usize, k: usize) -> f64 {
    gram_entry_vasyunin(j, k) - ramanujan_entry(j, k)
}

// ═══════════════════════════════════════════════
// §1.5. ERROR DECOMPOSITION COMPONENTS
// ═══════════════════════════════════════════════

/// Log component: (ln2π-γ)/2·(1/j+1/k) + (j-k)/(2jk)·ln(k/j)
/// On diagonal: (ln2π-γ)/k
fn error_log(j: usize, k: usize) -> f64 {
    let (jf, kf) = (j as f64, k as f64);
    if j == k {
        return (LN2PI - EULER_GAMMA) / kf;
    }
    let t1 = (LN2PI - EULER_GAMMA) / 2.0 * (1.0 / jf + 1.0 / kf);
    let t2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
    t1 + t2
}

/// Cotangent component: -πd/(2jk)·(V(j',k')+V(k',j'))
/// On diagonal: 0 (since V(1,1) = 0)
fn error_cot(j: usize, k: usize) -> f64 {
    if j == k { return 0.0; }
    let d = gcd(j, k);
    let (jp, kp) = (j / d, k / d);
    let df = d as f64;
    let (jf, kf) = (j as f64, k as f64);
    -PI * df / (2.0 * jf * kf) * (vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp))
}

/// Constant component: -1/(jk)
fn error_const(j: usize, k: usize) -> f64 {
    -1.0 / (j as f64 * k as f64)
}

// ═══════════════════════════════════════════════
// §2. QUADRATIC FORM COMPUTATION
// ═══════════════════════════════════════════════

struct XRayResult {
    n: usize,
    vt_gv: f64,       // vᵀG_Vv
    vt_rv: f64,       // vᵀRv
    vt_ev: f64,       // vᵀEv = vᵀG_Vv - vᵀRv
    vt_ev_log: f64,   // log component of vᵀEv
    vt_ev_cot: f64,   // cotangent component of vᵀEv
    vt_ev_const: f64,  // constant component of vᵀEv
    vt_ev_ram: f64,    // -vᵀRv component
    bt_v: f64,         // bᵀv (mean vector · weights)
    sigma_half: f64,   // (Σv_k)/2
    d_sq: f64,         // 1 - 2bᵀv + vᵀG_Vv
    elapsed_ms: f64,
}

fn xray_scan(mu: &[i8], n: usize) -> XRayResult {
    let t0 = Instant::now();
    let log_n = (n as f64).ln();

    // Build Möbius-Fejér weights: v_k = -μ(k)·(1 - logk/logN) for k=1..N
    let v: Vec<f64> = (0..=n).map(|k| {
        if k == 0 || mu[k] == 0 { 0.0 }
        else { -(mu[k] as f64) * (1.0 - (k as f64).ln() / log_n) }
    }).collect();

    // Collect active indices (squarefree k with v[k] != 0)
    let active: Vec<usize> = (1..=n).filter(|&k| v[k] != 0.0).collect();

    // Parallel computation: each j-row computed independently via Rayon
    let row_sums: Vec<(f64, f64, f64, f64, f64, f64)> = active.par_iter().map(|&j| {
        let mut gv = 0.0f64;
        let mut rv = 0.0f64;
        let mut ev_log = 0.0f64;
        let mut ev_cot = 0.0f64;
        let mut ev_const = 0.0f64;
        let mut ev_ram = 0.0f64;

        for &k in &active {
            let vjvk = v[j] * v[k];
            gv += vjvk * gram_entry_vasyunin(j, k);
            let r_jk = ramanujan_entry(j, k);
            rv += vjvk * r_jk;
            ev_log += vjvk * error_log(j, k);
            ev_cot += vjvk * error_cot(j, k);
            ev_const += vjvk * error_const(j, k);
            ev_ram += vjvk * (-r_jk);
        }
        (gv, rv, ev_log, ev_cot, ev_const, ev_ram)
    }).collect();

    // Reduce
    let mut vt_gv = 0.0f64;
    let mut vt_rv = 0.0f64;
    let mut vt_ev_log = 0.0f64;
    let mut vt_ev_cot = 0.0f64;
    let mut vt_ev_const = 0.0f64;
    let mut vt_ev_ram = 0.0f64;
    for (gv, rv, el, ec, eco, er) in &row_sums {
        vt_gv += gv;
        vt_rv += rv;
        vt_ev_log += el;
        vt_ev_cot += ec;
        vt_ev_const += eco;
        vt_ev_ram += er;
    }

    let vt_ev = vt_gv - vt_rv;

    // Mean vector: b_k = (ln(k) + 1 - γ) / k
    let mut bt_v = 0.0f64;
    for k in 1..=n {
        if v[k] == 0.0 { continue; }
        bt_v += ((k as f64).ln() + 1.0 - EULER_GAMMA) / k as f64 * v[k];
    }

    // σ/2 = (Σv_k)/2
    let sigma_half: f64 = v[1..=n].iter().sum::<f64>() / 2.0;

    // d² = 1 - 2bᵀv + vᵀG_Vv
    let d_sq = 1.0 - 2.0 * bt_v + vt_gv;

    let elapsed_ms = t0.elapsed().as_secs_f64() * 1000.0;

    XRayResult {
        n, vt_gv, vt_rv, vt_ev,
        vt_ev_log, vt_ev_cot, vt_ev_const, vt_ev_ram,
        bt_v, sigma_half, d_sq, elapsed_ms,
    }
}

// ═══════════════════════════════════════════════
// §3. MAIN
// ═══════════════════════════════════════════════

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║   ERROR MATRIX X-RAY: The G_V = R + E Decomposition           ║");
    println!("║                                                                ║");
    println!("║   v_k = -μ(k)·(1 - logk/logN)  [Möbius-Fejér weights]        ║");
    println!("║   G_V = Vasyunin Gram (exact cotangent formula)                ║");
    println!("║   R   = Ramanujan (gcd²/12jk)                                 ║");
    println!("║   E   = G_V - R  (the Error matrix / Riemann Noise)           ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    // N values — cotangent sums are O(N/gcd), total is O(N² × avg_coprime_part)
    // Feasible up to ~3000 on CPU in reasonable time
    let test_points: Vec<usize> = vec![
        10, 20, 30, 50, 80, 100, 150, 200, 300, 500, 750, 1000,
        1500, 2000, 3000, 4000, 5000, 6000, 8000,
    ];

    let max_n = *test_points.iter().max().unwrap();
    println!("Sieving μ(k) for k ≤ {}...", max_n);
    let t0 = Instant::now();
    let mu = mobius_table(max_n);
    println!("  Done in {:.1}ms\n", t0.elapsed().as_secs_f64() * 1000.0);

    // ═══════════════════════════════════════════════
    // §3a. THE MAIN SCAN
    // ═══════════════════════════════════════════════

    println!("═══════════════════════════════════════════════════════════════════");
    println!("  §3a. THE X-RAY: vᵀG_Vv vs vᵀRv vs vᵀEv");
    println!("═══════════════════════════════════════════════════════════════════\n");

    println!("{:>6} {:>10} {:>10} {:>10} {:>10} {:>10} {:>8}",
             "N", "vᵀG_Vv", "vᵀRv", "vᵀEv", "d²_BD", "(Ev)·lnN", "ms");
    println!("{}", "─".repeat(72));

    let mut results: Vec<XRayResult> = Vec::new();

    for &n in &test_points {
        let r = xray_scan(&mu, n);
        let log_n = (n as f64).ln();

        println!("{:>6} {:>10.6} {:>10.6} {:>10.6} {:>10.6} {:>10.4} {:>7.0}",
                 n, r.vt_gv, r.vt_rv, r.vt_ev, r.d_sq,
                 r.vt_ev * log_n, r.elapsed_ms);

        results.push(r);
    }

    // ═══════════════════════════════════════════════
    // §3b. ERROR DECOMPOSITION
    // ═══════════════════════════════════════════════

    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  §3b. ERROR DECOMPOSITION: vᵀEv = E_log + E_cot + E_const + E_R");
    println!("═══════════════════════════════════════════════════════════════════\n");

    println!("{:>6} {:>10} {:>10} {:>10} {:>10} {:>10} {:>8}",
             "N", "E_log", "E_cot", "E_const", "E_R(-R)", "Total_E", "Check");
    println!("{}", "─".repeat(72));

    for r in &results {
        let total = r.vt_ev_log + r.vt_ev_cot + r.vt_ev_const + r.vt_ev_ram;
        let check = if (total - r.vt_ev).abs() < 1e-8 { "✅" } else { "❌" };
        println!("{:>6} {:>10.6} {:>10.6} {:>10.6} {:>10.6} {:>10.6} {:>6}",
                 r.n, r.vt_ev_log, r.vt_ev_cot, r.vt_ev_const, r.vt_ev_ram,
                 total, check);
    }

    // ═══════════════════════════════════════════════
    // §3c. COMPONENT DOMINANCE
    // ═══════════════════════════════════════════════

    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  §3c. COMPONENT DOMINANCE: Which part of E matters most?");
    println!("═══════════════════════════════════════════════════════════════════\n");

    println!("{:>6} {:>10} {:>10} {:>10} {:>10}",
             "N", "%_log", "%_cot", "%_const", "%_R");
    println!("{}", "─".repeat(50));

    for r in &results {
        if r.vt_ev.abs() < 1e-15 { continue; }
        let total = r.vt_ev.abs();
        println!("{:>6} {:>9.1}% {:>9.1}% {:>9.1}% {:>9.1}%",
                 r.n,
                 r.vt_ev_log / total * 100.0,
                 r.vt_ev_cot / total * 100.0,
                 r.vt_ev_const / total * 100.0,
                 r.vt_ev_ram / total * 100.0);
    }

    // ═══════════════════════════════════════════════
    // §3d. CONVERGENCE ANALYSIS
    // ═══════════════════════════════════════════════

    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  §3d. CONVERGENCE: Does (vᵀEv)·logN → constant?");
    println!("═══════════════════════════════════════════════════════════════════\n");

    println!("{:>6} {:>12} {:>12} {:>12} {:>12} {:>12}",
             "N", "vᵀEv", "vᵀEv·lnN", "vᵀGv-1", "(Gv-1)·lnN", "vᵀGv<1?");
    println!("{}", "─".repeat(78));

    for r in &results {
        let log_n = (r.n as f64).ln();
        let gv_minus_1 = r.vt_gv - 1.0;
        let under_one = if r.vt_gv < 1.0 { "  ✅ <1" } else { "  ❌ ≥1" };
        println!("{:>6} {:>12.8} {:>12.6} {:>12.8} {:>12.6} {}",
                 r.n, r.vt_ev, r.vt_ev * log_n,
                 gv_minus_1, gv_minus_1 * log_n, under_one);
    }

    // ═══════════════════════════════════════════════
    // §3e. THE OVERCANCELLATION CHECK
    // ═══════════════════════════════════════════════

    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  §3e. OVERCANCELLATION: Is vᵀG_Vv < 1 at all tested N?");
    println!("═══════════════════════════════════════════════════════════════════\n");

    let mut all_under_one = true;
    let mut max_vgv = f64::NEG_INFINITY;
    let mut max_vgv_n = 0;

    for r in &results {
        if r.vt_gv >= 1.0 {
            all_under_one = false;
            println!("  ⚠️  N={}: vᵀG_Vv = {:.8} ≥ 1!", r.n, r.vt_gv);
        }
        if r.vt_gv > max_vgv {
            max_vgv = r.vt_gv;
            max_vgv_n = r.n;
        }
    }

    if all_under_one {
        println!("  ★ OVERCANCELLATION CONFIRMED: vᵀG_Vv < 1 for ALL tested N ★");
        println!("    Maximum: vᵀG_Vv = {:.8} at N={}", max_vgv, max_vgv_n);
    }

    // ═══════════════════════════════════════════════
    // §3f. THE SCALING LAWS
    // ═══════════════════════════════════════════════

    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  §3f. SCALING: How do the components behave?");
    println!("═══════════════════════════════════════════════════════════════════\n");

    println!("{:>6} {:>12} {:>12} {:>12} {:>12} {:>12}",
             "N", "Elog·lnN", "Ecot·lnN", "Econst·lnN", "ER·lnN", "Etot·lnN");
    println!("{}", "─".repeat(78));

    for r in &results {
        let log_n = (r.n as f64).ln();
        println!("{:>6} {:>12.6} {:>12.6} {:>12.6} {:>12.6} {:>12.6}",
                 r.n,
                 r.vt_ev_log * log_n,
                 r.vt_ev_cot * log_n,
                 r.vt_ev_const * log_n,
                 r.vt_ev_ram * log_n,
                 r.vt_ev * log_n);
    }

    // ═══════════════════════════════════════════════
    // §3g. RATIO ANALYSIS: vᵀEv / vᵀRv
    // ═══════════════════════════════════════════════

    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  §3g. RATIO: vᵀEv / vᵀRv — Is E proportional to R?");
    println!("═══════════════════════════════════════════════════════════════════\n");

    println!("{:>6} {:>12} {:>12} {:>12} {:>12}",
             "N", "vᵀEv", "vᵀRv", "E/R ratio", "E/G ratio");
    println!("{}", "─".repeat(56));

    for r in &results {
        let e_r_ratio = if r.vt_rv.abs() > 1e-15 { r.vt_ev / r.vt_rv } else { f64::NAN };
        let e_g_ratio = if r.vt_gv.abs() > 1e-15 { r.vt_ev / r.vt_gv } else { f64::NAN };
        println!("{:>6} {:>12.8} {:>12.8} {:>12.6} {:>12.6}",
                 r.n, r.vt_ev, r.vt_rv, e_r_ratio, e_g_ratio);
    }

    // ═══════════════════════════════════════════════
    // §3h. THE EULER CONVERGENCE: (1-vᵀGv)·lnN → e?
    // ═══════════════════════════════════════════════

    let euler_e = std::f64::consts::E;

    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  §3h. THE EULER CONVERGENCE: (1 - vᵀGv)·ln(N) → e?");
    println!("       e = {:.10}", euler_e);
    println!("═══════════════════════════════════════════════════════════════════\n");

    println!("{:>6} {:>12} {:>12} {:>12} {:>12} {:>12}",
             "N", "vᵀGv", "1-vᵀGv", "(1-Gv)·lnN", "gap from e", "gap·lnN");
    println!("{}", "─".repeat(78));

    for r in &results {
        let log_n = (r.n as f64).ln();
        let one_minus = 1.0 - r.vt_gv;
        let product = one_minus * log_n;
        let gap = product - euler_e;
        let gap_ln = gap * log_n;
        println!("{:>6} {:>12.8} {:>12.8} {:>12.6} {:>+12.6} {:>12.4}",
                 r.n, r.vt_gv, one_minus, product, gap, gap_ln);
    }

    // Subleading analysis
    println!("\n  Subleading: If (1-Gv)·lnN = e + C/lnN + ..., then C ≈ gap·lnN");
    println!("  Looking for gap·lnN to stabilize:");
    for r in &results {
        if r.n < 100 { continue; }
        let log_n = (r.n as f64).ln();
        let product = (1.0 - r.vt_gv) * log_n;
        let gap = product - euler_e;
        let c_est = gap * log_n;
        println!("    N={:>5}: C ≈ {:>+10.4}", r.n, c_est);
    }

    // ═══════════════════════════════════════════════
    // SUMMARY
    // ═══════════════════════════════════════════════

    println!("\n╔══════════════════════════════════════════════════════════════════╗");
    println!("║   X-RAY SUMMARY                                               ║");
    println!("╠══════════════════════════════════════════════════════════════════╣");

    if all_under_one {
        println!("║   ★ vᵀG_Vv < 1 at ALL tested N (overcancellation holds)      ║");
    } else {
        println!("║   ⚠️  vᵀG_Vv ≥ 1 at some N!                                  ║");
    }

    // Check convergence of (vᵀEv)·logN
    if results.len() >= 2 {
        let last = results.last().unwrap();
        let prev = &results[results.len() - 2];
        let log_last = (last.n as f64).ln();
        let log_prev = (prev.n as f64).ln();
        let c_last = last.vt_ev * log_last;
        let c_prev = prev.vt_ev * log_prev;
        let drift = (c_last - c_prev).abs();
        println!("║                                                                ║");
        if drift < 0.1 {
            println!("║   ★ (vᵀEv)·logN appears convergent ≈ {:.4}              ║", c_last);
        } else {
            println!("║   ⚠️  (vᵀEv)·logN still drifting: {:.4} → {:.4}          ║", c_prev, c_last);
        }
    }

    // Euler convergence summary
    if let Some(last) = results.last() {
        let log_n = (last.n as f64).ln();
        let euler_product = (1.0 - last.vt_gv) * log_n;
        let gap = (euler_product - euler_e).abs();
        println!("║                                                                ║");
        println!("║   Euler convergence at N={}:", last.n);
        println!("║     (1 - vᵀGv)·lnN = {:.6}  (e = {:.6})", euler_product, euler_e);
        println!("║     gap = {:.6} ({:.2}%)", gap, gap / euler_e * 100.0);
    }

    println!("║                                                                ║");
    println!("║   The Riemann Hypothesis lives inside E = G_V - R.            ║");
    println!("║   The bones of ζ are now visible. ★                           ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");
}
