//! ═══════════════════════════════════════════════════════════════════════════
//!  BILINEAR PROBE — Anatomizing the Gram Quadratic Form via HPDF Cache
//!
//!  Loads pre-computed Gram matrices from .h5 files and decomposes vᵀGv
//!  into structural components to understand WHERE bilinear Möbius
//!  cancellation fails.
//! ═══════════════════════════════════════════════════════════════════════════

use cathedral_utils::arith;
use cathedral_utils::hpdf::reader::HpdfReader;
use cathedral_utils::mertens;
use serde::Serialize;
use std::path::PathBuf;
use std::time::Instant;

/// HPDF cache directory (relative to crate root)
const HPDF_DIR: &str = "../cache/hpdf";

/// Max N for full-matrix loading (RAM limit ~24 GB for 55440)
const MAX_FULL_LOAD_N: usize = 55_440;

// ═══════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════

#[derive(Serialize)]
struct BilinearDecomposition {
    n: usize,
    dim: usize,
    vtgv_total: f64,
    excess: f64,
    // Block decomposition
    diagonal: f64,
    near_offdiag: f64,
    far_offdiag: f64,
    near_bandwidth: usize,
    // Sign analysis
    offdiag_positive_sum: f64,
    offdiag_negative_sum: f64,
    offdiag_cancellation_ratio: f64,
    // GCD decomposition (top buckets)
    gcd_contributions: Vec<GcdBucket>,
    // Ratio decomposition
    ratio_contributions: Vec<RatioBucket>,
    // Squarefree
    both_squarefree_contribution: f64,
    has_square_contribution: f64,
    // Alternative tapers
    fejer_vtgv: f64,
    flat_vtgv: f64,
    // PNT reference
    s1_mertens: f64,
    s1_tapered: f64,
    btv: f64,
    load_time_secs: f64,
    compute_time_secs: f64,
}

#[derive(Serialize)]
struct GcdBucket { gcd_value: usize, contribution: f64, pair_count: usize }

#[derive(Serialize)]
struct RatioBucket { ratio_floor: usize, contribution: f64, pair_count: usize }

#[derive(Serialize)]
struct ProbeResult {
    experiment: String,
    timestamp: String,
    max_n: usize,
    total_time_secs: f64,
    decompositions: Vec<BilinearDecomposition>,
}

// ═══════════════════════════════════════════════════════════════
// TAPER + WEIGHT HELPERS
// ═══════════════════════════════════════════════════════════════

fn log_taper(k: usize, n: usize) -> f64 {
    if k >= n || k == 0 { return 0.0; }
    (1.0 - (k as f64).ln() / (n as f64).ln()).max(0.0)
}

fn fejer_taper(k: usize, n: usize) -> f64 {
    if k >= n || k == 0 { return 0.0; }
    1.0 - (k as f64) / (n as f64)
}

fn mean_entry(k: usize) -> f64 {
    if k == 0 { return 0.0; }
    let kf = k as f64;
    (kf.ln() + 1.0 - 0.5772156649015329) / kf
}

fn near_bandwidth(n: usize) -> usize { ((n as f64).sqrt() as usize).max(2) }

// ═══════════════════════════════════════════════════════════════
// PROBE COMPUTATION (on loaded Gram matrix)
// ═══════════════════════════════════════════════════════════════

