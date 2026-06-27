#![allow(unused, dead_code, non_snake_case)]
use nalgebra::{DMatrix, SymmetricEigen};
use rayon::prelude::*;

// ══════════════════════════════════════════════════════════════════════
// GUE CONNECTION: RANDOM MATRIX UNIVERSALITY AT THE SPECTRAL EDGE
//
// Montgomery-Odlyzko: ζ(s) zeros have GUE statistics.
// Does the Nyman-Beurling Gram matrix G share this universality?
//
// Tests:
// 1. Eigenvalue spacing distribution near the edge (Wigner surmise)
// 2. Tracy-Widom scaling of λ_min
// 3. The "magic ratio" R = 0.924 — is it a GUE universal constant?
// 4. Bulk vs edge statistics comparison
// 5. Block-restricted vs full G statistics
// 6. Number variance Σ²(L) compared to GUE/GOE/Poisson
// ══════════════════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 {
    x - x.floor()
}

#[derive(Clone)]
struct Oct {
    c: [f64; 8],
}
impl Oct {
    fn basis(i: usize) -> Self {
        let mut c = [0.; 8];
        c[i] = 1.;
        Self { c }
    }
    fn real(a: f64) -> Self {
        Self {
            c: [a, 0., 0., 0., 0., 0., 0., 0.],
        }
    }
    fn norm(&self) -> f64 {
        self.c.iter().map(|x| x * x).sum::<f64>().sqrt()
    }
    fn scale(&self, s: f64) -> Self {
        let mut c = self.c;
        for x in c.iter_mut() {
            *x *= s;
        }
        Self { c }
    }
    fn mul(&self, o: &Self) -> Self {
        let (a, b) = (&self.c, &o.c);
        Self {
            c: [
                a[0] * b[0]
                    - a[1] * b[1]
                    - a[2] * b[2]
                    - a[3] * b[3]
                    - a[4] * b[4]
                    - a[5] * b[5]
                    - a[6] * b[6]
                    - a[7] * b[7],
                a[0] * b[1] + a[1] * b[0] + a[2] * b[3] - a[3] * b[2] + a[4] * b[5]
                    - a[5] * b[4]
                    - a[6] * b[7]
                    + a[7] * b[6],
                a[0] * b[2] - a[1] * b[3] + a[2] * b[0] + a[3] * b[1] + a[4] * b[6] + a[5] * b[7]
                    - a[6] * b[4]
                    - a[7] * b[5],
                a[0] * b[3] + a[1] * b[2] - a[2] * b[1] + a[3] * b[0] + a[4] * b[7] - a[5] * b[6]
                    + a[6] * b[5]
                    - a[7] * b[4],
                a[0] * b[4] - a[1] * b[5] - a[2] * b[6] - a[3] * b[7]
                    + a[4] * b[0]
                    + a[5] * b[1]
                    + a[6] * b[2]
                    + a[7] * b[3],
                a[0] * b[5] + a[1] * b[4] - a[2] * b[7] + a[3] * b[6] - a[4] * b[1] + a[5] * b[0]
                    - a[6] * b[3]
                    + a[7] * b[2],
                a[0] * b[6] + a[1] * b[7] + a[2] * b[4] - a[3] * b[5] - a[4] * b[2]
                    + a[5] * b[3]
                    + a[6] * b[0]
                    - a[7] * b[1],
                a[0] * b[7] - a[1] * b[6] + a[2] * b[5] + a[3] * b[4] - a[4] * b[3] - a[5] * b[2]
                    + a[6] * b[1]
                    + a[7] * b[0],
            ],
        }
    }
    fn dominant_basis(&self) -> usize {
        self.c
            .iter()
            .enumerate()
            .max_by(|(_, a), (_, b)| a.abs().partial_cmp(&b.abs()).unwrap())
            .unwrap()
            .0
    }
}

