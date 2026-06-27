#![allow(dead_code, unused_variables, unused_imports, unused_assignments, clippy::needless_range_loop, clippy::doc_lazy_continuation, non_snake_case, clippy::empty_line_after_doc_comments)]
// overcancellation-scan/src/bin/cotangent_bound_probe.rs
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║  COTANGENT BOUND PROBE — The Gap Chase                          ║
// ║                                                                   ║
// ║  Decomposes the Gram entry G(j,k) into four terms:               ║
// ║    term1 = (C/2)(1/j + 1/k)          [log → CσS]               ║
// ║    term2 = (j-k)/(2jk)·ln(k/j)       [log correction]          ║
// ║    term3 = −πd/(2jk)·(V+V)           [dissolved cotangent]      ║
// ║    term4 = −1/(jk)                    [constant → −S²]          ║
// ║                                                                   ║
// ║  Computes column sums of |term2 + term3| for Gershgorin.         ║
// ║  Target: max column sum < 2/3                                    ║
// ╚═══════════════════════════════════════════════════════════════════╝

use cathedral_utils::arith::{gcd, mobius_table};
use std::f64::consts::PI;

const EULER_GAMMA: f64 = 0.5772156649015329;

/// C = ln(2π) − γ
fn vasyunin_const() -> f64 {
    (2.0 * PI).ln() - EULER_GAMMA
}

/// Dedekind sum s(h, k) computed directly
fn dedekind_sum(h: usize, k: usize) -> f64 {
    if k <= 1 {
        return 0.0;
    }
    let mut s = 0.0;
    for r in 1..k {
        let x = r as f64 / k as f64;
        let hx = (h * r) as f64 / k as f64;
        // ((x)) = x - floor(x) - 1/2 if x not integer, else 0
        let sawtooth_x = x - x.floor() - 0.5;
        let sawtooth_hx = hx - hx.floor() - 0.5;
        s += sawtooth_x * sawtooth_hx;
    }
    s
}

/// Vasyunin sum V(a, b) = Σ_{m=1}^{a-1} cot(πm/a) · {mb/a}
fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 {
        return 0.0;
    }
    let mut s = 0.0;
    for m in 1..a {
        let cot_val = 1.0 / (PI * m as f64 / a as f64).tan();
        let frac = ((m * b) as f64 / a as f64).fract();
        s += cot_val * frac;
    }
    s
}

/// Dissolved cotangent: V(j',k') + V(k',j') using Dedekind reciprocity
/// Should equal −(j'²+k'²+1)/(6j'k') + 1/2
fn dissolved_vasyunin(jp: usize, kp: usize) -> f64 {
    let jpf = jp as f64;
    let kpf = kp as f64;
    -(jpf * jpf + kpf * kpf + 1.0) / (6.0 * jpf * kpf) + 0.5
}

/// Full Gram entry G(j,k) for j ≠ k
fn gram_entry(j: usize, k: usize) -> f64 {
    let c = vasyunin_const();
    let jf = j as f64;
    let kf = k as f64;
    let d = gcd(j, k);
    let jp = j / d;
    let kp = k / d;
    let df = d as f64;

    let term1 = c / 2.0 * (1.0 / jf + 1.0 / kf);
    let term2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
    let term3 = PI * df / (2.0 * jf * kf) * (vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp));
    let term4 = 1.0 / (jf * kf);

    term1 + term2 - term3 - term4
}

/// Diagonal Gram entry G(k,k)
fn gram_diag(k: usize) -> f64 {
    let c = vasyunin_const();
    let kf = k as f64;
    c / kf - 1.0 / (kf * kf)
}

/// Decompose G(j,k) into four terms (returns term1, term2, term3_raw, term4)
fn decompose(j: usize, k: usize) -> (f64, f64, f64, f64) {
    let c = vasyunin_const();
    let jf = j as f64;
    let kf = k as f64;
    let d = gcd(j, k);
    let jp = j / d;
    let kp = k / d;
    let df = d as f64;

    let term1 = c / 2.0 * (1.0 / jf + 1.0 / kf);
    let term2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
    // term3 = πd/(2jk) · (V(j',k') + V(k',j'))
    // We use direct computation, not dissolved formula
    let v_sum = vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp);
    let term3 = PI * df / (2.0 * jf * kf) * v_sum;
    let term4 = 1.0 / (jf * kf);

    (term1, term2, term3, term4)
}