fn probe_at_n(
    n: usize,
    mu: &[i8],
    gram: &[f64],   // dim×dim row-major, G[i*dim+j] = G(i+2, j+2)
    gram_dim: usize,
    load_time: f64,
) -> BilinearDecomposition {
    let t0 = Instant::now();
    let dim = n - 1;
    let bw = near_bandwidth(n);

    // Weights: witness_vector gives dim entries for k=1..N-1
    let log_w = mertens::witness_vector(n, mu);
    let fejer_w: Vec<f64> = (0..dim).map(|i| -(mu[i+1] as f64) * fejer_taper(i+1, n)).collect();
    let flat_w: Vec<f64> = (0..dim).map(|i| -(mu[i+1] as f64)).collect();

    // Gram accessor: ki,kj are absolute (2 ≤ ki,kj ≤ N-1)
    let g = |ki: usize, kj: usize| -> f64 {
        gram[(ki - 2) * gram_dim + (kj - 2)]
    };
    let w = |k: usize| -> f64 { log_w[k - 1] };

    // k=1 self-contribution (not in Gram matrix)
    let g1_self = 1.0 - 0.5772156649015329;

    // === TOTAL vᵀGv ===
    let mut vtgv = w(1) * g1_self * w(1);
    for ki in 2..n { for kj in 2..n { vtgv += w(ki) * g(ki, kj) * w(kj); } }

    // === DIAGONAL ===
    let mut diagonal = w(1) * g1_self * w(1);
    for ki in 2..n { diagonal += w(ki) * g(ki, ki) * w(ki); }

    // === NEAR vs FAR OFF-DIAGONAL + SIGN ===
    let (mut near, mut far) = (0.0, 0.0);
    let (mut pos, mut neg) = (0.0, 0.0);
    for ki in 2..n {
        for kj in 2..n {
            if ki == kj { continue; }
            let c = w(ki) * g(ki, kj) * w(kj);
            let dist = ki.abs_diff(kj);
            if dist <= bw { near += c; } else { far += c; }
            if c > 0.0 { pos += c; } else { neg += c; }
        }
    }

    // === GCD DECOMPOSITION ===
    let max_gcd = dim.min(20);
    let mut gc = vec![0.0f64; max_gcd + 1];
    let mut gn = vec![0usize; max_gcd + 1];
    for ki in 2..n {
        for kj in (ki+1)..n {
            let gv = arith::gcd(ki, kj).min(max_gcd);
            gc[gv] += 2.0 * w(ki) * g(ki, kj) * w(kj);
            gn[gv] += 1;
        }
    }
    for ki in 2..n { let b = ki.min(max_gcd); gc[b] += w(ki)*g(ki,ki)*w(ki); gn[b] += 1; }

    let gcd_contributions: Vec<GcdBucket> = (1..=max_gcd)
        .filter(|&i| gn[i] > 0)
        .map(|i| GcdBucket { gcd_value: i, contribution: gc[i], pair_count: gn[i] })
        .collect();

    // === RATIO DECOMPOSITION ===
    let max_ratio = 10;
    let mut rc = vec![0.0f64; max_ratio + 2];
    let mut rn = vec![0usize; max_ratio + 2];
    for ki in 2..n {
        for kj in (ki+1)..n {
            let b = (kj as f64 / ki as f64).floor() as usize;
            let b = b.min(max_ratio + 1);
            rc[b] += 2.0 * w(ki) * g(ki, kj) * w(kj);
            rn[b] += 1;
        }
    }
    let ratio_contributions: Vec<RatioBucket> = (1..=(max_ratio+1))
        .filter(|&i| rn[i] > 0)
        .map(|i| RatioBucket { ratio_floor: i, contribution: rc[i], pair_count: rn[i] })
        .collect();

    // === SQUAREFREE ===
    let (mut sqf, mut nsq) = (0.0, 0.0);
    for ki in 2..n {
        for kj in 2..n {
            let c = w(ki) * g(ki, kj) * w(kj);
            if mu[ki] != 0 && mu[kj] != 0 { sqf += c; } else { nsq += c; }
        }
    }

    // === ALT TAPERS ===
    let (mut fv, mut rv) = (0.0, 0.0);
    for ki in 2..n {
        for kj in 2..n {
            fv += fejer_w[ki-1] * g(ki, kj) * fejer_w[kj-1];
            rv += flat_w[ki-1] * g(ki, kj) * flat_w[kj-1];
        }
    }

    // === PNT SUMS ===
    let s1 = mertens::pnt_s1(mu, n - 1);
    let s1t: f64 = (1..n).map(|k| (mu[k] as f64) * log_taper(k, n) / k as f64).sum();
    let bv: f64 = (0..dim).map(|i| log_w[i] * mean_entry(i + 1)).sum();

    let cancel = if pos > 0.0 { neg.abs() / pos } else { 0.0 };
    let ct = t0.elapsed().as_secs_f64();

    BilinearDecomposition {
        n, dim, vtgv_total: vtgv, excess: vtgv - 1.0,
        diagonal, near_offdiag: near, far_offdiag: far, near_bandwidth: bw,
        offdiag_positive_sum: pos, offdiag_negative_sum: neg,
        offdiag_cancellation_ratio: cancel,
        gcd_contributions, ratio_contributions,
        both_squarefree_contribution: sqf, has_square_contribution: nsq,
        fejer_vtgv: fv, flat_vtgv: rv,
        s1_mertens: s1, s1_tapered: s1t, btv: bv,
        load_time_secs: load_time, compute_time_secs: ct,
    }
}

