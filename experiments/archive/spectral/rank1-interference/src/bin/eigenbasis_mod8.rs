#![allow(unused, dead_code)]
//! ═══════════════════════════════════════════════════════════════════════
//!  EIGENBASIS RANK-1 — MOD 8 (OCTONIONIC)
//!
//!  The critical test: does the eigenbasis transformation at mod 8
//!  recover the 99%+ rank-1 accuracy claimed in FiniteDimReduction.lean?
//!
//!  Unlike mod 2, the mod 8 partition creates 8 small blocks.
//!  The eigenvectors of these blocks may mix indices from
//!  different natural-basis positions, so the rotation W^T G^cross W
//!  genuinely changes the cross-class block structure.
//!
//!  Measures ALL 28 cross-class pairs in both raw and eigenbasis.
//! ═══════════════════════════════════════════════════════════════════════

use nalgebra::{DMatrix, SVD, SymmetricEigen};
use rayon::prelude::*;
use std::collections::HashMap;
use std::sync::Mutex;
use std::time::Instant;

// ═══════════════════════════════════════════════════════════════════════
// ARITHMETIC + VASYUNIN (same as eigenbasis.rs)
// ═══════════════════════════════════════════════════════════════════════

fn gcd(a: usize, b: usize) -> usize {
    let (mut a, mut b) = (a, b);
    while b != 0 {
        let t = b;
        b = a % b;
        a = t;
    }
    a
}

const EULER_GAMMA: f64 = 0.5772156649015328606;
type VCache = Mutex<HashMap<(usize, usize), f64>>;

fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 {
        return 0.0;
    }
    let pi = std::f64::consts::PI;
    let af = a as f64;
    let mut total = 0.0;
    for m in 1..a {
        let frac = ((m * b) % a) as f64 / af;
        let angle = pi * m as f64 / af;
        let (s, c) = angle.sin_cos();
        if s.abs() < 1e-15 {
            continue;
        }
        total += frac * c / s;
    }
    total
}

fn vasyunin_cached(a: usize, b: usize, cache: &VCache) -> f64 {
    {
        let g = cache.lock().unwrap();
        if let Some(&v) = g.get(&(a, b)) {
            return v;
        }
    }
    let val = vasyunin_sum(a, b);
    {
        cache.lock().unwrap().insert((a, b), val);
    }
    val
}

fn gram_entry(j: usize, k: usize, cache: &VCache) -> f64 {
    let pi = std::f64::consts::PI;
    let ln2pi = (2.0 * pi).ln();
    let coeff = (ln2pi - EULER_GAMMA) / 2.0;
    let (jf, kf) = (j as f64, k as f64);
    let jk = jf * kf;
    if j == k {
        return (ln2pi - EULER_GAMMA) / jf - 1.0 / (jf * jf);
    }
    let d = gcd(j, k);
    let (jp, kp) = (j / d, k / d);
    coeff * (1.0 / jf + 1.0 / kf) + (jf - kf) / (2.0 * jk) * (kf / jf).ln()
        - pi * d as f64 / (2.0 * jk)
            * (vasyunin_cached(jp, kp, cache) + vasyunin_cached(kp, jp, cache))
        - 1.0 / jk
}

fn build_gram(n: usize, cache: &VCache) -> DMatrix<f64> {
    let dim = n - 1;
    let pairs: Vec<_> = (0..dim)
        .flat_map(|i| (i..dim).map(move |j| (i, j)))
        .collect();
    let entries: Vec<_> = pairs
        .par_iter()
        .map(|&(i, j)| (i, j, gram_entry(i + 2, j + 2, cache)))
        .collect();
    let mut g = DMatrix::zeros(dim, dim);
    for (i, j, v) in entries {
        g[(i, j)] = v;
        g[(j, i)] = v;
    }
    g
}

// ═══════════════════════════════════════════════════════════════════════
// MOD-K PARTITION (generic)
// ═══════════════════════════════════════════════════════════════════════

fn classify(k: usize, modulus: usize) -> usize {
    k % modulus
}

