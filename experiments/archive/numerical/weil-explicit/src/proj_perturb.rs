#![allow(unused, dead_code, non_snake_case)]
use nalgebra::{DMatrix, DVector, SymmetricEigen};
use rayon::prelude::*;

// ══════════════════════════════════════════════════════════════════════
// PROJECTED PERTURBATION BOUND
//
// Key idea: Instead of bounding ||G^cross||_op (which is O(N)),
// project G^cross onto the SMALL-eigenvalue subspace of G^block
// and bound that projected norm.
//
// If V_small = span of k smallest eigenvectors of G^block, then:
//   Δ = V_small^T · G^cross · V_small  (a k×k matrix)
//   λ_min(G) ≥ λ_min(G^block) - ||Δ||_op
//
// Since the dangerous direction of G^cross is nearly orthogonal to
// the gap direction of G, ||Δ||_op should be MUCH smaller than
// ||G^cross||_op, making this bound viable.
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

fn liouville(n: usize) -> i32 {
    let mut v = n;
    let mut o = 0;
    let mut p = 2;
    while p * p <= v {
        while v.is_multiple_of(p) {
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
    println!("║  PROJECTED PERTURBATION BOUND                                  ║");
    println!("║  Δ = V_small^T · G^cross · V_small                            ║");
    println!("║  λ_min(G) ≥ λ_min(G^block) - ||Δ||_op                        ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let n_pts = 200_000;

    // Summary accumulators
    let mut summary: Vec<(usize, f64, f64, f64, f64, f64, f64)> = Vec::new();

    for &n in &[50, 100, 200, 400, 800] {
        let dim = n - 1;
        let start = std::time::Instant::now();

        println!("═══ N = {} (dim = {}) ═══\n", n, dim);

        // Classify + build matrices
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

        // Eigendecompositions
        let eig_full = SymmetricEigen::new(g_full.clone());
        let eig_block = SymmetricEigen::new(g_block.clone());

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

        // Sort block eigenvalues to find the small ones
        let mut block_eig_indexed: Vec<(usize, f64)> = eig_block
            .eigenvalues
            .iter()
            .enumerate()
            .map(|(i, &v)| (i, v))
            .collect();
        block_eig_indexed.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());

        println!("  λ_min(G):       {:14.10}", lmin_full);
        println!("  λ_min(G^block): {:14.10}", lmin_block);
        println!();

        // Show smallest eigenvalues of G^block
        println!("  Smallest eigenvalues of G^block:");
        for i in 0..20.min(dim) {
            let (idx, val) = block_eig_indexed[i];
            println!("    λ_{}: {:14.10}  (idx={})", i + 1, val, idx);
        }

        // Projected perturbation for different subspace sizes k
        println!("\n  Projected perturbation ||V_k^T G^cross V_k||_op:");
        println!(
            "  {:>4} {:>14} {:>14} {:>10} {:>12} {:>8}",
            "k", "||Δ_k||_op", "λ_min(block)", "Gap", "Pred λ_min", "OK?"
        );
        println!("  {}", "─".repeat(70));

        let mut best_k = 0;
        let mut best_pred = f64::NEG_INFINITY;

        for &k in &[1, 2, 4, 8, 16, 32, 64, 128] {
            if k >= dim {
                break;
            }

            // Build V_small: the k smallest eigenvectors of G^block
            let mut v_small = DMatrix::<f64>::zeros(dim, k);
            for col in 0..k {
                let (eig_idx, _) = block_eig_indexed[col];
                for row in 0..dim {
                    v_small[(row, col)] = eig_block.eigenvectors[(row, eig_idx)];
                }
            }

            // Δ_k = V_small^T · G^cross · V_small  (k × k matrix)
            let temp = &g_cross * &v_small; // dim × k
            let delta = v_small.transpose() * &temp; // k × k

            // ||Δ_k||_op = max |eigenvalue of Δ_k|
            let delta_eig = SymmetricEigen::new(delta);
            let delta_op = delta_eig
                .eigenvalues
                .iter()
                .map(|v| v.abs())
                .fold(0.0f64, f64::max);

            // The k-th smallest eigenvalue of G^block
            let lambda_k_block = block_eig_indexed[k - 1].1;

            // Predicted lower bound: λ_k(G^block) - ||Δ_k||_op
            let predicted = lambda_k_block - delta_op;
            let gap = lambda_k_block - delta_op;

            if predicted > best_pred {
                best_pred = predicted;
                best_k = k;
            }

            println!(
                "  {:4} {:14.8} {:14.8} {:10.6} {:12.8} {:>8}",
                k,
                delta_op,
                lambda_k_block,
                gap,
                predicted,
                if predicted > 0.0 { "✅" } else { "❌" }
            );
        }

        println!(
            "\n  Best prediction: k={}, λ_min(G) ≥ {:.10}",
            best_k, best_pred
        );
        println!("  Actual λ_min(G) = {:.10}", lmin_full);
        if best_pred > 0.0 {
            println!("  ⭐ PROJECTED BOUND PROVES λ_min > 0!");
        }

        // Overlap analysis: <v_min(G), v_i(G^block)> for small i
        let min_full_idx = eig_full
            .eigenvalues
            .iter()
            .enumerate()
            .min_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap())
            .unwrap()
            .0;

        println!("\n  Overlap <v_min(G), v_i(G^block)>:");
        let mut total_overlap_sq = 0.0;
        for i in 0..20.min(dim) {
            let (eig_idx, _) = block_eig_indexed[i];
            let overlap: f64 = (0..dim)
                .map(|r| {
                    eig_full.eigenvectors[(r, min_full_idx)] * eig_block.eigenvectors[(r, eig_idx)]
                })
                .sum();
            total_overlap_sq += overlap * overlap;
            if overlap.abs() > 0.01 {
                println!(
                    "    <v_min(G), v_{}(G^block)> = {:+8.5}  (λ = {:.6})",
                    i + 1,
                    overlap,
                    block_eig_indexed[i].1
                );
            }
        }
        println!("    Total |overlap|² in bottom 20: {:.6}", total_overlap_sq);

        // Liouville vector overlap
        let mut lio_vec = DVector::<f64>::zeros(dim);
        for i in 0..dim {
            let k = (i + 2) as f64;
            lio_vec[i] = liouville(i + 2) as f64 * k.ln() / k;
        }
        let lio_norm = lio_vec.norm();
        lio_vec /= lio_norm;

        let lio_overlap_full: f64 = (0..dim)
            .map(|r| eig_full.eigenvectors[(r, min_full_idx)] * lio_vec[r])
            .sum::<f64>()
            .abs();

        println!("\n  Liouville overlaps:");
        println!("    |<v_min(G), λ̂>| = {:.6}", lio_overlap_full);

        // Liouville overlap with G^block eigenvectors
        println!("    |<v_i(G^block), λ̂>| for small i:");
        for i in 0..8.min(dim) {
            let (eig_idx, _) = block_eig_indexed[i];
            let overlap: f64 = (0..dim)
                .map(|r| eig_block.eigenvectors[(r, eig_idx)] * lio_vec[r])
                .sum::<f64>()
                .abs();
            println!(
                "      i={}: {:.6}  (λ = {:.6})",
                i + 1,
                overlap,
                block_eig_indexed[i].1
            );
        }

        let t = start.elapsed().as_secs_f64();
        println!("\n  Time: {:.1}s\n", t);

        summary.push((
            n,
            lmin_full,
            lmin_block,
            best_pred,
            best_k as f64,
            lio_overlap_full,
            total_overlap_sq,
        ));
    }

    // Summary
    println!("═══ SUMMARY ═══\n");
    println!(
        "  {:>6} {:>12} {:>12} {:>12} {:>6} {:>10} {:>10}",
        "N", "λ_min(G)", "λ_min(blk)", "Best Pred", "Best k", "Lio|G", "|ovlp|²"
    );
    println!("  {}", "─".repeat(75));
    for &(n, lf, lb, bp, bk, lo, ov) in &summary {
        println!(
            "  {:6} {:12.8} {:12.8} {:12.8} {:6} {:10.6} {:10.6}",
            n, lf, lb, bp, bk as usize, lo, ov
        );
    }

    println!("\n╔══════════════════════════════════════════════════════════════════╗");
    println!("║  Projected perturbation analysis complete.                     ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
}
