//! ═══════════════════════════════════════════════════════════════════════
//!  RANK-1 CROSS-CLASS INTERFERENCE EXPERIMENT
//!  The Cathedral — Cayley-Dickson Partition Analysis
//!
//!  Tests the rank-1 interference structure at THREE levels
//!  of the Cayley-Dickson tower:
//!
//!    mod 2  — Parity (ℂ level, Liouville λ(k) = (-1)^Ω(k))
//!    mod 4  — Quaternionic (ℍ level, quadratic residue structure)
//!    mod 8  — Octonionic (𝕆 level, last division algebra)
//!
//!  For each partition, measures:
//!    1. SVD of each cross-class block: rank-1 accuracy σ₁²/‖block‖²_F
//!    2. Singular value gap: σ₁/σ₂ (should grow if rank-1 emerges)
//!    3. Eigenvalue comparison: λ_min(G) vs λ_min(G^block)
//!    4. Large sieve ratio R = |v^T G^cross v| / (v^T G^block v)
//!    5. Trend analysis: does accuracy INCREASE or DECREASE with N?
//!
//!  Parallelized via rayon. Exact Vasyunin cotangent formula.
//! ═══════════════════════════════════════════════════════════════════════

use nalgebra::{DMatrix, DVector, SymmetricEigen, SVD};
use rayon::prelude::*;
use std::sync::Mutex;
use std::collections::HashMap;
use std::time::Instant;

// ═══════════════════════════════════════════════════════════════════════
// ARITHMETIC PRIMITIVES
// ═══════════════════════════════════════════════════════════════════════

fn gcd(a: usize, b: usize) -> usize {
    let (mut a, mut b) = (a, b);
    while b != 0 { let t = b; b = a % b; a = t; }
    a
}

/// Ω(n) = number of prime factors with multiplicity
fn big_omega(mut n: usize) -> usize {
    let mut count = 0;
    let mut d = 2;
    while d * d <= n {
        while n % d == 0 { count += 1; n /= d; }
        d += 1;
    }
    if n > 1 { count += 1; }
    count
}

/// Liouville function: λ(n) = (-1)^Ω(n)
fn liouville(n: usize) -> i32 {
    if big_omega(n) % 2 == 0 { 1 } else { -1 }
}

// ═══════════════════════════════════════════════════════════════════════
// EXACT VASYUNIN COTANGENT FORMULA
// ═══════════════════════════════════════════════════════════════════════

const EULER_GAMMA: f64 = 0.5772156649015328606;

fn vasyunin_sum(a: usize, b: usize) -> f64 {
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
    {
        let guard = cache.lock().unwrap();
        if let Some(&val) = guard.get(&(a, b)) { return val; }
    }
    let val = vasyunin_sum(a, b);
    { let mut guard = cache.lock().unwrap(); guard.insert((a, b), val); }
    val
}