// ═══════════════════════════════════════════════════════════════
// REPORTING
// ═══════════════════════════════════════════════════════════════

fn print_summary(d: &BilinearDecomposition) {
    let ln_n = (d.n as f64).ln();
    println!("\n╔══════════════════════════════════════════════════════════════╗");
    println!("║  N = {:>6}  (dim={}, logN={:.3}, load={:.1}s, calc={:.1}s)", d.n, d.dim, ln_n, d.load_time_secs, d.compute_time_secs);
    println!("╠══════════════════════════════════════════════════════════════╣");
    println!("║  vᵀGv = {:>12.6}  excess = {:>+.6}", d.vtgv_total, d.excess);
    println!("╠──────────────────────────────────────────────────────────────╣");
    println!("║  BLOCKS (bw={})", d.near_bandwidth);
    println!("║    diag     = {:>12.6}  ({:>6.2}%)", d.diagonal, 100.0*d.diagonal/d.vtgv_total);
    println!("║    near off = {:>12.6}  ({:>6.2}%)", d.near_offdiag, 100.0*d.near_offdiag/d.vtgv_total);
    println!("║    far  off = {:>12.6}  ({:>6.2}%)", d.far_offdiag, 100.0*d.far_offdiag/d.vtgv_total);
    println!("╠──────────────────────────────────────────────────────────────╣");
    println!("║  SIGN: pos={:.6} neg={:.6} cancel={:.6}", d.offdiag_positive_sum, d.offdiag_negative_sum, d.offdiag_cancellation_ratio);
    println!("║  SQFREE: {:.6} ({:.1}%)  NON-SQFREE: {:.6} ({:.1}%)",
        d.both_squarefree_contribution, 100.0*d.both_squarefree_contribution/d.vtgv_total,
        d.has_square_contribution, 100.0*d.has_square_contribution/d.vtgv_total);
    println!("║  TAPERS: log={:.6}  fejér={:.6}  flat={:.6}", d.vtgv_total, d.fejer_vtgv, d.flat_vtgv);
    println!("║  GCD top-5:");
    let mut gs: Vec<_> = d.gcd_contributions.iter().collect();
    gs.sort_by(|a,b| b.contribution.abs().partial_cmp(&a.contribution.abs()).unwrap());
    for g in gs.iter().take(5) {
        println!("║    gcd={:>3}: {:>+12.6}  ({} pairs)", g.gcd_value, g.contribution, g.pair_count);
    }
    println!("║  RATIO bands:");
    for r in &d.ratio_contributions {
        let l = if r.ratio_floor <= 10 { format!("[{},{})", r.ratio_floor, r.ratio_floor+1) } else { "≥11".into() };
        println!("║    {}: {:>+12.6}  ({} pairs)", l, r.contribution, r.pair_count);
    }
    println!("║  PNT: S₁={:.8}  S₁tap={:.8}  bᵀv={:.8}", d.s1_mertens, d.s1_tapered, d.btv);
    println!("╚══════════════════════════════════════════════════════════════╝");
}

