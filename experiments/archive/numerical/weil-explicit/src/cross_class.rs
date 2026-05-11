#![allow(unused, dead_code, non_snake_case)]
use nalgebra::{DMatrix, SymmetricEigen};
use rayon::prelude::*;

// ══════════════════════════════════════════════════════════════════════
// CROSS-CLASS DEEP DIVE
//
// The octonionic class restriction showed that lambdaMin(G_block) ≈ 0.048
// while lambdaMin(G) ≈ 0.011. The difference comes from G_cross.
//
// Critical question: How does ||G_cross||_op / lambdaMin(G_block) scale?
// If this ratio stays < 1 for all N, then RH follows from Weyl's inequality.
//
// This experiment:
// 1. Computes G^{block} and G^{cross} explicitly
// 2. Analyzes eigenstructure of G^{cross}
// 3. Studies rank structure (is G^{cross} approximately low-rank?)
// 4. Computes the critical ratio ||G^{cross}||_op / λ_min(G^{block})
// 5. Examines Liouville eigenvector in G^{cross}
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
    fn inner(&self, o: &Self) -> f64 {
        self.c.iter().zip(o.c.iter()).map(|(a, b)| a * b).sum()
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
        while n % p == 0 {
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

fn liouville(n: usize) -> i32 {
    let mut v = n;
    let mut o = 0;
    let mut p = 2;
    while p * p <= v {
        while v % p == 0 {
            o += 1;
            v /= p;
        }
        p += 1;
    }
    if v > 1 {
        o += 1;
    }
    if o % 2 == 0 {
        1
    } else {
        -1
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
    println!("║  CROSS-CLASS DEEP DIVE                                         ║");
    println!("║  Analyzing G^{{cross}} structure — where RH lives               ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let n_pts = 200_000;

    for &n in &[50, 100, 200, 500, 800] {
        let dim = n - 1;
        let start = std::time::Instant::now();

        println!("═══ N = {} (dim = {}) ═══\n", n, dim);

        // Classify each integer
        let phis: Vec<Oct> = (0..dim).map(|i| int_to_octonion(i + 2)).collect();
        let classes: Vec<usize> = phis.iter().map(|p| p.dominant_basis()).collect();

        // Build full Gram matrix
        let entries: Vec<((usize, usize), f64)> = (0..dim)
            .into_par_iter()
            .flat_map(|i| {
                (i..dim)
                    .into_par_iter()
                    .map(move |j| ((i, j), gram_entry(i + 2, j + 2, n_pts)))
            })
            .collect();

        let mut g_full = DMatrix::<f64>::zeros(dim, dim);
        for ((i, j), v) in &entries {
            g_full[(*i, *j)] = *v;
            g_full[(*j, *i)] = *v;
        }

        // Build G^{block} (within-class only) and G^{cross} (cross-class only)
        let mut g_block = DMatrix::<f64>::zeros(dim, dim);
        let mut g_cross = DMatrix::<f64>::zeros(dim, dim);
        for i in 0..dim {
            for j in 0..dim {
                if classes[i] == classes[j] {
                    g_block[(i, j)] = g_full[(i, j)];
                } else {
                    g_cross[(i, j)] = g_full[(i, j)];
                }
            }
        }

        // Eigendecompositions
        let eig_full = SymmetricEigen::new(g_full.clone());
        let eig_block = SymmetricEigen::new(g_block.clone());
        let eig_cross = SymmetricEigen::new(g_cross.clone());

        let lmin_full = eig_full
            .eigenvalues
            .iter()
            .cloned()
            .fold(f64::INFINITY, f64::min);
        let lmin_block = eig_block
            .eigenvalues
            .iter()
            .cloned()
            .fold(f64::INFINITY, f64::min);
        let lmin_cross = eig_cross
            .eigenvalues
            .iter()
            .cloned()
            .fold(f64::INFINITY, f64::min);
        let lmax_cross = eig_cross
            .eigenvalues
            .iter()
            .cloned()
            .fold(f64::NEG_INFINITY, f64::max);

        // Operator norm of G^{cross}
        let op_norm_cross = lmin_cross.abs().max(lmax_cross.abs());

        println!("  Spectral decomposition:");
        println!("    λ_min(G):       {:14.10}", lmin_full);
        println!("    λ_min(G^block): {:14.10}", lmin_block);
        println!("    λ_min(G^cross): {:14.10}", lmin_cross);
        println!("    λ_max(G^cross): {:14.10}", lmax_cross);
        println!("    ||G^cross||_op: {:14.10}", op_norm_cross);
        println!();

        // THE CRITICAL RATIO
        let weyl_ratio = op_norm_cross / lmin_block;
        let margin = lmin_block + lmin_cross;
        println!(
            "  ⭐ Critical ratio ||G^cross||_op / λ_min(G^block) = {:.6}",
            weyl_ratio
        );
        println!(
            "     Weyl margin: λ_min(G^block) + λ_min(G^cross) = {:.10}",
            margin
        );
        println!(
            "     (Must be > 0 for RH, is {})",
            if margin > 0.0 {
                "✅ POSITIVE"
            } else {
                "❌ NEGATIVE"
            }
        );
        println!(
            "     Ratio < 1 means Weyl bound is useful: {}",
            if weyl_ratio < 1.0 {
                "✅ YES"
            } else {
                "❌ NO (Weyl too loose)"
            }
        );

        // Rank structure of G^{cross}
        let mut singular_vals: Vec<f64> = eig_cross.eigenvalues.iter().map(|v| v.abs()).collect();
        singular_vals.sort_by(|a, b| b.partial_cmp(a).unwrap());

        let total_spec_weight: f64 = singular_vals.iter().sum();
        let mut cumul = 0.0;
        let mut effective_rank = dim;
        for (i, &sv) in singular_vals.iter().enumerate() {
            cumul += sv;
            if cumul / total_spec_weight > 0.90 && effective_rank == dim {
                effective_rank = i + 1;
            }
        }

        println!("\n  Rank structure of G^cross:");
        println!("    Top 8 eigenvalues (absolute):");
        for i in 0..8.min(dim) {
            let pct = singular_vals[i] / total_spec_weight * 100.0;
            println!(
                "      σ_{}: {:12.8}  ({:.1}%)",
                i + 1,
                singular_vals[i],
                pct
            );
        }
        println!(
            "    Effective rank (90% of spectral weight): {}/{}",
            effective_rank, dim
        );
        println!(
            "    σ₁/σ₂ = {:.4}",
            singular_vals[0] / singular_vals[1].max(1e-15)
        );

        // Liouville eigenvector analysis
        // Find the minimum eigenvector of G^cross
        let min_cross_idx = eig_cross
            .eigenvalues
            .iter()
            .enumerate()
            .min_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap())
            .unwrap()
            .0;
        let cross_min_evec: Vec<f64> = eig_cross
            .eigenvectors
            .column(min_cross_idx)
            .iter()
            .cloned()
            .collect();

        // Liouville vector (weighted)
        let mut lio_vec: Vec<f64> = (0..dim)
            .map(|i| {
                let k = (i + 2) as f64;
                liouville(i + 2) as f64 * k.ln() / k
            })
            .collect();
        let lio_norm: f64 = lio_vec.iter().map(|x| x * x).sum::<f64>().sqrt();
        for v in lio_vec.iter_mut() {
            *v /= lio_norm;
        }

        let cross_lio_corr: f64 = cross_min_evec
            .iter()
            .zip(lio_vec.iter())
            .map(|(a, b)| a * b)
            .sum::<f64>()
            .abs();

        // Same for full G
        let min_full_idx = eig_full
            .eigenvalues
            .iter()
            .enumerate()
            .min_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap())
            .unwrap()
            .0;
        let full_min_evec: Vec<f64> = eig_full
            .eigenvectors
            .column(min_full_idx)
            .iter()
            .cloned()
            .collect();
        let full_lio_corr: f64 = full_min_evec
            .iter()
            .zip(lio_vec.iter())
            .map(|(a, b)| a * b)
            .sum::<f64>()
            .abs();

        println!("\n  Liouville correlation:");
        println!("    G full min-evec:   {:.6}", full_lio_corr);
        println!("    G^cross min-evec:  {:.6}", cross_lio_corr);

        // Cross-pair analysis: which class pairs contribute most?
        println!("\n  Cross-class pair analysis (||G^cross[Sm,Sm']||_F):");
        let mut pair_norms: Vec<(usize, usize, f64)> = Vec::new();
        for m1 in 0..8 {
            for m2 in (m1 + 1)..8 {
                let mut frob_sq = 0.0;
                let mut count = 0;
                for i in 0..dim {
                    for j in 0..dim {
                        if classes[i] == m1 && classes[j] == m2 {
                            frob_sq += g_cross[(i, j)] * g_cross[(i, j)];
                            count += 1;
                        }
                    }
                }
                if count > 0 {
                    pair_norms.push((m1, m2, frob_sq.sqrt()));
                }
            }
        }
        pair_norms.sort_by(|a, b| b.2.partial_cmp(&a.2).unwrap());
        let total_frob: f64 = pair_norms.iter().map(|x| x.2).sum();
        for &(m1, m2, norm) in pair_norms.iter().take(8) {
            println!(
                "    S_{} × S_{}: ||·||_F = {:10.6}  ({:.1}%)",
                m1,
                m2,
                norm,
                norm / total_frob * 100.0
            );
        }

        // GCD structure: are cross-class pairs mostly coprime?
        let mut coprime_count = 0;
        let mut total_cross = 0;
        for i in 0..dim {
            for j in (i + 1)..dim {
                if classes[i] != classes[j] {
                    total_cross += 1;
                    let a = i + 2;
                    let b = j + 2;
                    let g = gcd(a, b);
                    if g == 1 {
                        coprime_count += 1;
                    }
                }
            }
        }
        let coprime_frac = coprime_count as f64 / total_cross.max(1) as f64;
        println!("\n  GCD structure of cross-class pairs:");
        println!(
            "    Coprime: {}/{} ({:.1}%)",
            coprime_count,
            total_cross,
            coprime_frac * 100.0
        );

        // Scaling predictions
        println!("\n  Scaling:");
        println!("    ||G^cross||_op / λ_min(G^block) = {:.6}", weyl_ratio);
        println!("    Weyl gap = {:.10}", margin);

        let t = start.elapsed().as_secs_f64();
        println!("\n  Time: {:.1}s\n", t);
    }

    // Summary table
    println!("═══ SUMMARY TABLE ═══\n");
    println!(
        "  {:>6} {:>12} {:>12} {:>12} {:>10} {:>8} {:>8}",
        "N", "λ_min(G)", "λ_min(block)", "λ_min(cross)", "WeylGap", "ratio", "rank90"
    );
    println!("  {}", "─".repeat(80));

    for &n in &[50, 100, 200, 500, 800] {
        let dim = n - 1;
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
        let mut g_cross = DMatrix::<f64>::zeros(dim, dim);
        for ((i, j), v) in &entries {
            g_full[(*i, *j)] = *v;
            g_full[(*j, *i)] = *v;
            if classes[*i] == classes[*j] {
                g_block[(*i, *j)] = *v;
                g_block[(*j, *i)] = *v;
            } else {
                g_cross[(*i, *j)] = *v;
                g_cross[(*j, *i)] = *v;
            }
        }

        let eig_full = SymmetricEigen::new(g_full);
        let eig_block = SymmetricEigen::new(g_block);
        let eig_cross = SymmetricEigen::new(g_cross);

        let lmin_full = eig_full
            .eigenvalues
            .iter()
            .cloned()
            .fold(f64::INFINITY, f64::min);
        let lmin_block = eig_block
            .eigenvalues
            .iter()
            .cloned()
            .fold(f64::INFINITY, f64::min);
        let lmin_cross = eig_cross
            .eigenvalues
            .iter()
            .cloned()
            .fold(f64::INFINITY, f64::min);
        let margin = lmin_block + lmin_cross;
        let op_norm = lmin_cross.abs().max(
            eig_cross
                .eigenvalues
                .iter()
                .cloned()
                .fold(f64::NEG_INFINITY, f64::max)
                .abs(),
        );
        let ratio = op_norm / lmin_block;

        let mut sv: Vec<f64> = eig_cross.eigenvalues.iter().map(|v| v.abs()).collect();
        sv.sort_by(|a, b| b.partial_cmp(a).unwrap());
        let tot: f64 = sv.iter().sum();
        let mut cumul = 0.0;
        let mut r90 = dim;
        for (i, &s) in sv.iter().enumerate() {
            cumul += s;
            if cumul / tot > 0.9 && r90 == dim {
                r90 = i + 1;
            }
        }

        println!(
            "  {:6} {:12.8} {:12.8} {:12.8} {:10.8} {:8.4} {:8}",
            n, lmin_full, lmin_block, lmin_cross, margin, ratio, r90
        );
    }

    println!("\n╔══════════════════════════════════════════════════════════════════╗");
    println!("║  Cross-class deep dive complete.                               ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
}

fn gcd(mut a: usize, mut b: usize) -> usize {
    while b != 0 {
        let t = b;
        b = a % b;
        a = t;
    }
    a
}
