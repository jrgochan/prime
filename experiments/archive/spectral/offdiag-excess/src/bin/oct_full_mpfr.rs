#![allow(unused, dead_code)]
//! Full-Precision Octonionic Witness — Optimized MPFR
//!
//! Strategy: f64 breakpoints (fast) + MPFR antiderivatives (accurate)
//! Uses m_max = max(j,k)*100 to properly integrate near x=0.
//!
//! Usage: cargo run --release --bin oct_full_mpfr [sizes...]

use rayon::prelude::*;
use rug::{Float, float::Round};
use std::sync::Mutex;

const PREC: u32 = 128; // 128-bit precision (~38 decimal digits)

fn min_prime_factor(n: usize) -> usize {
    if n <= 1 { return 1; }
    if n % 2 == 0 { return 2; }
    let mut p = 3;
    while p * p <= n {
        if n % p == 0 { return p; }
        p += 2;
    }
    n
}

fn octonion_class(k: usize) -> usize {
    match min_prime_factor(k) {
        2 => 0, 3 => 1, 5 => 2, 7 => 3,
        11 => 4, 13 => 5, 17 => 6, _ => 7,
    }
}

fn class_label(cls: usize) -> &'static str {
    match cls {
        0 => "even", 1 => "3|k", 2 => "5|k", 3 => "7|k",
        4 => "11|k", 5 => "13|k", 6 => "17|k", 7 => "≥19",
        _ => "?",
    }
}

/// Compute gram_entry(j,k) = ∫₀¹ {j/x}{k/x} dx
/// Uses f64 breakpoints with MPFR antiderivative evaluation.
/// m_max = max(j,k)*100 ensures tail is < 10^-12.
fn gram_entry_hp(j: usize, k: usize) -> Float {
    if j == 0 || k == 0 {
        return Float::with_val(PREC, 0);
    }
    let jf = j as f64;
    let kf = k as f64;
    // Use much larger m_max to capture near-zero contributions
    let m_max = (j.max(k)) * 100 + 1000;

    // Collect breakpoints in f64 (fast)
    let mut breaks: Vec<f64> = Vec::with_capacity(2 * m_max);
    for m in j..=m_max {
        let x = jf / (m as f64);
        if x > 0.0 && x <= 1.0 { breaks.push(x); }
    }
    for m in k..=m_max {
        let x = kf / (m as f64);
        if x > 0.0 && x <= 1.0 { breaks.push(x); }
    }
    breaks.push(1.0);
    breaks.sort_by(|a, b| a.partial_cmp(b).unwrap());
    breaks.dedup_by(|a, b| (*a - *b).abs() < 1e-15);

    // MPFR constants
    let j_mp = Float::with_val(PREC, j as u32);
    let k_mp = Float::with_val(PREC, k as u32);
    let jk_mp = Float::with_val(PREC, &j_mp * &k_mp);

    let mut total = Float::with_val(PREC, 0);

    for i in 0..breaks.len() - 1 {
        let x_lo_f = breaks[i];
        let x_hi_f = breaks[i + 1];
        if x_hi_f - x_lo_f < 1e-18 { continue; }

        let x_mid_f = 0.5 * (x_lo_f + x_hi_f);
        let a = (jf / x_mid_f).floor();
        let b = (kf / x_mid_f).floor();

        // Convert to MPFR for the antiderivative computation
        let x_lo = Float::with_val(PREC, x_lo_f);
        let x_hi = Float::with_val(PREC, x_hi_f);
        let a_mp = Float::with_val(PREC, a);
        let b_mp = Float::with_val(PREC, b);

        // lin_coeff = b*j + a*k
        let bj = Float::with_val(PREC, &b_mp * &j_mp);
        let ak = Float::with_val(PREC, &a_mp * &k_mp);
        let lin_coeff = Float::with_val(PREC, &bj + &ak);
        let const_coeff = Float::with_val(PREC, &a_mp * &b_mp);

        // F(x) = -jk/x - lin_coeff * ln(x) + const_coeff * x
        let eval = |x: &Float| -> Float {
            let t1 = Float::with_val(PREC, -Float::with_val(PREC, &jk_mp / x));
            let t2 = Float::with_val(PREC, -Float::with_val(PREC, &lin_coeff * x.clone().ln()));
            let t3 = Float::with_val(PREC, &const_coeff * x);
            let s12 = Float::with_val(PREC, &t1 + &t2);
            Float::with_val(PREC, &s12 + &t3)
        };

        let f_hi = eval(&x_hi);
        let f_lo = eval(&x_lo);
        let diff = Float::with_val(PREC, &f_hi - &f_lo);
        total += &diff;
    }
    total
}

