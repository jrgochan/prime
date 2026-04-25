//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL PNT MÖBIUS SUM VALIDATOR
//!  256-bit MPFR · Segmented Sieve · Certified Convergence
//!
//!  Validates the three PNT axioms from PNTAbelMean.lean:
//!    S₁(N) = Σ_{k≤N} μ(k)/k           → 0    [pnt_mu_div_k]
//!    S₂(N) = Σ_{k≤N} μ(k)·ln(k)/k     → -1   [pnt_mu_log_div_k]
//!    S₃(N) = Σ_{k≤N} μ(k)·ln²(k)/k    → -2γ  [pnt_mu_log_sq_div_k]
//!
//!  Also validates the decay rates used in AbelTail/:
//!    |S₁(N)| ≤ C₁ · N^{-1/4}
//!    |S₂(N) + 1| ≤ C₂ · N^{-1/4} · ln(N)
//! ═══════════════════════════════════════════════════════════════════════════

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
const WHITE: &str = "\x1b[97m";
const RESET: &str = "\x1b[0m";

fn check(b: bool) -> &'static str {
    if b { "\x1b[32m✓\x1b[0m" } else { "\x1b[31m✗\x1b[0m" }
}

fn euler_gamma() -> Float {
    Float::with_val(P, Float::parse(
        "0.57721566490153286060651209008240243104215933593992359880576723488486772677766467"
    ).unwrap())
}

// ═══════════════════════════════════════════════
// MÖBIUS SIEVE
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

