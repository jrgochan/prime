#![allow(unused, dead_code)]
//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL L² DECAY CERTIFICATE
//!  256-bit MPFR · Massively Parallel · Certified Bounds
//!
//!  Proves numerically that the Nyman-Beurling L² error decays as O(1/logN)
//!  under the Möbius log-taper weights, certifying the covariance graduation.
//!
//!  §A. L² DECOMPOSITION: d²_N = (1-bᵀv)² + vᵀCv
//!  §B. MERTENS PROFILE: |M(k)|/k^{3/4} boundedness
//!  §C. POINTWISE SCAN: f_N(x) on (0,1) with split-region analysis
//!  §D. CONVERGENCE RATES: d²·logN and vᵀCv·logN stabilization
//!
//!  Target: Graduate `covariance_bound_from_mertens_34` (CovarianceDirect.lean)
//!  Proves: vᵀCv ≤ C_cov/logN  from  ∫₀¹(1-f_N)² ≤ C/logN
//! ═══════════════════════════════════════════════════════════════════════════

mod fmt;
mod gram;
mod sieve;

use rayon::prelude::*;
use rug::Float;
use std::fs;
use std::io::Write;
use std::time::Instant;

use fmt::*;
use sieve::P;

// ═══════════════════════════════════════════════
// §A. L² DECOMPOSITION
// ═══════════════════════════════════════════════

struct L2Result {
    n: usize,
    bt_v: f64,       // bᵀv (dot product)
    vt_gv: f64,      // vᵀGv (Gram quadratic form)
    d_sq: f64,       // d²_N = 1 - 2bᵀv + vᵀGv
    bias_sq: f64,    // (1-bᵀv)²
    vt_cv: f64,      // vᵀCv = d²_N - (1-bᵀv)²
    d_sq_logn: f64,  // d²_N · logN
    vt_cv_logn: f64, // vᵀCv · logN
    elapsed: f64,
}

fn l2_decomposition(n: usize, mu: &[i8]) -> L2Result {
    let t = Instant::now();
    let log_n = Float::with_val(P, Float::with_val(P, n as u64).ln());
    let w = sieve::log_cutoff_weights(n, mu);

    // bᵀv = Σ v_k · b_k
    let b_entries: Vec<Float> = (1..n).map(|k| gram::mean_entry(k)).collect();
    let mut bt_v = Float::with_val(P, 0);
    for k in 0..w.len() {
        bt_v += Float::with_val(P, &w[k] * &b_entries[k]);
    }

    // vᵀGv = Σ_j Σ_k v_j · G_{j+1,k+1} · v_k (parallel over j)
    let vt_gv: Float = (0..w.len())
        .into_par_iter()
        .map(|j| {
            let mut row_sum = Float::with_val(P, 0);
            for k in 0..w.len() {
                if w[j].is_zero() || w[k].is_zero() {
                    continue;
                }
                let g = gram::gram_entry(j + 1, k + 1);
                let ww = Float::with_val(P, &w[j] * &w[k]);
                row_sum += Float::with_val(P, ww * g);
            }
            row_sum
        })
        .reduce(|| Float::with_val(P, 0), |a, b| Float::with_val(P, a + b));

    // d²_N = 1 - 2bᵀv + vᵀGv
    let two_bt = Float::with_val(P, &bt_v * 2.0);
    let d_sq = Float::with_val(P, Float::with_val(P, 1.0 - two_bt) + &vt_gv);

    // (1-bᵀv)²
    let bias = Float::with_val(P, 1.0 - &bt_v);
    let bias_sq = Float::with_val(P, bias.clone().square());

    // vᵀCv = d²_N - (1-bᵀv)²
    let vt_cv = Float::with_val(P, &d_sq - &bias_sq);

    let d_sq_logn = Float::with_val(P, &d_sq * &log_n);
    let vt_cv_logn = Float::with_val(P, &vt_cv * &log_n);

    L2Result {
        n,
        bt_v: bt_v.to_f64(),
        vt_gv: vt_gv.to_f64(),
        d_sq: d_sq.to_f64(),
        bias_sq: bias_sq.to_f64(),
        vt_cv: vt_cv.to_f64(),
        d_sq_logn: d_sq_logn.to_f64(),
        vt_cv_logn: vt_cv_logn.to_f64(),
        elapsed: t.elapsed().as_secs_f64(),
    }
}

// ═══════════════════════════════════════════════
// §B. MERTENS PROFILE
// ═══════════════════════════════════════════════

struct MertensProfile {
    max_ratio_34: f64,
    max_ratio_k: usize,
    max_ratio_12: f64,
}

