#![allow(unused, dead_code, non_snake_case)]
use nalgebra::{DMatrix, SymmetricEigen};
use rayon::prelude::*;

// ══════════════════════════════════════════════════════════════════════
// OCTONIONIC CLASS RESTRICTION
//
// Split {2,...,N} into 8 classes S_m based on which octonionic basis
// element φ(k) maps to. Compute λ_min(G|_{S_m}) for each class.
//
// Hypothesis: λ_min(G|_{S_m}) > λ_min(G) for each m, because the
// integers within each class share multiplicative structure that
// reduces Liouville cancellation.
//
// If true: the "hard part" of the spectral gap problem ONLY lives in
// the CROSS-CLASS interactions, not within any single class.
// ══════════════════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 {
    x - x.floor()
}

#[derive(Clone)]
struct Oct {
    c: [f64; 8],
}
impl Oct {
    fn real(a: f64) -> Self {
        Self {
            c: [a, 0., 0., 0., 0., 0., 0., 0.],
        }
    }
    fn basis(i: usize) -> Self {
        let mut c = [0.; 8];
        c[i] = 1.;
        Self { c }
    }
    fn norm(&self) -> f64 {
        self.c.iter().map(|x| x * x).sum::<f64>().sqrt()
    }
    fn conj(&self) -> Self {
        let mut c = self.c;
        for i in 1..8 {
            c[i] = -c[i];
        }
        Self { c }
    }
    fn scale(&self, s: f64) -> Self {
        let mut c = self.c;
        for x in c.iter_mut() {
            *x *= s;
        }
        Self { c }
    }
    fn re(&self) -> f64 {
        self.c[0]
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
        self.conj().mul(o).re()
    }
    /// Which basis element has the largest absolute component?
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
    println!("║  OCTONIONIC CLASS RESTRICTION                                  ║");
    println!("║  Split integers into 8 classes by octonionic image             ║");
    println!("║  Compute spectral gap of G restricted to each class            ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let n_pts = 200_000;

    for &n in &[100, 200, 500, 1000] {
        let dim = n - 1;
        let start = std::time::Instant::now();

        println!("═══ N = {} (dim = {}) ═══\n", n, dim);

        // Classify each integer
        let phis: Vec<Oct> = (0..dim).map(|i| int_to_octonion(i + 2)).collect();
        let classes: Vec<usize> = phis.iter().map(|p| p.dominant_basis()).collect();

        // Build class index sets
        let mut class_indices: Vec<Vec<usize>> = vec![Vec::new(); 8];
        for (idx, &cls) in classes.iter().enumerate() {
            class_indices[cls].push(idx);
        }

        // Print class sizes
        let class_names = [
            "e0 (real)",
            "e1 (→2)",
            "e2 (→3)",
            "e3 (→5)",
            "e4 (→7)",
            "e5 (→11)",
            "e6 (→13)",
            "e7 (→17)",
        ];
        println!("  Class sizes:");
        for m in 0..8 {
            let size = class_indices[m].len();
            let lio_sum: i32 = class_indices[m].iter().map(|&i| liouville(i + 2)).sum();
            if size > 0 {
                println!(
                    "    S_{} {:<12}: {:4} integers, Liouville sum = {:+4} (bias = {:.3})",
                    m,
                    class_names[m],
                    size,
                    lio_sum,
                    lio_sum as f64 / size as f64
                );
            }
        }

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

        // Full G eigenvalue
        let full_eig = SymmetricEigen::new(g_full.clone());
        let lmin_full = full_eig
            .eigenvalues
            .iter()
            .cloned()
            .fold(f64::INFINITY, f64::min);

        // Build G^𝕆
        let mut go_full = DMatrix::<f64>::zeros(dim, dim);
        for ((i, j), v) in &entries {
            let w = phis[*i].inner(&phis[*j]);
            go_full[(*i, *j)] = w * v;
            go_full[(*j, *i)] = w * v;
        }
        let go_eig = SymmetricEigen::new(go_full);
        let lmin_go = go_eig
            .eigenvalues
            .iter()
            .cloned()
            .fold(f64::INFINITY, f64::min);

        println!("\n  Full matrix results:");
        println!("    λ_min(G):   {:14.10}", lmin_full);
        println!("    λ_min(G^𝕆): {:14.10}", lmin_go);

        // Compute restricted Gram matrix for each class
        println!(
            "\n  {:>10} {:>6} {:>14} {:>14} {:>10} {:>10}",
            "Class", "size", "λ_min(G|_S)", "λ_min/λ(G)", "L_sum", "PSD?"
        );
        println!("  {}", "─".repeat(70));

        let mut min_restricted = f64::INFINITY;

        for m in 0..8 {
            let idx = &class_indices[m];
            let sz = idx.len();
            if sz < 2 {
                continue;
            }

            // Extract submatrix
            let mut g_sub = DMatrix::<f64>::zeros(sz, sz);
            for (ii, &i) in idx.iter().enumerate() {
                for (jj, &j) in idx.iter().enumerate() {
                    g_sub[(ii, jj)] = g_full[(i, j)];
                }
            }

            let sub_eig = SymmetricEigen::new(g_sub);
            let lmin_sub = sub_eig
                .eigenvalues
                .iter()
                .cloned()
                .fold(f64::INFINITY, f64::min);
            let neg = sub_eig.eigenvalues.iter().filter(|&&v| v < -1e-10).count();
            let lio_sum: i32 = idx.iter().map(|&i| liouville(i + 2)).sum();

            if lmin_sub < min_restricted {
                min_restricted = lmin_sub;
            }

            println!(
                "  {:>10} {:6} {:14.10} {:14.4} {:10} {:>10}",
                class_names[m],
                sz,
                lmin_sub,
                lmin_sub / lmin_full,
                lio_sum,
                if neg == 0 { "✅" } else { "❌" }
            );
        }

        println!(
            "\n  min over classes: λ_min(G|_S) = {:14.10}",
            min_restricted
        );
        println!("  vs full:          λ_min(G)    = {:14.10}", lmin_full);
        println!("  vs octonionic:    λ_min(G^𝕆)  = {:14.10}", lmin_go);

        if min_restricted > lmin_full {
            println!("  ⭐ EACH CLASS has LARGER spectral gap than the full matrix!");
            println!(
                "     Ratio: {:.2}× (worst class / full)",
                min_restricted / lmin_full
            );
        } else {
            println!("  ℹ️  Some classes have smaller gap than full G.");
        }

        // Liouville eigenvector analysis for worst class
        let worst_m = (0..8)
            .filter(|&m| class_indices[m].len() >= 2)
            .min_by(|&a, &b| {
                let la: f64 = {
                    let idx_a = &class_indices[a];
                    let sz = idx_a.len();
                    let mut g_sub = DMatrix::<f64>::zeros(sz, sz);
                    for (ii, &i) in idx_a.iter().enumerate() {
                        for (jj, &j) in idx_a.iter().enumerate() {
                            g_sub[(ii, jj)] = g_full[(i, j)];
                        }
                    }
                    SymmetricEigen::new(g_sub)
                        .eigenvalues
                        .iter()
                        .cloned()
                        .fold(f64::INFINITY, f64::min)
                };
                let lb: f64 = {
                    let idx_b = &class_indices[b];
                    let sz = idx_b.len();
                    let mut g_sub = DMatrix::<f64>::zeros(sz, sz);
                    for (ii, &i) in idx_b.iter().enumerate() {
                        for (jj, &j) in idx_b.iter().enumerate() {
                            g_sub[(ii, jj)] = g_full[(i, j)];
                        }
                    }
                    SymmetricEigen::new(g_sub)
                        .eigenvalues
                        .iter()
                        .cloned()
                        .fold(f64::INFINITY, f64::min)
                };
                la.partial_cmp(&lb).unwrap()
            })
            .unwrap_or(0);

        let idx_w = &class_indices[worst_m];
        if idx_w.len() >= 2 {
            let sz = idx_w.len();
            let mut g_sub = DMatrix::<f64>::zeros(sz, sz);
            for (ii, &i) in idx_w.iter().enumerate() {
                for (jj, &j) in idx_w.iter().enumerate() {
                    g_sub[(ii, jj)] = g_full[(i, j)];
                }
            }
            let sub_eig = SymmetricEigen::new(g_sub);
            let min_idx = sub_eig
                .eigenvalues
                .iter()
                .enumerate()
                .min_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap())
                .unwrap()
                .0;
            let evec: Vec<f64> = sub_eig
                .eigenvectors
                .column(min_idx)
                .iter()
                .cloned()
                .collect();

            // Liouville correlation within this class
            let mut dot = 0.0f64;
            let mut nv = 0.0f64;
            let mut nl = 0.0f64;
            for (ii, &i) in idx_w.iter().enumerate() {
                let k = i + 2;
                let v = evec[ii];
                let l = liouville(k) as f64 * (k as f64).ln() / k as f64;
                dot += v * l;
                nv += v * v;
                nl += l * l;
            }
            let corr = if nv > 1e-20 && nl > 1e-20 {
                dot / (nv.sqrt() * nl.sqrt())
            } else {
                0.0
            };

            println!(
                "\n  Liouville correlation in worst class (S_{} {}):",
                worst_m, class_names[worst_m]
            );
            println!("    Restricted:  {:.6}", corr);
            println!("    Full G:      ~0.70  (for comparison)");
            if corr.abs() < 0.5 {
                println!("    ✨ Decorrelated within class!");
            }
        }

        let t = start.elapsed().as_secs_f64();
        println!("\n  Time: {:.1}s\n", t);
    }

    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  Octonionic class restriction analysis complete.               ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
}
