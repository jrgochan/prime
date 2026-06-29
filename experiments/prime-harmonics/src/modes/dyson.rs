//! # Dyson Mode: The Nuclear Option
//!
//! Implements the Dyson equation (resolvent identity) for the Cathedral:
//!
//! ```text
//! d²_opt(G) = (1 - bᵀ R_true⁻¹ b) + (w*)ᵀ Δ_true v*
//! ```
//!
//! where:
//! - R_true(j,k) = gcd(j,k)²/(12jk) + 1/4  (full sawtooth Gram with DC offset)
//! - G(j,k) = ∫₀¹ {1/(jx)}{1/(kx)} dx       (BD Gram)
//! - Δ_true = G - R_true                      (true anomaly, NEGATIVE/attractive)
//! - w* = R_true⁻¹ b                          (bare vacuum / Smith weights)
//! - v* = G⁻¹ b                               (dressed vacuum / BD optimal)
//! - b_k = (ln(k) + 1 - γ) / k               (BD mean vector)
//!
//! Also tests Option C: Smith weights c_k=1/2 used in BD basis.
//!
//! Created: May 29, 2026 — The Dyson Protocol (Gemini directive)

use crate::modes::anomaly::exact_gram;
use cathedral_utils::arith::gcd;
use nalgebra::{DMatrix, DVector};
use rayon::prelude::*;
use std::time::Instant;

const EULER_GAMMA: f64 = 0.5772156649015329;

/// Möbius function μ(n)
fn moebius_fn(n: usize) -> i32 {
    if n == 1 {
        return 1;
    }
    let mut temp = n;
    let mut d = 2usize;
    let mut count = 0;
    while d * d <= temp {
        if temp.is_multiple_of(d) {
            let mut exp = 0;
            while temp.is_multiple_of(d) {
                temp /= d;
                exp += 1;
            }
            if exp > 1 {
                return 0;
            }
            count += 1;
        }
        d += 1;
    }
    if temp > 1 {
        count += 1;
    }
    if count % 2 == 0 {
        1
    } else {
        -1
    }
}

/// BD mean: b_k = (ln(k) + 1 - γ) / k
fn bd_mean(k: usize) -> f64 {
    ((k as f64).ln() + 1.0 - EULER_GAMMA) / k as f64
}

/// Full sawtooth Gram: R_true(j,k) = gcd(j,k)²/(12jk) + 1/4
fn r_true(j: usize, k: usize) -> f64 {
    let g = gcd(j, k);
    (g * g) as f64 / (12.0 * j as f64 * k as f64) + 0.25
}

/// Build the full Gram matrix G for indices 2..=N (dimension N-1 × N-1).
/// Uses Rayon for parallel row computation.
fn build_gram_matrix(n: usize) -> DMatrix<f64> {
    let dim = n - 1;
    // Compute upper triangle in parallel (each row independently)
    let upper: Vec<Vec<f64>> = (0..dim)
        .into_par_iter()
        .map(|i| {
            let ki = i + 2;
            (i..dim)
                .map(|j| {
                    let kj = j + 2;
                    exact_gram(ki, kj)
                })
                .collect()
        })
        .collect();

    let mut g = DMatrix::zeros(dim, dim);
    for i in 0..dim {
        for j in i..dim {
            let val = upper[i][j - i];
            g[(i, j)] = val;
            g[(j, i)] = val;
        }
    }
    g
}

/// Build the R_true matrix for indices 2..=N.
fn build_r_true(n: usize) -> DMatrix<f64> {
    let dim = n - 1;
    let mut rt = DMatrix::zeros(dim, dim);
    for i in 0..dim {
        for j in i..dim {
            let val = r_true(i + 2, j + 2);
            rt[(i, j)] = val;
            rt[(j, i)] = val;
        }
    }
    rt
}

/// Build the BD mean vector b for indices 2..=N.
fn build_b_vector(n: usize) -> DVector<f64> {
    let dim = n - 1;
    DVector::from_fn(dim, |i, _| bd_mean(i + 2))
}

/// Build the sawtooth mean vector c for indices 2..=N (all 1/2).
fn build_c_vector(n: usize) -> DVector<f64> {
    DVector::from_element(n - 1, 0.5)
}

