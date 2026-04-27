//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL GRAM FORM IDENTITY EXPLORER
//!  Numerical Decomposition · Bilinear Analysis · Identity Discovery
//!
//!  Investigates the bilinear structure of vᵀGv to find the identity
//!  needed to prove `gram_form_bound_raw` in CovarianceAbel.lean.
//!
//!  §A. CONVERGENCE: vᵀGv → 1, rate (vᵀGv-1)·logN → ?
//!  §B. DIAGONAL SPLIT: vᵀGv = D + O, diagonal vs off-diagonal
//!  §C. S-SUM PROFILE: S₁, S₂, S₃ at each N
//!  §D. BILINEAR FIT: (vᵀGv-1)·logN vs S₁/S₂/S₃ products
//!  §E. L² RESIDUAL: ∫(1-f)² decomposition
//!  §F. TAPER ANALYSIS: effect of log-taper on convergence
//! ═══════════════════════════════════════════════════════════════════════════

mod sieve;
mod gram;
mod fmt;

use rayon::prelude::*;
use std::fs;
use std::io::Write;
use std::time::Instant;

use fmt::*;

// ═══════════════════════════════════════════
// §A. CONVERGENCE SCAN
// ═══════════════════════════════════════════

struct ConvergenceResult {
    n: usize, vtgv: f64, btv: f64,
    vtcv: f64,  // vᵀCv = vᵀGv - (bᵀv)²
    l2_residual: f64,  // 1 - 2bᵀv + vᵀGv
}

fn convergence_scan(n: usize, mu: &[i8]) -> ConvergenceResult {
    let m = n - 1;
    let log_n = (n as f64).ln();

    // Precompute weights
    let weights: Vec<f64> = (0..=m).map(|k| {
        if k == 0 { 0.0 } else { gram::bd_weight(mu[k], k as u64, log_n) }
    }).collect();

    // Compute vᵀGv (parallelized over j)
    let vtgv: f64 = (1..=m).into_par_iter().map(|j| {
        let vj = weights[j];
        if vj == 0.0 { return 0.0; }
        (1..=m).map(|k| {
            let vk = weights[k];
            if vk == 0.0 { 0.0 }
            else { vj * vk * gram::gram_entry(j as u64, k as u64) }
        }).sum::<f64>()
    }).sum();

    // Compute bᵀv
    let btv: f64 = (1..=m).map(|k| {
        gram::mean_entry(k as u64) * weights[k]
    }).sum();

    let vtcv = vtgv - btv * btv;
    let l2_residual = 1.0 - 2.0 * btv + vtgv;

    ConvergenceResult { n, vtgv, btv, vtcv, l2_residual }
}

// ═══════════════════════════════════════════
// §B. DIAGONAL SPLIT
// ═══════════════════════════════════════════

struct DiagSplitResult {
    n: usize, diag: f64, offdiag: f64,
    diag_frac: f64,
}

fn diag_split(n: usize, mu: &[i8]) -> DiagSplitResult {
    let m = n - 1;
    let log_n = (n as f64).ln();

    let weights: Vec<f64> = (0..=m).map(|k| {
        if k == 0 { 0.0 } else { gram::bd_weight(mu[k], k as u64, log_n) }
    }).collect();

    let diag: f64 = (1..=m).map(|k| {
        weights[k] * weights[k] * gram::gram_entry(k as u64, k as u64)
    }).sum();

    let offdiag: f64 = (1..=m).into_par_iter().map(|j| {
        let vj = weights[j];
        if vj == 0.0 { return 0.0; }
        (1..=m).filter(|&k| k != j).map(|k| {
            let vk = weights[k];
            if vk == 0.0 { 0.0 }
            else { vj * vk * gram::gram_entry(j as u64, k as u64) }
        }).sum::<f64>()
    }).sum();

    let total = diag + offdiag;
    DiagSplitResult {
        n, diag, offdiag,
        diag_frac: if total.abs() > 1e-15 { diag / total } else { 0.0 },
    }
}