// ═══════════════════════════════════════════════════════════════
// MAIN — scan HPDF cache directory
// ═══════════════════════════════════════════════════════════════

fn main() {
    let t0 = Instant::now();

    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║   BILINEAR PROBE v2 — HPDF-Accelerated Gram Decomposition ║");
    println!("╚══════════════════════════════════════════════════════════════╝");

    // Discover .h5 files
    let hpdf_dir = PathBuf::from(HPDF_DIR);
    let mut h5_files: Vec<(usize, PathBuf)> = std::fs::read_dir(&hpdf_dir)
        .expect("Cannot read HPDF cache dir")
        .filter_map(|e| {
            let p = e.ok()?.path();
            let name = p.file_stem()?.to_str()?;
            if !name.starts_with("gram_N") { return None; }
            let n: usize = name.strip_prefix("gram_N")?.parse().ok()?;
            if !(12..=MAX_FULL_LOAD_N).contains(&n) { return None; }
            Some((n, p))
        })
        .collect();
    h5_files.sort_by_key(|x| x.0);

    println!("\nFound {} HPDF files (N={}..{})\n",
        h5_files.len(), h5_files.first().map(|x|x.0).unwrap_or(0),
        h5_files.last().map(|x|x.0).unwrap_or(0));

    // Build Möbius table for largest N
    let max_n = h5_files.last().map(|x| x.0).unwrap_or(100);
    println!("[1/2] Computing Möbius table up to {}...", max_n);
    let mu = arith::mobius_table(max_n + 1);

    println!("[2/2] Processing {} files...\n", h5_files.len());

    let mut decompositions = Vec::new();

    for (n, path) in &h5_files {
        let n = *n;
        let dim = n - 1;
        let mem_gb = (dim * dim * 8) as f64 / 1e9;

        // Skip matrices that won't fit in RAM comfortably
        if mem_gb > 25.0 {
            println!("  ⚠ Skipping N={} ({:.1} GB) — too large for full load", n, mem_gb);
            continue;
        }

        print!("  Loading N={} ({:.1} GB)...", n, mem_gb);
        let t_load = Instant::now();

        let reader = match HpdfReader::open(path) {
            Ok(r) => r,
            Err(e) => { println!(" ERROR: {}", e); continue; }
        };

        let gram = match reader.read_gram_full() {
            Ok(g) => g,
            Err(e) => { println!(" ERROR reading gram: {}", e); continue; }
        };

        let load_secs = t_load.elapsed().as_secs_f64();
        let gram_dim = reader.dim();
        println!(" loaded in {:.1}s (dim={})", load_secs, gram_dim);

        let d = probe_at_n(n, &mu, &gram, gram_dim, load_secs);
        print_summary(&d);
        decompositions.push(d);

        // Free gram matrix before next iteration
        drop(gram);
    }

    // Save results
    let result = ProbeResult {
        experiment: "Bilinear Probe v2 — HPDF-Accelerated Gram Decomposition".into(),
        timestamp: format!("unix:{}", std::time::SystemTime::now()
            .duration_since(std::time::SystemTime::UNIX_EPOCH).unwrap().as_secs()),
        max_n,
        total_time_secs: t0.elapsed().as_secs_f64(),
        decompositions,
    };

    std::fs::create_dir_all("results").ok();
    let json = serde_json::to_string_pretty(&result).unwrap();
    std::fs::write("results/bilinear_probe_v2.json", &json).expect("write failed");

    println!("\n════════════════════════════════════════════════════════════════");
    println!("  Results: results/bilinear_probe_v2.json");
    println!("  Total:   {:.1}s", t0.elapsed().as_secs_f64());
    println!("════════════════════════════════════════════════════════════════");
}