fn gram_entry(j: usize, k: usize, cache: &VCache) -> f64 {
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

// ═══════════════════════════════════════════════════════════════════════
// PARTITION SCHEMES
// ═══════════════════════════════════════════════════════════════════════

/// Partition type — which level of the Cayley-Dickson tower
#[derive(Debug, Clone, Copy)]
enum Partition {
    Parity,      // mod 2 — Liouville λ(k) = (-1)^Ω(k)
    Quaternionic, // mod 4 — k mod 4
    Octonionic,   // mod 8 — k mod 8
}

impl Partition {
    fn name(&self) -> &'static str {
        match self {
            Partition::Parity => "Parity (mod 2, Liouville)",
            Partition::Quaternionic => "Quaternionic (mod 4)",
            Partition::Octonionic => "Octonionic (mod 8)",
        }
    }

    fn short_name(&self) -> &'static str {
        match self {
            Partition::Parity => "mod2",
            Partition::Quaternionic => "mod4",
            Partition::Octonionic => "mod8",
        }
    }

    fn num_classes(&self) -> usize {
        match self {
            Partition::Parity => 2,
            Partition::Quaternionic => 4,
            Partition::Octonionic => 8,
        }
    }

    fn num_cross_pairs(&self) -> usize {
        let c = self.num_classes();
        c * (c - 1) / 2
    }

    /// Classify index k (the actual integer, not the matrix index).
    /// For Parity: class = Ω(k) mod 2 (0 = even parity, 1 = odd parity)
    /// For Quaternionic: class = k mod 4
    /// For Octonionic: class = k mod 8
    fn classify(&self, k: usize) -> usize {
        match self {
            Partition::Parity => big_omega(k) % 2,
            Partition::Quaternionic => k % 4,
            Partition::Octonionic => k % 8,
        }
    }

    /// Partition indices {0, 1, ..., dim-1} (mapping to k = idx+2) into classes.
    fn partition(&self, n: usize) -> Vec<Vec<usize>> {
        let dim = n - 1;
        let nc = self.num_classes();
        let mut classes = vec![Vec::new(); nc];
        for idx in 0..dim {
            let k = idx + 2;
            let c = self.classify(k);
            classes[c].push(idx);
        }
        classes
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MATRIX CONSTRUCTION (parallelized)
// ═══════════════════════════════════════════════════════════════════════

fn build_gram_matrix(n: usize, cache: &VCache) -> DMatrix<f64> {
    let dim = n - 1;
    let pairs: Vec<(usize, usize)> = (0..dim)
        .flat_map(|i| (i..dim).map(move |j| (i, j)))
        .collect();

    let entries: Vec<(usize, usize, f64)> = pairs
        .par_iter()
        .map(|&(i, j)| {
            let val = gram_entry(i + 2, j + 2, cache);
            (i, j, val)
        })
        .collect();

    let mut g = DMatrix::zeros(dim, dim);
    for (i, j, val) in entries {
        g[(i, j)] = val;
        g[(j, i)] = val;
    }
    g
}

fn extract_submatrix(g: &DMatrix<f64>, rows: &[usize], cols: &[usize]) -> DMatrix<f64> {
    DMatrix::from_fn(rows.len(), cols.len(), |i, j| g[(rows[i], cols[j])])
}

// ═══════════════════════════════════════════════════════════════════════
// SVD ANALYSIS
// ═══════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone)]
struct BlockSVD {
    class1: usize,
    class2: usize,
    rows: usize,
    cols: usize,
    rank1_accuracy: f64,
    sv_gap: f64,
    sigma1: f64,
}

fn analyze_cross_block(g: &DMatrix<f64>, c1: usize, c2: usize, classes: &[Vec<usize>]) -> BlockSVD {
    let rows = &classes[c1];
    let cols = &classes[c2];
    if rows.is_empty() || cols.is_empty() {
        return BlockSVD { class1: c1, class2: c2, rows: 0, cols: 0,
            rank1_accuracy: 1.0, sv_gap: f64::INFINITY, sigma1: 0.0 };
    }

    let block = extract_submatrix(g, rows, cols);
    let total_sq: f64 = block.iter().map(|x| x * x).sum();
    let svd = SVD::new(block, false, false);
    let mut svs: Vec<f64> = svd.singular_values.iter().cloned().collect();
    svs.sort_by(|a, b| b.partial_cmp(a).unwrap());

    let sigma1_sq = if !svs.is_empty() { svs[0] * svs[0] } else { 0.0 };
    let rank1_accuracy = if total_sq > 0.0 { sigma1_sq / total_sq } else { 1.0 };
    let sv_gap = if svs.len() >= 2 && svs[1] > 1e-15 { svs[0] / svs[1] } else { f64::INFINITY };

    BlockSVD {
        class1: c1, class2: c2, rows: rows.len(), cols: cols.len(),
        rank1_accuracy, sv_gap, sigma1: svs.first().cloned().unwrap_or(0.0),
    }
}

// ═══════════════════════════════════════════════════════════════════════
// EIGENVALUE / EIGENVECTOR ANALYSIS
// ═══════════════════════════════════════════════════════════════════════

fn min_eigenvalue(m: &DMatrix<f64>) -> f64 {
    let eig = SymmetricEigen::new(m.clone());
    eig.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min)
}

