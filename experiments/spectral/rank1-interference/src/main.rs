//! ═══════════════════════════════════════════════════════════════════════
//!  RANK-1 CROSS-CLASS INTERFERENCE EXPERIMENT
//!  The Cathedral — Octonionic Partition Analysis
//!
//!  Tests whether the cross-class (mod 8) interaction blocks of the
//!  Gram matrix are rank-1 in the N → ∞ limit.
//!
//!  If each cross-class block M_{m1,m2} is rank-1:
//!    M_{m1,m2} ≈ σ · u ⊗ v
//!  then the infinite-dimensional spectral gap problem reduces
//!  to an 8×8 bilinear form — a finite-dimensional reduction of RH.
//!
//!  Measurements:
//!    1. SVD of each cross-class block: σ₁²/‖block‖²_F (rank-1 accuracy)
//!    2. Singular value gap: σ₁/σ₂ (should grow with N)
//!    3. Eigenvalue comparison: λ_min(G) vs λ_min(G^block)
//!    4. The 8×8 reduced interference matrix Σ(m1,m2) = σ₁(m1,m2)
//!    5. Large sieve ratio R at v_min
//!
//!  Parallelized via rayon for M2 Max (12 cores).
//!  Uses exact Vasyunin cotangent formula for Gram entries.
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

// ═══════════════════════════════════════════════════════════════════════
// EXACT VASYUNIN COTANGENT FORMULA
// ═══════════════════════════════════════════════════════════════════════

const EULER_GAMMA: f64 = 0.5772156649015328606;

/// V(a, b) = Σ_{m=1}^{a-1} {mb/a} · cot(πm/a)
/// Computed in f64 with exact integer modular arithmetic for {mb/a}.
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
        if let Some(&val) = guard.get(&(a, b)) {
            return val;
        }
    }
    let val = vasyunin_sum(a, b);
    {
        let mut guard = cache.lock().unwrap();
        guard.insert((a, b), val);
    }
    val
}

/// Exact Vasyunin cotangent formula for the Gram matrix entry G(j,k).
///
/// For j = k (diagonal):
///   G(k,k) = (ln(2π) - γ)/k - 1/k²
///
/// For j ≠ k (off-diagonal):
///   G(j,k) = [(ln(2π)-γ)/2](1/j + 1/k) + (j-k)/(2jk)·ln(k/j)
///            - π·d/(2jk)·[V(a,b) + V(b,a)] - 1/(jk)
///   where d = gcd(j,k), a = j/d, b = k/d.
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
// OCTONIONIC CLASS PARTITION (mod 8)
// ═══════════════════════════════════════════════════════════════════════

/// Octonionic class: class(k) = k mod 8 (matching Lean's octonionClass).
/// For the Gram matrix indexed by {2, 3, ..., N}, index i maps to k = i+2.
/// class(k) = k mod 8 ∈ {0, 1, 2, 3, 4, 5, 6, 7}.
fn octonion_class(k: usize) -> usize {
    k % 8
}

/// Partition the indices {0, 1, ..., dim-1} (mapping to k = idx+2)
/// into 8 classes by k mod 8.
fn partition_by_class(n: usize) -> [Vec<usize>; 8] {
    let mut classes: [Vec<usize>; 8] = Default::default();
    let dim = n - 1; // indices 0..dim-1 map to k=2..N
    for idx in 0..dim {
        let k = idx + 2;
        let c = octonion_class(k);
        classes[c].push(idx);
    }
    classes
}

// ═══════════════════════════════════════════════════════════════════════
// MATRIX CONSTRUCTION (parallelized)
// ═══════════════════════════════════════════════════════════════════════

