#!/usr/bin/env -S cargo +nightly -Zscript
//! SUSY Sector Decomposition v3 — DD-precision HPDF sweep
//!
//! Reads precomputed DD-lossless Gram matrices and decomposes:
//!   vᵀGv = D(N) + B_off(N) + F_off(N)
//!
//! GU-reframed analysis (Inhomogeneous Gauge Theory):
//!   Gap 1: |B+F| grows slower than D(N)  → "matter dilutes"
//!   Gap 2: |B+F|/D(N) → 0               → cosmological constant vanishes
//!   Gap 3: (vᵀGv - 1) ~ ln(N)^α, α < 1 → sub-linear excess
//!
//! Usage:
//!   cargo run --release --bin susy-sweep -- --cache-dir experiments/cache/hpdf
//!   cargo run --release --bin susy-sweep -- --cache-dir experiments/cache/hpdf --max-n 60000

use std::path::{Path, PathBuf};
use std::time::Instant;
use clap::Parser;

use cathedral_utils::arith;
use cathedral_utils::fitting;
use cathedral_utils::hpdf::reader::HpdfReader;

#[derive(Parser)]
#[command(name = "susy-sweep")]
struct Cli {
    /// Directory containing gram_N*.h5 files
    #[arg(long, default_value = "experiments/cache/hpdf")]
    cache_dir: String,

    /// Specific N values to process (comma-separated). If empty, process all.
    #[arg(long, value_delimiter = ',')]
    n_values: Vec<usize>,

    /// Maximum N to process
    #[arg(long, default_value = "60000")]
    max_n: usize,

    /// Minimum N for scaling fits (skip tiny matrices)
    #[arg(long, default_value = "60")]
    min_n_fit: usize,

    /// Output TSV file
    #[arg(long, default_value = "susy_sectors.tsv")]
    output: String,

    /// Output JSON certificate
    #[arg(long, default_value = "susy_certificate.json")]
    cert: String,
}

/// Compute Ω(n) table (number of prime factors with multiplicity).
fn big_omega_table(max_n: usize) -> Vec<u32> {
    let mut omega = vec![0u32; max_n + 1];
    for p in 2..=max_n {
        if omega[p] != 0 { continue; }
        let mut pk = p;
        while pk <= max_n {
            for m in (pk..=max_n).step_by(pk) {
                omega[m] += 1;
            }
            if pk > max_n / p { break; }
            pk *= p;
        }
    }
    omega
}

#[derive(Debug, Clone)]
struct SusyResult {
    n: usize,
    dim: usize,
    vtgv: f64,
    diagonal: f64,
    bosonic_off: f64,
    fermionic_off: f64,
    off_diagonal: f64,
    susy_residual: f64,   // |B+F|
    signed_bf: f64,        // B+F (signed — for phase transition detection)
    gap: f64,              // 1 - vᵀGv
    gap_times_ln: f64,     // (1 - vᵀGv) · ln(N)
    d_fraction: f64,       // D / vᵀGv
    bf_over_d: f64,        // |B+F| / D(N) — KEY RATIO for o(D) test
    bf_times_ln: f64,      // |B+F| · ln(N) — stabilization test
    cancel_pct: f64,       // 1 - |B+F|/(|B|+|F|) — cancellation percentage
    cosmo_ratio: f64,      // |B+F|/(|B|+|F|) — arithmetic cosmological constant
    excess: f64,           // (vᵀGv - 1) — for ln(N)^α fitting
    excess_over_ln: f64,   // (vᵀGv - 1)/ln(N) — should → 0
    num_sqfree: usize,
    num_bosonic: usize,
    num_fermionic: usize,
    elapsed_secs: f64,
    is_hc: bool,
}