/// BD witness weight: v(k) = -μ(k) · w(k,N) where w = 1 - ln(k)/ln(N)
fn log_weight(k: usize, n: usize) -> f64 {
    if k >= n { return 0.0; }
    1.0 - (k as f64).ln() / (n as f64).ln()
}

fn main() {
    println!("╔═══════════════════════════════════════════════════════════════╗");
    println!("║  COTANGENT BOUND PROBE — The Gap Chase                      ║");
    println!("╚═══════════════════════════════════════════════════════════════╝");
    println!();

    let c = vasyunin_const();
    println!("C = ln(2π) − γ = {:.6}", c);
    println!("1/3 + C = {:.6}", 1.0/3.0 + c);
    println!("C − 2/3 = {:.6}", c - 2.0/3.0);
    println!();

    // ═══════════════════════════════════════════════════
    // SECTION 1: Verify Dedekind dissolution formula
    // ═══════════════════════════════════════════════════
    println!("═══ SECTION 1: Dedekind Dissolution Verification ═══");
    println!("{:>5} {:>5} {:>12} {:>12} {:>12}", "j'", "k'", "V+V (direct)", "dissolved", "error");
    for jp in 1..=8 {
        for kp in (jp+1)..=8 {
            if gcd(jp, kp) != 1 { continue; }
            let v_direct = vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp);
            let v_dissolved = dissolved_vasyunin(jp, kp);
            let err = (v_direct - v_dissolved).abs();
            println!("{:5} {:5} {:12.6} {:12.6} {:12.2e}", jp, kp, v_direct, v_dissolved, err);
        }
    }
    println!();

    // ═══════════════════════════════════════════════════
    // SECTION 2: Column sums of |term2 + term3| (Gershgorin)
    // ═══════════════════════════════════════════════════
    println!("═══ SECTION 2: Column Sums (Gershgorin Analysis) ═══");
    println!("For column j: Σ_{{k≠j}} |G(j,k) − term1(j,k) + term4(j,k)|");
    println!("            = Σ_{{k≠j}} |term2(j,k) − term3(j,k)|");
    println!();

    let n_max = 200;
    println!("  Column sums up to N = {}:", n_max);
    println!("{:>5} {:>12} {:>12} {:>12} {:>12}", "j", "Σ|term2-t3|", "Σ|term2|", "Σ|term3|", "diag G(j,j)");

    let mut max_col_sum = 0.0f64;
    let mut max_col_j = 0;
    for j in 1..=20 {
        let mut sum_residual = 0.0;
        let mut sum_term2 = 0.0;
        let mut sum_term3 = 0.0;
        for k in 1..=n_max {
            if k == j { continue; }
            let (_, t2, t3, _) = decompose(j, k);
            sum_residual += (t2 - t3).abs();
            sum_term2 += t2.abs();
            sum_term3 += t3.abs();
        }
        let diag = gram_diag(j);
        println!("{:5} {:12.6} {:12.6} {:12.6} {:12.6}", j, sum_residual, sum_term2, sum_term3, diag);
        if sum_residual > max_col_sum {
            max_col_sum = sum_residual;
            max_col_j = j;
        }
    }
    println!();
    println!("  Max column sum: {:.6} at j = {}", max_col_sum, max_col_j);
    println!("  Target: < 2/3 = {:.6}", 2.0/3.0);
    println!("  Status: {}", if max_col_sum < 2.0/3.0 { "✅ WITHIN BOUND" } else { "❌ EXCEEDS BOUND" });
    println!();

    // ═══════════════════════════════════════════════════
    // SECTION 3: Full Gram form for BD witness
    // ═══════════════════════════════════════════════════
    println!("═══ SECTION 3: Full vᵀGv Decomposition for BD Witness ═══");

    for &n in &[30, 100, 300, 1000, 2520] {
        let mu = mobius_table(n + 1);

        // Build witness: v(k) = -μ(k) · w(k,N) for k = 1..N-1
        let size = n - 1;
        let mut v = vec![0.0f64; size];
        for k in 1..n {
            v[k-1] = -(mu[k] as f64) * log_weight(k, n);
        }

        // Compute vᵀGv decomposition
        let mut diag_sum = 0.0;
        let mut term1_sum = 0.0;
        let mut term2_sum = 0.0;
        let mut term3_sum = 0.0;
        let mut term4_sum = 0.0;
        let mut full_gram = 0.0;

        for j_idx in 0..size {
            let j = j_idx + 1;
            // Diagonal
            diag_sum += v[j_idx] * v[j_idx] * gram_diag(j);

            // Off-diagonal
            for k_idx in 0..size {
                let k = k_idx + 1;
                if k == j { continue; }
                let (t1, t2, t3, t4) = decompose(j, k);
                let vv = v[j_idx] * v[k_idx];
                term1_sum += vv * t1;
                term2_sum += vv * t2;
                term3_sum += vv * (-t3); // note: G = term1 + term2 - term3 - term4
                term4_sum += vv * (-t4);
                full_gram += vv * (t1 + t2 - t3 - t4);
            }
        }
        full_gram += diag_sum;

        let norm_sq: f64 = v.iter().map(|x| x * x).sum();
        let sigma: f64 = v.iter().sum();
        let s: f64 = v.iter().enumerate().map(|(i, vi)| vi / (i as f64 + 1.0)).sum();

        println!("  N = {:5}: vᵀGv = {:.6} | diag = {:.4} | term1(CσS) = {:.4} | term2(log) = {:.4} | -term3(cot) = {:.4} | -term4(-S²) = {:.4}",
            n, full_gram, diag_sum, term1_sum, term2_sum, term3_sum, term4_sum);
        println!("           ‖v‖² = {:.4} | σ = {:.6} | S = {:.6} | CσS = {:.6} | S² = {:.6}",
            norm_sq, sigma, s, c * sigma * s, s * s);
    }

    println!();

    // ═══════════════════════════════════════════════════
    // SECTION 4: What fraction is term2+term3?
    // ═══════════════════════════════════════════════════
    println!("═══ SECTION 4: Fraction Analysis ═══");
    println!("How much of vᵀGv comes from each component?");
    println!();

    for &n in &[100, 1000, 2520] {
        let mu = mobius_table(n + 1);
        let size = n - 1;
        let mut v = vec![0.0f64; size];
        for k in 1..n {
            v[k-1] = -(mu[k] as f64) * log_weight(k, n);
        }

        let mut diag_total = 0.0;
        let mut t1_total = 0.0;
        let mut t2_total = 0.0;
        let mut t3_total = 0.0;  // this is −term3 (cotangent contribution)
        let mut t4_total = 0.0;  // this is −term4 (= +S²)

        for j_idx in 0..size {
            let j = j_idx + 1;
            diag_total += v[j_idx] * v[j_idx] * gram_diag(j);
            for k_idx in 0..size {
                let k = k_idx + 1;
                if k == j { continue; }
                let (t1, t2, t3, t4) = decompose(j, k);
                let vv = v[j_idx] * v[k_idx];
                t1_total += vv * t1;
                t2_total += vv * t2;
                t3_total += vv * (-t3);
                t4_total += vv * (-t4);
            }
        }
        let full = diag_total + t1_total + t2_total + t3_total + t4_total;
        let norm_sq: f64 = v.iter().map(|x| x * x).sum();

        println!("  N = {:5}:  vᵀGv = {:.6}", n, full);
        println!("    diagonal:   {:+.6} ({:.1}% of ‖v‖²={:.4})",
            diag_total, 100.0 * diag_total / norm_sq, norm_sq);
        println!("    term1(CσS): {:+.6}", t1_total);
        println!("    term2(log): {:+.6}", t2_total);
        println!("    −term3(cot):{:+.6}  ← THE GAP", t3_total);
        println!("    −term4(S²): {:+.6}", t4_total);
        println!("    residual = term2 + (−term3) = {:+.6}", t2_total + t3_total);
        println!();
    }
}