fn partition(n: usize, modulus: usize) -> Vec<Vec<usize>> {
    let dim = n - 1;
    let mut classes = vec![Vec::new(); modulus];
    for idx in 0..dim {
        classes[classify(idx + 2, modulus)].push(idx);
    }
    classes
}

fn build_block_cross_mod(
    n: usize,
    g: &DMatrix<f64>,
    modulus: usize,
) -> (DMatrix<f64>, DMatrix<f64>) {
    let dim = n - 1;
    let mut g_block = DMatrix::zeros(dim, dim);
    let mut g_cross = DMatrix::zeros(dim, dim);
    for i in 0..dim {
        for j in 0..dim {
            if classify(i + 2, modulus) == classify(j + 2, modulus) {
                g_block[(i, j)] = g[(i, j)];
            } else {
                g_cross[(i, j)] = g[(i, j)];
            }
        }
    }
    (g_block, g_cross)
}

// ═══════════════════════════════════════════════════════════════════════
// EIGENBASIS EXPERIMENT (generic modulus)
// ═══════════════════════════════════════════════════════════════════════

fn run_eigenbasis_mod(n: usize, modulus: usize, g: &DMatrix<f64>) {
    let t0 = Instant::now();
    let dim = n - 1;
    let nc = modulus;
    let num_pairs = nc * (nc - 1) / 2;

    let (g_block, g_cross) = build_block_cross_mod(n, g, modulus);

    // Eigendecomposition of G^block
    let eig_block = SymmetricEigen::new(g_block.clone());
    let w = &eig_block.eigenvectors;
    let block_evals: Vec<f64> = eig_block.eigenvalues.iter().cloned().collect();

    // Transform: M = W^T · G^cross · W
    let m_eig = w.transpose() * &g_cross * w;

    // Classify each eigenvector by max-energy class
    let classes = partition(n, modulus);
    let mut evec_class = vec![0usize; dim];
    for idx in 0..dim {
        let evec = w.column(idx);
        let mut best_c = 0;
        let mut best_e = 0.0f64;
        for c in 0..nc {
            let e: f64 = classes[c].iter().map(|&i| evec[i] * evec[i]).sum();
            if e > best_e {
                best_e = e;
                best_c = c;
            }
        }
        evec_class[idx] = best_c;
    }

    let mut evec_by_class: Vec<Vec<usize>> = vec![Vec::new(); nc];
    for (idx, &c) in evec_class.iter().enumerate() {
        evec_by_class[c].push(idx);
    }

    // Analyze ALL cross-class pairs
    let pairs: Vec<(usize, usize)> = (0..nc)
        .flat_map(|i| ((i + 1)..nc).map(move |j| (i, j)))
        .collect();

    struct PairResult {
        c1: usize,
        c2: usize,
        raw_acc: f64,
        raw_gap: f64,
        eig_acc: f64,
        eig_gap: f64,
        lambda_eff: f64,
    }

    let results: Vec<PairResult> = pairs
        .par_iter()
        .map(|&(c1, c2)| {
            let raw_rows = &classes[c1];
            let raw_cols = &classes[c2];
            let eig_rows = &evec_by_class[c1];
            let eig_cols = &evec_by_class[c2];

            // Raw cross-block SVD
            let (raw_acc, raw_gap) = if !raw_rows.is_empty() && !raw_cols.is_empty() {
                let block = DMatrix::from_fn(raw_rows.len(), raw_cols.len(), |i, j| {
                    g_cross[(raw_rows[i], raw_cols[j])]
                });
                let frob: f64 = block.iter().map(|x| x * x).sum();
                let svd = SVD::new(block, false, false);
                let mut sv: Vec<f64> = svd.singular_values.iter().cloned().collect();
                sv.sort_by(|a, b| b.partial_cmp(a).unwrap());
                let acc = if frob > 0.0 {
                    sv[0] * sv[0] / frob
                } else {
                    1.0
                };
                let gap = if sv.len() >= 2 && sv[1] > 1e-15 {
                    sv[0] / sv[1]
                } else {
                    f64::INFINITY
                };
                (acc, gap)
            } else {
                (1.0, f64::INFINITY)
            };

            // Eigenbasis cross-block SVD
            let (eig_acc, eig_gap, lambda_eff) = if !eig_rows.is_empty() && !eig_cols.is_empty() {
                let block = DMatrix::from_fn(eig_rows.len(), eig_cols.len(), |i, j| {
                    m_eig[(eig_rows[i], eig_cols[j])]
                });
                let frob: f64 = block.iter().map(|x| x * x).sum();
                let svd = SVD::new(block, true, false);
                let mut sv: Vec<f64> = svd.singular_values.iter().cloned().collect();
                sv.sort_by(|a, b| b.partial_cmp(a).unwrap());
                let acc = if frob > 0.0 {
                    sv[0] * sv[0] / frob
                } else {
                    1.0
                };
                let gap = if sv.len() >= 2 && sv[1] > 1e-15 {
                    sv[0] / sv[1]
                } else {
                    f64::INFINITY
                };

                // λ_eff from the dominant left singular vector
                let leff = if let Some(u_mat) = &svd.u {
                    let u = u_mat.column(0);
                    let mut rsum = 0.0f64;
                    for (li, &gi) in eig_rows.iter().enumerate() {
                        let lam = block_evals[gi];
                        if lam.abs() > 1e-15 {
                            rsum += u[li] * u[li] / lam;
                        }
                    }
                    if rsum.abs() > 1e-30 {
                        1.0 / rsum
                    } else {
                        f64::NAN
                    }
                } else {
                    f64::NAN
                };

                (acc, gap, leff)
            } else {
                (1.0, f64::INFINITY, f64::NAN)
            };

            PairResult {
                c1,
                c2,
                raw_acc,
                raw_gap,
                eig_acc,
                eig_gap,
                lambda_eff,
            }
        })
        .collect();

    // Summary stats
    let raw_accs: Vec<f64> = results.iter().map(|r| r.raw_acc).collect();
    let eig_accs: Vec<f64> = results.iter().map(|r| r.eig_acc).collect();
    let eig_gaps: Vec<f64> = results
        .iter()
        .filter(|r| r.eig_gap.is_finite())
        .map(|r| r.eig_gap)
        .collect();
    let lambda_effs: Vec<f64> = results
        .iter()
        .filter(|r| !r.lambda_eff.is_nan())
        .map(|r| r.lambda_eff)
        .collect();

    let raw_min = raw_accs.iter().cloned().fold(f64::INFINITY, f64::min);
    let raw_mean = raw_accs.iter().sum::<f64>() / raw_accs.len() as f64;
    let eig_min = eig_accs.iter().cloned().fold(f64::INFINITY, f64::min);
    let eig_mean = eig_accs.iter().sum::<f64>() / eig_accs.len() as f64;
    let eig_max = eig_accs.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    let eig_gap_min = if !eig_gaps.is_empty() {
        eig_gaps.iter().cloned().fold(f64::INFINITY, f64::min)
    } else {
        f64::NAN
    };
    let leff_mean = if !lambda_effs.is_empty() {
        lambda_effs.iter().sum::<f64>() / lambda_effs.len() as f64
    } else {
        f64::NAN
    };

    // Eigenvalue stats
    let mut g_evals: Vec<f64> = SymmetricEigen::new(g.clone())
        .eigenvalues
        .iter()
        .cloned()
        .collect();
    g_evals.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let mut b_evals = block_evals.clone();
    b_evals.sort_by(|a, b| a.partial_cmp(b).unwrap());

    let elapsed = t0.elapsed().as_secs_f64();
    let ln_n = (n as f64).ln();

    println!(
        "\n  ┌─ mod {} │ N={} │ {:.1}s │ {} pairs ─────────────────┐",
        modulus, n, elapsed, num_pairs
    );
    println!(
        "  │  Class sizes (eigenbasis): {:?}",
        evec_by_class.iter().map(|v| v.len()).collect::<Vec<_>>()
    );
    println!(
        "  │  λ_min(G)={:.8e}  λ_min(block)={:.8e}  ratio={:.3}",
        g_evals[0],
        b_evals[0],
        b_evals[0] / g_evals[0]
    );
    println!("  │");
    println!("  │  ── RANK-1 ACCURACY ──");
    println!(
        "  │  Raw:        min={:.4}%   mean={:.4}%",
        raw_min * 100.0,
        raw_mean * 100.0
    );
    println!(
        "  │  EIGENBASIS: min={:.4}%   mean={:.4}%   max={:.4}%   ◄◄◄",
        eig_min * 100.0,
        eig_mean * 100.0,
        eig_max * 100.0
    );
    println!(
        "  │  Improvement: mean {:+.4}%",
        (eig_mean - raw_mean) * 100.0
    );
    println!("  │  σ₁/σ₂ min (eigenbasis): {:.3}", eig_gap_min);
    println!("  │");
    println!("  │  ── EFFECTIVE EIGENVALUE ──");
    println!(
        "  │  λ_eff mean = {:.6}  │  λ_eff/log(N) = {:.4}  │  λ_eff/N = {:.6}",
        leff_mean,
        leff_mean / ln_n,
        leff_mean / n as f64
    );
    println!("  │");

    // Print per-pair detail for small numbers of pairs
    if num_pairs <= 10 {
        println!("  │  ── PER-PAIR DETAIL ──");
        println!(
            "  │  {:>3} {:>3} {:>10} {:>10} {:>10} {:>8} {:>10}",
            "c1", "c2", "raw_acc%", "eig_acc%", "Δ%", "eig_gap", "λ_eff"
        );
        for r in &results {
            println!(
                "  │  {:>3} {:>3} {:>9.4}% {:>9.4}% {:>+9.4}% {:>8.3} {:>10.4}",
                r.c1,
                r.c2,
                r.raw_acc * 100.0,
                r.eig_acc * 100.0,
                (r.eig_acc - r.raw_acc) * 100.0,
                if r.eig_gap.is_finite() {
                    r.eig_gap
                } else {
                    f64::NAN
                },
                r.lambda_eff
            );
        }
    }
    println!("  └───────────────────────────────────────────────────────────┘");
}