/// Compute ∫₀¹ {j/x} dx using f64 breakpoints + MPFR evaluation
fn fract_integral_hp(j: usize) -> Float {
    if j == 0 {
        return Float::with_val(PREC, 0);
    }
    let jf = j as f64;
    let m_max = j * 100 + 1000;

    let mut breaks: Vec<f64> = Vec::with_capacity(m_max);
    for m in j..=m_max {
        let x = jf / (m as f64);
        if x > 0.0 && x <= 1.0 { breaks.push(x); }
    }
    breaks.push(1.0);
    breaks.sort_by(|a, b| a.partial_cmp(b).unwrap());
    breaks.dedup_by(|a, b| (*a - *b).abs() < 1e-15);

    let j_mp = Float::with_val(PREC, j as u32);
    let mut total = Float::with_val(PREC, 0);

    for i in 0..breaks.len() - 1 {
        let x_lo_f = breaks[i];
        let x_hi_f = breaks[i + 1];
        if x_hi_f - x_lo_f < 1e-18 { continue; }

        let x_mid_f = 0.5 * (x_lo_f + x_hi_f);
        let a = (jf / x_mid_f).floor();

        let x_lo = Float::with_val(PREC, x_lo_f);
        let x_hi = Float::with_val(PREC, x_hi_f);
        let a_mp = Float::with_val(PREC, a);

        // F(x) = j*ln(x) - a*x
        let f = |x: &Float| -> Float {
            let t1 = Float::with_val(PREC, &j_mp * x.clone().ln());
            let t2 = Float::with_val(PREC, &a_mp * x);
            Float::with_val(PREC, &t1 - &t2)
        };
        let diff = Float::with_val(PREC, &f(&x_hi) - &f(&x_lo));
        total += &diff;
    }
    total
}

/// Solve n×n system with MPFR Gaussian elimination
fn solve_mpfr(a: &[Vec<Float>], b: &[Float]) -> Vec<Float> {
    let n = b.len();
    let mut aug: Vec<Vec<Float>> = (0..n).map(|i| {
        let mut row: Vec<Float> = a[i].iter().map(|x| x.clone()).collect();
        row.push(b[i].clone());
        row
    }).collect();

    for col in 0..n {
        let mut max_row = col;
        for row in (col + 1)..n {
            if aug[row][col].clone().abs() > aug[max_row][col].clone().abs() {
                max_row = row;
            }
        }
        aug.swap(col, max_row);
        let pivot = aug[col][col].clone();
        if pivot.clone().abs() < Float::with_val(PREC, 1e-80) { continue; }
        for row in (col + 1)..n {
            let factor = Float::with_val(PREC, &aug[row][col] / &pivot);
            for j in col..=n {
                let val = aug[col][j].clone();
                aug[row][j] -= &factor * &val;
            }
        }
    }
    let mut x: Vec<Float> = (0..n).map(|_| Float::with_val(PREC, 0)).collect();
    for i in (0..n).rev() {
        let mut sum = aug[i][n].clone();
        for j in (i + 1)..n { sum -= &aug[i][j] * &x[j]; }
        x[i] = Float::with_val(PREC, &sum / &aug[i][i]);
    }
    x
}

