#![allow(dead_code, unused_variables, unused_imports, unused_assignments, clippy::needless_range_loop, clippy::doc_lazy_continuation, non_snake_case, clippy::empty_line_after_doc_comments)]
// overcancellation-scan/src/bin/two_tier_gram_probe.rs
//
// ╔═══════════════════════════════════════════════════════════════╗
// ║  TWO-TIER GRAM BOUND (Option A) — HPDF-Backed               ║
// ║  MASSIVELY PARALLEL version                                   ║
// ║                                                               ║
// ║  Evaluates: vᵀGv ≤ Head_G(J) + M_tail · (Σ_{k≥J} |v_k|)²  ║
// ║  Using precomputed .h5 Gram matrices up to N=55440           ║
// ║                                                               ║
// ║  KEY OPTIMIZATION: Single O(n²) parallel pass computes all   ║
// ║  J values simultaneously via shell decomposition.             ║
// ║                                                               ║
// ║  Shell decomposition:                                         ║
// ║    shell[i] = Σ_j v[i]·v[j]·G(i,j) where min(i,j) = i      ║
// ║    Head(J) = Σ_{i<J} shell[i]  (prefix sum)                  ║
// ║    M_tail(J) = max_{i,j≥J} |G(i,j)|  (suffix max)           ║
// ╚═══════════════════════════════════════════════════════════════╝

use cathedral_utils::hpdf::HpdfReader;
use rayon::prelude::*;
use std::f64::consts::PI;
use std::path::PathBuf;

const EULER_GAMMA: f64 = 0.5772156649015329;

fn vasyunin_const() -> f64 {
    (2.0 * PI).ln() - EULER_GAMMA
}

/// Vasyunin cotangent sum V(a,b) = Σ_{m=1}^{a-1} cot(πm/a) · {mb/a}
fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 { return 0.0; }
    let af = a as f64;
    let mut s = 0.0;
    for m in 1..a {
        let angle = PI * m as f64 / af;
        let cot = angle.cos() / angle.sin();
        let frac = ((m * b) as f64 / af).fract();
        s += cot * frac;
    }
    s
}

/// G(1,k) via Vasyunin formula (analytic, for k=1 row)
fn gram_entry_k1(k: usize) -> f64 {
    let c = vasyunin_const();
    if k == 1 {
        return c - 1.0;
    }
    let kf = k as f64;
    let t1 = c / 2.0 * (1.0 + 1.0 / kf);
    let t2 = (1.0 - kf) / (2.0 * kf) * kf.ln();
    let vk1 = vasyunin_sum(k, 1);
    let t3 = PI / (2.0 * kf) * vk1;
    let t4 = 1.0 / kf;
    t1 + t2 - t3 - t4
}

