#![allow(
    dead_code,
    unused_variables,
    unused_imports,
    unused_assignments,
    clippy::needless_range_loop,
    clippy::doc_lazy_continuation,
    non_snake_case,
    clippy::empty_line_after_doc_comments
)]
// overcancellation-scan/src/bin/cotangent_residual_hpdf.rs
//
// ╔═══════════════════════════════════════════════════════════════╗
// ║  COTANGENT RESIDUAL — HPDF-Backed (up to N=55440)           ║
// ║  WITH k=1 ANCHOR (Mertens correction)                        ║
// ║                                                               ║
// ║  Uses precomputed .h5 Gram matrices + analytic k=1 row.      ║
// ║  Reports: D, CσS-S², R_cot, |L₁/A₁|, R/rest ratio          ║
// ╚═══════════════════════════════════════════════════════════════╝

use cathedral_utils::arith::gcd;
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
    if a <= 1 {
        return 0.0;
    }
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

/// G(1,k) via Vasyunin formula (analytic, for augmenting the HPDF k≥2 matrix)
/// gcd(1,k)=1, j'=1, k'=k
/// G(1,1) = C - 1
/// G(1,k) = (C/2)(1+1/k) + (1-k)/(2k)·ln(k) - π/(2k)·V(k,1) - 1/k
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

/// B₁ skeleton entry: gcd²/(12jk)
fn b1_entry(j: usize, k: usize) -> f64 {
    let g = gcd(j, k) as f64;
    g * g / (12.0 * j as f64 * k as f64)
}