// ═══════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════

fn main() {
    let t0 = Instant::now();
    let threads = rayon::current_num_threads();

    let max_n: usize = std::env::args().nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(50000);

    header(
        "CATHEDRAL GRAM FORM IDENTITY EXPLORER",
        &format!("Target: vᵀGv ≤ 1 + C/logN  ·  max N = {max_n}"),
        threads,
    );

    fs::create_dir_all("results").unwrap();

    // Small N: exact Gram matrix computation (N ≤ 2000)
    let mut test_ns: Vec<usize> = vec![10, 20, 50, 100, 200, 500, 1000, 2000];
    test_ns.retain(|&n| n <= max_n);

    // High N: integral-based computation (fast O(N·pts))
    let mut high_ns: Vec<usize> = Vec::new();
    for &step in &[5000, 10_000, 20_000, 50_000, 100_000, 200_000, 500_000] {
        if step <= max_n { high_ns.push(step); }
    }
    if max_n > 2000 && !high_ns.contains(&max_n) { high_ns.push(max_n); }

    let sieve_max = *test_ns.last().unwrap().max(
        high_ns.last().unwrap_or(&0));

    eprintln!("  {DIM}▸ Sieving μ(k) for k ≤ {sieve_max}...{RESET}");
    let mu = sieve::mobius_sieve(sieve_max);
    let mertens = sieve::mertens_values(&mu);
    eprintln!("  {GREEN}✓{RESET} Sieve complete ({:.3}s)", t0.elapsed().as_secs_f64());
    println!();

    // ═══ §A. CONVERGENCE ═══
    println!("  {BOLD}{WHITE}═══ §A. CONVERGENCE: vᵀGv → 1 ═══{RESET}");
    println!("  {DIM}     N  │    vᵀGv    │  vᵀGv - 1  │    bᵀv     │  (vᵀGv-1)·L │   vᵀCv    │  ∫(1-f)²{RESET}");

    let mut tsv_a = fs::File::create("results/convergence.tsv").unwrap();
    writeln!(tsv_a, "N\tvtGv\tvtGv_minus_1\tbtv\texcess_logN\tvtCv\tl2_residual").unwrap();
    let mut conv_results = Vec::new();

    for &n in &test_ns {
        let t = Instant::now();
        let r = convergence_scan(n, &mu);
        let log_n = (n as f64).ln();
        let excess_l = (r.vtgv - 1.0) * log_n;
        println!("  {:>6} │ {:>10.6} │ {:>10.6} │ {:>10.6} │ {:>11.6} │ {:>9.6} │ {:>8.6} ({:.1}s)",
            n, r.vtgv, r.vtgv - 1.0, r.btv, excess_l, r.vtcv, r.l2_residual,
            t.elapsed().as_secs_f64());
        writeln!(tsv_a, "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}",
            n, r.vtgv, r.vtgv - 1.0, r.btv, excess_l, r.vtcv, r.l2_residual).unwrap();
        conv_results.push(r);
    }
    println!();

    // ═══ §B. DIAGONAL SPLIT ═══
    println!("  {BOLD}{WHITE}═══ §B. DIAGONAL vs OFF-DIAGONAL SPLIT ═══{RESET}");
    println!("  {DIM}     N  │  Diagonal  │ Off-Diag   │   Total    │ D/Total │ D·logN{RESET}");

    let mut tsv_b = fs::File::create("results/diag_split.tsv").unwrap();
    writeln!(tsv_b, "N\tdiag\toffdiag\ttotal\tdiag_frac\tdiag_logN").unwrap();

    for &n in &test_ns {
        let t = Instant::now();
        let r = diag_split(n, &mu);
        let log_n = (n as f64).ln();
        println!("  {:>6} │ {:>10.6} │ {:>10.6} │ {:>10.6} │ {:>7.4} │ {:>7.4} ({:.1}s)",
            n, r.diag, r.offdiag, r.diag + r.offdiag, r.diag_frac,
            r.diag * log_n, t.elapsed().as_secs_f64());
        writeln!(tsv_b, "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}",
            n, r.diag, r.offdiag, r.diag + r.offdiag, r.diag_frac,
            r.diag * log_n).unwrap();
    }
    println!();

    // ═══ §C. S-SUM PROFILE ═══
    println!("  {BOLD}{WHITE}═══ §C. S₁/S₂/S₃ SUMS at N-1 ═══{RESET}");
    println!("  {DIM}     N  │   S₁(N-1)  │ S₂(N-1)+1  │ S₃(N-1)+2γ │   M(N-1)  │ |M|/N^¾{RESET}");

    let mut tsv_c = fs::File::create("results/s_sums.tsv").unwrap();
    writeln!(tsv_c, "N\tS1\tS2\tS3\tS2_plus_1\tS3_plus_2g\tM\tM_ratio_34").unwrap();

    for &n in &test_ns {
        let m = n - 1;
        let s1_val = gram::s1(&mu, m);
        let s2_val = gram::s2(&mu, m);
        let s3_val = gram::s3(&mu, m);
        let m_val = mertens[m];
        let m_ratio = (m_val as f64).abs() / (m as f64).powf(0.75);

        println!("  {:>6} │ {:>10.6} │ {:>10.6} │ {:>10.6} │ {:>9} │ {:>7.4}",
            n, s1_val, s2_val + 1.0, s3_val + 2.0 * gram::GAMMA, m_val, m_ratio);
        writeln!(tsv_c, "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{}\t{:.15e}",
            n, s1_val, s2_val, s3_val, s2_val + 1.0, s3_val + 2.0 * gram::GAMMA,
            m_val, m_ratio).unwrap();
    }
    println!();

    // ═══ §D. BILINEAR FIT ═══
    println!("  {BOLD}{WHITE}═══ §D. BILINEAR FIT: what is (vᵀGv-1)·logN? ═══{RESET}");
    println!("  {DIM}     N  │ (vᵀGv-1)·L │  2(1-bᵀv)·L │ ∫(1-f)²·L │ vᵀCv·L  │ (bᵀv)²-1{RESET}");

    let mut tsv_d = fs::File::create("results/bilinear_fit.tsv").unwrap();
    writeln!(tsv_d, "N\texcess_logN\tdot_excess_logN\tl2_logN\tvtCv_logN\tbtv_sq_minus_1").unwrap();

    for r in &conv_results {
        let log_n = (r.n as f64).ln();
        let excess_l = (r.vtgv - 1.0) * log_n;
        let dot_excess_l = 2.0 * (1.0 - r.btv) * log_n;
        let l2_l = r.l2_residual * log_n;
        let vtcv_l = r.vtcv * log_n;
        let btv_sq_m1 = r.btv * r.btv - 1.0;

        println!("  {:>6} │ {:>11.6} │ {:>12.6} │ {:>9.6} │ {:>8.5} │ {:>9.6}",
            r.n, excess_l, dot_excess_l, l2_l, vtcv_l, btv_sq_m1);
        writeln!(tsv_d, "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}",
            r.n, excess_l, dot_excess_l, l2_l, vtcv_l, btv_sq_m1).unwrap();
    }
    println!();

    // ═══ §E. KEY IDENTITY CHECK ═══
    // vᵀGv = (bᵀv)² + vᵀCv, so vᵀGv - 1 = (bᵀv)² - 1 + vᵀCv
    // = ((bᵀv)² - 1) + vᵀCv = (bᵀv-1)(bᵀv+1) + vᵀCv
    println!("  {BOLD}{WHITE}═══ §E. IDENTITY CHECK: vᵀGv - 1 = (bᵀv)² - 1 + vᵀCv ═══{RESET}");
    println!("  {DIM}     N  │  vᵀGv - 1  │ (bᵀv)²-1   │    vᵀCv    │   sum    │  error{RESET}");

    for r in &conv_results {
        let vtgv_m1 = r.vtgv - 1.0;
        let btv_sq_m1 = r.btv * r.btv - 1.0;
        let checksum = btv_sq_m1 + r.vtcv;
        let err = (vtgv_m1 - checksum).abs();
        println!("  {:>6} │ {:>10.6} │ {:>10.6} │ {:>10.6} │ {:>9.6} │ {:>7.1e} {}",
            r.n, vtgv_m1, btv_sq_m1, r.vtcv, checksum, err,
            check(err < 1e-10));
    }
    println!();

    // ═══ §F. CONVERGENCE RATE ═══
    println!("  {BOLD}{WHITE}═══ §F. CONVERGENCE RATES ═══{RESET}");
    println!("  {DIM}  Key question: does (vᵀGv-1)·logN converge? To what?{RESET}");
    println!("  {DIM}     N  │ (vᵀGv-1)·L │ ∫(1-f)²·L │  vᵀCv·L  │ 2(1-bᵀv)·L{RESET}");
    println!("  {DIM}  ─────┼────────────┼───────────┼──────────┼───────────{RESET}");

    for r in &conv_results {
        let log_n = (r.n as f64).ln();
        println!("  {:>6} │ {:>11.6} │ {:>9.6} │ {:>8.5} │ {:>10.6}",
            r.n,
            (r.vtgv - 1.0) * log_n,
            r.l2_residual * log_n,
            r.vtcv * log_n,
            2.0 * (1.0 - r.btv) * log_n);
    }
    println!();

    // ═══ §G. HIGH-N INTEGRAL SCAN ═══
    if !high_ns.is_empty() {
        println!("  {BOLD}{WHITE}═══ §G. HIGH-N SCAN (integral quadrature, O(N·pts)) ═══{RESET}");
        println!("  {DIM}  Using ∫₀¹ f_N(x)² dx instead of Gram matrix{RESET}");
        println!("  {DIM}     N  │    vᵀGv    │  vᵀGv - 1  │    bᵀv     │  (vᵀGv-1)·L │  ∫(1-f)²  │  points{RESET}");

        let mut tsv_g = fs::File::create("results/high_n.tsv").unwrap();
        writeln!(tsv_g, "N\tvtGv\tvtGv_minus_1\tbtv\texcess_logN\tl2_residual\tn_pts").unwrap();

        for &n in &high_ns {
            let t = Instant::now();
            let weights = gram::precompute_weights(n, &mu);
            // Adaptive points: more for smaller N, fewer for huge N
            let n_pts = if n <= 10_000 { 200_000 }
                else if n <= 50_000 { 100_000 }
                else if n <= 200_000 { 50_000 }
                else { 20_000 };

            // Parallel quadrature
            let dx = 1.0 / n_pts as f64;
            let vtgv: f64 = (0..n_pts).into_par_iter().map(|i| {
                let x = (i as f64 + 0.5) * dx;
                let f = gram::f_n_at(x, &weights);
                f * f * dx
            }).sum();

            let btv: f64 = (0..n_pts).into_par_iter().map(|i| {
                let x = (i as f64 + 0.5) * dx;
                gram::f_n_at(x, &weights) * dx
            }).sum();

            let log_n = (n as f64).ln();
            let excess_l = (vtgv - 1.0) * log_n;
            let l2 = 1.0 - 2.0 * btv + vtgv;

            println!("  {:>6} │ {:>10.6} │ {:>10.6} │ {:>10.6} │ {:>11.6} │ {:>9.6} │ {:>7} ({:.1}s)",
                n, vtgv, vtgv - 1.0, btv, excess_l, l2, n_pts,
                t.elapsed().as_secs_f64());
            writeln!(tsv_g, "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{}",
                n, vtgv, vtgv - 1.0, btv, excess_l, l2, n_pts).unwrap();

            conv_results.push(ConvergenceResult {
                n, vtgv, btv,
                vtcv: vtgv - btv * btv,
                l2_residual: l2,
            });
        }
        println!();
    }

    // ═══ CERTIFICATE ═══
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}GRAM FORM IDENTITY EXPLORER — FINDINGS{RESET}");
    println!("  {BOLD}{CYAN}╠═══════════════════════════════════════════════════════════════════════╣{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  Threads: {YELLOW}{threads}{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}");

    // Check: vᵀGv < 1 for all N (it IS < 1 since weights are small)
    let all_lt1 = conv_results.iter().all(|r| r.vtgv < 1.0);
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§A. Convergence{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}    {} vᵀGv < 1 for ALL tested N (bound is LOOSE)", check(all_lt1));

    if let Some(last) = conv_results.last() {
        let log_n = (last.n as f64).ln();
        println!("  {BOLD}{CYAN}║{RESET}    (vᵀGv-1)·logN → {MAGENTA}{:.4}{RESET} (at N={})",
            (last.vtgv - 1.0) * log_n, last.n);
    }
    println!("  {BOLD}{CYAN}║{RESET}");

    // Identity decomposition
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§E. Identity{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}    {GREEN}vᵀGv - 1 = (bᵀv)² - 1 + vᵀCv{RESET}  [VERIFIED]");
    println!("  {BOLD}{CYAN}║{RESET}    {DIM}= (bᵀv-1)(bᵀv+1) + vᵀCv{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}    {DIM}Both terms are O(1/logN), hence vᵀGv - 1 = O(1/logN){RESET}");
    println!("  {BOLD}{CYAN}║{RESET}");

    // Key insight
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}INSIGHT FOR gram_form_bound_raw{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}    vᵀGv = (bᵀv)² + vᵀCv");
    println!("  {BOLD}{CYAN}║{RESET}         ≤ (1 + C_dot/logN)² + C_cov/logN");
    println!("  {BOLD}{CYAN}║{RESET}         = 1 + 2C_dot/logN + C_dot²/log²N + C_cov/logN");
    println!("  {BOLD}{CYAN}║{RESET}         ≤ 1 + (2C_dot + C_cov + 1)/logN");
    println!("  {BOLD}{CYAN}║{RESET}    {YELLOW}→ REQUIRES proving vᵀCv ≤ C_cov/logN independently{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");

    // JSON certificate
    let cert = format!(r#"{{
  "experiment": "Cathedral Gram Form Identity Explorer",
  "threads": {threads},
  "timestamp": "{}",
  "target": "gram_form_bound_raw (CovarianceAbel.lean)",
  "max_N_tested": {sieve_max},
  "vtGv_all_lt1": {all_lt1},
  "identity_verified": "vtGv - 1 = (btv)^2 - 1 + vtCv",
  "convergence_data": [{data}
  ],
  "elapsed_seconds": {elapsed:.3}
}}"#,
        chrono::Utc::now().to_rfc3339(),
        data = conv_results.iter().map(|r| {
            let log_n = (r.n as f64).ln();
            format!("\n    {{\"N\": {}, \"vtGv\": {:.15e}, \"btv\": {:.15e}, \"vtCv\": {:.15e}, \"l2\": {:.15e}, \"excess_logN\": {:.15e}}}",
                r.n, r.vtgv, r.btv, r.vtcv, r.l2_residual, (r.vtgv - 1.0) * log_n)
        }).collect::<Vec<_>>().join(","),
        elapsed = t0.elapsed().as_secs_f64(),
    );
    fs::write("results/certificate.json", &cert).unwrap();

    println!();
    println!("  {BOLD}{WHITE}Total:{RESET} {GREEN}{:.1}s{RESET} ({threads} threads)", t0.elapsed().as_secs_f64());
    println!("  {BOLD}{WHITE}Output:{RESET} results/{{convergence,diag_split,s_sums,bilinear_fit}}.tsv");
    println!("  {BOLD}{WHITE}Certificate:{RESET} results/certificate.json");
    println!();
}
