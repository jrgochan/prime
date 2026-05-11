#![allow(unused, dead_code)]
//! ═══════════════════════════════════════════════════════════════════════
//!  EIGENBASIS RANK-1 EXPERIMENT
//!  The Cathedral — Testing FiniteDimReduction.lean's Actual Claim
//!
//!  The key insight: the Lean code claims rank-1 accuracy in the
//!  EIGENBASIS of G^block, not in the raw natural basis.
//!
//!  This experiment:
//!    1. Computes G, G^block, G^cross = G - G^block
//!    2. Diagonalizes G^block: G^block = W Λ W^T
//!    3. Transforms: M = W^T · G^cross · W (interference in eigenbasis)
//!    4. Extracts cross-class blocks of M and computes SVD
//!    5. Measures rank-1 accuracy IN THE EIGENBASIS
//!    6. Computes the effective eigenvalue λ_eff
//!    7. Tracks the Möbius log-cutoff witness projection
//!
//!  Uses mod 2 (Liouville parity) as the cleanest test case.
//!  Exact Vasyunin formula, rayon parallelism.
//! ═══════════════════════════════════════════════════════════════════════

use nalgebra::{DMatrix, DVector, SVD, SymmetricEigen};
use rayon::prelude::*;
use std::collections::HashMap;
use std::sync::Mutex;
use std::time::Instant;

// ═══════════════════════════════════════════════════════════════════════
// ARITHMETIC
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

fn big_omega(mut n: usize) -> usize {
    let mut count = 0;
    let mut d = 2;
    while d * d <= n {
        while n % d == 0 {
            count += 1;
            n /= d;
        }
        d += 1;
    }
    if n > 1 {
        count += 1;
    }
    count
}

fn mobius(mut n: usize) -> i32 {
    if n <= 1 {
        return 1;
    }
    let mut count = 0;
    let mut d = 2;
    while d * d <= n {
        if n % d == 0 {
            n /= d;
            if n % d == 0 {
                return 0;
            } // squared factor
            count += 1;
        }
        d += 1;
    }
    if n > 1 {
        count += 1;
    }
    if count % 2 == 0 { 1 } else { -1 }
}

// ═══════════════════════════════════════════════════════════════════════
// VASYUNIN FORMULA
// ═══════════════════════════════════════════════════════════════════════

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
        let mb_mod_a = (m * b) % a;
        let frac = mb_mod_a as f64 / af;
        let angle = pi * m as f64 / af;
        let (sin_v, cos_v) = angle.sin_cos();
        if sin_v.abs() < 1e-15 {
            continue;
        }
        total += frac * cos_v / sin_v;
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
    let jf = j as f64;
    let kf = k as f64;
    let jk = jf * kf;
    if j == k {
        return (ln2pi - EULER_GAMMA) / jf - 1.0 / (jf * jf);
    }
    let d = gcd(j, k);
    let jp = j / d;
    let kp = k / d;
    let t1 = coeff * (1.0 / jf + 1.0 / kf);
    let t2 = (jf - kf) / (2.0 * jk) * (kf / jf).ln();
    let v1 = vasyunin_cached(jp, kp, cache);
    let v2 = vasyunin_cached(kp, jp, cache);
    let t3 = pi * d as f64 / (2.0 * jk) * (v1 + v2);
    let t4 = 1.0 / jk;
    t1 + t2 - t3 - t4
}

fn mean_entry(k: usize) -> f64 {
    let kf = k as f64;
    (kf.ln() + 1.0 - EULER_GAMMA) / kf
}

// ═══════════════════════════════════════════════════════════════════════
// MATRIX CONSTRUCTION
// ═══════════════════════════════════════════════════════════════════════