fn main() {
    println!("╔═══════════════════════════════════════════════════════════════════════════════╗");
    println!("║  COTANGENT RESIDUAL (HPDF + k=1) — The Missing 88% at Scale                ║");
    println!("║  Decomposition: vᵀGv = D + CσS - S² + R_cot                                ║");
    println!("╚═══════════════════════════════════════════════════════════════════════════════╝");
    println!();

    let c = vasyunin_const();
    println!("  C = ln(2π) − γ = {:.6}", c);
    println!("  C - 2/3 = {:.6}", c - 2.0 / 3.0);
    println!();

    let cache_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .join("cache/hpdf");

    // HCN files available
    let hc_ns: Vec<usize> = vec![
        360, 840, 1260, 2520, 7560, 10080, 20160, 27720, 45360, 55440,
    ];

    println!("═══ FULL k≥1 (HPDF k≥2 + analytic k=1 anchor) ═══");
    println!(
        "{:>8} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10}",
        "N", "vᵀGv", "D", "CσS-S²", "R_cot", "R/rest", "vᵀA₁v", "|L₁/A₁|", "|L₁/A₁|·lnN", "1/lnN"
    );
    println!("{}", "─".repeat(108));

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

        let dim = reader.dim(); // N-1
        let max_n = reader.max_n();
        assert_eq!(max_n, n);

        eprint!("  N = {:>6} (dim={})...", n, dim);

        let mu_raw = reader.read_mobius().unwrap();
        let gram = reader.read_gram_full().unwrap();

        let log_n = (n as f64).ln();

        // ═══ Build full witness k=1..N ═══
        // k=1: v₁ = -μ(1)·(1-ln(1)/lnN)/1 = -1·1/1 = -1
        let v1: f64 = -(mu_raw[1] as f64) * (1.0 - (1.0f64).ln() / log_n) / 1.0;

        // k=2..N: from HPDF
        let mut v2 = vec![0.0f64; dim];
        for i in 0..dim {
            let k = i + 2;
            if k >= n {
                break;
            }
            let mu_k = mu_raw[k] as f64;
            let cutoff = 1.0 - (k as f64).ln() / log_n;
            if cutoff > 0.0 {
                v2[i] = -mu_k * cutoff / (k as f64);
            }
        }

        // Full norm for normalization (k=1 + k≥2)
        let norm_sq_full: f64 = v1 * v1 + v2.iter().map(|x| x * x).sum::<f64>();
        let norm = norm_sq_full.sqrt();
        if norm < 1e-15 {
            continue;
        }

        // Normalize everything
        let v1_n = v1 / norm;
        let v2_n: Vec<f64> = v2.iter().map(|x| x / norm).collect();

        // ═══ Compute σ and S for full k=1..N ═══
        // σ = v₁ + Σ_{k≥2} vₖ
        let sigma: f64 = v1_n + v2_n.iter().sum::<f64>();
        // S = v₁/2 + Σ_{k=2..N} vₖ/(k+1)
        //   = v₁/(1+1) + Σ_{i=0..dim} v2_n[i]/(i+2+1)
        let s: f64 = v1_n / 2.0
            + v2_n
                .iter()
                .enumerate()
                .map(|(i, &vi)| vi / (i as f64 + 3.0)) // k=i+2, k+1=i+3
                .sum::<f64>();

        // ═══ vᵀGv for k≥2 sector (from HPDF) ═══
        let row_results: Vec<(f64, f64, f64)> = (0..dim)
            .into_par_iter()
            .map(|i| {
                let mut row_full = 0.0;
                let mut row_diag = 0.0;
                let mut row_a1 = 0.0;
                let j = i + 2;
                for ji in 0..dim {
                    let k = ji + 2;
                    let prod = v2_n[i] * v2_n[ji];
                    row_full += prod * gram[i * dim + ji];
                    row_a1 += prod * b1_entry(j, k);
                    if i == ji {
                        row_diag += prod * gram[i * dim + ji];
                    }
                }
                (row_full, row_diag, row_a1)
            })
            .collect();

        let vtgv_k2: f64 = row_results.iter().map(|r| r.0).sum();
        let diag_k2: f64 = row_results.iter().map(|r| r.1).sum();
        let vta1v_k2: f64 = row_results.iter().map(|r| r.2).sum();

        // ═══ k=1 contributions (analytic) ═══
        // Diagonal: v₁² · G(1,1)
        let g11 = gram_entry_k1(1);
        let diag_k1 = v1_n * v1_n * g11;

        // Cross terms: 2 · v₁ · Σ_{k≥2} vₖ · G(1,k)
        // Also A₁ cross terms
        let mut cross_vtgv = 0.0f64;
        let mut cross_a1 = 0.0f64;
        for i in 0..dim {
            let k = i + 2;
            if k >= n {
                break;
            }
            let g1k = gram_entry_k1(k);
            cross_vtgv += 2.0 * v1_n * v2_n[i] * g1k;
            cross_a1 += 2.0 * v1_n * v2_n[i] * b1_entry(1, k);
        }
        // A₁(1,1) = 1/12
        let a1_k1 = v1_n * v1_n * b1_entry(1, 1);

        // ═══ Full k≥1 totals ═══
        let vtgv = vtgv_k2 + diag_k1 + cross_vtgv;
        let diag = diag_k2 + diag_k1;
        let vta1v = vta1v_k2 + a1_k1 + cross_a1;
        let vtl1v = vtgv - vta1v;

        let brake = c * sigma * s - s * s;
        let r_cot = vtgv - diag - brake;
        let rest = diag + brake;
        let r_ratio = if rest.abs() > 1e-15 {
            r_cot / rest
        } else {
            f64::NAN
        };
        let l1_ratio = if vta1v.abs() > 1e-15 {
            (vtl1v / vta1v).abs()
        } else {
            f64::NAN
        };
        let l1_logn = l1_ratio * log_n;
        let inv_logn = 1.0 / log_n;

        eprintln!(" done (vᵀGv={:.6}, σ={:.6}, S={:.6})", vtgv, sigma, s);

        println!("{:>8} {:>+10.6} {:>+10.6} {:>+10.6} {:>+10.6} {:>+10.4} {:>+10.6} {:>10.4} {:>10.4} {:>10.4}",
            n, vtgv, diag, brake, r_cot, r_ratio, vta1v, l1_ratio, l1_logn, inv_logn);
    }

    println!();
    println!("═══════════════════════════════════════════════════════════════════════════════");
    println!("KEY COLUMNS:");
    println!("  R/rest     : cotangent residual / (D+brake). Expect ≈ -0.88 with k=1");
    println!("  |L₁/A₁|   : perturbation/skeleton ratio");
    println!("  |L₁/A₁|·lnN : if stabilizes → |L₁/A₁| = O(1/logN) CONFIRMED");
    println!("═══════════════════════════════════════════════════════════════════════════════");
}
