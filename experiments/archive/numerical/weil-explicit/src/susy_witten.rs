#![allow(unused, dead_code, non_snake_case)]
use nalgebra::{DMatrix, SymmetricEigen};
use rayon::prelude::*;

// ══════════════════════════════════════════════════════════════════════
// SUSY WITTEN INDEX — LIOUVILLE GRADING OF THE GRAM MATRIX
//
// W(β) = Tr(Γ · e^{-βG})   where Γ = diag(λ(2), λ(3), ..., λ(N))
//
// β=0:   W = L(N)-1 = Σ_{k=2}^N λ(k)     (Liouville summatory function)
// β→∞:   W dominated by ground state       (spectral gap regime)
//
// RH ⟺ W(0) = O(N^{1/2+ε})
//
// The β-interpolation reveals whether there's a "phase transition"
// between the arithmetic regime (β≈0) and the spectral regime (β→∞).
// ══════════════════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 {
    x - x.floor()
}

fn liouville(n: usize) -> i32 {
    let mut val = n;
    let mut omega = 0;
    let mut p = 2;
    while p * p <= val {
        while val.is_multiple_of(p) {
            omega += 1;
            val /= p;
        }
        p += 1;
    }
    if val > 1 {
        omega += 1;
    }
    if omega % 2 == 0 {
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
    println!("║  SUSY WITTEN INDEX — LIOUVILLE GRADING                         ║");
    println!("║  W(β) = Tr(Γ · exp(-βG))                                      ║");
    println!("║  Γ = diag(λ(2),...,λ(N)), G = Nyman-Beurling Gram matrix       ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let n_pts = 500_000;
    let total_start = std::time::Instant::now();

    // β values to scan: from arithmetic regime to spectral regime
    let betas: Vec<f64> = {
        let mut b = Vec::new();
        b.push(0.0);
        let mut x = 0.001;
        while x <= 1000.0 {
            b.push(x);
            x *= 1.5;
        }
        b
    };

    // ═══════════════════════════════════════════════════════
    // SECTION 1: Witten index W(β) for multiple N
    // ═══════════════════════════════════════════════════════
    println!("═══ Section 1: Witten index W(β) vs N ═══\n");

    struct NData {
        n: usize,
        eigenvalues: Vec<f64>,
        // Γ in eigenbasis: gamma_eig[i] = Σ_k λ(k+2) · U[k,i]²
        // where U diagonalizes G = U Λ U^T
        gamma_eig: Vec<f64>,
        liouville_sum: i64, // L(N) - 1
    }

    let test_ns = vec![50, 100, 200, 300, 500, 800];
    let mut all_data: Vec<NData> = Vec::new();

    for &n in &test_ns {
        let dim = n - 1;
        let start = std::time::Instant::now();

        // Build Gram matrix
        let entries: Vec<((usize, usize), f64)> = (0..dim)
            .into_par_iter()
            .flat_map(|i| {
                (i..dim)
                    .into_par_iter()
                    .map(move |j| ((i, j), gram_entry(i + 2, j + 2, n_pts)))
            })
            .collect();

        let mut g_mat = DMatrix::<f64>::zeros(dim, dim);
        for ((i, j), v) in &entries {
            g_mat[(*i, *j)] = *v;
            g_mat[(*j, *i)] = *v;
        }

        // Diagonalize
        let eig = SymmetricEigen::new(g_mat);
        let eigenvalues: Vec<f64> = eig.eigenvalues.iter().cloned().collect();

        // Compute Liouville values
        let lio: Vec<f64> = (0..dim).map(|k| liouville(k + 2) as f64).collect();
        let lio_sum: i64 = lio.iter().map(|&x| x as i64).sum();

        // Transform Γ to eigenbasis: gamma_eig[i] = Σ_k λ(k) · U[k,i]
        // W(β) = Σ_i gamma_eig[i] · exp(-β·λ_i)
        // Actually: Tr(Γ·e^{-βG}) = Σ_i (U^T Γ U)_{ii} · e^{-β·λ_i}
        // = Σ_i [Σ_k U_{ki} λ(k) U_{ki}] · e^{-β·λ_i}
        // Wait, no. Let me be more careful.
        // e^{-βG} = U · diag(e^{-β·λ_i}) · U^T
        // Tr(Γ · e^{-βG}) = Σ_{k,i} Γ_{kk} · U_{ki}² · e^{-β·λ_i}
        // = Σ_i [Σ_k λ(k+2) · U_{ki}²] · e^{-β·λ_i}

        let mut gamma_eig = vec![0.0f64; dim];
        for i in 0..dim {
            let mut sum = 0.0f64;
            for k in 0..dim {
                let u_ki = eig.eigenvectors[(k, i)];
                sum += lio[k] * u_ki * u_ki;
            }
            gamma_eig[i] = sum;
        }

        let t = start.elapsed().as_secs_f64();
        println!(
            "  N={:4}: diagonalized (dim={}) in {:.1}s, L(N)-1 = {}",
            n, dim, t, lio_sum
        );

        all_data.push(NData {
            n,
            eigenvalues,
            gamma_eig,
            liouville_sum: lio_sum,
        });
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 2: W(β) curves
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 2: W(β) for each N ═══\n");

    // Print header
    print!("  {:>10}", "β");
    for d in &all_data {
        print!("  {:>12}", format!("N={}", d.n));
    }
    println!();
    println!("  {}", "─".repeat(10 + 14 * all_data.len()));

    for &beta in &betas {
        print!("  {:10.4}", beta);
        for d in &all_data {
            // W(β) = Σ_i gamma_eig[i] · exp(-β · λ_i)
            let w: f64 = d
                .gamma_eig
                .iter()
                .zip(d.eigenvalues.iter())
                .map(|(&g, &lam)| g * (-beta * lam).exp())
                .sum();
            print!("  {:12.6}", w);
        }
        println!();
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 3: Phase transition analysis
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 3: Phase transition analysis ═══\n");

    for d in &all_data {
        let dim = d.eigenvalues.len();
        let lmin = d.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);
        let lmax = d
            .eigenvalues
            .iter()
            .cloned()
            .fold(f64::NEG_INFINITY, f64::max);

        // Find β where |W(β)| first drops below 1% of |W(0)|
        let w0 = d.liouville_sum as f64;
        let threshold = 0.01 * w0.abs().max(1.0);
        let mut beta_cross = f64::NAN;
        for &beta in &betas {
            if beta == 0.0 {
                continue;
            }
            let w: f64 = d
                .gamma_eig
                .iter()
                .zip(d.eigenvalues.iter())
                .map(|(&g, &lam)| g * (-beta * lam).exp())
                .sum();
            if w.abs() < threshold && beta_cross.is_nan() {
                beta_cross = beta;
            }
        }

        // Find β where W(β) changes sign
        let mut beta_sign = f64::NAN;
        let mut prev_sign = w0.signum();
        for &beta in &betas {
            if beta == 0.0 {
                continue;
            }
            let w: f64 = d
                .gamma_eig
                .iter()
                .zip(d.eigenvalues.iter())
                .map(|(&g, &lam)| g * (-beta * lam).exp())
                .sum();
            if w.signum() != prev_sign && w.signum() != 0.0 && beta_sign.is_nan() {
                beta_sign = beta;
            }
            if w.abs() > 1e-15 {
                prev_sign = w.signum();
            }
        }

        // Compute "SUSY order parameter": W(β) / Tr(e^{-βG})
        // This normalizes by the partition function
        println!("  N={:4}:", d.n);
        println!("    L(N)-1 = W(0) = {}", d.liouville_sum);
        println!("    λ_min = {:.6}, λ_max = {:.4}", lmin, lmax);
        println!(
            "    β where |W| < 1% of |W(0)|: {:.4}",
            if beta_cross.is_nan() {
                f64::NAN
            } else {
                beta_cross
            }
        );
        println!(
            "    β where W changes sign:      {:.4}",
            if beta_sign.is_nan() {
                f64::NAN
            } else {
                beta_sign
            }
        );

        // Normalized Witten index: W(β) / Z(β)
        println!("    Normalized W/Z at selected β:");
        for &beta in &[0.1, 1.0, 10.0, 100.0] {
            let w: f64 = d
                .gamma_eig
                .iter()
                .zip(d.eigenvalues.iter())
                .map(|(&g, &lam)| g * (-beta * lam).exp())
                .sum();
            let z: f64 = d.eigenvalues.iter().map(|&lam| (-beta * lam).exp()).sum();
            println!(
                "      β={:6.1}: W={:12.6}, Z={:12.4}, W/Z={:12.8}",
                beta,
                w,
                z,
                if z.abs() > 1e-30 { w / z } else { f64::NAN }
            );
        }
        println!();
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 4: Scaling of |W(0)| vs N
    // ═══════════════════════════════════════════════════════
    println!("═══ Section 4: Scaling of |L(N)| vs N ═══\n");
    println!(
        "  {:>6} {:>10} {:>12} {:>12} {:>12}",
        "N", "L(N)-1", "|L|/√N", "|L|/N^0.5", "ln|L|/lnN"
    );
    println!("  {}", "─".repeat(52));
    for d in &all_data {
        let l = d.liouville_sum.unsigned_abs() as f64;
        let n = d.n as f64;
        let ratio_sqrt = l / n.sqrt();
        let exponent = if l > 0.0 { l.ln() / n.ln() } else { 0.0 };
        println!(
            "  {:6} {:10} {:12.6} {:12.6} {:12.6}",
            d.n,
            d.liouville_sum,
            ratio_sqrt,
            l / n.powf(0.5),
            exponent
        );
    }
    println!("\n  RH prediction: |L(N)| / √N → 0 (or bounded)");
    println!("  Anti-RH:       |L(N)| / √N → ∞");

    // ═══════════════════════════════════════════════════════
    // SECTION 5: Spectral decomposition of Liouville
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 5: Liouville spectral projection (N=500) ═══\n");
    if let Some(d) = all_data.iter().find(|d| d.n == 500) {
        let dim = d.eigenvalues.len();
        // Sort eigenvalues for display
        let mut indexed: Vec<(usize, f64, f64)> = d
            .eigenvalues
            .iter()
            .zip(d.gamma_eig.iter())
            .enumerate()
            .map(|(i, (&lam, &g))| (i, lam, g))
            .collect();
        indexed.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());

        println!("  How much of the Liouville sum lives in each eigenmode:\n");
        println!(
            "  {:>5} {:>14} {:>14} {:>14} {:>10}",
            "rank", "λ_i", "γ_i (weight)", "cumulative", "|γ_i|/Σ|γ|"
        );
        println!("  {}", "─".repeat(60));

        let total_gamma: f64 = d.gamma_eig.iter().map(|g| g.abs()).sum();
        let mut cum = 0.0f64;

        // Show bottom 10 and top 10
        for (rank, &(_, lam, g)) in indexed.iter().enumerate().take(10) {
            cum += g;
            println!(
                "  {:5} {:14.10} {:14.10} {:14.10} {:10.4}%",
                rank + 1,
                lam,
                g,
                cum,
                100.0 * g.abs() / total_gamma
            );
        }
        println!("  {:>5} {:>14} {:>14}", "...", "...", "...");
        let top5: Vec<_> = indexed
            .iter()
            .rev()
            .take(5)
            .collect::<Vec<_>>()
            .into_iter()
            .rev()
            .collect();
        for (i, &&(_, lam, g)) in top5.iter().enumerate() {
            println!(
                "  {:5} {:14.10} {:14.10} {:14.10} {:10.4}%",
                dim - 4 + i,
                lam,
                g,
                d.liouville_sum as f64,
                100.0 * g.abs() / total_gamma
            );
        }

        println!(
            "\n  Total |γ| = {:.6}, W(0) = L(N)-1 = {}",
            total_gamma, d.liouville_sum
        );
        println!(
            "  Cancellation ratio: W(0)/Σ|γ| = {:.6}",
            d.liouville_sum as f64 / total_gamma
        );
    }

    println!(
        "\n  Total time: {:.1}s",
        total_start.elapsed().as_secs_f64()
    );
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  SUSY Witten index analysis complete.                          ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
}