fn build_gram(n: usize, cache: &VCache) -> DMatrix<f64> {
    let dim = n - 1;
    let pairs: Vec<(usize, usize)> = (0..dim)
        .flat_map(|i| (i..dim).map(move |j| (i, j)))
        .collect();
    let entries: Vec<(usize, usize, f64)> = pairs
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

/// Build the augmented Gram matrix H_N = [[1, bᵀ], [b, G_N]]
fn build_augmented(n: usize, g: &DMatrix<f64>) -> DMatrix<f64> {
    let dim = n - 1;
    let aug_dim = dim + 1;
    let mut h = DMatrix::zeros(aug_dim, aug_dim);
    h[(0, 0)] = 1.0;
    for i in 0..dim {
        let b_i = mean_entry(i + 2);
        h[(0, i + 1)] = b_i;
        h[(i + 1, 0)] = b_i;
    }
    for i in 0..dim {
        for j in 0..dim {
            h[(i + 1, j + 1)] = g[(i, j)];
        }
    }
    h
}

// ═══════════════════════════════════════════════════════════════════════
// PARTITION + BLOCK DECOMPOSITION
// ═══════════════════════════════════════════════════════════════════════

fn parity_class(k: usize) -> usize {
    big_omega(k) % 2
}

fn partition_parity(n: usize) -> [Vec<usize>; 2] {
    let dim = n - 1;
    let mut classes = [Vec::new(), Vec::new()];
    for idx in 0..dim {
        let c = parity_class(idx + 2);
        classes[c].push(idx);
    }
    classes
}

fn build_block_cross(n: usize, g: &DMatrix<f64>) -> (DMatrix<f64>, DMatrix<f64>) {
    let dim = n - 1;
    let mut g_block = DMatrix::zeros(dim, dim);
    let mut g_cross = DMatrix::zeros(dim, dim);
    for i in 0..dim {
        for j in 0..dim {
            if parity_class(i + 2) == parity_class(j + 2) {
                g_block[(i, j)] = g[(i, j)];
            } else {
                g_cross[(i, j)] = g[(i, j)];
            }
        }
    }
    (g_block, g_cross)
}

// ═══════════════════════════════════════════════════════════════════════
// THE KEY EXPERIMENT
// ═══════════════════════════════════════════════════════════════════════

fn run_eigenbasis_experiment(n: usize, cache: &VCache) {
    let t0 = Instant::now();
    let dim = n - 1;
    let ln_n = (n as f64).ln();

    eprintln!("  Building {}×{} Gram matrix (N={})...", dim, dim, n);
    let g = build_gram(n, cache);
    let (g_block, g_cross) = build_block_cross(n, &g);

    // ─── Eigendecomposition of G^block ────────────────────────────
    let eig_block = SymmetricEigen::new(g_block.clone());
    let w_mat = &eig_block.eigenvectors; // columns are eigenvectors
    let block_evals: Vec<f64> = eig_block.eigenvalues.iter().cloned().collect();

    // ─── Transform G^cross into the eigenbasis of G^block ─────────
    // M = W^T · G^cross · W
    let m_eigenbasis = w_mat.transpose() * &g_cross * w_mat;

    // ─── Partition the eigenvectors by which class they belong to ──
    // Each eigenvector of G^block belongs to one class (block-diagonal structure)
    // The eigenvectors of a block-diagonal matrix are eigenvectors of individual blocks
    // We classify each eigenvector by which class has the most energy
    let classes = partition_parity(n);
    let mut evec_class = vec![0usize; dim];
    for idx in 0..dim {
        let evec = w_mat.column(idx);
        let mut energy = [0.0f64; 2];
        for &i in &classes[0] {
            energy[0] += evec[i] * evec[i];
        }
        for &i in &classes[1] {
            energy[1] += evec[i] * evec[i];
        }
        evec_class[idx] = if energy[0] >= energy[1] { 0 } else { 1 };
    }

    let mut evec_by_class = [Vec::new(), Vec::new()];
    for (idx, &c) in evec_class.iter().enumerate() {
        evec_by_class[c].push(idx);
    }

    // ─── SVD of the cross-class block in the eigenbasis ───────────
    let rows = &evec_by_class[0];
    let cols = &evec_by_class[1];

    let cross_block_eigenbasis = DMatrix::from_fn(rows.len(), cols.len(), |i, j| {
        m_eigenbasis[(rows[i], cols[j])]
    });

    let frob_sq: f64 = cross_block_eigenbasis.iter().map(|x| x * x).sum();
    let svd = SVD::new(cross_block_eigenbasis.clone(), true, true);
    let mut svs: Vec<f64> = svd.singular_values.iter().cloned().collect();
    svs.sort_by(|a, b| b.partial_cmp(a).unwrap());

    let sigma1_sq = if !svs.is_empty() {
        svs[0] * svs[0]
    } else {
        0.0
    };
    let rank1_acc_eigenbasis = if frob_sq > 0.0 {
        sigma1_sq / frob_sq
    } else {
        1.0
    };
    let sv_gap_eigenbasis = if svs.len() >= 2 && svs[1] > 1e-15 {
        svs[0] / svs[1]
    } else {
        f64::INFINITY
    };

    // ─── Also compute raw cross-block SVD for comparison ──────────
    let raw_cross = DMatrix::from_fn(classes[0].len(), classes[1].len(), |i, j| {
        g_cross[(classes[0][i], classes[1][j])]
    });
    let raw_frob_sq: f64 = raw_cross.iter().map(|x| x * x).sum();
    let raw_svd = SVD::new(raw_cross, false, false);
    let mut raw_svs: Vec<f64> = raw_svd.singular_values.iter().cloned().collect();
    raw_svs.sort_by(|a, b| b.partial_cmp(a).unwrap());
    let raw_sigma1_sq = if !raw_svs.is_empty() {
        raw_svs[0] * raw_svs[0]
    } else {
        0.0
    };
    let raw_rank1_acc = if raw_frob_sq > 0.0 {
        raw_sigma1_sq / raw_frob_sq
    } else {
        1.0
    };
    let raw_sv_gap = if raw_svs.len() >= 2 && raw_svs[1] > 1e-15 {
        raw_svs[0] / raw_svs[1]
    } else {
        f64::INFINITY
    };

    // ─── Effective eigenvalue λ_eff ───────────────────────────────
    // λ_eff = (Σ u_j² / λ_j)^{-1} where u is the rank-1 direction
    // and λ_j are the block eigenvalues
    let lambda_eff = if let Some(u_mat) = &svd.u {
        let u_col = u_mat.column(0); // dominant left singular vector
        let mut resolvent_sum = 0.0f64;
        for (local_i, &global_i) in rows.iter().enumerate() {
            let lambda_i = block_evals[global_i];
            if lambda_i.abs() > 1e-15 {
                resolvent_sum += u_col[local_i] * u_col[local_i] / lambda_i;
            }
        }
        if resolvent_sum.abs() > 1e-30 {
            1.0 / resolvent_sum
        } else {
            f64::NAN
        }
    } else {
        f64::NAN
    };

    // ─── Eigenvalue stats ─────────────────────────────────────────
    let eig_g = SymmetricEigen::new(g.clone());
    let mut g_evals: Vec<f64> = eig_g.eigenvalues.iter().cloned().collect();
    g_evals.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let lmin_g = g_evals[0];

    let mut block_evals_sorted = block_evals.clone();
    block_evals_sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let lmin_block = block_evals_sorted[0];

    // ─── Min eigenvector analysis ─────────────────────────────────
    let mut min_idx = 0;
    for (i, &v) in eig_g.eigenvalues.iter().enumerate() {
        if v < eig_g.eigenvalues[min_idx] {
            min_idx = i;
        }
    }
    let v_min = eig_g.eigenvectors.column(min_idx);
    let diag_form = v_min.dot(&(&g_block * &v_min));
    let cross_form = v_min.dot(&(&g_cross * &v_min));
    let r_ratio = if diag_form.abs() > 1e-30 {
        cross_form.abs() / diag_form
    } else {
        f64::NAN
    };

    // ─── Möbius log-cutoff witness vector ─────────────────────────
    let log_witness: DVector<f64> = DVector::from_fn(dim, |i, _| {
        let k = i + 2;
        let mu = mobius(k) as f64;
        -mu * (1.0 - (k as f64).ln() / ln_n)
    });
    let log_witness_norm = log_witness.norm();
    let log_witness_normalized = &log_witness / log_witness_norm;

    // Rayleigh quotient of the witness
    let witness_vtgv = log_witness_normalized.dot(&(&g * &log_witness_normalized));

    // Witness projection onto min eigenvector
    let witness_min_proj = log_witness_normalized.dot(&v_min).abs();

    // ─── Augmented Gram matrix analysis ───────────────────────────
    let h = build_augmented(n, &g);
    let eig_h = SymmetricEigen::new(h.clone());
    let mut h_evals: Vec<f64> = eig_h.eigenvalues.iter().cloned().collect();
    h_evals.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let lmin_h = h_evals[0];

    // NB distance: d²_N = 1 - bᵀG⁻¹b
    // We compute it via the mean vector and G inverse
    let b_vec = DVector::from_fn(dim, |i, _| mean_entry(i + 2));
    let g_inv = g.clone().try_inverse();
    let d_sq = if let Some(gi) = &g_inv {
        1.0 - b_vec.dot(&(gi * &b_vec))
    } else {
        f64::NAN
    };

    let elapsed = t0.elapsed().as_secs_f64();

    // ─── Print ────────────────────────────────────────────────────
    println!("\n╔══════════════════════════════════════════════════════════════════╗");
    println!(
        "║  N = {:5}  │  dim = {:4}  │  {:.1}s                           ║",
        n, dim, elapsed
    );
    println!("╠══════════════════════════════════════════════════════════════════╣");
    println!(
        "║  Class sizes: even-parity={}, odd-parity={}",
        evec_by_class[0].len(),
        evec_by_class[1].len()
    );
    println!("║");
    println!("║  ── RANK-1 ACCURACY COMPARISON ──");
    println!(
        "║  Raw basis:       {:.6}%  │  σ₁/σ₂ = {:.3}",
        raw_rank1_acc * 100.0,
        raw_sv_gap
    );
    println!(
        "║  EIGENBASIS:      {:.6}%  │  σ₁/σ₂ = {:.3}   ◄◄◄",
        rank1_acc_eigenbasis * 100.0,
        sv_gap_eigenbasis
    );
    println!(
        "║  Improvement:     {:+.4}%",
        (rank1_acc_eigenbasis - raw_rank1_acc) * 100.0
    );
    println!("║");
    println!("║  ── EIGENVALUES ──");
    println!("║  λ_min(G)       = {:.10}", lmin_g);
    println!("║  λ_min(G^block) = {:.10}", lmin_block);
    println!("║  λ_min(H)       = {:.10}", lmin_h);
    println!("║  block/G ratio  = {:.4}", lmin_block / lmin_g);
    println!("║  R = |cross/diag| = {:.8}", r_ratio);
    println!("║");
    println!("║  ── EFFECTIVE EIGENVALUE λ_eff ──");
    println!(
        "║  λ_eff = {:.6}  │  λ_eff/λ_min(block) = {:.2}",
        lambda_eff,
        lambda_eff / lmin_block
    );
    println!(
        "║  λ_eff / N = {:.6}  (linear growth?)",
        lambda_eff / n as f64
    );
    println!("║");
    println!("║  ── MÖBIUS LOG-CUTOFF WITNESS ──");
    println!(
        "║  ‖v‖ = {:.4}  │  Rayleigh(v) = {:.8}",
        log_witness_norm, witness_vtgv
    );
    println!("║  |⟨v̂, v_min⟩| = {:.8}", witness_min_proj);
    println!("║  d²_N = {:.10}", d_sq);
    println!("║  log(N)·d²_N = {:.8}", ln_n * d_sq);
    println!("║");
    println!("║  ── TOP 5 SINGULAR VALUES (eigenbasis) ──");
    for (i, sv) in svs.iter().take(5).enumerate() {
        let pct = if frob_sq > 0.0 {
            sv * sv / frob_sq * 100.0
        } else {
            0.0
        };
        println!(
            "║    σ_{} = {:.6e}  ({:.4}% cumulative at {})",
            i + 1,
            sv,
            pct,
            i + 1
        );
    }
    println!("╚══════════════════════════════════════════════════════════════════╝");
}

fn main() {
    let t_start = Instant::now();
    println!();
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  EIGENBASIS RANK-1 EXPERIMENT                                  ║");
    println!("║  Parity (mod 2) · Eigenbasis of G^block · λ_eff tracking       ║");
    println!("║  Augmented Gram matrix · Möbius log-cutoff witness              ║");
    println!(
        "║  {} cores via rayon                                             ║",
        rayon::current_num_threads()
    );
    println!("╚══════════════════════════════════════════════════════════════════╝");

    let cache: VCache = Mutex::new(HashMap::new());
    let sizes = vec![50, 100, 200, 300, 500, 800, 1000];

    for &n in &sizes {
        run_eigenbasis_experiment(n, &cache);
    }

    println!("\n  Total runtime: {:.1}s", t_start.elapsed().as_secs_f64());
    println!("\n  🏛️  If eigenbasis accuracy INCREASES and λ_eff ~ N,");
    println!("     the finite-dimensional reduction is rigorous.");
    println!();
}