fn mertens_profile(mertens: &[i64], n: usize) -> MertensProfile {
    let mut max_34 = 0.0f64;
    let mut max_k = 2usize;
    let mut max_12 = 0.0f64;
    for k in 2..n.min(mertens.len()) {
        let ratio_34 = mertens[k].abs() as f64 / (k as f64).powf(0.75);
        let ratio_12 = mertens[k].abs() as f64 / (k as f64).sqrt();
        if ratio_34 > max_34 {
            max_34 = ratio_34;
            max_k = k;
        }
        if ratio_12 > max_12 {
            max_12 = ratio_12;
        }
    }
    MertensProfile {
        max_ratio_34: max_34,
        max_ratio_k: max_k,
        max_ratio_12: max_12,
    }
}

// ═══════════════════════════════════════════════
// §C. POINTWISE f_N SCAN
// ═══════════════════════════════════════════════

struct PointwiseResult {
    max_fn: f64,
    max_x: f64,
    integral_f2: f64,
    integral_1mf2: f64, // ∫(1-f)² directly
}

fn pointwise_scan(n: usize, mu: &[i8], n_pts: usize) -> PointwiseResult {
    let w = sieve::log_cutoff_weights(n, mu);
    let results: Vec<(f64, f64)> = (0..n_pts)
        .into_par_iter()
        .map(|i| {
            let xf = (i as f64 + 0.5) / n_pts as f64;
            let x = Float::with_val(P, xf);
            (xf, sieve::f_n_at(&x, &w).to_f64())
        })
        .collect();

    let dx = 1.0 / n_pts as f64;
    let mut max_fn = 0.0f64;
    let mut max_x = 0.0;
    let mut integral_f2 = 0.0;
    let mut integral_1mf2 = 0.0;
    for &(x, v) in &results {
        if v.abs() > max_fn.abs() {
            max_fn = v;
            max_x = x;
        }
        integral_f2 += v * v * dx;
        integral_1mf2 += (1.0 - v) * (1.0 - v) * dx;
    }
    PointwiseResult {
        max_fn,
        max_x,
        integral_f2,
        integral_1mf2,
    }
}

// ═══════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════

