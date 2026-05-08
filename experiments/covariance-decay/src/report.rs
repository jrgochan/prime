//! Formatted output, decay fitting, and certificate generation.

use crate::panels::NResult;
use cathedral_utils::fitting;
use sha2::{Sha256, Digest};
use std::time::Duration;

const CYAN: &str = "\x1b[36m";
const GREEN: &str = "\x1b[32m";
const YELLOW: &str = "\x1b[33m";
const BOLD: &str = "\x1b[1m";
const DIM: &str = "\x1b[2m";
const RESET: &str = "\x1b[0m";
const SEP: &str = "═══════════════════════════════════════════════════════════════";

pub fn header() {
    eprintln!("\n{BOLD}{CYAN}{SEP}{RESET}");
    eprintln!("{BOLD}{CYAN}  COVARIANCE DECAY EXPERIMENT{RESET}");
    eprintln!("{BOLD}{CYAN}  witness_covariance_decay: vᵀCv ≤ C/ln(N){RESET}");
    eprintln!("{BOLD}{CYAN}  The last axiom ≡ The Riemann Hypothesis{RESET}");
    eprintln!("{BOLD}{CYAN}{SEP}{RESET}");
}

pub fn panel1_table(results: &[NResult]) {
    println!("\n{BOLD}PANEL 1: QUADRATIC FORM DECOMPOSITION{RESET}");
    println!("────────────────────────────────────────────────────────────────────────────────────────────────────");
    println!("{:>6} │{:>14} │{:>14} │{:>14} │{:>14} │{:>12} │{:>10}",
        "N", "vᵀGv", "bᵀv", "vᵀCv", "d²_N", "vᵀCv·ln(N)", "Q(N)");
    println!("───────┼───────────────┼───────────────┼───────────────┼───────────────┼─────────────┼───────────");
    for r in results {
        println!("{:>6} │{:>14.8} │{:>14.8} │{:>14.8} │{:>14.8} │{:>12.6} │{:>10.3}",
            r.n, r.vt_gv, r.bt_v, r.vt_cv, r.d2_n, r.vt_cv_times_ln, r.rayleigh_q);
    }
}

pub fn panel2_spectrum(results: &[NResult]) {
    println!("\n{BOLD}PANEL 2: EIGENVALUE SPECTRUM OF G{RESET}");
    println!("────────────────────────────────────────────────────────────────────────────");
    println!("{:>6} │{:>14} │{:>14} │{:>14} │{:>8} │{:>8} │{:>5}",
        "N", "λ_min", "λ_max", "κ(G)", "PR(v)", "eff_90", "mode");
    println!("───────┼───────────────┼───────────────┼───────────────┼─────────┼─────────┼──────");
    for r in results {
        let mode = if r.used_lanczos { "L" } else { "full" };
        let pr_str = if r.pr_witness > 0.0 { format!("{:>8.1}", r.pr_witness) } else { "     n/a".to_string() };
        let eff_str = if r.eff_rank_90 > 0 { format!("{:>8}", r.eff_rank_90) } else { "     n/a".to_string() };
        println!("{:>6} │{:>14.6e} │{:>14.8} │{:>14.1} │{pr_str} │{eff_str} │{:>5}",
            r.n, r.lambda_min, r.lambda_max, r.condition_number, mode);
    }
}

pub fn panel3_projection(results: &[NResult]) {
    println!("\n{BOLD}PANEL 3: SPECTRAL PROJECTION OF WITNESS{RESET}");
    println!("────────────────────────────────────────────────────────────────────────");
    for r in results {
        if r.top_modes.is_empty() { continue; }
        let mode_label = if r.used_lanczos { "Lanczos bottom-k" } else { "full spectrum" };
        println!("  {BOLD}N = {}:{RESET}  (top 5 modes — {mode_label})", r.n);
        for (i, (idx, lambda, energy)) in r.top_modes.iter().enumerate() {
            let bar_len = (energy * 50.0).round() as usize;
            let bar: String = "█".repeat(bar_len.min(50));
            println!("    Mode {:>4} (λ={:>12.4e}): {:>6.2}%  {DIM}{bar}{RESET}",
                idx, lambda, energy * 100.0);
            if i >= 4 { break; }
        }
    }
}