fn eigenvalues_sorted(m: &DMatrix<f64>) -> Vec<f64> {
    let eig = SymmetricEigen::new(m.clone());
    let mut vals: Vec<f64> = eig.eigenvalues.iter().cloned().collect();
    vals.sort_by(|a, b| a.partial_cmp(b).unwrap());
    vals
}

fn min_eigenvector(m: &DMatrix<f64>) -> (f64, DVector<f64>) {
    let eig = SymmetricEigen::new(m.clone());
    let mut min_idx = 0;
    let mut min_val = f64::INFINITY;
    for (i, &v) in eig.eigenvalues.iter().enumerate() {
        if v < min_val { min_val = v; min_idx = i; }
    }
    (min_val, eig.eigenvectors.column(min_idx).into_owned())
}

fn large_sieve_ratio(g_block: &DMatrix<f64>, g_cross: &DMatrix<f64>, v: &DVector<f64>) -> f64 {
    let diag_form = v.dot(&(g_block * v));
    let cross_form = v.dot(&(g_cross * v));
    if diag_form.abs() < 1e-30 { return f64::NAN; }
    cross_form.abs() / diag_form
}

// ═══════════════════════════════════════════════════════════════════════
// PARITY-SPECIFIC: Liouville correlation with min eigenvector
// ═══════════════════════════════════════════════════════════════════════

fn liouville_correlation(n: usize, v: &DVector<f64>) -> f64 {
    let dim = n - 1;
    // Build normalized Liouville vector
    let liou: Vec<f64> = (0..dim).map(|i| liouville(i + 2) as f64).collect();
    let norm_l: f64 = liou.iter().map(|x| x * x).sum::<f64>().sqrt();
    let norm_v: f64 = v.iter().map(|x| x * x).sum::<f64>().sqrt();
    if norm_l < 1e-15 || norm_v < 1e-15 { return 0.0; }
    let dot: f64 = liou.iter().zip(v.iter()).map(|(a, b)| a * b).sum();
    (dot / (norm_l * norm_v)).abs()
}

// ═══════════════════════════════════════════════════════════════════════
// SINGLE EXPERIMENT (one N, one partition)
// ═══════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone)]
struct ExperimentResult {
    n: usize,
    partition: String,
    num_classes: usize,
    class_sizes: Vec<usize>,
    lmin_g: f64,
    lmin_block: f64,
    block_over_g: f64,
    r_ratio: f64,
    min_accuracy: f64,
    mean_accuracy: f64,
    max_accuracy: f64,
    min_sv_gap: f64,
    max_sv_gap: f64,
    liouville_corr: f64,
    elapsed: f64,
    blocks: Vec<BlockSVD>,
}

fn run_single(n: usize, part: Partition, g: &DMatrix<f64>) -> ExperimentResult {
    let t0 = Instant::now();
    let dim = n - 1;
    let classes = part.partition(n);
    let nc = part.num_classes();
    let class_sizes: Vec<usize> = classes.iter().map(|c| c.len()).collect();

    // Build G^block and G^cross
    let mut g_block = DMatrix::zeros(dim, dim);
    let mut g_cross = DMatrix::zeros(dim, dim);
    for i in 0..dim {
        for j in 0..dim {
            let ci = part.classify(i + 2);
            let cj = part.classify(j + 2);
            if ci == cj {
                g_block[(i, j)] = g[(i, j)];
            } else {
                g_cross[(i, j)] = g[(i, j)];
            }
        }
    }

    // Eigenvalues
    let lmin_g = min_eigenvalue(g);
    let lmin_block = min_eigenvalue(&g_block);

    // Min eigenvector of G
    let (_, v_min) = min_eigenvector(g);
    let r_ratio = large_sieve_ratio(&g_block, &g_cross, &v_min);
    let liouville_corr = liouville_correlation(n, &v_min);

    // SVD of all cross-class blocks (parallel)
    let pairs: Vec<(usize, usize)> = (0..nc)
        .flat_map(|i| ((i+1)..nc).map(move |j| (i, j)))
        .collect();

    let blocks: Vec<BlockSVD> = pairs.par_iter()
        .map(|&(c1, c2)| analyze_cross_block(g, c1, c2, &classes))
        .collect();

    // Summary stats
    let valid_blocks: Vec<&BlockSVD> = blocks.iter()
        .filter(|b| b.rows > 0 && b.cols > 0).collect();
    let min_accuracy = valid_blocks.iter().map(|b| b.rank1_accuracy)
        .fold(f64::INFINITY, f64::min);
    let max_accuracy = valid_blocks.iter().map(|b| b.rank1_accuracy)
        .fold(f64::NEG_INFINITY, f64::max);
    let mean_accuracy = if valid_blocks.is_empty() { 0.0 } else {
        valid_blocks.iter().map(|b| b.rank1_accuracy).sum::<f64>() / valid_blocks.len() as f64
    };
    let min_sv_gap = valid_blocks.iter().filter(|b| b.sv_gap.is_finite())
        .map(|b| b.sv_gap).fold(f64::INFINITY, f64::min);
    let max_sv_gap = valid_blocks.iter().filter(|b| b.sv_gap.is_finite())
        .map(|b| b.sv_gap).fold(f64::NEG_INFINITY, f64::max);

    ExperimentResult {
        n, partition: part.short_name().to_string(), num_classes: nc,
        class_sizes, lmin_g, lmin_block,
        block_over_g: lmin_block / lmin_g, r_ratio,
        min_accuracy, mean_accuracy, max_accuracy,
        min_sv_gap, max_sv_gap, liouville_corr,
        elapsed: t0.elapsed().as_secs_f64(), blocks,
    }
}

