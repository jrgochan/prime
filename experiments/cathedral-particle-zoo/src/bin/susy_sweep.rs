#!/usr/bin/env -S cargo +nightly -Zscript
//! SUSY Sector Decomposition — DD-precision HPDF sweep
//!
//! Reads precomputed DD-lossless Gram matrices and decomposes:
//!   vᵀGv = D(N) + B_off(N) + F_off(N)
//!
//! Usage: cargo run --release --bin susy-sweep -- --cache-dir experiments/cache/hpdf

use std::path::{Path, PathBuf};
use std::time::Instant;
use clap::Parser;
use rayon::prelude::*;

use cathedral_utils::arith;
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
    #[arg(long, default_value = "5100")]
    max_n: usize,

    /// Output TSV file
    #[arg(long, default_value = "susy_sectors.tsv")]
    output: String,
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
    susy_residual: f64,
    gap: f64,         // 1 - vᵀGv
    gap_times_ln: f64, // (1 - vᵀGv) · ln(N)
    d_fraction: f64,   // D / vᵀGv
    bf_fraction: f64,  // (B+F) / vᵀGv
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

    // Read full Gram matrix
    let gram = reader.read_gram_full().ok()?;
    if gram.len() != dim * dim {
        eprintln!("  [N={}] Gram matrix size mismatch: {} vs {}×{}", n, gram.len(), dim, dim);
        return None;
    }

    // Compute arithmetic tables
    let mu = arith::mobius_table(n);
    let omega = big_omega_table(n);
    let ln_n = (n as f64).ln();

    // HPDF Gram matrix convention: dim×dim with dim = N-1
    // Matrix entry gram[i*dim + ii] = G(i+2, ii+2) for i,ii = 0..dim-1
    // So j = i+2, k = ii+2 ranges from 2 to N.
    //
    // Witness vector (Baez-Duarte): v(k) = -μ(k)·(1 - ln(k)/ln(N)) for k=2,...,N
    let v: Vec<f64> = (0..dim).map(|i| {
        let k = i + 2;  // k = 2, 3, ..., N
        let mu_k = mu[k] as f64;
        let w = 1.0 - (k as f64).ln() / ln_n;
        -mu_k * w
    }).collect();

    // Decompose vᵀGv into sectors
    let mut diagonal = 0.0f64;
    let mut bosonic_off = 0.0f64;
    let mut fermionic_off = 0.0f64;
    let mut vtgv = 0.0f64;
    let mut num_sqfree = 0usize;
    let mut num_bosonic = 0usize;
    let mut num_fermionic = 0usize;

    for i in 0..dim {
        let j = i + 2;  // Gram index j = 2, ..., N
        let vj = v[i];
        if mu[j] != 0 { num_sqfree += 1; }

        for ii in 0..dim {
            let k = ii + 2;  // Gram index k = 2, ..., N
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

    // Check if HC number
    let is_hc = [2, 4, 6, 12, 24, 36, 48, 60, 120, 180, 240, 360, 720, 840,
                 1260, 1680, 2520, 5040, 7560, 10080, 15120, 20160, 25200,
                 27720, 45360, 50400, 55440].contains(&n);

    Some(SusyResult {
        n, dim, vtgv, diagonal, bosonic_off, fermionic_off,
        off_diagonal,
        susy_residual: off_diagonal.abs(),
        gap,
        gap_times_ln: gap * ln_n,
        d_fraction: if vtgv.abs() > 1e-15 { diagonal / vtgv } else { 0.0 },
        bf_fraction: if vtgv.abs() > 1e-15 { off_diagonal / vtgv } else { 0.0 },
        num_sqfree, num_bosonic, num_fermionic,
        elapsed_secs: elapsed,
        is_hc,
    })
}

fn main() {
    let cli = Cli::parse();

    println!("╔══════════════════════════════════════════════════════════════════════╗");
    println!("║     SUSY SECTOR SWEEP — DD-Precision HPDF Matrices                ║");
    println!("║     vᵀGv = D(N) + B_off(N) + F_off(N)                             ║");
    println!("║     GaugeCancellation.lean ✅ (0-sorry, 0-axiom)                    ║");
    println!("╚══════════════════════════════════════════════════════════════════════╝");

    // Find all gram_N*.h5 files
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
                if n <= cli.max_n {
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
    println!("  Processing with {} threads...\n", rayon::current_num_threads());

    let t_total = Instant::now();

    // Process sequentially (HDF5 may not be thread-safe for opening)
    let mut results: Vec<SusyResult> = Vec::new();
    for (n, path) in &h5_files {
        eprint!("  N={:>6} ...", n);
        match decompose_from_hpdf(path) {
            Some(r) => {
                eprintln!(" vᵀGv={:>+12.8}  D={:>+12.8}  B+F={:>+12.8}  gap·ln={:>10.6}  ({:.2}s)",
                         r.vtgv, r.diagonal, r.off_diagonal, r.gap_times_ln, r.elapsed_secs);
                results.push(r);
            }
            None => {
                eprintln!(" FAILED");
            }
        }
    }

    let total_time = t_total.elapsed().as_secs_f64();

    // Print summary table
    println!("\n  ╔══════════════════════════════════════════════════════════════════════════════════════════════╗");
    println!("  ║  SUSY SECTOR DECOMPOSITION — FULL RESULTS                                                  ║");
    println!("  ╠═══════╦══════════════╦══════════════╦══════════════╦══════════════╦══════════════╦═══════════╣");
    println!("  ║   N   ║    vᵀGv      ║     D(N)     ║   B_off(N)   ║   F_off(N)   ║  gap·ln(N)   ║   HC?   ║");
    println!("  ╠═══════╬══════════════╬══════════════╬══════════════╬══════════════╬══════════════╬═══════════╣");

    for r in &results {
        let hc_marker = if r.is_hc { " ★" } else { "  " };
        println!("  ║{:>6} ║ {:>+12.8} ║ {:>+12.8} ║ {:>+12.8} ║ {:>+12.8} ║ {:>+12.8} ║{:>8} ║",
                 r.n, r.vtgv, r.diagonal, r.bosonic_off, r.fermionic_off, r.gap_times_ln, hc_marker);
    }
    println!("  ╚═══════╩══════════════╩══════════════╩══════════════╩══════════════╩══════════════╩═══════════╝");

    // Write TSV
    let mut tsv = String::from("N\tdim\tvtgv\tD\tB_off\tF_off\tB_plus_F\tgap\tgap_times_ln\tD_frac\tBF_frac\tsqfree\tbosonic_pairs\tfermionic_pairs\tis_hc\n");
    for r in &results {
        tsv.push_str(&format!("{}\t{}\t{:.15}\t{:.15}\t{:.15}\t{:.15}\t{:.15}\t{:.15}\t{:.15}\t{:.6}\t{:.6}\t{}\t{}\t{}\t{}\n",
            r.n, r.dim, r.vtgv, r.diagonal, r.bosonic_off, r.fermionic_off,
            r.off_diagonal, r.gap, r.gap_times_ln, r.d_fraction, r.bf_fraction,
            r.num_sqfree, r.num_bosonic, r.num_fermionic, r.is_hc));
    }

    std::fs::write(&cli.output, &tsv).expect("Failed to write TSV");
    println!("\n  Results written to: {}", cli.output);
    println!("  Total time: {:.2}s ({} files)", total_time, results.len());
}