/// Build the full (N-1)×(N-1) Gram matrix in parallel.
/// Uses the upper triangle + symmetry.
fn build_gram_matrix(n: usize, cache: &VCache) -> DMatrix<f64> {
    let dim = n - 1;
    // Compute all unique (i,j) pairs with i <= j
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

/// Extract a submatrix from G given row indices and column indices.
fn extract_submatrix(g: &DMatrix<f64>, rows: &[usize], cols: &[usize]) -> DMatrix<f64> {
    DMatrix::from_fn(rows.len(), cols.len(), |i, j| g[(rows[i], cols[j])])
}

// ═══════════════════════════════════════════════════════════════════════
// SVD ANALYSIS OF CROSS-CLASS BLOCKS
// ═══════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone)]
struct BlockSVDResult {
    class1: usize,
    class2: usize,
    rows: usize,
    cols: usize,
    singular_values: Vec<f64>,
    rank1_accuracy: f64,   // σ₁² / Σσᵢ²
    sv_gap: f64,           // σ₁ / σ₂
    frobenius_norm: f64,
}

/// Analyze a single cross-class block via SVD.
fn analyze_cross_block(
    g: &DMatrix<f64>,
    class1: usize,
    class2: usize,
    classes: &[Vec<usize>; 8],
) -> BlockSVDResult {
    let rows = &classes[class1];
    let cols = &classes[class2];

    if rows.is_empty() || cols.is_empty() {
        return BlockSVDResult {
            class1, class2,
            rows: 0, cols: 0,
            singular_values: vec![],
            rank1_accuracy: 1.0,
            sv_gap: f64::INFINITY,
            frobenius_norm: 0.0,
        };
    }

    let block = extract_submatrix(g, rows, cols);
    let frobenius_sq: f64 = block.iter().map(|x| x * x).sum();
    let frobenius_norm = frobenius_sq.sqrt();

    let svd = SVD::new(block, false, false);
    let mut svs: Vec<f64> = svd.singular_values.iter().cloned().collect();
    svs.sort_by(|a, b| b.partial_cmp(a).unwrap()); // descending

    let sigma1_sq = if !svs.is_empty() { svs[0] * svs[0] } else { 0.0 };
    let total_sq: f64 = svs.iter().map(|s| s * s).sum();
    let rank1_accuracy = if total_sq > 0.0 { sigma1_sq / total_sq } else { 1.0 };

    let sv_gap = if svs.len() >= 2 && svs[1] > 1e-15 {
        svs[0] / svs[1]
    } else {
        f64::INFINITY
    };

    BlockSVDResult {
        class1, class2,
        rows: rows.len(),
        cols: cols.len(),
        singular_values: svs,
        rank1_accuracy,
        sv_gap,
        frobenius_norm,
    }
}

// ═══════════════════════════════════════════════════════════════════════
// EIGENVALUE ANALYSIS
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

/// Get the minimum eigenvector of a symmetric matrix.
fn min_eigenvector(m: &DMatrix<f64>) -> (f64, DVector<f64>) {
    let eig = SymmetricEigen::new(m.clone());
    let mut min_idx = 0;
    let mut min_val = f64::INFINITY;
    for (i, &v) in eig.eigenvalues.iter().enumerate() {
        if v < min_val {
            min_val = v;
            min_idx = i;
        }
    }
    let evec = eig.eigenvectors.column(min_idx).into_owned();
    (min_val, evec)
}

// ═══════════════════════════════════════════════════════════════════════
// LARGE SIEVE RATIO
// ═══════════════════════════════════════════════════════════════════════

/// Compute the large sieve ratio R for a given eigenvector v:
///   R = |v^T G^cross v| / (v^T G^block v)
/// R < 1 ⟺ λ_min(G) > 0 ⟺ RH
fn large_sieve_ratio(
    g_block: &DMatrix<f64>,
    g_cross: &DMatrix<f64>,
    v: &DVector<f64>,
) -> f64 {
    let diag_form = v.dot(&(g_block * v));
    let cross_form = v.dot(&(g_cross * v));
    if diag_form.abs() < 1e-30 { return f64::NAN; }
    cross_form.abs() / diag_form
}

// ═══════════════════════════════════════════════════════════════════════
// MAIN EXPERIMENT
// ═══════════════════════════════════════════════════════════════════════

fn run_experiment(n: usize, cache: &VCache) -> serde_json::Value {
    let t0 = Instant::now();
    let dim = n - 1;

    eprintln!("  Building {0}×{0} Gram matrix (N={1})...", dim, n);
    let g = build_gram_matrix(n, cache);
    let t_gram = t0.elapsed().as_secs_f64();
    eprintln!("    Gram matrix built in {:.1}s", t_gram);

    // ─── Partition ────────────────────────────────────────────────
    let classes = partition_by_class(n);
    let class_sizes: Vec<usize> = classes.iter().map(|c| c.len()).collect();

    // ─── Build G^block and G^cross ────────────────────────────────
    let mut g_block = DMatrix::zeros(dim, dim);
    let mut g_cross = DMatrix::zeros(dim, dim);
    for i in 0..dim {
        for j in 0..dim {
            let ci = octonion_class(i + 2);
            let cj = octonion_class(j + 2);
            if ci == cj {
                g_block[(i, j)] = g[(i, j)];
            } else {
                g_cross[(i, j)] = g[(i, j)];
            }
        }
    }

    // Verify decomposition
    let residual_norm = (&g - &g_block - &g_cross).iter().map(|x| x*x).sum::<f64>().sqrt();
    assert!(residual_norm < 1e-12, "Decomposition check failed: residual = {}", residual_norm);

    // ─── Eigenvalues ──────────────────────────────────────────────
    eprintln!("    Computing eigenvalues...");
    let lmin_g = min_eigenvalue(&g);
    let lmin_block = min_eigenvalue(&g_block);
    let lmin_cross = min_eigenvalue(&g_cross);

    // Get bottom eigenvalues for detail
    let eigs_g = eigenvalues_sorted(&g);
    let eigs_block = eigenvalues_sorted(&g_block);

    // ─── Minimum eigenvector analysis ─────────────────────────────
    let (_, v_min) = min_eigenvector(&g);
    let ratio_r = large_sieve_ratio(&g_block, &g_cross, &v_min);

    // ─── SVD of all 28 cross-class blocks ─────────────────────────
    eprintln!("    Computing SVD of 28 cross-class blocks...");
    let mut block_results: Vec<BlockSVDResult> = Vec::new();
    let pairs: Vec<(usize, usize)> = (0..8)
        .flat_map(|i| ((i+1)..8).map(move |j| (i, j)))
        .collect();

    // Parallel SVD over all 28 pairs
    let results_par: Vec<BlockSVDResult> = pairs
        .par_iter()
        .map(|&(c1, c2)| analyze_cross_block(&g, c1, c2, &classes))
        .collect();
    block_results.extend(results_par);

    // Sort by class pair for consistent output
    block_results.sort_by_key(|r| (r.class1, r.class2));

    // ─── Summary statistics ───────────────────────────────────────
    let min_accuracy: f64 = block_results.iter()
        .filter(|r| r.rows > 0 && r.cols > 0)
        .map(|r| r.rank1_accuracy)
        .fold(f64::INFINITY, f64::min);
    let max_accuracy: f64 = block_results.iter()
        .filter(|r| r.rows > 0 && r.cols > 0)
        .map(|r| r.rank1_accuracy)
        .fold(f64::NEG_INFINITY, f64::max);
    let mean_accuracy: f64 = {
        let valid: Vec<f64> = block_results.iter()
            .filter(|r| r.rows > 0 && r.cols > 0)
            .map(|r| r.rank1_accuracy)
            .collect();
        if valid.is_empty() { 0.0 } else { valid.iter().sum::<f64>() / valid.len() as f64 }
    };
    let min_sv_gap: f64 = block_results.iter()
        .filter(|r| r.rows > 0 && r.cols > 0 && r.sv_gap.is_finite())
        .map(|r| r.sv_gap)
        .fold(f64::INFINITY, f64::min);
    let max_sv_gap: f64 = block_results.iter()
        .filter(|r| r.rows > 0 && r.cols > 0 && r.sv_gap.is_finite())
        .map(|r| r.sv_gap)
        .fold(f64::NEG_INFINITY, f64::max);

    // ─── Build the 8×8 dominant singular value matrix ─────────────
    let mut sigma_matrix = [[0.0f64; 8]; 8];
    for r in &block_results {
        if !r.singular_values.is_empty() {
            sigma_matrix[r.class1][r.class2] = r.singular_values[0];
            sigma_matrix[r.class2][r.class1] = r.singular_values[0];
        }
    }

    let elapsed = t0.elapsed().as_secs_f64();

    // ─── Print results ────────────────────────────────────────────
    println!("\n╔════════════════════════════════════════════════════════════════╗");
    println!("║  N = {:5}  │  dim = {:4}  │  {:.1}s  │  {} threads          ║",
        n, dim, elapsed, rayon::current_num_threads());
    println!("╠════════════════════════════════════════════════════════════════╣");
    println!("║  Class sizes: {:?}", class_sizes);
    println!("║");
    println!("║  EIGENVALUES:");
    println!("║    λ_min(G)       = {:.10}", lmin_g);
    println!("║    λ_min(G^block) = {:.10}", lmin_block);
    println!("║    λ_min(G^cross) = {:.10}", lmin_cross);
    println!("║    Ratio block/G  = {:.6}", lmin_block / lmin_g);
    println!("║    G ≤ G^block?   {} (proved theorem)", if lmin_g <= lmin_block + 1e-12 { "✅ YES" } else { "❌ NO" });
    println!("║");
    println!("║  LARGE SIEVE RATIO:");
    println!("║    R = |v^T G^cross v| / (v^T G^block v) = {:.8}", ratio_r);
    println!("║    R < 1? {} {}", if ratio_r < 1.0 { "✅ YES" } else { "❌ NO" },
        if ratio_r < 1.0 { "(spectral gap positive)" } else { "(spectral gap may vanish)" });
    println!("║");
    println!("║  RANK-1 ACCURACY (σ₁²/‖M‖²_F):");
    println!("║    Min accuracy:  {:.6}%", min_accuracy * 100.0);
    println!("║    Max accuracy:  {:.6}%", max_accuracy * 100.0);
    println!("║    Mean accuracy: {:.6}%", mean_accuracy * 100.0);
    println!("║");
    println!("║  SINGULAR VALUE GAP (σ₁/σ₂):");
    println!("║    Min gap: {:.4}", min_sv_gap);
    println!("║    Max gap: {:.4}", max_sv_gap);
    println!("║");
    println!("║  CROSS-CLASS BLOCK DETAIL:");
    println!("║  {:>4} {:>4} {:>5} {:>5} {:>12} {:>10} {:>10}",
        "c1", "c2", "rows", "cols", "accuracy%", "σ₁/σ₂", "σ₁");
    println!("║  {}", "─".repeat(60));
    for r in &block_results {
        if r.rows > 0 && r.cols > 0 {
            println!("║  {:>4} {:>4} {:>5} {:>5} {:>11.6}% {:>10.4} {:>10.6e}",
                r.class1, r.class2, r.rows, r.cols,
                r.rank1_accuracy * 100.0,
                if r.sv_gap.is_finite() { r.sv_gap } else { f64::NAN },
                r.singular_values.first().unwrap_or(&0.0));
        }
    }
    println!("║");
    println!("║  8×8 DOMINANT SINGULAR VALUE MATRIX Σ(m₁,m₂):");
    print!("║       ");
    for c in 0..8 { print!("{:>9}", c); }
    println!();
    for r in 0..8 {
        print!("║    {}: ", r);
        for c in 0..8 {
            if r == c {
                print!("    ----");
            } else {
                print!("{:>9.4e}", sigma_matrix[r][c]);
            }
        }
        println!();
    }
    println!("║");
    println!("║  BOTTOM 5 EIGENVALUES:");
    print!("║    G:       ");
    for e in eigs_g.iter().take(5) { print!("{:.8} ", e); }
    println!();
    print!("║    G^block: ");
    for e in eigs_block.iter().take(5) { print!("{:.8} ", e); }
    println!();
    println!("╚════════════════════════════════════════════════════════════════╝");

    // ─── JSON output ──────────────────────────────────────────────
    let block_json: Vec<serde_json::Value> = block_results.iter()
        .filter(|r| r.rows > 0 && r.cols > 0)
        .map(|r| {
            serde_json::json!({
                "class1": r.class1,
                "class2": r.class2,
                "rows": r.rows,
                "cols": r.cols,
                "rank1_accuracy": r.rank1_accuracy,
                "sv_gap": if r.sv_gap.is_finite() { r.sv_gap } else { -1.0 },
                "sigma1": r.singular_values.first().unwrap_or(&0.0),
                "sigma2": r.singular_values.get(1).unwrap_or(&0.0),
                "frobenius_norm": r.frobenius_norm,
                "top5_sv": r.singular_values.iter().take(5).collect::<Vec<_>>(),
            })
        })
        .collect();

    serde_json::json!({
        "N": n,
        "dim": dim,
        "elapsed_s": elapsed,
        "class_sizes": class_sizes,
        "lambda_min_G": lmin_g,
        "lambda_min_block": lmin_block,
        "lambda_min_cross": lmin_cross,
        "block_over_G_ratio": lmin_block / lmin_g,
        "large_sieve_ratio_R": ratio_r,
        "rank1_min_accuracy": min_accuracy,
        "rank1_max_accuracy": max_accuracy,
        "rank1_mean_accuracy": mean_accuracy,
        "sv_gap_min": if min_sv_gap.is_finite() { min_sv_gap } else { -1.0 },
        "sv_gap_max": if max_sv_gap.is_finite() { max_sv_gap } else { -1.0 },
        "bottom5_eigs_G": eigs_g.iter().take(5).collect::<Vec<_>>(),
        "bottom5_eigs_block": eigs_block.iter().take(5).collect::<Vec<_>>(),
        "cross_class_blocks": block_json,
    })
}

fn main() {
    let t_start = Instant::now();

    println!();
    println!("╔════════════════════════════════════════════════════════════════╗");
    println!("║  RANK-1 CROSS-CLASS INTERFERENCE EXPERIMENT                  ║");
    println!("║  Octonionic partition (mod 8) · Exact Vasyunin formula        ║");
    println!("║  Does cross-class interaction become rank-1 as N → ∞?         ║");
    println!("║  {} cores available via rayon                                 ║",
        rayon::current_num_threads());
    println!("╚════════════════════════════════════════════════════════════════╝");

    let cache: VCache = Mutex::new(HashMap::new());

    // Sizes: go high — 1000 is an 999×999 matrix, feasible on M2 Max
    let sizes = vec![50, 100, 200, 300, 500, 800, 1000];

    let mut all_results: Vec<serde_json::Value> = Vec::new();

    for &n in &sizes {
        let result = run_experiment(n, &cache);
        all_results.push(result);
    }

    // ─── Grand Summary ────────────────────────────────────────────
    println!("\n\n{}", "═".repeat(78));
    println!("  GRAND SUMMARY — RANK-1 INTERFERENCE ANALYSIS");
    println!("{}", "═".repeat(78));
    println!("\n  {:>5} {:>8} {:>12} {:>12} {:>12} {:>10} {:>10}",
        "N", "dim", "min_acc%", "mean_acc%", "max_acc%", "min_gap", "R_ratio");
    println!("  {}", "─".repeat(72));
    for r in &all_results {
        println!("  {:>5} {:>8} {:>11.6}% {:>11.6}% {:>11.6}% {:>10.4} {:>10.6}",
            r["N"].as_u64().unwrap(),
            r["dim"].as_u64().unwrap(),
            r["rank1_min_accuracy"].as_f64().unwrap() * 100.0,
            r["rank1_mean_accuracy"].as_f64().unwrap() * 100.0,
            r["rank1_max_accuracy"].as_f64().unwrap() * 100.0,
            r["sv_gap_min"].as_f64().unwrap(),
            r["large_sieve_ratio_R"].as_f64().unwrap());
    }

    // ─── Trend analysis: does accuracy increase with N? ───────────
    println!("\n  ─── RANK-1 ACCURACY TREND ───");
    println!("  {:>5} {:>12} {:>12} {:>12}", "N", "min_acc%", "Δ_min", "Δ_mean");
    let mut prev_min = 0.0;
    let mut prev_mean = 0.0;
    for (i, r) in all_results.iter().enumerate() {
        let min_acc = r["rank1_min_accuracy"].as_f64().unwrap() * 100.0;
        let mean_acc = r["rank1_mean_accuracy"].as_f64().unwrap() * 100.0;
        if i > 0 {
            println!("  {:>5} {:>11.6}% {:>+11.6}% {:>+11.6}%",
                r["N"].as_u64().unwrap(), min_acc, min_acc - prev_min, mean_acc - prev_mean);
        } else {
            println!("  {:>5} {:>11.6}%      ---          ---", r["N"].as_u64().unwrap(), min_acc);
        }
        prev_min = min_acc;
        prev_mean = mean_acc;
    }

    // ─── Singular value gap scaling ───────────────────────────────
    println!("\n  ─── SINGULAR VALUE GAP σ₁/σ₂ SCALING ───");
    println!("  {:>5} {:>10} {:>10} {:>12}", "N", "min_gap", "max_gap", "log(N)");
    for r in &all_results {
        let n = r["N"].as_u64().unwrap();
        println!("  {:>5} {:>10.4} {:>10.4} {:>12.4}",
            n,
            r["sv_gap_min"].as_f64().unwrap(),
            r["sv_gap_max"].as_f64().unwrap(),
            (n as f64).ln());
    }

    // Fit σ₁/σ₂ ~ N^α
    if all_results.len() >= 2 {
        let first = &all_results[1]; // skip N=50 (too small)
        let last = all_results.last().unwrap();
        let n1 = first["N"].as_f64().unwrap();
        let n2 = last["N"].as_f64().unwrap();
        let g1 = first["sv_gap_min"].as_f64().unwrap();
        let g2 = last["sv_gap_min"].as_f64().unwrap();
        if g1 > 0.0 && g2 > 0.0 {
            let alpha = (g2.ln() - g1.ln()) / (n2.ln() - n1.ln());
            println!("\n  Power-law fit: σ₁/σ₂ ~ N^{:.4}", alpha);
            println!("  (cathedral-next.tex predicts α ≈ 0.72)");
        }
    }

    // ─── Eigenvalue ratio scaling ─────────────────────────────────
    println!("\n  ─── EIGENVALUE RATIOS ───");
    println!("  {:>5} {:>12} {:>12} {:>12}", "N", "λ_min(G)", "block/G", "R_ratio");
    for r in &all_results {
        println!("  {:>5} {:>12.8} {:>12.6} {:>12.8}",
            r["N"].as_u64().unwrap(),
            r["lambda_min_G"].as_f64().unwrap(),
            r["block_over_G_ratio"].as_f64().unwrap(),
            r["large_sieve_ratio_R"].as_f64().unwrap());
    }

    // ─── Write JSON ───────────────────────────────────────────────
    let output = serde_json::json!({
        "experiment": "rank1_cross_class_interference",
        "description": "Octonionic (mod 8) partition rank-1 analysis of the Nyman-Beurling Gram matrix",
        "date": "2026-04-21",
        "threads": rayon::current_num_threads(),
        "vasyunin_cache_size": cache.lock().unwrap().len(),
        "results": all_results,
    });

    let json_path = "results.json";
    std::fs::write(json_path, serde_json::to_string_pretty(&output).unwrap()).unwrap();
    println!("\n  📁 JSON results written to {}", json_path);

    let total = t_start.elapsed().as_secs_f64();
    println!("\n  Total runtime: {:.1}s", total);
    println!("\n  🏛️  If rank-1 accuracy → 100% and R < 1 stabilizes,");
    println!("     the cross-class interference is exactly rank-1 in the limit,");
    println!("     reducing the spectral gap problem to an 8×8 bilinear form.");
    println!();
}