// ═══════════════════════════════════════════════════════════════════════
// PRINT RESULTS
// ═══════════════════════════════════════════════════════════════════════

fn print_result(r: &ExperimentResult) {
    println!("  ┌─ {} │ N={} │ {:.1}s ─────────────────────────────┐",
        r.partition, r.n, r.elapsed);
    println!("  │  Classes: {} │ Sizes: {:?}", r.num_classes, r.class_sizes);
    println!("  │  λ_min(G)={:.8}  λ_min(block)={:.8}  ratio={:.3}",
        r.lmin_g, r.lmin_block, r.block_over_g);
    println!("  │  R = {:.8}  │  R<1? {}  │  Liouville corr: {:.6}",
        r.r_ratio,
        if r.r_ratio < 1.0 { "✅" } else { "❌" },
        r.liouville_corr);
    println!("  │  Rank-1 accuracy: min={:.4}%  mean={:.4}%  max={:.4}%",
        r.min_accuracy * 100.0, r.mean_accuracy * 100.0, r.max_accuracy * 100.0);
    if r.min_sv_gap.is_finite() {
        println!("  │  σ₁/σ₂ gap: min={:.3}  max={:.3}",
            r.min_sv_gap, r.max_sv_gap);
    }
    // Per-block detail (compact)
    if r.blocks.len() <= 6 {
        for b in &r.blocks {
            if b.rows > 0 && b.cols > 0 {
                println!("  │    ({},{}) {}×{}: acc={:.4}%  gap={:.3}  σ₁={:.4e}",
                    b.class1, b.class2, b.rows, b.cols,
                    b.rank1_accuracy * 100.0,
                    if b.sv_gap.is_finite() { b.sv_gap } else { f64::NAN },
                    b.sigma1);
            }
        }
    }
    println!("  └───────────────────────────────────────────────────────┘");
}

// ═══════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════