pub fn run(n_max: usize) {
    eprintln!("🔥 DYSON PROTOCOL — The Nuclear Option");
    eprintln!("  N_max: {}", n_max);
    eprintln!("  Threads: {}", rayon::current_num_threads());
    eprintln!();

    let total_start = Instant::now();

    // ═══════════════════════════════════════════════
    // §1. THE DYSON EQUATION
    // ═══════════════════════════════════════════════
    println!("════════════════════════════════════════════════════════════════════════════════════════════");
    println!("§1. DYSON EQUATION: d²_opt(G) = (1 - bᵀ R⁻¹ b) + (w*)ᵀ Δ v*");
    println!("════════════════════════════════════════════════════════════════════════════════════════════");
    println!();
    println!(
        "{:>6} {:>14} {:>14} {:>14} {:>12} {:>12} {:>8}",
        "N", "d²_free", "scattering", "d²_opt(G)", "d²·lnN", "check", "time"
    );
    println!("{}", "-".repeat(90));

    let mut test_ns: Vec<usize> = vec![];
    for n in [5, 8, 10, 15, 20, 30, 40, 50, 60, 80, 100].iter() {
        if *n <= n_max {
            test_ns.push(*n);
        }
    }
    // Add larger N
    let mut n = 120;
    while n <= n_max {
        test_ns.push(n);
        n += if n < 300 {
            20
        } else if n < 500 {
            50
        } else {
            100
        };
    }
    if !test_ns.contains(&n_max) && n_max > 100 {
        test_ns.push(n_max);
    }

    let mut dyson_results: Vec<(usize, f64, f64, f64)> = Vec::new();

    for &n in &test_ns {
        let t0 = Instant::now();
        let _dim = n - 1;

        // Build matrices
        let g_mat = build_gram_matrix(n);
        let rt_mat = build_r_true(n);
        let b = build_b_vector(n);

        // Δ_true = G - R_true
        let delta_true = &g_mat - &rt_mat;

        // Solve w* = R_true⁻¹ b and v* = G⁻¹ b
        let lu_rt = rt_mat.clone().lu();
        let lu_g = g_mat.clone().lu();

        let w_star = match lu_rt.solve(&b) {
            Some(w) => w,
            None => {
                eprintln!("  N={}: R_true singular!", n);
                continue;
            }
        };
        let v_star = match lu_g.solve(&b) {
            Some(v) => v,
            None => {
                eprintln!("  N={}: G singular!", n);
                continue;
            }
        };

        // Term 1: d²_free = 1 - bᵀ w*
        let d2_free = 1.0 - b.dot(&w_star);

        // Term 2: scattering = (w*)ᵀ Δ_true v*
        let scattering = w_star.dot(&(&delta_true * &v_star));

        // Dyson sum
        let d2_opt = d2_free + scattering;

        // Direct check: d²_opt = 1 - bᵀ v*
        let d2_direct = 1.0 - b.dot(&v_star);
        let check = (d2_opt - d2_direct).abs();

        let log_n = (n as f64).ln();
        let elapsed = t0.elapsed();

        dyson_results.push((n, d2_free, scattering, d2_opt));

        println!(
            "{:>6} {:>+14.8} {:>+14.8} {:>14.10} {:>12.6} {:>12.2e} {:>7.1?}",
            n,
            d2_free,
            scattering,
            d2_opt,
            d2_opt * log_n,
            check,
            elapsed
        );
    }

    // ═══════════════════════════════════════════════
    // §2. BORN PROTOCOL (OPTION D): w_bare = R_true⁻¹ b
    // ═══════════════════════════════════════════════
    println!();
    println!("════════════════════════════════════════════════════════════════════════════════════════════");
    println!("§2. BORN PROTOCOL: w_bare = R_true⁻¹ b (First-Order Born Approximation)");
    println!("════════════════════════════════════════════════════════════════════════════════════════════");
    println!();
    println!("d²_BD(w_bare) = d²_free + w_bare^T Δ_true w_bare   [UPPER BOUND on d²_opt]");
    println!();
    println!(
        "{:>6} {:>12} {:>14} {:>14} {:>14} {:>14} {:>10}",
        "N", "cᵀw_bare", "d²_free", "w^TΔw", "d²_Born", "d²_opt", "ratio"
    );
    println!("{}", "-".repeat(90));

    for &n in &test_ns {
        let g_mat = build_gram_matrix(n);
        let rt_mat = build_r_true(n);
        let b = build_b_vector(n);
        let c = build_c_vector(n);
        let delta_true = &g_mat - &rt_mat;

        let lu_rt = rt_mat.clone().lu();
        let lu_g = g_mat.clone().lu();

        // Bare BD weights: w_bare = R_true⁻¹ b
        let w_bare = match lu_rt.solve(&b) {
            Some(w) => w,
            None => {
                eprintln!("  N={}: R_true singular!", n);
                continue;
            }
        };

        // Optimal: v* = G⁻¹ b
        let v_star = match lu_g.solve(&b) {
            Some(v) => v,
            None => {
                eprintln!("  N={}: G singular!", n);
                continue;
            }
        };

        // DC orthogonality: c^T w_bare (should → 0 by symmetry)
        let ct_w_bare = c.dot(&w_bare);

        // Free energy: d²_free = 1 - b^T w_bare
        let d2_free = 1.0 - b.dot(&w_bare);

        // Thermal scattering: w_bare^T Δ_true w_bare
        let scatt = w_bare.dot(&(&delta_true * &w_bare));

        // Born energy (upper bound): d²_BD(w_bare) = d²_free + scatt
        let d2_born = d2_free + scatt;

        // Optimal: d²_opt = 1 - b^T v*
        let d2_opt = 1.0 - b.dot(&v_star);

        let ratio = if d2_opt > 0.0 {
            d2_born / d2_opt
        } else {
            f64::INFINITY
        };

        println!(
            "{:>6} {:>+12.8} {:>+14.8} {:>+14.8} {:>14.10} {:>14.10} {:>10.4}",
            n, ct_w_bare, d2_free, scatt, d2_born, d2_opt, ratio
        );
    }

    // ═══════════════════════════════════════════════
    // §4. HCN RESONATOR: Fejér-Möbius at Highly Composite Numbers
    // ═══════════════════════════════════════════════
    println!();
    println!("════════════════════════════════════════════════════════════════════════════════════════════");
    println!("§4. HCN RESONATOR: Fejér-Möbius weights at Highly Composite Numbers");
    println!("════════════════════════════════════════════════════════════════════════════════════════════");
    println!();
    println!("Wilsonian UV cutoff: w_k = -μ(k)(1 - lnk/lnN)/k");
    println!("HCNs: 120, 180, 240, 360, 720, 840, 1260, 1680, 2520");
    println!();
    println!(
        "{:>6} {:>14} {:>14} {:>14} {:>14} {:>14} {:>8}",
        "N", "d²_saw(FM)", "2(c-b)ᵀv", "vᵀΔ_true v", "d²_BD(FM)", "d²_opt", "time"
    );
    println!("{}", "-".repeat(95));

    // HCNs up to reasonable N for CPU
    let hcn_ns: Vec<usize> = vec![120, 180, 240, 360, 720, 840, 1260, 1680, 2520];
    let hcn_ns: Vec<usize> = hcn_ns.into_iter().filter(|&n| n <= n_max).collect();

    for &n in &hcn_ns {
        let t0 = Instant::now();

        let g_mat = build_gram_matrix(n);
        let rt_mat = build_r_true(n);
        let b = build_b_vector(n);
        let c = build_c_vector(n);
        let delta_true = &g_mat - &rt_mat;
        let dim = n - 1;

        // Fejér-Möbius weights: v_k = -μ(k+1)(1 - ln(k+1)/ln(N))
        let mut v_fm = DVector::zeros(dim);
        let ln_n = (n as f64).ln();
        for i in 0..dim {
            let k = i + 2;
            let mu = moebius_fn(k);
            if mu != 0 {
                v_fm[i] = -(mu as f64) * (1.0 - (k as f64).ln() / ln_n);
            }
        }

        // d²_saw(FM) = 1 - 2cᵀv + vᵀR_true v
        let d2_saw = 1.0 - 2.0 * c.dot(&v_fm) + v_fm.dot(&(&rt_mat * &v_fm));

        // 2(c-b)ᵀv
        let c_minus_b = &c - &b;
        let mean_corr = 2.0 * c_minus_b.dot(&v_fm);

        // vᵀΔ_true v
        let anomaly = v_fm.dot(&(&delta_true * &v_fm));

        // d²_BD(FM)
        let d2_bd = d2_saw + mean_corr + anomaly;

        // Optimal for comparison
        let lu_g = g_mat.lu();
        let v_star = match lu_g.solve(&b) {
            Some(v) => v,
            None => {
                continue;
            }
        };
        let d2_opt = 1.0 - b.dot(&v_star);

        let elapsed = t0.elapsed();

        println!(
            "{:>6} {:>+14.8} {:>+14.8} {:>+14.8} {:>14.10} {:>14.10} {:>7.1?}",
            n, d2_saw, mean_corr, anomaly, d2_bd, d2_opt, elapsed
        );
    }

    // Also run at non-HCN neighbors for comparison
    println!();
    println!("COMPARISON: Non-HCN neighbors");
    println!(
        "{:>6} {:>14} {:>14} {:>14} {:>14} {:>14} {:>8}",
        "N", "d²_saw(FM)", "2(c-b)ᵀv", "vᵀΔ_true v", "d²_BD(FM)", "d²_opt", "time"
    );
    println!("{}", "-".repeat(95));

    let non_hcn_ns: Vec<usize> = vec![100, 150, 200, 300, 500, 700];
    let non_hcn_ns: Vec<usize> = non_hcn_ns.into_iter().filter(|&n| n <= n_max).collect();

    for &n in &non_hcn_ns {
        let t0 = Instant::now();

        let g_mat = build_gram_matrix(n);
        let rt_mat = build_r_true(n);
        let b = build_b_vector(n);
        let c = build_c_vector(n);
        let delta_true = &g_mat - &rt_mat;
        let dim = n - 1;

        let mut v_fm = DVector::zeros(dim);
        let ln_n = (n as f64).ln();
        for i in 0..dim {
            let k = i + 2;
            let mu = moebius_fn(k);
            if mu != 0 {
                v_fm[i] = -(mu as f64) * (1.0 - (k as f64).ln() / ln_n);
            }
        }

        let d2_saw = 1.0 - 2.0 * c.dot(&v_fm) + v_fm.dot(&(&rt_mat * &v_fm));
        let c_minus_b = &c - &b;
        let mean_corr = 2.0 * c_minus_b.dot(&v_fm);
        let anomaly = v_fm.dot(&(&delta_true * &v_fm));
        let d2_bd = d2_saw + mean_corr + anomaly;

        let lu_g = g_mat.lu();
        let v_star = match lu_g.solve(&b) {
            Some(v) => v,
            None => {
                continue;
            }
        };
        let d2_opt = 1.0 - b.dot(&v_star);

        let elapsed = t0.elapsed();

        println!(
            "{:>6} {:>+14.8} {:>+14.8} {:>+14.8} {:>14.10} {:>14.10} {:>7.1?}",
            n, d2_saw, mean_corr, anomaly, d2_bd, d2_opt, elapsed
        );
    }

    // ═══════════════════════════════════════════════
    // §5. SUMMARY
    // ═══════════════════════════════════════════════
    println!();
    let elapsed = total_start.elapsed();
    println!("════════════════════════════════════════════════════════════════════════════════════════════");
    println!("DYSON PROTOCOL COMPLETE");
    println!("════════════════════════════════════════════════════════════════════════════════════════════");
    println!();
    println!("  N_max:      {}", n_max);
    println!("  Total time: {:.2?}", elapsed);
    println!();
    println!("  Master Equation: d²_opt(G) = d²_free + (w*)ᵀ Δ_true v*");
    println!("  HCN Resonator: Fejér-Möbius weights at Highly Composite Numbers");
    println!("  The prime number gas has fired its Nuclear Option. 🔥");
    println!();
}