fn decompose_from_hpdf(path: &Path) -> Option<SusyResult> {
    let t0 = Instant::now();

    let reader = HpdfReader::open(path).ok()?;
    let n = reader.max_n();
    let dim = reader.dim();

    let gram = reader.read_gram_full().ok()?;
    if gram.len() != dim * dim {
        eprintln!("  [N={}] Gram matrix size mismatch: {} vs {}×{}", n, gram.len(), dim, dim);
        return None;
    }

    let mu = arith::mobius_table(n);
    let omega = big_omega_table(n);
    let ln_n = (n as f64).ln();

    // HPDF convention: dim = N-1, indices k = 2..=N
    let v: Vec<f64> = (0..dim).map(|i| {
        let k = i + 2;
        let mu_k = mu[k] as f64;
        let w = 1.0 - (k as f64).ln() / ln_n;
        -mu_k * w
    }).collect();

    let mut diagonal = 0.0f64;
    let mut bosonic_off = 0.0f64;
    let mut fermionic_off = 0.0f64;
    let mut vtgv = 0.0f64;
    let mut num_sqfree = 0usize;
    let mut num_bosonic = 0usize;
    let mut num_fermionic = 0usize;

    for i in 0..dim {
        let j = i + 2;
        let vj = v[i];
        if mu[j] != 0 { num_sqfree += 1; }

        for ii in 0..dim {
            let k = ii + 2;
            let vk = v[ii];
            let g_jk = gram[i * dim + ii];
            let term = vj * g_jk * vk;
            vtgv += term;

            if i == ii {
                diagonal += term;
            } else {
                let omega_sum = omega[j] + omega[k];
                if omega_sum % 2 == 0 {
                    bosonic_off += term;
                    num_bosonic += 1;
                } else {
                    fermionic_off += term;
                    num_fermionic += 1;
                }
            }
        }
    }

    let off_diagonal = bosonic_off + fermionic_off;
    let gap = 1.0 - vtgv;
    let elapsed = t0.elapsed().as_secs_f64();

    let hc_vals = [2, 4, 6, 12, 24, 36, 48, 60, 120, 180, 240, 360, 720, 840,
                   1260, 1680, 2520, 5040, 7560, 10080, 15120, 20160, 25200,
                   27720, 45360, 50400, 55440, 40000, 20000, 10000, 1000];
    let is_hc = hc_vals.contains(&n);

    let abs_b = bosonic_off.abs();
    let abs_f = fermionic_off.abs();
    let sector_sum = abs_b + abs_f;
    let excess = vtgv - 1.0;

    Some(SusyResult {
        n, dim, vtgv, diagonal, bosonic_off, fermionic_off,
        off_diagonal,
        susy_residual: off_diagonal.abs(),
        signed_bf: off_diagonal,
        gap,
        gap_times_ln: gap * ln_n,
        d_fraction: if vtgv.abs() > 1e-15 { diagonal / vtgv } else { 0.0 },
        bf_over_d: if diagonal.abs() > 1e-15 { off_diagonal.abs() / diagonal.abs() } else { 0.0 },
        bf_times_ln: off_diagonal.abs() * ln_n,
        cancel_pct: if sector_sum > 1e-15 { 1.0 - off_diagonal.abs() / sector_sum } else { 0.0 },
        cosmo_ratio: if sector_sum > 1e-15 { off_diagonal.abs() / sector_sum } else { 0.0 },
        excess,
        excess_over_ln: if ln_n > 1e-10 { excess / ln_n } else { 0.0 },
        num_sqfree, num_bosonic, num_fermionic,
        elapsed_secs: elapsed,
        is_hc,
    })
}