fn main() {
    let t_start = Instant::now();

    println!();
    println!("╔════════════════════════════════════════════════════════════════╗");
    println!("║  CAYLEY-DICKSON PARTITION EXPERIMENT                          ║");
    println!("║  mod 2 (Parity) · mod 4 (Quaternionic) · mod 8 (Octonionic)  ║");
    println!("║  Exact Vasyunin formula · {} cores                            ║",
        rayon::current_num_threads());
    println!("╚════════════════════════════════════════════════════════════════╝");

    let cache: VCache = Mutex::new(HashMap::new());
    let sizes = vec![50, 100, 200, 300, 500, 800, 1000];
    let partitions = [Partition::Parity, Partition::Quaternionic, Partition::Octonionic];

    // Store all results grouped by partition type
    let mut all_results: HashMap<String, Vec<ExperimentResult>> = HashMap::new();
    for p in &partitions {
        all_results.insert(p.short_name().to_string(), Vec::new());
    }

    for &n in &sizes {
        let dim = n - 1;
        eprintln!("  Building {}×{} Gram matrix (N={})...", dim, dim, n);
        let g = build_gram_matrix(n, &cache);
        eprintln!("    Done.");

        println!("\n{}", "═".repeat(70));
        println!("  N = {} (dim = {})", n, dim);
        println!("{}", "═".repeat(70));

        for &part in &partitions {
            let result = run_single(n, part, &g);
            print_result(&result);
            all_results.get_mut(part.short_name()).unwrap().push(result);
        }
    }

    // ─── Grand Comparison ─────────────────────────────────────────
    println!("\n\n{}", "═".repeat(90));
    println!("  GRAND COMPARISON — CAYLEY-DICKSON TOWER");
    println!("{}", "═".repeat(90));

    for part in &partitions {
        let results = all_results.get(part.short_name()).unwrap();
        println!("\n  ── {} ({} classes, {} cross-pairs) ──",
            part.name(), part.num_classes(), part.num_cross_pairs());
        println!("  {:>5} {:>11} {:>11} {:>11} {:>9} {:>9} {:>9}",
            "N", "min_acc%", "mean_acc%", "max_acc%", "min_gap", "R", "λ_corr");
        println!("  {}", "─".repeat(72));
        for r in results {
            println!("  {:>5} {:>10.4}% {:>10.4}% {:>10.4}% {:>9.3} {:>9.6} {:>9.6}",
                r.n,
                r.min_accuracy * 100.0, r.mean_accuracy * 100.0, r.max_accuracy * 100.0,
                if r.min_sv_gap.is_finite() { r.min_sv_gap } else { f64::NAN },
                r.r_ratio, r.liouville_corr);
        }
    }

    // ─── Trend Analysis ───────────────────────────────────────────
    println!("\n\n{}", "═".repeat(90));
    println!("  TREND ANALYSIS — Does rank-1 accuracy INCREASE or DECREASE?");
    println!("{}", "═".repeat(90));

    for part in &partitions {
        let results = all_results.get(part.short_name()).unwrap();
        println!("\n  ── {} ──", part.name());
        println!("  {:>5} {:>11} {:>12} {:>12}", "N", "mean_acc%", "Δ_mean", "direction");
        let mut prev = 0.0;
        for (i, r) in results.iter().enumerate() {
            let acc = r.mean_accuracy * 100.0;
            if i > 0 {
                let delta = acc - prev;
                let dir = if delta > 0.01 { "↑ INCREASING" }
                    else if delta < -0.01 { "↓ decreasing" }
                    else { "→ stable" };
                println!("  {:>5} {:>10.4}% {:>+11.4}% {:>12}", r.n, acc, delta, dir);
            } else {
                println!("  {:>5} {:>10.4}%         ---          ---", r.n, acc);
            }
            prev = acc;
        }
    }

    // ─── Singular Value Gap Scaling ───────────────────────────────
    println!("\n\n{}", "═".repeat(90));
    println!("  SINGULAR VALUE GAP σ₁/σ₂ SCALING");
    println!("{}", "═".repeat(90));

    for part in &partitions {
        let results = all_results.get(part.short_name()).unwrap();
        println!("\n  ── {} ──", part.name());
        println!("  {:>5} {:>10} {:>10} {:>10}", "N", "min_gap", "max_gap", "log(N)");
        for r in results {
            println!("  {:>5} {:>10.3} {:>10.3} {:>10.4}",
                r.n,
                if r.min_sv_gap.is_finite() { r.min_sv_gap } else { f64::NAN },
                if r.max_sv_gap.is_finite() { r.max_sv_gap } else { f64::NAN },
                (r.n as f64).ln());
        }

        // Power-law fit
        if results.len() >= 3 {
            let first = &results[1]; // skip N=50
            let last = results.last().unwrap();
            if first.min_sv_gap.is_finite() && last.min_sv_gap.is_finite()
                && first.min_sv_gap > 0.0 && last.min_sv_gap > 0.0 {
                let alpha = (last.min_sv_gap.ln() - first.min_sv_gap.ln())
                    / (last.n as f64).ln().max(1.0) - (first.n as f64).ln().max(1.0);
                let _ = alpha; // avoid unused
                let ratio = last.min_sv_gap / first.min_sv_gap;
                let n_ratio = (last.n as f64) / (first.n as f64);
                let alpha2 = ratio.ln() / n_ratio.ln();
                println!("  Power-law fit (N={} → N={}): σ₁/σ₂ ~ N^{:.4}",
                    first.n, last.n, alpha2);
            }
        }
    }

    // ─── Block-over-G ratio comparison ────────────────────────────
    println!("\n\n{}", "═".repeat(90));
    println!("  BLOCK/G EIGENVALUE RATIO (gap amplification by partition)");
    println!("{}", "═".repeat(90));
    println!("\n  {:>5} {:>12} {:>12} {:>12}", "N", "mod2", "mod4", "mod8");
    println!("  {}", "─".repeat(48));
    for i in 0..sizes.len() {
        let r2 = &all_results["mod2"][i];
        let r4 = &all_results["mod4"][i];
        let r8 = &all_results["mod8"][i];
        println!("  {:>5} {:>12.4} {:>12.4} {:>12.4}",
            r2.n, r2.block_over_g, r4.block_over_g, r8.block_over_g);
    }

    // ─── R ratio comparison ───────────────────────────────────────
    println!("\n  LARGE SIEVE RATIO R (must stay < 1 for RH)");
    println!("  {:>5} {:>12} {:>12} {:>12}", "N", "mod2", "mod4", "mod8");
    println!("  {}", "─".repeat(48));
    for i in 0..sizes.len() {
        let r2 = &all_results["mod2"][i];
        let r4 = &all_results["mod4"][i];
        let r8 = &all_results["mod8"][i];
        println!("  {:>5} {:>12.8} {:>12.8} {:>12.8}",
            r2.n, r2.r_ratio, r4.r_ratio, r8.r_ratio);
    }

    // ─── JSON Output ──────────────────────────────────────────────
    let mut json_results = serde_json::Map::new();
    json_results.insert("experiment".into(), "cayley_dickson_partition_tower".into());
    json_results.insert("date".into(), "2026-04-21".into());
    json_results.insert("threads".into(), serde_json::json!(rayon::current_num_threads()));

    for part in &partitions {
        let results = all_results.get(part.short_name()).unwrap();
        let json_entries: Vec<serde_json::Value> = results.iter().map(|r| {
            serde_json::json!({
                "N": r.n,
                "num_classes": r.num_classes,
                "lambda_min_G": r.lmin_g,
                "lambda_min_block": r.lmin_block,
                "block_over_G": r.block_over_g,
                "R_ratio": r.r_ratio,
                "rank1_min_accuracy": r.min_accuracy,
                "rank1_mean_accuracy": r.mean_accuracy,
                "rank1_max_accuracy": r.max_accuracy,
                "sv_gap_min": if r.min_sv_gap.is_finite() { r.min_sv_gap } else { -1.0 },
                "sv_gap_max": if r.max_sv_gap.is_finite() { r.max_sv_gap } else { -1.0 },
                "liouville_correlation": r.liouville_corr,
            })
        }).collect();
        json_results.insert(part.short_name().into(), serde_json::json!(json_entries));
    }

    let json_path = "results.json";
    std::fs::write(json_path,
        serde_json::to_string_pretty(&serde_json::Value::Object(json_results)).unwrap()
    ).unwrap();
    println!("\n  📁 JSON results written to {}", json_path);

    let total = t_start.elapsed().as_secs_f64();
    println!("\n  Total runtime: {:.1}s ({} cores)", total, rayon::current_num_threads());

    println!("\n  🏛️  The Cayley-Dickson tower reveals the structure of RH:");
    println!("     mod 2 = where the Liouville function lives");
    println!("     mod 4 = where quadratic residues live");
    println!("     mod 8 = the last division algebra boundary");
    println!();
}