fn prime_to_basis(p: usize) -> usize {
    match p {
        2 => 1,
        3 => 2,
        5 => 3,
        7 => 4,
        11 => 5,
        13 => 6,
        17 => 7,
        _ => (p % 7) + 1,
    }
}
fn int_to_octonion(k: usize) -> Oct {
    if k <= 1 {
        return Oct::real(1.0);
    }
    let mut r = Oct::real(1.0);
    let mut n = k;
    let mut p = 2;
    while p * p <= n {
        while n.is_multiple_of(p) {
            r = r.mul(&Oct::basis(prime_to_basis(p)));
            n /= p;
        }
        p += 1;
    }
    if n > 1 {
        r = r.mul(&Oct::basis(prime_to_basis(n)));
    }
    let nm = r.norm();
    if nm > 1e-10 {
        r.scale(1. / nm)
    } else {
        Oct::real(1.)
    }
}

fn gram_entry(j: usize, k: usize, n_pts: usize) -> f64 {
    let (jf, kf) = (j as f64, k as f64);
    let dx = 1.0 / n_pts as f64;
    let mut s = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        s += frac_part(jf / x) * frac_part(kf / x);
    }
    s * dx
}

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  GUE CONNECTION: Random Matrix Universality                    ║");
    println!("║  Is R = 0.924 a universal constant?                            ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let mut all_spacings_full: Vec<f64> = Vec::new();
    let mut all_spacings_block: Vec<f64> = Vec::new();
    let mut lmin_data: Vec<(f64, f64, f64)> = Vec::new(); // (N, lmin, lmin_block)

    for &n in &[100, 200, 300, 500, 700, 1000, 1500] {
        let dim = n - 1;
        let n_pts = if n <= 500 { 200_000 } else { 100_000 };
        let start = std::time::Instant::now();

        let phis: Vec<Oct> = (0..dim).map(|i| int_to_octonion(i + 2)).collect();
        let classes: Vec<usize> = phis.iter().map(|p| p.dominant_basis()).collect();

        let entries: Vec<((usize, usize), f64)> = (0..dim)
            .into_par_iter()
            .flat_map(|i| {
                (i..dim)
                    .into_par_iter()
                    .map(move |j| ((i, j), gram_entry(i + 2, j + 2, n_pts)))
            })
            .collect();

        let mut g_full = DMatrix::<f64>::zeros(dim, dim);
        let mut g_block = DMatrix::<f64>::zeros(dim, dim);
        for ((i, j), v) in &entries {
            g_full[(*i, *j)] = *v;
            g_full[(*j, *i)] = *v;
            if classes[*i] == classes[*j] {
                g_block[(*i, *j)] = *v;
                g_block[(*j, *i)] = *v;
            }
        }

        let eig_full = SymmetricEigen::new(g_full);
        let eig_block = SymmetricEigen::new(g_block);

        let mut evs_full: Vec<f64> = eig_full.eigenvalues.iter().cloned().collect();
        let mut evs_block: Vec<f64> = eig_block.eigenvalues.iter().cloned().collect();
        evs_full.sort_by(|a, b| a.partial_cmp(b).unwrap());
        evs_block.sort_by(|a, b| a.partial_cmp(b).unwrap());

        let lmin = evs_full[0];
        let lmin_blk = evs_block[0];

        lmin_data.push((n as f64, lmin, lmin_blk));

        // ── Nearest-neighbor spacing (unfolded) for edge eigenvalues ──
        // Use bottom 20% of spectrum for "edge" statistics
        let n_edge = (dim as f64 * 0.2) as usize;

        // Unfold: compute local mean spacing
        if n_edge >= 10 {
            let edge_evs = &evs_full[0..n_edge];
            let mean_spacing = (edge_evs[n_edge - 1] - edge_evs[0]) / (n_edge - 1) as f64;
            for i in 0..n_edge - 1 {
                let s = (edge_evs[i + 1] - edge_evs[i]) / mean_spacing;
                all_spacings_full.push(s);
            }

            let edge_blk = &evs_block[0..n_edge];
            let mean_sp_blk = (edge_blk[n_edge - 1] - edge_blk[0]) / (n_edge - 1) as f64;
            for i in 0..n_edge - 1 {
                let s = (edge_blk[i + 1] - edge_blk[i]) / mean_sp_blk;
                all_spacings_block.push(s);
            }
        }

        let t = start.elapsed().as_secs_f64();
        println!(
            "  N={:5}: λ_min(G)={:.8}, λ_min(blk)={:.8}, dim={}, t={:.1}s",
            n, lmin, lmin_blk, dim, t
        );
    }

    // ── TEST 1: Tracy-Widom Scaling ──
    println!("\n\n═══ TEST 1: Tracy-Widom Scaling ═══\n");
    println!("  Tracy-Widom predicts: λ_min ~ a + b·N^(-2/3)\n");
    println!(
        "  {:>6} {:>12} {:>12} {:>14} {:>14}",
        "N", "λ_min(G)", "λ_min(blk)", "N^(2/3)·λ_min", "N^(2/3)·λ_blk"
    );

    for &(n, lmin, lmin_blk) in &lmin_data {
        let n23 = n.powf(2.0 / 3.0);
        println!(
            "  {:6.0} {:12.8} {:12.8} {:14.6} {:14.6}",
            n,
            lmin,
            lmin_blk,
            n23 * lmin,
            n23 * lmin_blk
        );
    }

    // ── TEST 2: 1/N Scaling ──
    println!("\n\n═══ TEST 2: Alternative Scalings ═══\n");
    println!(
        "  {:>6} {:>14} {:>14} {:>14} {:>14}",
        "N", "N·λ_min", "N^(1/2)·λ_min", "log(N)·λ_min", "1/(λ_min·logN)"
    );

    for &(n, lmin, _) in &lmin_data {
        let ln_n = n.ln();
        println!(
            "  {:6.0} {:14.6} {:14.6} {:14.6} {:14.6}",
            n,
            n * lmin,
            n.sqrt() * lmin,
            ln_n * lmin,
            1.0 / (lmin * ln_n)
        );
    }

    // ── TEST 3: Spacing Distribution vs GUE/GOE/Poisson ──
    println!("\n\n═══ TEST 3: Spacing Distribution (bottom 20%% of spectrum) ═══\n");

    let n_bins = 20;
    let max_s = 4.0;
    let bin_w = max_s / n_bins as f64;

    let mut hist_full = vec![0usize; n_bins];
    let mut hist_block = vec![0usize; n_bins];

    for &s in &all_spacings_full {
        let bin = ((s / bin_w) as usize).min(n_bins - 1);
        hist_full[bin] += 1;
    }
    for &s in &all_spacings_block {
        let bin = ((s / bin_w) as usize).min(n_bins - 1);
        hist_block[bin] += 1;
    }

    let total_full = all_spacings_full.len() as f64;
    let total_block = all_spacings_block.len() as f64;

    println!(
        "  {:>6} {:>10} {:>10} {:>10} {:>10} {:>10}",
        "s", "P(s) full", "P(s) blk", "GOE pred", "GUE pred", "Poisson"
    );

    for b in 0..n_bins {
        let s = (b as f64 + 0.5) * bin_w;
        let p_full = hist_full[b] as f64 / (total_full * bin_w);
        let p_block = hist_block[b] as f64 / (total_block * bin_w);

        // Wigner surmise for GOE: (π/2)·s·exp(-πs²/4)
        let goe = (std::f64::consts::PI / 2.0) * s * (-std::f64::consts::PI * s * s / 4.0).exp();
        // Wigner surmise for GUE: (32/π²)·s²·exp(-4s²/π)
        let gue = (32.0 / (std::f64::consts::PI * std::f64::consts::PI))
            * s
            * s
            * (-4.0 * s * s / std::f64::consts::PI).exp();
        // Poisson: exp(-s)
        let poisson = (-s).exp();

        println!(
            "  {:6.2} {:10.4} {:10.4} {:10.4} {:10.4} {:10.4}",
            s, p_full, p_block, goe, gue, poisson
        );
    }

    // ── TEST 4: Compute r = <s²>/<s>² - 1 (a GUE indicator) ──
    println!("\n\n═══ TEST 4: Level Repulsion Indicator ═══\n");

    let mean_s_full: f64 = all_spacings_full.iter().sum::<f64>() / total_full;
    let var_s_full: f64 = all_spacings_full
        .iter()
        .map(|s| (s - mean_s_full).powi(2))
        .sum::<f64>()
        / total_full;
    let mean_s_blk: f64 = all_spacings_block.iter().sum::<f64>() / total_block;
    let var_s_blk: f64 = all_spacings_block
        .iter()
        .map(|s| (s - mean_s_blk).powi(2))
        .sum::<f64>()
        / total_block;

    println!(
        "  Full G:  <s> = {:.4}, var(s) = {:.4}, var/mean² = {:.4}",
        mean_s_full,
        var_s_full,
        var_s_full / (mean_s_full * mean_s_full)
    );
    println!(
        "  Block G: <s> = {:.4}, var(s) = {:.4}, var/mean² = {:.4}",
        mean_s_blk,
        var_s_blk,
        var_s_blk / (mean_s_blk * mean_s_blk)
    );
    println!();
    println!("  Predictions:");
    println!(
        "  GOE:     var/mean² = {:.4}",
        1.0 - std::f64::consts::PI / 4.0 + 4.0 / std::f64::consts::PI - 1.0
    );
    println!("  GUE:     var/mean² ≈ 0.178");
    println!("  Poisson: var/mean² = 1.000");

    // ── TEST 5: The Magic Number 0.924 ──
    println!("\n\n═══ TEST 5: Is R = 0.924 a Universal Constant? ═══\n");

    // In random matrix theory, the ratio of the smallest eigenvalue
    // to the mean of the bottom fraction has universal predictions.
    // GUE: λ_min → a + b·N^{-2/3} where a depends on the mean density.
    // GOE: similar but different constants.

    // Compute the ratio λ_min(G) / λ_min(G^block) for each N
    println!(
        "  {:>6} {:>12} {:>12} {:>12}",
        "N", "λ_min/λ_blk", "1-ratio", "R ≈ 1-ratio"
    );
    for &(n, lmin, lmin_blk) in &lmin_data {
        let ratio = lmin / lmin_blk;
        println!(
            "  {:6.0} {:12.6} {:12.6} {:12.6}",
            n,
            ratio,
            1.0 - ratio,
            1.0 - ratio
        );
    }

    // ── TEST 6: P(s=0) — level repulsion ──
    println!("\n\n═══ TEST 6: Level Repulsion at s=0 ═══\n");

    let small_s = 0.1;
    let n_small_full = all_spacings_full.iter().filter(|&&s| s < small_s).count();
    let n_small_block = all_spacings_block.iter().filter(|&&s| s < small_s).count();

    println!(
        "  P(s < {}) for full G:  {:.4} ({} / {})",
        small_s,
        n_small_full as f64 / total_full,
        n_small_full,
        total_full as usize
    );
    println!(
        "  P(s < {}) for block G: {:.4} ({} / {})",
        small_s,
        n_small_block as f64 / total_block,
        n_small_block,
        total_block as usize
    );
    println!();
    println!(
        "  GOE predicts P(s<0.1) ≈ {:.4}",
        0.1_f64.powi(2) * std::f64::consts::PI / 4.0
    );
    println!(
        "  GUE predicts P(s<0.1) ≈ {:.6}",
        0.1_f64.powi(3) * 32.0 / (3.0 * std::f64::consts::PI * std::f64::consts::PI)
    );
    println!(
        "  Poisson predicts P(s<0.1) ≈ {:.4}",
        1.0 - (-0.1_f64).exp()
    );

    println!("\n╔══════════════════════════════════════════════════════════════════╗");
    println!("║  GUE analysis complete.                                        ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
}