/// Scaling analysis — GU-reframed (Inhomogeneous Gauge Theory)
struct ScalingAnalysis {
    // Power-law fit: |B+F| ~ c · N^(α)
    bf_power_c: f64,
    bf_power_alpha: f64,
    bf_power_r2: f64,
    // Log-decay fit: |B+F| ~ c / (ln N)^β
    bf_log_c: f64,
    bf_log_beta: f64,
    bf_log_r2: f64,
    // Power-law fit: |B+F|/D ~ c · N^(-α)
    ratio_power_c: f64,
    ratio_power_alpha: f64,
    ratio_power_r2: f64,
    // Power-law fit: D(N) ~ c · N^(α)
    d_power_c: f64,
    d_power_alpha: f64,
    d_power_r2: f64,
    // Excess growth: (vᵀGv - 1) ~ c · ln(N)^α
    excess_alpha: f64,
    excess_r2: f64,
    // Gap: |B+F|·ln(N) bounded?
    bf_ln_max: f64,
    bf_ln_min: f64,
    bf_ln_span: f64,
    // GU verdicts
    gu_gap1_matter_dilutes: bool,   // |B+F| grows slower than D
    gu_gap2_cosmo_vanishes: bool,   // |B+F|/D → 0
    gu_gap3_sublinear: bool,        // excess α < 1
}

fn analyze_scaling(results: &[SusyResult], min_n: usize) -> ScalingAnalysis {
    let fit_data: Vec<&SusyResult> = results.iter()
        .filter(|r| r.n >= min_n && r.susy_residual > 1e-20)
        .collect();

    let ns: Vec<f64> = fit_data.iter().map(|r| r.n as f64).collect();
    let bf_vals: Vec<f64> = fit_data.iter().map(|r| r.susy_residual).collect();
    let ratio_vals: Vec<f64> = fit_data.iter().map(|r| r.bf_over_d).collect();
    let d_vals: Vec<f64> = fit_data.iter().map(|r| r.diagonal.abs()).collect();

    let (bf_power_c, bf_power_alpha, bf_power_r2) = if ns.len() >= 3 {
        fitting::power_law_fit(&ns, &bf_vals)
    } else { (0.0, 0.0, 0.0) };

    let (bf_log_c, bf_log_beta, bf_log_r2) = if ns.len() >= 3 {
        fitting::log_decay_fit(&ns, &bf_vals)
    } else { (0.0, 0.0, 0.0) };

    let (ratio_power_c, ratio_power_alpha, ratio_power_r2) = if ns.len() >= 3 {
        fitting::power_law_fit(&ns, &ratio_vals)
    } else { (0.0, 0.0, 0.0) };

    let (d_power_c, d_power_alpha, d_power_r2) = if ns.len() >= 3 {
        fitting::power_law_fit(&ns, &d_vals)
    } else { (0.0, 0.0, 0.0) };

    // Fit excess (vᵀGv - 1) vs ln(N) to find growth exponent α
    let excess_data: Vec<(&SusyResult, f64)> = fit_data.iter()
        .filter(|r| r.excess > 0.0)
        .map(|r| (*r, (r.n as f64).ln()))
        .collect();
    let (excess_alpha, excess_r2) = if excess_data.len() >= 3 {
        let ln_ns: Vec<f64> = excess_data.iter().map(|(_, l)| *l).collect();
        let excesses: Vec<f64> = excess_data.iter().map(|(r, _)| r.excess).collect();
        let (_, alpha, r2) = fitting::power_law_fit(&ln_ns, &excesses);
        (alpha, r2)
    } else { (0.0, 0.0) };

    let bf_ln_vals: Vec<f64> = fit_data.iter().map(|r| r.bf_times_ln).collect();
    let bf_ln_max = bf_ln_vals.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    let bf_ln_min = bf_ln_vals.iter().cloned().fold(f64::INFINITY, f64::min);

    // GU verdicts: does |B+F| grow slower than D?
    let bf_grows_slower = bf_power_alpha < d_power_alpha;
    let ratio_decays = ratio_power_alpha > 0.0;
    let sublinear = excess_alpha < 1.0 && excess_alpha > 0.0;

    ScalingAnalysis {
        bf_power_c, bf_power_alpha, bf_power_r2,
        bf_log_c, bf_log_beta, bf_log_r2,
        ratio_power_c, ratio_power_alpha, ratio_power_r2,
        d_power_c, d_power_alpha, d_power_r2,
        excess_alpha, excess_r2,
        bf_ln_max, bf_ln_min,
        bf_ln_span: bf_ln_max - bf_ln_min,
        gu_gap1_matter_dilutes: bf_grows_slower,
        gu_gap2_cosmo_vanishes: ratio_decays,
        gu_gap3_sublinear: sublinear,
    }
}