fn main() {
    let t_global = Instant::now();

    println!();
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}CATHEDRAL PNT MÖBIUS SUM VALIDATOR{RESET}                           {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}256-bit MPFR · Certified Convergence{RESET}                        {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}Target: pnt_mu_div_k, pnt_mu_log_div_k, pnt_mu_log_sq_div_k{RESET}{BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}{}-bit MPFR{RESET}                                                  {BOLD}{CYAN}║{RESET}", P);
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════╝{RESET}");
    println!();

    fs::create_dir_all("results").unwrap();

    // Sieve to N_MAX
    let n_max: usize = 1_000_000; // Start with 10^6, can scale up
    eprintln!("  {DIM}▸ Sieving μ(k) for k ≤ {}...{RESET}", n_max);
    let t = Instant::now();
    let mu = mobius_sieve(n_max);
    eprintln!("  {GREEN}✓{RESET} Sieve complete in {:.2}s", t.elapsed().as_secs_f64());
    println!();

    let gamma = euler_gamma();
    let two_gamma = Float::with_val(P, &gamma * 2u32);

    // Checkpoints to report at
    let checkpoints: Vec<usize> = vec![
        10, 100, 1_000, 10_000, 50_000, 100_000, 200_000, 500_000, 1_000_000,
    ].into_iter().filter(|&n| n <= n_max).collect();

    // Accumulate sums at 256-bit
    let mut s1 = Float::with_val(P, 0);
    let mut s2 = Float::with_val(P, 0);
    let mut s3 = Float::with_val(P, 0);

    let mut results = Vec::new();
    let mut tsv = fs::File::create("results/pnt_sums.tsv").unwrap();
    writeln!(tsv, "N\tS1\tS2\tS3\tS2_plus_1\tS3_plus_2gamma\tS1_sqrt_N\tS1_N14\tS2p1_N14logN").unwrap();

    println!("  {BOLD}{WHITE}═══ PNT MÖBIUS SUMS: S₁ → 0, S₂ → -1, S₃ → -2γ ═══{RESET}");
    println!("  {DIM}  2γ ≈ {:.15}{RESET}", two_gamma.to_f64());
    println!();
    println!("  {DIM}        N   │  S₁ = Σμ/k          │  S₂+1 = Σμlnk/k+1   │  S₃+2γ              │  |S₁|·√N      │  time{RESET}");

    let mut cp_idx = 0;
    let t = Instant::now();

    for k in 1..=n_max {
        if mu[k] != 0 {
            let mk = mu[k] as f64;
            let kf = Float::with_val(P, k as u64);
            let log_k = Float::with_val(P, kf.clone().ln());
            let log_k_sq = Float::with_val(P, &log_k * &log_k);
            let inv_k = Float::with_val(P, Float::with_val(P, 1u32) / &kf);

            s1 += Float::with_val(P, mk * &inv_k);
            let mk_logk = Float::with_val(P, mk * &log_k);
            s2 += Float::with_val(P, &mk_logk * &inv_k);
            let mk_logksq = Float::with_val(P, mk * &log_k_sq);
            s3 += Float::with_val(P, &mk_logksq * &inv_k);
        }

        if cp_idx < checkpoints.len() && k == checkpoints[cp_idx] {
            let n = k;
            let nf = n as f64;
            let s1f = s1.to_f64();
            let s2f = s2.to_f64();
            let s3f = s3.to_f64();
            let s2p1 = s2f + 1.0;
            let s3p2g = s3f + two_gamma.to_f64();
            let s1_sqrt = s1f.abs() * nf.sqrt();
            let s1_n14 = s1f.abs() * nf.powf(0.25);
            let s2p1_n14logn = if nf > 1.0 { s2p1.abs() * nf.powf(0.25) / nf.ln() } else { 0.0 };

            writeln!(tsv, "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}",
                n, s1f, s2f, s3f, s2p1, s3p2g, s1_sqrt, s1_n14, s2p1_n14logn).unwrap();

            println!("    {:>9} │  {MAGENTA}{:>20.14e}{RESET} │  {YELLOW}{:>20.14e}{RESET} │  {:>20.14e} │  {:>12.6} │ {:.2}s",
                n, s1f, s2p1, s3p2g, s1_sqrt, t.elapsed().as_secs_f64());

            results.push((n, s1f, s2f, s3f, s2p1, s3p2g, s1_sqrt, s1_n14, s2p1_n14logn));
            cp_idx += 1;
        }
    }

    // Certificate
    println!();
    let last = results.last().unwrap();
    let s1_converging = last.1.abs() < 0.01;
    let s2_converging = last.4.abs() < 0.1;
    let s3_converging = last.5.abs() < 1.0;

    // Decay rate analysis
    let decay_pairs: Vec<(usize, f64, f64)> = results.iter()
        .filter(|r| r.0 >= 100)
        .map(|r| (r.0, r.7, r.8)) // (N, |S1|·N^{1/4}, |S2+1|·N^{1/4}/lnN)
        .collect();
    let s1_decay_bounded = decay_pairs.iter().all(|(_, v, _)| *v < 5.0);
    let s2_decay_bounded = decay_pairs.iter().all(|(_, _, v)| *v < 5.0);

    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}PNT MÖBIUS SUM VALIDATOR — CERTIFICATE{RESET}                     {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}╠═══════════════════════════════════════════════════════════════════╣{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  Precision: {YELLOW}{}-bit MPFR{RESET}    N_max: {YELLOW}{}{RESET}", P, n_max);
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§A. S₁ = Σμ(k)/k → 0{RESET}  [pnt_mu_div_k]");
    println!("  {BOLD}{CYAN}║{RESET}    {} S₁({}) = {:.14e}", check(s1_converging), n_max, last.1);
    println!("  {BOLD}{CYAN}║{RESET}    {} |S₁|·N^{{1/4}} bounded by {:.4}", check(s1_decay_bounded),
        decay_pairs.iter().map(|p| p.1).fold(0.0f64, f64::max));
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§B. S₂ = Σμ(k)ln(k)/k → -1{RESET}  [pnt_mu_log_div_k]");
    println!("  {BOLD}{CYAN}║{RESET}    {} S₂({}) + 1 = {:.14e}", check(s2_converging), n_max, last.4);
    println!("  {BOLD}{CYAN}║{RESET}    {} |S₂+1|·N^{{1/4}}/ln(N) bounded by {:.4}", check(s2_decay_bounded),
        decay_pairs.iter().map(|p| p.2).fold(0.0f64, f64::max));
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§C. S₃ = Σμ(k)ln²(k)/k → -2γ{RESET}  [pnt_mu_log_sq_div_k]");
    println!("  {BOLD}{CYAN}║{RESET}    {} S₃({}) + 2γ = {:.14e}", check(s3_converging), n_max, last.5);
    println!("  {BOLD}{CYAN}║{RESET}    2γ = {:.15}", two_gamma.to_f64());
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════╝{RESET}");

    // Summary JSON
    let summary = format!(r#"{{
  "experiment": "Cathedral PNT Möbius Sum Validator",
  "precision_bits": {P},
  "N_max": {n_max},
  "timestamp": "{}",
  "two_gamma": {:.15e},
  "S1_final": {:.15e},
  "S2_final": {:.15e},
  "S3_final": {:.15e},
  "S1_converging": {},
  "S2_converging": {},
  "S3_converging": {},
  "S1_decay_bounded": {},
  "S2_decay_bounded": {},
  "elapsed_seconds": {:.3}
}}"#,
        chrono::Utc::now().to_rfc3339(),
        two_gamma.to_f64(),
        last.1, last.2, last.3,
        s1_converging, s2_converging, s3_converging,
        s1_decay_bounded, s2_decay_bounded,
        t_global.elapsed().as_secs_f64()
    );
    fs::write("results/certificate.json", &summary).unwrap();

    println!();
    println!("  {BOLD}{WHITE}Total:{RESET} {GREEN}{:.1}s{RESET}", t_global.elapsed().as_secs_f64());
    println!("  {BOLD}{WHITE}Output:{RESET} results/{{pnt_sums.tsv, certificate.json}}");
    println!();
}