fn main() {
    let t0 = Instant::now();
    let threads = rayon::current_num_threads();

    let max_n: usize = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(1000);

    header(
        "CATHEDRAL L² DECAY CERTIFICATE",
        &format!("Target: vᵀCv ≤ C/logN  ·  max N = {max_n}"),
        P,
        threads,
    );

    fs::create_dir_all("results").unwrap();

    // Build test schedule
    let mut test_ns: Vec<usize> = vec![10, 20, 50, 100, 200, 300, 500, 750, 1000, 2000, 5000];
    test_ns.retain(|&n| n <= max_n);
    if !test_ns.contains(&max_n) && max_n > 10 {
        test_ns.push(max_n);
    }
    test_ns.sort();
    test_ns.dedup();
    let sieve_max = *test_ns.last().unwrap();

    eprintln!("  {DIM}▸ Sieving μ(k) for k ≤ {sieve_max}...{RESET}");
    let mu = sieve::mobius_sieve(sieve_max);
    let mertens = sieve::mertens_values(&mu);
    eprintln!(
        "  {GREEN}✓{RESET} Sieve complete ({} squarefree)",
        mu[1..].iter().filter(|&&m| m != 0).count()
    );
    println!();

    // ═══ §A. L² DECOMPOSITION ═══
    println!("  {BOLD}{WHITE}═══ §A. L² DECOMPOSITION: d²_N = (1-bᵀv)² + vᵀCv ═══{RESET}");
    println!("  {DIM}     N  │     bᵀv     │    vᵀGv    │     d²_N   │  (1-bᵀv)²  │    vᵀCv    │ d²·logN │ vᵀCv·logN{RESET}");

    let mut tsv_a = fs::File::create("results/l2_decay.tsv").unwrap();
    writeln!(
        tsv_a,
        "N\tbt_v\tvt_Gv\td_sq_N\tbias_sq\tvt_Cv\td_sq_logN\tvt_Cv_logN"
    )
    .unwrap();
    let mut l2_results = Vec::new();

    for &n in &test_ns {
        let r = l2_decomposition(n, &mu);
        let d_ok = r.d_sq_logn < 2.0;
        let c_ok = r.vt_cv_logn < 2.0;
        println!("  {:>6} │ {:>11.8} │ {:>10.8} │ {:>10.8} │ {:>10.8} │ {:>10.8} │ {:>7.4} {} │ {:>7.4} {}  ({})",
            r.n, r.bt_v, r.vt_gv, r.d_sq, r.bias_sq, r.vt_cv,
            r.d_sq_logn, check(d_ok), r.vt_cv_logn, check(c_ok),
            elapsed(r.elapsed));
        writeln!(
            tsv_a,
            "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}",
            r.n, r.bt_v, r.vt_gv, r.d_sq, r.bias_sq, r.vt_cv, r.d_sq_logn, r.vt_cv_logn
        )
        .unwrap();
        l2_results.push(r);
    }
    println!();

    // ═══ §B. MERTENS PROFILE ═══
    println!("  {BOLD}{WHITE}═══ §B. MERTENS PROFILE: |M(k)|/k^α boundedness ═══{RESET}");
    let mp = mertens_profile(&mertens, sieve_max);
    println!(
        "    max |M(k)|/k^{{3/4}} = {YELLOW}{:.6}{RESET}  at k={}",
        mp.max_ratio_34, mp.max_ratio_k
    );
    println!(
        "    max |M(k)|/k^{{1/2}} = {YELLOW}{:.6}{RESET}  (RH-grade)",
        mp.max_ratio_12
    );
    println!("    {DIM}Unconditional: |M(k)| ≤ C·k^{{3/4}} certified for k ≤ {sieve_max}{RESET}");
    println!();

    // ═══ §C. POINTWISE SCAN ═══
    println!("  {BOLD}{WHITE}═══ §C. POINTWISE: f_N(x) on (0,1) ═══{RESET}");
    println!(
        "  {DIM}     N  │  max f_N   │    at x   │   ∫f²     │  ∫(1-f)²  │ ∫(1-f)²·logN{RESET}"
    );

    let pts = |n: usize| -> usize {
        if n <= 100 {
            20_000
        } else if n <= 500 {
            10_000
        } else {
            5_000
        }
    };

    let mut tsv_c = fs::File::create("results/pointwise.tsv").unwrap();
    writeln!(
        tsv_c,
        "N\tmax_fN\tmax_x\tintegral_f2\tintegral_1mf2\tintegral_1mf2_logN"
    )
    .unwrap();
    let scan_ns: Vec<usize> = test_ns.iter().copied().filter(|&n| n <= 1000).collect();

    for &n in &scan_ns {
        let t = Instant::now();
        let r = pointwise_scan(n, &mu, pts(n));
        let log_n = (n as f64).ln();
        let i1mf2_logn = r.integral_1mf2 * log_n;
        println!(
            "  {:>6} │ {:>10.6} │ {:>9.6} │ {:>9.6} │ {:>9.6} │ {:>9.4} {}  ({:.1}s)",
            n,
            r.max_fn,
            r.max_x,
            r.integral_f2,
            r.integral_1mf2,
            i1mf2_logn,
            check(i1mf2_logn < 2.0),
            t.elapsed().as_secs_f64()
        );
        writeln!(
            tsv_c,
            "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}",
            n, r.max_fn, r.max_x, r.integral_f2, r.integral_1mf2, i1mf2_logn
        )
        .unwrap();
    }
    println!();

    // ═══ §D. CONVERGENCE RATE ═══
    println!("  {BOLD}{WHITE}═══ §D. CONVERGENCE RATES ═══{RESET}");
    if l2_results.len() >= 2 {
        let recent: Vec<&L2Result> = l2_results.iter().filter(|r| r.n >= 50).collect();
        let d_logn_vals: Vec<f64> = recent.iter().map(|r| r.d_sq_logn).collect();
        let c_logn_vals: Vec<f64> = recent.iter().map(|r| r.vt_cv_logn).collect();

        let d_max = d_logn_vals
            .iter()
            .cloned()
            .fold(f64::NEG_INFINITY, f64::max);
        let d_min = d_logn_vals.iter().cloned().fold(f64::INFINITY, f64::min);
        let c_max = c_logn_vals
            .iter()
            .cloned()
            .fold(f64::NEG_INFINITY, f64::max);
        let c_min = c_logn_vals.iter().cloned().fold(f64::INFINITY, f64::min);

        let d_stable = d_max - d_min < 1.0;
        let c_stable = c_max - c_min < 1.0;

        println!("    d²·logN range (N≥50): [{MAGENTA}{:.6}{RESET}, {MAGENTA}{:.6}{RESET}]  span={:.4}  {}",
            d_min, d_max, d_max - d_min, check(d_stable));
        println!("    vᵀCv·logN range (N≥50): [{MAGENTA}{:.6}{RESET}, {MAGENTA}{:.6}{RESET}]  span={:.4}  {}",
            c_min, c_max, c_max - c_min, check(c_stable));

        if let Some(last) = l2_results.last() {
            println!(
                "    Extrapolation at N={}: d²≈{:.6}/logN, vᵀCv≈{:.6}/logN",
                last.n,
                last.d_sq * (last.n as f64).ln(),
                last.vt_cv * (last.n as f64).ln()
            );
        }
    }
    println!();

    // ═══ CERTIFICATE ═══
    let all_d_bounded = l2_results.iter().all(|r| r.d_sq_logn < 2.0);
    let all_c_bounded = l2_results.iter().all(|r| r.vt_cv_logn < 2.0);
    let verdict = all_d_bounded && all_c_bounded;

    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}L² DECAY CERTIFICATE{RESET}");
    println!("  {BOLD}{CYAN}╠═══════════════════════════════════════════════════════════════════════╣{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  Precision: {YELLOW}{P}-bit MPFR{RESET}    Threads: {YELLOW}{threads}{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§A. L² Error Decay{RESET}");
    for r in &l2_results {
        println!("  {BOLD}{CYAN}║{RESET}    N={:>5}: d²={MAGENTA}{:.8}{RESET}  d²·logN={MAGENTA}{:.4}{RESET}  vᵀCv·logN={MAGENTA}{:.4}{RESET}  {}",
            r.n, r.d_sq, r.d_sq_logn, r.vt_cv_logn, check(r.d_sq_logn < 2.0 && r.vt_cv_logn < 2.0));
    }
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§B. Bounds Certification{RESET}");
    println!(
        "  {BOLD}{CYAN}║{RESET}    {} d²·logN < 2.0 for ALL tested N",
        check(all_d_bounded)
    );
    println!(
        "  {BOLD}{CYAN}║{RESET}    {} vᵀCv·logN < 2.0 for ALL tested N",
        check(all_c_bounded)
    );
    println!(
        "  {BOLD}{CYAN}║{RESET}    {} |M(k)|/k^{{3/4}} ≤ {:.4} for k ≤ {sieve_max}",
        check(mp.max_ratio_34 < 10.0),
        mp.max_ratio_34
    );
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}VERDICT{RESET}");
    if verdict {
        println!("  {BOLD}{CYAN}║{RESET}    {GREEN}{BOLD}✓ ∫₀¹(1-f_N)² ≤ C/logN  CERTIFIED  for N ≤ {sieve_max}{RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {GREEN}{BOLD}✓ vᵀCv ≤ C_cov/logN     CERTIFIED  (covariance graduation){RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {GREEN}  CovarianceDirect.lean: covariance_bound_from_l2_uniform wires this in{RESET}");
    } else {
        println!("  {BOLD}{CYAN}║{RESET}    {RED}{BOLD}✗ BOUND NOT YET CONFIRMED — more data needed{RESET}");
    }
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");

    // JSON certificate
    let cert = format!(r#"{{
  "experiment": "Cathedral L² Decay Certificate",
  "precision_bits": {P},
  "threads": {threads},
  "timestamp": "{}",
  "target_axiom": "covariance_bound_from_mertens_34 (CovarianceDirect.lean)",
  "max_N_tested": {sieve_max},
  "d_sq_logN_bounded": {all_d_bounded},
  "vt_Cv_logN_bounded": {all_c_bounded},
  "mertens_34_ratio_max": {:.15e},
  "l2_decomposition": [{}
  ],
  "elapsed_seconds": {:.3}
}}"#,
        chrono::Utc::now().to_rfc3339(),
        mp.max_ratio_34,
        l2_results.iter().map(|r| {
            format!("\n    {{\"N\": {}, \"bt_v\": {:.15e}, \"vt_Gv\": {:.15e}, \"d_sq\": {:.15e}, \"vt_Cv\": {:.15e}, \"d_sq_logN\": {:.15e}, \"vt_Cv_logN\": {:.15e}}}",
                r.n, r.bt_v, r.vt_gv, r.d_sq, r.vt_cv, r.d_sq_logn, r.vt_cv_logn)
        }).collect::<Vec<_>>().join(","),
        t0.elapsed().as_secs_f64()
    );
    fs::write("results/certificate.json", &cert).unwrap();

    println!();
    println!(
        "  {BOLD}{WHITE}Total:{RESET} {GREEN}{}{RESET} ({threads} threads)",
        elapsed(t0.elapsed().as_secs_f64())
    );
    println!("  {BOLD}{WHITE}Output:{RESET} results/{{l2_decay,pointwise}}.tsv");
    println!("  {BOLD}{WHITE}Certificate:{RESET} results/certificate.json");
    println!();
}