fn main() {
    let cli = Cli::parse();

    println!("╔══════════════════════════════════════════════════════════════════════╗");
    println!("║     SUSY SECTOR SWEEP v3 — Inhomogeneous Gauge Theory              ║");
    println!("║     vᵀGv = D(N) + B_off(N) + F_off(N)                             ║");
    println!("║     GU Analysis: matter dilution · cosmo ratio · excess exponent   ║");
    println!("╚══════════════════════════════════════════════════════════════════════╝");

    let cache_dir = Path::new(&cli.cache_dir);
    if !cache_dir.exists() {
        eprintln!("Cache directory not found: {}", cli.cache_dir);
        return;
    }

    let mut h5_files: Vec<(usize, PathBuf)> = std::fs::read_dir(cache_dir)
        .unwrap()
        .filter_map(|e| e.ok())
        .filter_map(|e| {
            let name = e.file_name().to_string_lossy().to_string();
            if name.starts_with("gram_N") && name.ends_with(".h5") && !name.contains("_p") {
                let n_str = name.strip_prefix("gram_N")?.strip_suffix(".h5")?;
                let n: usize = n_str.parse().ok()?;
                if n <= cli.max_n && n >= 6 {
                    if cli.n_values.is_empty() || cli.n_values.contains(&n) {
                        return Some((n, e.path()));
                    }
                }
                None
            } else {
                None
            }
        })
        .collect();

    h5_files.sort_by_key(|(n, _)| *n);

    println!("\n  Found {} HPDF files (N ≤ {})", h5_files.len(), cli.max_n);
    println!("  Processing sequentially (HDF5 I/O)...\n");

    let t_total = Instant::now();

    let mut results: Vec<SusyResult> = Vec::new();
    for (n, path) in &h5_files {
        eprint!("  N={:>6} ...", n);
        match decompose_from_hpdf(path) {
            Some(r) => {
                eprintln!(" D={:>+12.8}  |B+F|={:.6e}  |B+F|/D={:.6e}  gap·ln={:>10.6}  ({:.1}s)",
                         r.diagonal, r.susy_residual, r.bf_over_d, r.gap_times_ln, r.elapsed_secs);
                results.push(r);
            }
            None => {
                eprintln!(" FAILED (may need more RAM — try on WSL GPU)");
            }
        }
    }

    let total_time = t_total.elapsed().as_secs_f64();

    if results.is_empty() {
        eprintln!("No results to analyze.");
        return;
    }

    // ═══ SUMMARY TABLE ═══
    println!("\n  ╔════════╦══════════════╦══════════════╦══════════════╦══════════════╦══════════════╦═══════════╗");
    println!("  ║   N    ║    D(N)      ║   B_off(N)   ║   F_off(N)   ║   |B+F|      ║  |B+F|/D     ║   HC?   ║");
    println!("  ╠════════╬══════════════╬══════════════╬══════════════╬══════════════╬══════════════╬═══════════╣");

    for r in &results {
        let hc = if r.is_hc { " ★" } else { "  " };
        println!("  ║{:>7} ║ {:>+12.8} ║ {:>+12.8} ║ {:>+12.8} ║ {:>12.6e} ║ {:>12.6e} ║{:>8} ║",
                 r.n, r.diagonal, r.bosonic_off, r.fermionic_off, r.susy_residual, r.bf_over_d, hc);
    }
    println!("  ╚════════╩══════════════╩══════════════╩══════════════╩══════════════╩══════════════╩═══════════╝");

    // ═══ SCALING ANALYSIS ═══
    let scaling = analyze_scaling(&results, cli.min_n_fit);

    // ═══ GU-REFRAMED PHASE TRANSITION TABLE ═══
    println!("\n  ╔════════╦════════════╦════════════╦════════════╦══════════╗");
    println!("  ║   N    ║  cancel%%  ║ cosmo_ratio║  signed BF ║  excess  ║");
    println!("  ╠════════╬════════════╬════════════╬════════════╬══════════╣");
    for r in &results {
        let hc_mark = if r.is_hc { "★" } else { " " };
        println!("  ║{:>6}{} ║ {:>8.4}%% ║ {:>10.6} ║ {:>+10.6} ║ {:>8.5} ║",
                 r.n, hc_mark, r.cancel_pct * 100.0, r.cosmo_ratio, r.signed_bf, r.excess);
    }
    println!("  ╚════════╩════════════╩════════════╩════════════╩══════════╝");

    println!("\n  ╔══════════════════════════════════════════════════════════════════════╗");
    println!("  ║  SCALING ANALYSIS v3 — GU Inhomogeneous Gauge Framing              ║");
    println!("  ╠══════════════════════════════════════════════════════════════════════╣");
    println!("  ║                                                                    ║");
    println!("  ║  GU-GAP 1: Matter dilutes (|B+F| grows slower than D)              ║");
    println!("  ║    |B+F| ~ N^({:.4})   D(N) ~ N^({:.4})                       ║",
             scaling.bf_power_alpha, scaling.d_power_alpha);
    let g1 = if scaling.gu_gap1_matter_dilutes { "✅ DILUTES" } else { "❌ FAILS  " };
    println!("  ║    VERDICT: {}  (bf_α < d_α)                             ║", g1);
    println!("  ║                                                                    ║");
    println!("  ║  GU-GAP 2: Cosmological constant vanishes (|B+F|/D → 0)            ║");
    println!("  ║    |B+F|/D ~ N^(-{:.4})   R² = {:.6}                        ║",
             scaling.ratio_power_alpha, scaling.ratio_power_r2);
    let g2 = if scaling.gu_gap2_cosmo_vanishes { "✅ VANISHES" } else { "❌ FAILS   " };
    println!("  ║    VERDICT: {}                                            ║", g2);
    println!("  ║                                                                    ║");
    println!("  ║  GU-GAP 3: Sub-linear excess (vᵀGv - 1) ~ ln(N)^α, α < 1         ║");
    println!("  ║    Excess growth exponent α = {:.4}   R² = {:.6}             ║",
             scaling.excess_alpha, scaling.excess_r2);
    let g3 = if scaling.gu_gap3_sublinear { "✅ SUBLINEAR" } else { "❌ FAILS    " };
    println!("  ║    VERDICT: {}  (need α < 1)                          ║", g3);
    println!("  ║                                                                    ║");
    println!("  ║  AUXILIARY: |B+F|·ln(N) stabilization                              ║");
    println!("  ║    Range: [{:.6}, {:.6}]  span = {:.6}                   ║",
             scaling.bf_ln_min, scaling.bf_ln_max, scaling.bf_ln_span);
    let stable = scaling.bf_ln_span < 1.0;
    let stab = if stable { "✅ STABLE" } else { "⚠  UNSTABLE" };
    println!("  ║    VERDICT: {}                                              ║", stab);
    println!("  ╚══════════════════════════════════════════════════════════════════════╝");

    // ═══ WRITE TSV ═══
    let mut tsv = String::from("N\tdim\tvtgv\tD\tB_off\tF_off\tB_plus_F\tabs_BF\tBF_over_D\tBF_times_ln\tgap\tgap_times_ln\tD_frac\tcancel_pct\tcosmo_ratio\texcess\texcess_over_ln\tsqfree\tbosonic_pairs\tfermionic_pairs\tis_hc\n");
    for r in &results {
        tsv.push_str(&format!("{}\t{}\t{:.15}\t{:.15}\t{:.15}\t{:.15}\t{:.15}\t{:.15e}\t{:.15e}\t{:.15}\t{:.15}\t{:.15}\t{:.6}\t{:.10}\t{:.10}\t{:.15}\t{:.15}\t{}\t{}\t{}\t{}\n",
            r.n, r.dim, r.vtgv, r.diagonal, r.bosonic_off, r.fermionic_off,
            r.off_diagonal, r.susy_residual, r.bf_over_d, r.bf_times_ln,
            r.gap, r.gap_times_ln, r.d_fraction,
            r.cancel_pct, r.cosmo_ratio, r.excess, r.excess_over_ln,
            r.num_sqfree, r.num_bosonic, r.num_fermionic, r.is_hc));
    }
    std::fs::write(&cli.output, &tsv).expect("Failed to write TSV");

    // ═══ WRITE JSON CERTIFICATE ═══
    let max_tested = results.last().map(|r| r.n).unwrap_or(0);
    let cert = format!(r#"{{
  "experiment": "SUSY Sector Cancellation Sweep v3 — GU Inhomogeneous",
  "format": "cathedral-susy-sweep-v3",
  "timestamp": "{}",
  "max_N_tested": {},
  "files_processed": {},
  "total_time_secs": {:.2},
  "scaling": {{
    "bf_power_law": {{ "c": {:.10}, "alpha": {:.10}, "r2": {:.10} }},
    "bf_log_decay": {{ "c": {:.10}, "beta": {:.10}, "r2": {:.10} }},
    "ratio_power_law": {{ "c": {:.10}, "alpha": {:.10}, "r2": {:.10} }},
    "d_power_law": {{ "c": {:.10}, "alpha": {:.10}, "r2": {:.10} }},
    "excess_growth": {{ "alpha": {:.10}, "r2": {:.10} }},
    "bf_ln_range": [{:.10}, {:.10}],
    "bf_ln_span": {:.10}
  }},
  "gu_verdicts": {{
    "gap1_matter_dilutes": {},
    "gap2_cosmo_vanishes": {},
    "gap3_sublinear_excess": {},
    "bf_ln_stabilized": {}
  }},
  "data": [{}
  ]
}}"#,
        chrono::Utc::now().to_rfc3339(),
        max_tested, results.len(), total_time,
        scaling.bf_power_c, scaling.bf_power_alpha, scaling.bf_power_r2,
        scaling.bf_log_c, scaling.bf_log_beta, scaling.bf_log_r2,
        scaling.ratio_power_c, scaling.ratio_power_alpha, scaling.ratio_power_r2,
        scaling.d_power_c, scaling.d_power_alpha, scaling.d_power_r2,
        scaling.excess_alpha, scaling.excess_r2,
        scaling.bf_ln_min, scaling.bf_ln_max, scaling.bf_ln_span,
        scaling.gu_gap1_matter_dilutes, scaling.gu_gap2_cosmo_vanishes,
        scaling.gu_gap3_sublinear, stable,
        results.iter().map(|r| {
            format!("\n    {{\"N\": {}, \"D\": {:.15e}, \"B_off\": {:.15e}, \"F_off\": {:.15e}, \"signed_BF\": {:.15e}, \"abs_BF\": {:.15e}, \"BF_over_D\": {:.15e}, \"cancel_pct\": {:.10}, \"cosmo_ratio\": {:.10}, \"excess\": {:.10}, \"gap_ln\": {:.10}}}",
                r.n, r.diagonal, r.bosonic_off, r.fermionic_off, r.signed_bf, r.susy_residual, r.bf_over_d, r.cancel_pct, r.cosmo_ratio, r.excess, r.gap_times_ln)
        }).collect::<Vec<_>>().join(",")
    );
    std::fs::write(&cli.cert, &cert).expect("Failed to write JSON");

    println!("\n  Results: {}", cli.output);
    println!("  Certificate: {}", cli.cert);
    println!("  Total: {:.1}s ({} files)", total_time, results.len());
}