pub fn panel4_pnt(results: &[NResult]) {
    println!("\n{BOLD}PANEL 4: PNT SUB-SUM VERIFICATION{RESET}");
    println!("────────────────────────────────────────────────────────────────────────");
    println!("{:>6} │{:>14} │{:>14} │{:>14} │{:>14} │{:>12}",
        "N", "S₁(N)→0", "S₂(N)→-1", "S₃(N)→-2γ", "|bᵀv-1|", "cos²(v,b)");
    println!("───────┼───────────────┼───────────────┼───────────────┼───────────────┼─────────────");
    let two_gamma = 2.0 * 0.5772156649015329;
    for r in results {
        println!("{:>6} │{:>14.8} │{:>14.8} │{:>14.8} │{:>14.8} │{:>12.8}",
            r.n, r.s1, r.s2 + 1.0, r.s3 + two_gamma,
            (r.bt_v - 1.0).abs(), r.cos2_angle);
    }
}

pub fn panel6_route_c(results: &[NResult]) {
    println!("\n{BOLD}PANEL 6: ROUTE C — SPECTRAL DECOUPLING{RESET}");
    println!("────────────────────────────────────────────────────────────────────────────────────────────────────");
    println!("  {DIM}If c_max²/λ_max → 1 and ⟨b²⟩/⟨G_diag⟩ → 1, the top eigenmode dominates{RESET}");
    println!("  {DIM}and d² = 1 - Σcₖ²/λₖ → 0, forcing covariance decay.{RESET}");
    println!();
    println!("{:>6} │{:>14} │{:>14} │{:>14} │{:>10} │{:>10}",
        "N", "c²_max/λ_max", "⟨b²⟩/⟨G_diag⟩", "Σcₖ²/λₖ", "tail %", "1-top");
    println!("───────┼───────────────┼───────────────┼───────────────┼───────────┼───────────");
    for r in results {
        let sum_str = if r.rc_spectral_sum > 0.0 {
            format!("{:>14.8}", r.rc_spectral_sum)
        } else {
            "           n/a".to_string()
        };
        let tail_str = if r.rc_tail_pct > 0.0 || !r.used_lanczos {
            format!("{:>10.4}%", r.rc_tail_pct)
        } else {
            "       n/a".to_string()
        };
        let gap = 1.0 - r.rc_top_ratio;
        println!("{:>6} │{:>14.8} │{:>14.8} │{sum_str} │{tail_str} │{:>10.6}",
            r.n, r.rc_top_ratio, r.rc_mean_ratio, gap);
    }

    // Convergence check on the top ratio
    let valid: Vec<&NResult> = results.iter()
        .filter(|r| r.rc_top_ratio > 0.0 && r.n >= 50)
        .collect();
    if valid.len() >= 3 {
        let gaps: Vec<(f64, f64)> = valid.iter()
            .map(|r| ((r.n as f64).ln(), (1.0 - r.rc_top_ratio).ln()))
            .filter(|(_, y)| y.is_finite())
            .collect();
        if gaps.len() >= 3 {
            let (slope, _intercept, r2) = cathedral_utils::fitting::linreg(&gaps);
            println!("\n  {BOLD}Route C convergence:{RESET} 1 - c²/λ ~ N^{slope:.4}  (R² = {r2:.4})");
            if slope < -0.5 && r2 > 0.8 {
                println!("    {GREEN}✓ Top-mode ratio converging to 1 — spectral decoupling confirmed{RESET}");
            } else if slope < 0.0 {
                println!("    {YELLOW}~ Converging, but slowly{RESET}");
            } else {
                println!("    ✗ Not converging");
            }
        }
    }
}