fn main() {
    println!("╔═══════════════════════════════════════════════════════════════════════════════╗");
    println!("║  TWO-TIER GRAM BOUND (Option A) — HPDF MASSIVELY PARALLEL                  ║");
    println!("║  vᵀGv ≤ Head(J) + M_tail · (Σ_{{k≥J}} |v_k|)²                               ║");
    println!("║  Shell decomposition: single O(n²) pass → all J values in O(1)              ║");
    println!("╚═══════════════════════════════════════════════════════════════════════════════╝");
    println!();

    let cache_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent().unwrap()
        .join("cache/hpdf");

    let hc_ns: Vec<usize> = vec![
        360, 840, 1260, 2520, 7560, 10080, 20160, 27720, 45360, 55440,
    ];

    let j_values: Vec<usize> = vec![3, 5, 10, 15, 20, 30, 50, 75, 100];

    for &n in &hc_ns {
        let path = cache_dir.join(format!("gram_N{}.h5", n));
        if !path.exists() {
            eprintln!("  [skip] {} not found", path.display());
            continue;
        }

        let reader = match HpdfReader::open(&path) {
            Ok(r) => r,
            Err(e) => {
                eprintln!("  [skip] N={}: {}", n, e);
                continue;
            }
        };

        let dim = reader.dim(); // N-1 (HPDF stores k≥2)
        let gram_flat = reader.read_gram_full().unwrap();
        let mu_raw = reader.read_mobius().unwrap();
        let log_n = (n as f64).ln();

        // ═══ Build witness v_k = -μ(k)·(1-ln(k)/lnN)/k, k=1..N ═══
        let mut v_full = vec![0.0f64; n]; // 0-indexed: v_full[k-1] = v_k
        v_full[0] = -1.0; // k=1

        for k in 2..n {
            let i = k - 2;
            if i >= dim { break; }
            let mu_k = mu_raw[k] as f64;
            let cutoff = 1.0 - (k as f64).ln() / log_n;
            if cutoff > 0.0 {
                v_full[k - 1] = -mu_k * cutoff / (k as f64);
            }
        }

        // Normalize
        let norm: f64 = v_full.iter().map(|x| x * x).sum::<f64>().sqrt();
        if norm < 1e-15 { continue; }
        for x in v_full.iter_mut() { *x /= norm; }

        // ═══ Gram entry accessor ═══
        let gram_entry = |j: usize, k: usize| -> f64 {
            // j, k are 1-indexed
            if j == 1 && k == 1 { return gram_entry_k1(1); }
            if j == 1 { return gram_entry_k1(k); }
            if k == 1 { return gram_entry_k1(j); }
            let ii = j - 2; let ji = k - 2;
            if ii < dim && ji < dim { gram_flat[ii * dim + ji] } else { 0.0 }
        };

        // ═══════════════════════════════════════════════════════════
        // SHELL DECOMPOSITION (massively parallel)
        //
        // For each index i (0-indexed, representing k=i+1):
        //   shell[i] = contribution to Head when J first exceeds i
        //            = Σ_{j≥i} v[i]·v[j]·G(i+1,j+1) if i < j (counted twice: (i,j) and (j,i))
        //              + v[i]²·G(i+1,i+1) for diagonal
        //   BUT we also need (j,i) pairs where j < i — those belong to shell[j].
        //
        // Clean definition:
        //   For pair (i,j) with i ≤ j:
        //     min = i, so it enters Head(J) when J > i
        //     contribution = v[i]·v[j]·G(i+1,j+1) · (1 if i==j, 2 if i<j)
        //   shell[i] = Σ_{j≥i} weight(i,j) · v[i]·v[j]·G(i+1,j+1)
        //   Head(J) = Σ_{i < J-1} shell[i]   (using 0-indexed i, J is 1-indexed k)
        //
        // max_entry_at[i] = max_{j≥i} |G(i+1,j+1)|   (for suffix max)
        // ═══════════════════════════════════════════════════════════

        eprint!("  N={:>6}: computing shells...", n);

        // Parallel over rows: compute shell[i] and max_entry_at[i]
        let row_data: Vec<(f64, f64)> = (0..n).into_par_iter()
            .map(|i| {
                let j_1 = i + 1; // 1-indexed
                let mut shell = 0.0f64;
                let mut max_g = 0.0f64;

                for j in i..n {
                    let k_1 = j + 1; // 1-indexed
                    let g = gram_entry(j_1, k_1);
                    let weight = if i == j { 1.0 } else { 2.0 };
                    shell += weight * v_full[i] * v_full[j] * g;
                    max_g = max_g.max(g.abs());
                }
                (shell, max_g)
            })
            .collect();

        let shells: Vec<f64> = row_data.iter().map(|r| r.0).collect();
        let max_per_row: Vec<f64> = row_data.iter().map(|r| r.1).collect();

        // ═══ Prefix sums & suffix max ═══
        // Head(J) = Σ_{i: i+1 < J} shell[i] = prefix_sum[J-2]  (for J ≥ 2)
        let mut prefix_sum = vec![0.0f64; n];
        prefix_sum[0] = shells[0];
        for i in 1..n {
            prefix_sum[i] = prefix_sum[i - 1] + shells[i];
        }

        // M_tail(J) = max_{i ≥ J-1} max_per_row[i]  (suffix max)
        let mut suffix_max = vec![0.0f64; n];
        suffix_max[n - 1] = max_per_row[n - 1];
        for i in (0..n - 1).rev() {
            suffix_max[i] = suffix_max[i + 1].max(max_per_row[i]);
        }

        // tail_l1(J) = Σ_{k≥J} |v_k| = Σ_{i≥J-1} |v_full[i]|  (suffix sum)
        let mut suffix_l1 = vec![0.0f64; n + 1]; // suffix_l1[i] = Σ_{j≥i} |v[j]|
        for i in (0..n).rev() {
            suffix_l1[i] = suffix_l1[i + 1] + v_full[i].abs();
        }

        // vᵀGv = prefix_sum[n-1] (sum of all shells)
        let vtgv = prefix_sum[n - 1];

        eprintln!(" vᵀGv = {:+.8}", vtgv);

        // ═══ Print table ═══
        println!();
        println!("═══ N = {} (dim={}, vᵀGv = {:+.8}, 1/lnN = {:.6}) ═══", n, n, vtgv, 1.0/log_n);
        println!("{:>6} {:>+14} {:>10} {:>14} {:>+14} {:>+10} {:>10}",
            "J", "Head(J)", "M_tail", "TailBound", "BOUND", "Slack", "K_eff");
        println!("{}", "─".repeat(82));

        for &j in &j_values {
            if j < 2 || j >= n { continue; }

            // Head(J) = prefix_sum[J-2]  (all shells with 0-indexed i < J-1)
            let head = prefix_sum[j - 2];

            // M_tail(J) = suffix_max[J-1]
            let m_tail = suffix_max[j - 1];

            // tail_l1(J) = suffix_l1[J-1]
            let tail_l1 = suffix_l1[j - 1];
            let tail_bound = m_tail * tail_l1 * tail_l1;

            let bound = head + tail_bound;
            let slack = bound - vtgv;
            let k_eff = (bound - 1.0) * log_n;

            let marker = if bound <= 1.0 { " ✓✓" } else if k_eff < 5.0 { " ✓" } else { "" };

            println!("{:>6} {:>+14.8} {:>10.6} {:>14.8} {:>+14.8} {:>+10.6} {:>10.4}{}",
                j, head, m_tail, tail_bound, bound, slack, k_eff, marker);
        }

        // ═══ Find optimal J ═══
        let mut best_j = 2usize;
        let mut best_bound = f64::INFINITY;
        for j in 2..n.min(200) {
            let head = prefix_sum[j - 2];
            let m_tail = suffix_max[j - 1];
            let tail_l1 = suffix_l1[j - 1];
            let bound = head + m_tail * tail_l1 * tail_l1;
            if bound < best_bound {
                best_bound = bound;
                best_j = j;
            }
        }
        let k_eff_best = (best_bound - 1.0) * log_n;
        println!("{}", "─".repeat(82));
        println!("  OPTIMAL: J* = {}, Bound = {:+.8}, K_eff = {:.4}", best_j, best_bound, k_eff_best);
        println!();
    }

    // ═══ SUMMARY TABLE ═══
    println!();
    println!("╔═══════════════════════════════════════════════════════════════════════════════╗");
    println!("║  SUMMARY: Optimal J* and K_eff across N                                     ║");
    println!("╚═══════════════════════════════════════════════════════════════════════════════╝");
    println!("{:>8} {:>+12} {:>6} {:>+12} {:>10} {:>10}",
        "N", "vᵀGv", "J*", "Bound*", "K_eff", "1/lnN");
    println!("{}", "─".repeat(62));

    // Re-run optimal J search for summary
    for &n in &hc_ns {
        let path = cache_dir.join(format!("gram_N{}.h5", n));
        if !path.exists() { continue; }

        let reader = match HpdfReader::open(&path) {
            Ok(r) => r,
            Err(_) => continue,
        };

        let dim = reader.dim();
        let gram_flat = reader.read_gram_full().unwrap();
        let mu_raw = reader.read_mobius().unwrap();
        let log_n = (n as f64).ln();

        let mut v_full = vec![0.0f64; n];
        v_full[0] = -1.0;
        for k in 2..n {
            let i = k - 2;
            if i >= dim { break; }
            let mu_k = mu_raw[k] as f64;
            let cutoff = 1.0 - (k as f64).ln() / log_n;
            if cutoff > 0.0 {
                v_full[k - 1] = -mu_k * cutoff / (k as f64);
            }
        }
        let norm: f64 = v_full.iter().map(|x| x * x).sum::<f64>().sqrt();
        if norm < 1e-15 { continue; }
        for x in v_full.iter_mut() { *x /= norm; }

        let gram_entry = |j: usize, k: usize| -> f64 {
            if j == 1 && k == 1 { return gram_entry_k1(1); }
            if j == 1 { return gram_entry_k1(k); }
            if k == 1 { return gram_entry_k1(j); }
            let ii = j - 2; let ji = k - 2;
            if ii < dim && ji < dim { gram_flat[ii * dim + ji] } else { 0.0 }
        };

        // Quick parallel shell computation
        let row_data: Vec<(f64, f64)> = (0..n).into_par_iter()
            .map(|i| {
                let j_1 = i + 1;
                let mut shell = 0.0f64;
                let mut max_g = 0.0f64;
                for j in i..n {
                    let g = gram_entry(j_1, j + 1);
                    let w = if i == j { 1.0 } else { 2.0 };
                    shell += w * v_full[i] * v_full[j] * g;
                    max_g = max_g.max(g.abs());
                }
                (shell, max_g)
            })
            .collect();

        let mut prefix_sum = vec![0.0f64; n];
        prefix_sum[0] = row_data[0].0;
        for i in 1..n { prefix_sum[i] = prefix_sum[i-1] + row_data[i].0; }

        let mut suffix_max = vec![0.0f64; n];
        suffix_max[n-1] = row_data[n-1].1;
        for i in (0..n-1).rev() { suffix_max[i] = suffix_max[i+1].max(row_data[i].1); }

        let mut suffix_l1 = vec![0.0f64; n+1];
        for i in (0..n).rev() { suffix_l1[i] = suffix_l1[i+1] + v_full[i].abs(); }

        let vtgv = prefix_sum[n-1];

        let mut best_j = 2usize;
        let mut best_bound = f64::INFINITY;
        for j in 2..n.min(200) {
            let head = prefix_sum[j-2];
            let m_tail = suffix_max[j-1];
            let tl1 = suffix_l1[j-1];
            let bound = head + m_tail * tl1 * tl1;
            if bound < best_bound { best_bound = bound; best_j = j; }
        }

        let k_eff = (best_bound - 1.0) * log_n;
        println!("{:>8} {:>+12.8} {:>6} {:>+12.8} {:>10.4} {:>10.6}",
            n, vtgv, best_j, best_bound, k_eff, 1.0/log_n);
    }

    println!();
    println!("═══════════════════════════════════════════════════════════════════════════════");
    println!("KEY:");
    println!("  Shell[i] = Σ_{{j≥i}} w·v[i]·v[j]·G(i+1,j+1)  (parallel over i)");
    println!("  Head(J)  = Σ_{{i<J}} Shell[i]                   (prefix sum, O(1) lookup)");
    println!("  M_tail(J)= max_{{i≥J}} max_{{j≥i}} |G|          (suffix max, O(1) lookup)");
    println!("  Bound(J) = Head(J) + M_tail(J) · (Σ_{{k≥J}} |v_k|)²");
    println!("  K_eff    = (Bound - 1) · lnN                   (want → stabilize = O(1/lnN))");
    println!("═══════════════════════════════════════════════════════════════════════════════");
}
