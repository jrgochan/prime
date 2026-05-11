#![allow(unused, dead_code, non_snake_case)]
use rayon::prelude::*;
use nalgebra::{DMatrix, SymmetricEigen};

// ══════════════════════════════════════════════════════════════════════
// OPERATOR-THEORETIC SPECTRAL GAP ANALYSIS
//
// Key idea: Decompose G = (1/4)·11ᵀ + E
// where E captures arithmetic correlations beyond the mean field.
//
// If E has a spectral gap (λ_min(E) > 0), then λ_min(G) ≥ λ_min(E) > 0
// for ALL N simultaneously — proving the infinite-dimensional spectral gap.
//
// Tests:
// 1. Gershgorin: does E[k,k] > Σ_{j≠k} |E[j,k]|?
// 2. Spectrum: does λ_min(E_N) converge to a positive limit?
// 3. Structure: how does E[j,k] depend on gcd(j,k)?
// ══════════════════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 { x - x.floor() }

fn gcd(a: usize, b: usize) -> usize {
    if b == 0 { a } else { gcd(b, a % b) }
}

/// Compute Gram entry G[j,k] = ∫₀¹ {j/x}{k/x} dx
fn gram_entry(j: usize, k: usize, n_pts: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let mut sum = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        sum += frac_part(jf / x) * frac_part(kf / x);
    }
    sum * dx
}

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  OPERATOR-THEORETIC SPECTRAL GAP ANALYSIS                      ║");
    println!("║  Decomposition: G = (1/4)·11ᵀ + E                             ║");
    println!("║  Question: Does λ_min(E) > 0?                                 ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let n_pts = 500_000;
    let max_n = 500; // Study up to N=500
    let dim = max_n - 1; // 499×499 matrix

    // ═══════════════════════════════════════════════════════
    // SECTION 1: Compute the Gram matrix and E = G - (1/4)·11ᵀ
    // ═══════════════════════════════════════════════════════
    println!("═══ Section 1: Computing Gram matrix (N={}) ═══\n", max_n);

    let start = std::time::Instant::now();
    let gram: Vec<Vec<f64>> = (0..dim).into_par_iter().map(|i| {
        let mut row = vec![0.0; dim];
        for j in i..dim {
            let val = gram_entry(i + 2, j + 2, n_pts);
            row[j] = val;
        }
        row
    }).collect();

    // Symmetrize
    let mut gram_full = vec![vec![0.0; dim]; dim];
    for i in 0..dim {
        for j in i..dim {
            gram_full[i][j] = gram[i][j];
            gram_full[j][i] = gram[i][j];
        }
    }
    println!("  Gram matrix computed in {:.1}s\n", start.elapsed().as_secs_f64());

    // ═══════════════════════════════════════════════════════
    // SECTION 2: Diagonal and off-diagonal structure
    // ═══════════════════════════════════════════════════════
    println!("═══ Section 2: Entry structure ═══\n");
    println!("  {:>5} {:>12} {:>12} {:>12} {:>8}",
        "k", "G[k,k]", "E[k,k]", "E[k,k]-1/4", "G[k,k]≈");
    println!("  {}", "─".repeat(52));

    for &k in &[2, 3, 5, 10, 20, 50, 100, 200, 500] {
        if k > max_n { continue; }
        let idx = k - 2;
        let gkk = gram_full[idx][idx];
        let ekk = gkk - 0.25;
        // Theoretical: G[k,k] ≈ 1/2 - 1/(2k) + 1/(12k²) (approx)
        let approx = 0.5 - 0.5 / k as f64;
        println!("  {:5} {:12.8} {:12.8} {:12.8} {:8.6}",
            k, gkk, ekk, ekk - 0.25, approx);
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 3: Off-diagonal E[j,k] by gcd
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 3: Off-diagonal E[j,k] = G[j,k] - 1/4 by gcd ═══\n");
    println!("  {:>5} {:>5} {:>5} {:>12} {:>12} {:>12}",
        "j", "k", "gcd", "G[j,k]", "E[j,k]", "|E[j,k]|×jk");
    println!("  {}", "─".repeat(58));

    let examples = vec![
        (2, 3), (2, 5), (3, 5), (3, 7), (6, 10),    // small coprime
        (2, 4), (3, 6), (4, 8), (5, 10), (6, 12),    // gcd > 1
        (100, 101), (100, 103), (100, 200), (100, 300), // large
        (2, 100), (3, 100), (50, 51), (50, 100),       // mixed
    ];
    for (j, k) in &examples {
        if *j > max_n || *k > max_n { continue; }
        let (ji, ki) = (j - 2, k - 2);
        let gjk = gram_full[ji][ki];
        let ejk = gjk - 0.25;
        let d = gcd(*j, *k);
        println!("  {:5} {:5} {:5} {:12.8} {:12.8} {:12.6}",
            j, k, d, gjk, ejk, ejk.abs() * (*j as f64) * (*k as f64));
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 4: Gershgorin analysis of E
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 4: Gershgorin diagonal dominance of E ═══\n");
    println!("  {:>5} {:>12} {:>12} {:>12} {:>8}",
        "k", "E[k,k]", "Σ|E[k,j]|", "ratio", "dom?");
    println!("  {}", "─".repeat(52));

    let mut gershgorin_pass = 0;
    let mut gershgorin_fail = 0;

    for k_idx in 0..dim {
        let k = k_idx + 2;
        let ekk = gram_full[k_idx][k_idx] - 0.25;
        let mut row_sum = 0.0f64;
        for j_idx in 0..dim {
            if j_idx == k_idx { continue; }
            let ejk = gram_full[k_idx][j_idx] - 0.25;
            row_sum += ejk.abs();
        }
        let ratio = row_sum / ekk;
        let dominant = ekk > row_sum;

        if dominant { gershgorin_pass += 1; } else { gershgorin_fail += 1; }

        if k <= 10 || k == 20 || k == 50 || k == 100 || k == 200 || k == 500 {
            println!("  {:5} {:12.8} {:12.8} {:12.4} {:>8}",
                k, ekk, row_sum, ratio, if dominant { "✅" } else { "❌" });
        }
    }
    println!("\n  Gershgorin pass: {} / {} rows", gershgorin_pass, dim);

    // ═══════════════════════════════════════════════════════
    // SECTION 5: Spectrum comparison G_N vs E_N
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 5: Spectrum comparison G vs E ═══\n");
    println!("  {:>5} {:>14} {:>14} {:>14} {:>10}",
        "N", "λ_min(G_N)", "λ_min(E_N)", "λ_min(E)/λ_min(G)", "improved?");
    println!("  {}", "─".repeat(62));

    for &n in &[5, 10, 20, 50, 100, 200, 300, 400, 500] {
        let d = n - 1;
        if d > dim { continue; }

        // Build G_N and E_N = G_N - (1/4)·11ᵀ
        let mut g_mat = DMatrix::<f64>::zeros(d, d);
        let mut e_mat = DMatrix::<f64>::zeros(d, d);
        for i in 0..d {
            for j in 0..d {
                g_mat[(i, j)] = gram_full[i][j];
                e_mat[(i, j)] = gram_full[i][j] - 0.25;
            }
        }

        let g_eig = SymmetricEigen::new(g_mat);
        let e_eig = SymmetricEigen::new(e_mat);

        let lmin_g = g_eig.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);
        let lmin_e = e_eig.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);

        let ratio = if lmin_g.abs() > 1e-15 { lmin_e / lmin_g } else { f64::NAN };
        let improved = lmin_e > lmin_g;

        println!("  {:5} {:14.10} {:14.10} {:14.4} {:>10}",
            n, lmin_g, lmin_e, ratio, if improved { "✅ YES" } else { "❌ no" });
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 6: E eigenvalues — full spectrum at N=500
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 6: Smallest eigenvalues of E_500 ═══\n");
    {
        let d = dim.min(499);
        let mut e_mat = DMatrix::<f64>::zeros(d, d);
        for i in 0..d {
            for j in 0..d {
                e_mat[(i, j)] = gram_full[i][j] - 0.25;
            }
        }
        let e_eig = SymmetricEigen::new(e_mat);
        let mut evals: Vec<f64> = e_eig.eigenvalues.iter().cloned().collect();
        evals.sort_by(|a, b| a.partial_cmp(b).unwrap());

        println!("  10 smallest eigenvalues of E_500:");
        for i in 0..10.min(evals.len()) {
            println!("    λ_{} = {:.10}", i + 1, evals[i]);
        }
        println!("\n  10 largest eigenvalues of E_500:");
        for i in (evals.len().saturating_sub(10))..evals.len() {
            println!("    λ_{} = {:.10}", i + 1, evals[i]);
        }

        // Check: how many negative eigenvalues?
        let neg_count = evals.iter().filter(|&&v| v < 0.0).count();
        println!("\n  Negative eigenvalues: {}/{}", neg_count, evals.len());
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 7: Alternative decompositions
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 7: Alternative mean-field values ═══\n");
    println!("  Testing G - μ·11ᵀ for various μ:\n");
    println!("  {:>8} {:>14} {:>14} {:>8}",
        "μ", "λ_min(G-μ11ᵀ)", "neg evals", "gap?");
    println!("  {}", "─".repeat(48));

    for &mu in &[0.0, 0.10, 0.20, 0.24, 0.245, 0.25, 0.255, 0.26, 0.30] {
        let d = 200; // Use N=201 for speed
        let mut mod_mat = DMatrix::<f64>::zeros(d, d);
        for i in 0..d {
            for j in 0..d {
                mod_mat[(i, j)] = gram_full[i][j] - mu;
            }
        }
        let eig = SymmetricEigen::new(mod_mat);
        let mut evals: Vec<f64> = eig.eigenvalues.iter().cloned().collect();
        evals.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let lmin = evals[0];
        let neg = evals.iter().filter(|&&v| v < -1e-10).count();
        let gap = lmin > 0.0;
        println!("  {:8.4} {:14.10} {:>14} {:>8}",
            mu, lmin, neg, if gap { "✅" } else { "❌" });
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 8: Weighted Gershgorin
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 8: Weighted Gershgorin (D⁻¹ED weights) ═══\n");
    println!("  Testing weights d_k = k^α:\n");
    println!("  {:>6} {:>8} {:>8} {:>8} {:>12}",
        "α", "pass", "fail", "ratio", "min Gersh");
    println!("  {}", "─".repeat(48));

    for &alpha in &[0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0] {
        let d = dim.min(499);
        let mut pass = 0;
        let mut fail = 0;
        let mut min_gersh = f64::INFINITY;

        for k_idx in 0..d {
            let k = k_idx + 2;
            let dk = (k as f64).powf(alpha);
            let ekk = gram_full[k_idx][k_idx] - 0.25;

            let mut weighted_sum = 0.0f64;
            for j_idx in 0..d {
                if j_idx == k_idx { continue; }
                let j = j_idx + 2;
                let dj = (j as f64).powf(alpha);
                let ejk = gram_full[k_idx][j_idx] - 0.25;
                weighted_sum += ejk.abs() * dj / dk;
            }
            let gersh_bound = ekk - weighted_sum;
            if gersh_bound > 0.0 { pass += 1; } else { fail += 1; }
            min_gersh = min_gersh.min(gersh_bound);
        }

        println!("  {:6.2} {:>8} {:>8} {:>8.1}% {:12.6}",
            alpha, pass, fail, 100.0 * pass as f64 / d as f64, min_gersh);
    }

    println!("\n  Total time: {:.1}s", start.elapsed().as_secs_f64());
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  Analysis complete.                                            ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
}