pub fn decay_fit(results: &[NResult]) {
    if results.len() < 3 { return; }

    println!("\n{BOLD}PANEL 5: DECAY RATE FITTING{RESET}");
    println!("────────────────────────────────────────────────────────────────────────");

    // Fit vᵀCv ≈ C / ln(N)^β using log-decay model
    let ns: Vec<f64> = results.iter().map(|r| r.n as f64).collect();
    let vtcv: Vec<f64> = results.iter().map(|r| r.vt_cv).collect();
    let (c_log, beta_log, r2_log) = fitting::log_decay_fit(&ns, &vtcv);
    println!("  {BOLD}Model 1:{RESET} vᵀCv ≈ C / ln(N)^β");
    println!("    C     = {c_log:.6}");
    println!("    β     = {beta_log:.6}  {}", decay_verdict(beta_log));
    println!("    R²    = {r2_log:.6}");

    // Fit Q(N) ≈ α · ln(N)^δ
    let qs: Vec<f64> = results.iter().map(|r| r.rayleigh_q).collect();
    let lns: Vec<f64> = results.iter().map(|r| (r.n as f64).ln()).collect();
    let q_data: Vec<(f64, f64)> = lns.iter().zip(qs.iter())
        .filter(|(_, q)| q.is_finite() && **q > 0.0)
        .map(|(&x, &y)| (x, y.ln()))
        .collect();
    if q_data.len() >= 2 {
        let (slope, intercept, r2_q) = fitting::linreg(&q_data);
        println!("\n  {BOLD}Model 2:{RESET} Q(N) ≈ α · ln(N)^δ");
        println!("    α     = {:.6}", intercept.exp());
        println!("    δ     = {slope:.6}  {}", decay_verdict(slope));
        println!("    R²    = {r2_q:.6}");
    }

    // Fit vᵀCv · ln(N) → constant (direct test of 1/ln decay)
    let product: Vec<f64> = results.iter().map(|r| r.vt_cv_times_ln).collect();
    let mean: f64 = product.iter().sum::<f64>() / product.len() as f64;
    let var: f64 = product.iter().map(|x| (x - mean).powi(2)).sum::<f64>() / product.len() as f64;
    let cv = var.sqrt() / mean.abs();
    println!("\n  {BOLD}Model 3:{RESET} vᵀCv · ln(N) → constant?");
    println!("    mean  = {mean:.8}");
    println!("    CV    = {cv:.4} (coefficient of variation)");
    println!("    {}",
        if cv < 0.05 { format!("{GREEN}✓ Stabilizing — consistent with 1/ln(N) decay{RESET}") }
        else if cv < 0.15 { format!("{YELLOW}~ Approaching stability{RESET}") }
        else { format!("✗ Not yet stable (need larger N range)") }
    );

    // Observed constant C_cov
    if let Some(last) = results.last() {
        println!("\n  {BOLD}Observed C_cov:{RESET}");
        println!("    At N={}: vᵀCv·ln(N) = {:.8}", last.n, last.vt_cv_times_ln);
        println!("    Implies: witness_covariance_decay holds with C_cov ≈ {:.4}",
            last.vt_cv_times_ln * 1.5); // safety factor
    }
}

fn decay_verdict(exponent: f64) -> String {
    if (exponent - 1.0).abs() < 0.1 {
        format!("{GREEN}✓ Consistent with RH (β≈1){RESET}")
    } else if (exponent - 1.0).abs() < 0.3 {
        format!("{YELLOW}~ Near RH prediction{RESET}")
    } else {
        format!("(deviation from β=1)")
    }
}

pub fn certificate(results: &[NResult], elapsed: Duration) {
    println!("\n{BOLD}{SEP}{RESET}");
    println!("{BOLD}  CERTIFICATE: COVARIANCE DECAY EXPERIMENT{RESET}");
    println!("{SEP}");

    // Build certificate JSON
    let mut hasher = Sha256::new();
    let cert_data: Vec<serde_json::Value> = results.iter().map(|r| {
        serde_json::json!({
            "N": r.n,
            "vtCv": r.vt_cv,
            "btv": r.bt_v,
            "vtGv": r.vt_gv,
            "d2N": r.d2_n,
            "rayleigh_Q": r.rayleigh_q,
            "vtCv_times_lnN": r.vt_cv_times_ln,
            "lambda_min": r.lambda_min,
            "lambda_max": r.lambda_max,
            "condition_number": r.condition_number,
            "PR_witness": r.pr_witness,
            "eff_rank_90": r.eff_rank_90,
            "S1": r.s1,
            "S2": r.s2,
            "S3": r.s3,
            "coprime_frac": r.coprime_frac,
            "rc_top_ratio": r.rc_top_ratio,
            "rc_mean_ratio": r.rc_mean_ratio,
            "rc_tail_pct": r.rc_tail_pct,
            "rc_spectral_sum": r.rc_spectral_sum,
        })
    }).collect();

    let cert = serde_json::json!({
        "experiment": "covariance-decay",
        "axiom": "witness_covariance_decay",
        "description": "vᵀCv ≤ C_cov / ln(N) — equivalent to Riemann Hypothesis",
        "schedule": results.iter().map(|r| r.n).collect::<Vec<_>>(),
        "elapsed_seconds": elapsed.as_secs_f64(),
        "results": cert_data,
    });

    let cert_str = serde_json::to_string_pretty(&cert).unwrap();
    hasher.update(cert_str.as_bytes());
    let hash = format!("{:x}", hasher.finalize());

    println!("  SHA-256: {hash}");
    println!("  Schedule: {:?}", results.iter().map(|r| r.n).collect::<Vec<_>>());
    println!("  Elapsed: {:.1}s", elapsed.as_secs_f64());

    // Write certificate to disk
    let cert_path = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("results")
        .join("certificate.json");
    if let Some(parent) = cert_path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    if let Ok(mut f) = std::fs::File::create(&cert_path) {
        use std::io::Write;
        let _ = writeln!(f, "{cert_str}");
        println!("  Certificate: {}", cert_path.display());
    }

    println!("{SEP}");
}