// ═══════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════

fn main() {
    let t_start = Instant::now();
    println!();
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  EIGENBASIS EXPERIMENT — ALL PARTITION LEVELS                   ║");
    println!("║  mod 4 (Quaternionic) · mod 8 (Octonionic)                     ║");
    println!("║  Raw vs Eigenbasis SVD · λ_eff tracking                        ║");
    println!(
        "║  {} cores via rayon                                             ║",
        rayon::current_num_threads()
    );
    println!("╚══════════════════════════════════════════════════════════════════╝");

    let cache: VCache = Mutex::new(HashMap::new());
    let sizes = vec![50, 100, 200, 300, 500, 800, 1000];

    for &n in &sizes {
        eprintln!("  Building Gram matrix N={}", n);
        let g = build_gram(n, &cache);

        println!("\n{}", "═".repeat(70));
        println!("  N = {} (dim = {})", n, n - 1);
        println!("{}", "═".repeat(70));

        run_eigenbasis_mod(n, 4, &g);
        run_eigenbasis_mod(n, 8, &g);
    }

    // Summary tables
    println!("\n\n{}", "═".repeat(80));
    println!("  GRAND SUMMARY — EIGENBASIS vs RAW ACCURACY");
    println!("{}", "═".repeat(80));
    println!("\n  (Run complete — see per-N results above for full detail)");

    println!(
        "\n  Total runtime: {:.1}s ({} cores)",
        t_start.elapsed().as_secs_f64(),
        rayon::current_num_threads()
    );

    println!("\n  🏛️  Does the eigenbasis transformation recover rank-1 accuracy?");
    println!("     If eigenbasis acc > raw acc and INCREASING → the Lean claims hold.");
    println!("     If no change → the rank-1 reduction needs a different formulation.");
    println!();
}