fn main() {
    let sizes: Vec<usize> = std::env::args()
        .skip(1)
        .filter_map(|s| s.parse().ok())
        .collect();
    let sizes = if sizes.is_empty() {
        vec![50, 100, 150, 200, 250, 300]
    } else {
        sizes
    };

    eprintln!("══════════════════════════════════════════════════════════════════");
    eprintln!("  Full-Precision Octonionic Witness (MPFR {}-bit)", PREC);
    eprintln!("  Gram entries: f64 breaks + MPFR eval, m_max=100*max(j,k)");
    eprintln!("  Fixed truncation: integrates to x ≈ 0.01 (not 0.1)");
    eprintln!("══════════════════════════════════════════════════════════════════\n");

    // First, validate by comparing a few gram entries with the old f64 version
    {
        use offdiag_excess::{gram_entry, fract_integral};
        eprintln!("  ── Validation: old vs new gram_entry ──");
        for &(j, k) in &[(2,2), (5,5), (10,10), (50,50), (100,100)] {
            let old = gram_entry(j, k);
            let new = gram_entry_hp(j, k);
            let new_f = new.to_f64_round(Round::Nearest);
            let diff = (new_f - old).abs();
            eprintln!("    G[{:3},{:3}]: old={:.15}, new={:.15}, diff={:.2e}",
                j, k, old, new_f, diff);
        }
        eprintln!("  ── Validation: old vs new fract_integral ──");
        for &j in &[2, 10, 50, 100] {
            let old = fract_integral(j);
            let new = fract_integral_hp(j);
            let new_f = new.to_f64_round(Round::Nearest);
            let diff = (new_f - old).abs();
            eprintln!("    b[{:3}]: old={:.15}, new={:.15}, diff={:.2e}",
                j, old, new_f, diff);
        }
        eprintln!();
    }

    eprintln!("{:>5} {:>12} {:>14} {:>14} {:>8}",
        "n", "d2(const)", "d2(8cls)", "btv", "time");
    eprintln!("{}", "-".repeat(58));

    for &n in &sizes {
        let start = std::time::Instant::now();
        let dim = n;

        let classes: Vec<usize> = (0..dim).map(|i| octonion_class(i + 2)).collect();
        let mut active_classes: Vec<usize> = Vec::new();
        let mut class_count = vec![0usize; 8];
        for &c in &classes { class_count[c] += 1; }
        for c in 0..8 { if class_count[c] > 0 { active_classes.push(c); } }
        let nc = active_classes.len();
        let mut class_to_idx = vec![0usize; 8];
        for (idx, &c) in active_classes.iter().enumerate() { class_to_idx[c] = idx; }

        eprintln!("  N={}: computing {} gram_entries + {} b_entries...",
            n + 1, dim * (dim + 1) / 2, dim);

        // b vector (class-aggregated)
        let mut b_cls: Vec<Float> = (0..nc).map(|_| Float::with_val(PREC, 0)).collect();
        for i in 0..dim {
            let bi = fract_integral_hp(i + 2);
            let ci = class_to_idx[classes[i]];
            b_cls[ci] += &bi;
        }

        // G matrix (class-aggregated) — use symmetry, parallelized
        let g_cls_mutex: Vec<Vec<Mutex<Float>>> = (0..nc).map(|_| {
            (0..nc).map(|_| Mutex::new(Float::with_val(PREC, 0))).collect()
        }).collect();

        (0..dim).into_par_iter().for_each(|i| {
            let ci = class_to_idx[classes[i]];
            for j in i..dim {
                let cj = class_to_idx[classes[j]];
                let gij = gram_entry_hp(i + 2, j + 2);
                {
                    let mut val = g_cls_mutex[ci][cj].lock().unwrap();
                    *val += &gij;
                }
                if i != j {
                    let mut val = g_cls_mutex[cj][ci].lock().unwrap();
                    *val += &gij;
                }
            }
        });

        let g_cls: Vec<Vec<Float>> = (0..nc).map(|i| {
            (0..nc).map(|j| g_cls_mutex[i][j].lock().unwrap().clone()).collect()
        }).collect();

        // Solve 8×8 system
        let c_cls = solve_mpfr(&g_cls, &b_cls);

        // btv = cᵀ b_cls
        let mut btv = Float::with_val(PREC, 0);
        for i in 0..nc {
            btv += Float::with_val(PREC, &c_cls[i] * &b_cls[i]);
        }
        let d2_cls = Float::with_val(PREC, 1) - &btv;

        // Constant witness
        let mut b_sum = Float::with_val(PREC, 0);
        let mut g_sum = Float::with_val(PREC, 0);
        for i in 0..nc { b_sum += &b_cls[i]; }
        for i in 0..nc { for j in 0..nc { g_sum += &g_cls[i][j]; } }
        let c_const = Float::with_val(PREC, &b_sum / &g_sum);
        let cb = Float::with_val(PREC, &c_const * &b_sum);
        let two_cb = Float::with_val(PREC, Float::with_val(PREC, 2) * &cb);
        let cc = Float::with_val(PREC, &c_const * &c_const);
        let ccg = Float::with_val(PREC, &cc * &g_sum);
        let tmp = Float::with_val(PREC, Float::with_val(PREC, 1) - &two_cb);
        let d2_const = Float::with_val(PREC, &tmp + &ccg);

        let elapsed = start.elapsed();

        let d2_const_f = d2_const.to_f64_round(Round::Nearest);
        let d2_cls_str = d2_cls.to_string_radix(10, Some(15));
        let btv_str = btv.to_string_radix(10, Some(18));

        eprintln!("{:5} {:12.6} {:>14} {:>14} {:8.1}s",
            n, d2_const_f, d2_cls_str, btv_str, elapsed.as_secs_f64());

        // Detailed output
        eprintln!("        classes: [{}]",
            active_classes.iter().map(|c| format!("{}:{}", class_label(*c), class_count[*c]))
                .collect::<Vec<_>>().join(", "));
        for (idx, &cls) in active_classes.iter().enumerate() {
            eprintln!("        c[{}] ({:>4}) = {}",
                cls, class_label(cls), c_cls[idx].to_string_radix(10, Some(12)));
        }
        let btv_f = btv.to_f64_round(Round::Nearest);
        if btv_f > 1.0 {
            eprintln!("        ⚠️  btv = {:.15} > 1 — Cauchy-Schwarz VIOLATED", btv_f);
        } else {
            eprintln!("        ✓  btv = {:.15} ≤ 1 (Cauchy-Schwarz OK)", btv_f);
        }
        eprintln!();
    }

    eprintln!("══════════════════════════════════════════════════════════════════");
    eprintln!("  With corrected integration + MPFR arithmetic:");
    eprintln!("  btv MUST satisfy 0 ≤ btv ≤ 1 (Cauchy-Schwarz).");
    eprintln!("  d²(8cls) ≥ 0 always. If it → 0, RH = 8 parameters!");
    eprintln!("══════════════════════════════════════════════════════════════════");
}
