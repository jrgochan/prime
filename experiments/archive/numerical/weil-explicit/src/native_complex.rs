#![allow(unused, dead_code, non_snake_case)]
use rayon::prelude::*;
use num_complex::Complex64;

// ══════════════════════════════════════════════════════════════════════
// NATIVE COMPLEX HERMITIAN SOLVER v2
//
// Strategy: Use COMPLEX CHOLESKY (verified correct in previous test)
// for d²_N and coefficients, plus 2n×2n nalgebra SymmetricEigen for
// eigenvalues/statistics (verified correct for eigenvalues).
//
// The key insight: the 2n×2n embedding gives CORRECT eigenvalues and
// CORRECT d²_N (via eigendecomposition), but the COEFFICIENTS from the
// embedding's linear solve can't be used for quadrature verification.
//
// Fix: Use complex Cholesky for coefficients → quadrature.
//      Use nalgebra SymmetricEigen for eigenvalues → d²_spectral.
//      Compare all three.
// ══════════════════════════════════════════════════════════════════════

type C64 = Complex64;

fn c(re: f64, im: f64) -> C64 { C64::new(re, im) }
fn cr(re: f64) -> C64 { C64::new(re, 0.0) }
fn czero() -> C64 { C64::new(0.0, 0.0) }

fn frac_part(x: f64) -> f64 { x - x.floor() }

fn gram_entry_real(j: usize, k: usize, n_pts: usize) -> f64 {
    let (jf, kf) = (j as f64, k as f64);
    let dx = 1.0 / n_pts as f64;
    let mut s = 0.0f64;
    for i in 0..n_pts { let x = (i as f64+0.5)*dx; s += frac_part(jf/x)*frac_part(kf/x); }
    s * dx
}

/// Complex Gram entry: G[j,k] = ∫₀¹ f_j(x)·conj(f_k(x)) dx
/// For f_k(x) = {k/x}·e^{iαk/x}:
/// G[j,k] = ∫₀¹ {j/x}·{k/x}·e^{iα(j-k)/x} dx
fn gram_entry_complex(j: usize, k: usize, alpha: f64, n_pts: usize) -> C64 {
    let (jf, kf) = (j as f64, k as f64);
    let diff = (j as f64 - k as f64) * alpha;
    let dx = 1.0 / n_pts as f64;
    let (mut sr, mut si) = (0.0f64, 0.0f64);
    for i in 0..n_pts {
        let x = (i as f64+0.5)*dx;
        let base = frac_part(jf/x) * frac_part(kf/x);
        let phase = diff / x;
        sr += base * phase.cos();
        si += base * phase.sin();
    }
    c(sr * dx, si * dx)
}

/// Target vector: b_k = ⟨1, f_k⟩ = ∫₀¹ conj(f_k(x))·1 dx = ∫₀¹ {k/x}·e^{-iαk/x} dx
fn nb_target(k: usize, alpha: f64, n_pts: usize) -> C64 {
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let (mut sr, mut si) = (0.0f64, 0.0f64);
    for i in 0..n_pts {
        let x = (i as f64+0.5)*dx;
        let f = frac_part(kf / x);
        let phase = -alpha * kf / x;
        sr += f * phase.cos();
        si += f * phase.sin();
    }
    c(sr * dx, si * dx)
}

// ══════════════════════════════════════════════════════════════════════
// COMPLEX CHOLESKY + SOLVE
// ══════════════════════════════════════════════════════════════════════

fn complex_cholesky(h: &[Vec<C64>]) -> Option<Vec<Vec<C64>>> {
    let n = h.len();
    let mut l = vec![vec![czero(); n]; n];
    for j in 0..n {
        let mut sum = 0.0f64;
        for k in 0..j { sum += l[j][k].norm_sqr(); }
        let diag = h[j][j].re - sum;
        if diag <= 1e-15 { return None; }
        l[j][j] = cr(diag.sqrt());
        for i in (j+1)..n {
            let mut s = czero();
            for k in 0..j { s += l[i][k] * l[j][k].conj(); }
            l[i][j] = (h[i][j] - s) / l[j][j];
        }
    }
    Some(l)
}

fn forward_solve(l: &[Vec<C64>], b: &[C64]) -> Vec<C64> {
    let n = b.len();
    let mut x = vec![czero(); n];
    for i in 0..n {
        let mut s = b[i];
        for j in 0..i { s -= l[i][j] * x[j]; }
        x[i] = s / l[i][i];
    }
    x
}

fn backward_solve_adj(l: &[Vec<C64>], b: &[C64]) -> Vec<C64> {
    let n = b.len();
    let mut x = vec![czero(); n];
    for i in (0..n).rev() {
        let mut s = b[i];
        for j in (i+1)..n { s -= l[j][i].conj() * x[j]; }
        x[i] = s / l[i][i]; // L diagonal is real
    }
    x
}

fn cholesky_solve(h: &[Vec<C64>], b: &[C64]) -> Option<Vec<C64>> {
    let l = complex_cholesky(h)?;
    let y = forward_solve(&l, b);
    Some(backward_solve_adj(&l, &y))
}

// ══════════════════════════════════════════════════════════════════════
// EIGENDECOMPOSITION via 2n×2n embedding + nalgebra
// (Eigenvalues are correct from the embedding — verified previously)
// ══════════════════════════════════════════════════════════════════════

use nalgebra::{DMatrix, DVector, SymmetricEigen};

fn eigenvalues_via_embedding(gre: &[Vec<f64>], gim: &[Vec<f64>]) -> Vec<f64> {
    let n = gre.len();
    let m = 2 * n;
    let mut mat = DMatrix::<f64>::zeros(m, m);
    for i in 0..n { for j in 0..n {
        mat[(i, j)] = gre[i][j];
        mat[(i, n+j)] = -gim[i][j];
        mat[(n+i, j)] = gim[i][j];
        mat[(n+i, n+j)] = gre[i][j];
    }}
    let eig = SymmetricEigen::new(mat);
    let mut ev: Vec<f64> = eig.eigenvalues.iter().cloned().collect();
    ev.sort_by(|a,b| a.partial_cmp(b).unwrap());

    // Extract distinct eigenvalues (embedding gives each eigenvalue twice)
    let mut distinct = Vec::new();
    let mut i = 0;
    while i < ev.len() {
        distinct.push(ev[i]);
        if i+1 < ev.len() && (ev[i+1]-ev[i]).abs() < 1e-8 * ev[i].abs().max(1e-10) {
            i += 2;
        } else {
            i += 1;
        }
    }
    distinct
}

fn d2_via_embedding(gre: &[Vec<f64>], gim: &[Vec<f64>], bre: &[f64], bim: &[f64]) -> f64 {
    let n = gre.len();
    let m = 2 * n;
    let mut mat = DMatrix::<f64>::zeros(m, m);
    for i in 0..n { for j in 0..n {
        mat[(i, j)] = gre[i][j];
        mat[(i, n+j)] = -gim[i][j];
        mat[(n+i, j)] = gim[i][j];
        mat[(n+i, n+j)] = gre[i][j];
    }}
    let mut bvec = DVector::<f64>::zeros(m);
    for i in 0..n { bvec[i] = bre[i]; bvec[n+i] = bim[i]; }

    let eig = SymmetricEigen::new(mat);
    let mut sum = 0.0f64;
    for i in 0..eig.eigenvalues.len() {
        let lam = eig.eigenvalues[i];
        if lam.abs() > 1e-15 {
            let bvi = bvec.dot(&eig.eigenvectors.column(i));
            sum += bvi * bvi / lam;
        }
    }
    1.0 - sum
}

// ══════════════════════════════════════════════════════════════════════
// QUADRATURE VERIFICATION
// ══════════════════════════════════════════════════════════════════════

fn d2_quadrature(coeffs: &[C64], alpha: f64, dim: usize, n_pts: usize) -> f64 {
    let dx = 1.0 / n_pts as f64;
    let mut total = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        let mut approx = czero();
        for j in 0..dim {
            let k = j + 2;
            let fv = frac_part(k as f64 / x);
            let phase = alpha * k as f64 / x;
            let basis = c(fv * phase.cos(), fv * phase.sin());
            approx += coeffs[j] * basis;
        }
        total += (1.0 - approx.re).powi(2) + approx.im.powi(2);
    }
    total * dx
}

// ══════════════════════════════════════════════════════════════════════
// BUILD MATRICES
// ══════════════════════════════════════════════════════════════════════

struct GramData {
    h_complex: Vec<Vec<C64>>,
    b_complex: Vec<C64>,
    gre: Vec<Vec<f64>>,
    gim: Vec<Vec<f64>>,
    bre: Vec<f64>,
    bim: Vec<f64>,
}

fn build_gram(dim: usize, alpha: f64, n_pts: usize) -> GramData {
    let entries: Vec<((usize,usize), C64)> = (0..dim).into_par_iter()
        .flat_map(|j| (j..dim).into_par_iter().map(move |k| {
            let val = if alpha == 0.0 {
                cr(gram_entry_real(j+2, k+2, n_pts))
            } else {
                gram_entry_complex(j+2, k+2, alpha, n_pts)
            };
            ((j,k), val)
        })).collect();

    let mut h = vec![vec![czero(); dim]; dim];
    let mut gre = vec![vec![0.0; dim]; dim];
    let mut gim = vec![vec![0.0; dim]; dim];
    for ((j,k), val) in entries {
        h[j][k] = val; h[k][j] = val.conj();
        gre[j][k] = val.re; gre[k][j] = val.re;
        gim[j][k] = val.im; gim[k][j] = -val.im;
    }

    let b: Vec<C64> = (0..dim).map(|j| nb_target(j+2, alpha, n_pts)).collect();
    let bre: Vec<f64> = b.iter().map(|x| x.re).collect();
    let bim: Vec<f64> = b.iter().map(|x| x.im).collect();

    GramData { h_complex: h, b_complex: b, gre, gim, bre, bim }
}

// ══════════════════════════════════════════════════════════════════════
// RATIO TEST
// ══════════════════════════════════════════════════════════════════════

fn ratio_mean(ev: &[f64]) -> f64 {
    if ev.len() < 3 { return 0.0; }
    let mut ratios = Vec::new();
    for i in 0..(ev.len()-2) {
        let s1 = ev[i+1] - ev[i];
        let s2 = ev[i+2] - ev[i+1];
        if s1 > 1e-15 && s2 > 1e-15 { ratios.push(s1.min(s2)/s1.max(s2)); }
    }
    if ratios.is_empty() { 0.0 } else { ratios.iter().sum::<f64>() / ratios.len() as f64 }
}

fn classify(rm: f64) -> &'static str {
    let d = [("Poi",0.3863), ("GOE",0.5307), ("GUE",0.5996), ("GSE",0.6744)];
    d.iter().min_by(|a,b| (rm-a.1).abs().partial_cmp(&(rm-b.1).abs()).unwrap()).unwrap().0
}

// ══════════════════════════════════════════════════════════════════════
// MAIN
// ══════════════════════════════════════════════════════════════════════

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  NATIVE COMPLEX VERIFICATION v2                                ║");
    println!("║  Complex Cholesky + nalgebra eigenvalues + quadrature          ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let total_start = std::time::Instant::now();
    let n_pts = 150_000;

    // ════════════════════════════════════════════════════════════════
    // TEST 1: Three-method comparison at N=100
    // ════════════════════════════════════════════════════════════════
    let max_n: usize = 100;
    let dim = max_n - 1;

    println!("═══════════════════════════════════════════════════════════════════");
    println!("  TEST 1: DEFINITIVE three-method d²_N comparison (N={})", max_n);
    println!("  • Spectral: d² = 1 - Σ(b·v_i)²/λ_i  (nalgebra embedding)");
    println!("  • Cholesky: d² = 1 - Re(b†·G⁻¹·b)  (NATIVE complex Cholesky)");
    println!("  • Quadrature: ||1 - Σcₖfₖ||²  (using Cholesky coefficients)");
    println!("═══════════════════════════════════════════════════════════════════\n");

    let test_alphas = vec![0.0, 0.05, 0.1, 0.2, 0.3, 0.5, 0.7, 0.8, 0.85, 0.9, 1.0, 1.5, 2.0];

    println!("  {:>5} │ {:>14} {:>14} {:>14} │ {:>10} {:>7} {:>8} │ {}",
        "α", "d² spectral", "d² Cholesky", "d² quadrature",
        "λ_min", "κ", "||c||", "Agree?");
    println!("  {}┼{}┼{}┼{}", "─".repeat(6), "─".repeat(45), "─".repeat(28), "─".repeat(10));

    for &alpha in &test_alphas {
        let start = std::time::Instant::now();
        let g = build_gram(dim, alpha, n_pts);

        // Method 1: Spectral via nalgebra embedding
        let d2s = d2_via_embedding(&g.gre, &g.gim, &g.bre, &g.bim);

        // Eigenvalues (distinct) for stats
        let eigs = eigenvalues_via_embedding(&g.gre, &g.gim);
        let lmin = eigs[0];
        let lmax = eigs[eigs.len()-1];
        let kappa = if lmin > 1e-15 { lmax/lmin } else { f64::INFINITY };

        // Method 2: Complex Cholesky
        let (d2c, c_vec) = match cholesky_solve(&g.h_complex, &g.b_complex) {
            Some(cv) => {
                let btc: C64 = g.b_complex.iter().zip(cv.iter())
                    .map(|(bi, ci)| bi.conj() * ci).sum();
                (1.0 - btc.re, cv)
            }
            None => (f64::NAN, vec![czero(); dim])
        };
        let c_norm: f64 = c_vec.iter().map(|x| x.norm_sqr()).sum::<f64>().sqrt();

        // Method 3: Quadrature using Cholesky coefficients
        let d2q = if !d2c.is_nan() {
            d2_quadrature(&c_vec, alpha, dim, n_pts)
        } else { f64::NAN };

        let time = start.elapsed().as_secs_f64();

        let finite = !d2s.is_nan() && !d2c.is_nan() && !d2q.is_nan();
        let agree_all = finite && (d2s - d2c).abs() < 0.001 && (d2c - d2q).abs() < 0.01;
        let agree_sc = finite && (d2s - d2c).abs() < 0.01;
        let status = if agree_all { "✅ ALL" }
                    else if agree_sc { "✅ SC" }
                    else if finite { "❌" }
                    else { "⚠ NaN" };

        println!("  {:5.2} │ {:14.8} {:14.8} {:14.8} │ {:10.6} {:7.1} {:8.4} │ {} ({:.1}s)",
            alpha, d2s, d2c, d2q, lmin, kappa, c_norm, status, time);
    }

    // ════════════════════════════════════════════════════════════════
    // TEST 2: d²_N scaling with N  (Cholesky method — native complex)
    // ════════════════════════════════════════════════════════════════
    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  TEST 2: d²_N convergence (native complex Cholesky)");
    println!("═══════════════════════════════════════════════════════════════════\n");

    let n_sizes = vec![50, 75, 100, 150, 200, 250];
    let key_alphas = vec![0.0, 0.1, 0.2, 0.5, 0.8, 1.0];

    print!("  {:>5} │", "N");
    for &a in &key_alphas { print!("  {:>11}", format!("α={:.1}", a)); }
    println!();
    println!("  {}┼{}", "─".repeat(6), "─".repeat(13 * key_alphas.len()));

    for &max_n in &n_sizes {
        let dim = max_n - 1;
        print!("  {:5} │", max_n);
        for &alpha in &key_alphas {
            let g = build_gram(dim, alpha, n_pts);
            let d2 = match cholesky_solve(&g.h_complex, &g.b_complex) {
                Some(cv) => {
                    let btc: C64 = g.b_complex.iter().zip(cv.iter())
                        .map(|(bi, ci)| bi.conj() * ci).sum();
                    1.0 - btc.re
                }
                None => f64::NAN
            };
            if d2.abs() < 1e-10 { print!("     {:>6}", "≡0"); }
            else { print!(" {:12.8}", d2); }
        }
        println!();
    }

    // ════════════════════════════════════════════════════════════════
    // TEST 3: λ_min convergence (nalgebra embedding — proven correct)
    // ════════════════════════════════════════════════════════════════
    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  TEST 3: λ_min convergence (nalgebra, distinct eigenvalues)");
    println!("═══════════════════════════════════════════════════════════════════\n");

    print!("  {:>5} │", "N");
    for &a in &key_alphas { print!(" {:>12}", format!("α={:.1}", a)); }
    println!();
    println!("  {}┼{}", "─".repeat(6), "─".repeat(13 * key_alphas.len()));

    for &max_n in &n_sizes {
        let dim = max_n - 1;
        print!("  {:5} │", max_n);
        for &alpha in &key_alphas {
            let g = build_gram(dim, alpha, n_pts);
            let eigs = eigenvalues_via_embedding(&g.gre, &g.gim);
            print!(" {:12.8}", eigs[0]);
        }
        println!();
    }

    // ════════════════════════════════════════════════════════════════
    // TEST 4: Ratio test (native distinct eigenvalues)
    // ════════════════════════════════════════════════════════════════
    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  TEST 4: Ratio test ⟨r⟩ (distinct eigenvalues)");
    println!("═══════════════════════════════════════════════════════════════════\n");

    print!("  {:>5} │", "N");
    for &a in &key_alphas { print!(" {:>12}", format!("α={:.1}", a)); }
    println!();
    println!("  {}┼{}", "─".repeat(6), "─".repeat(13 * key_alphas.len()));

    for &max_n in &[75, 100, 150, 200] {
        let dim = max_n - 1;
        print!("  {:5} │", max_n);
        for &alpha in &key_alphas {
            let g = build_gram(dim, alpha, n_pts);
            let eigs = eigenvalues_via_embedding(&g.gre, &g.gim);
            let rm = ratio_mean(&eigs);
            print!(" {:5.3} {:>5}", rm, classify(rm));
        }
        println!();
    }

    // ════════════════════════════════════════════════════════════════
    // TEST 5: Fine α scan — d²_N via Cholesky (DEFINITIVE)
    // ════════════════════════════════════════════════════════════════
    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  TEST 5: Fine α scan of d²_N — native Cholesky (N=100)");
    println!("═══════════════════════════════════════════════════════════════════\n");

    println!("  {:>6} {:>14} {:>14} {:>14} {:>10} {:>8}",
        "α", "d²_N Cholesky", "d²_N spectral", "d²_N quadrature", "λ_min", "||c||");
    println!("  {}", "─".repeat(70));

    let dim = 99;
    for i in 0..=40 {
        let alpha = i as f64 * 0.05;
        let g = build_gram(dim, alpha, n_pts);

        // Cholesky d²
        let (d2c, c_vec) = match cholesky_solve(&g.h_complex, &g.b_complex) {
            Some(cv) => {
                let btc: C64 = g.b_complex.iter().zip(cv.iter())
                    .map(|(bi, ci)| bi.conj() * ci).sum();
                (1.0 - btc.re, cv)
            }
            None => (f64::NAN, vec![czero(); dim])
        };

        // Spectral d² (embedding)
        let d2s = d2_via_embedding(&g.gre, &g.gim, &g.bre, &g.bim);

        // Quadrature
        let d2q = if !d2c.is_nan() {
            d2_quadrature(&c_vec, alpha, dim, n_pts)
        } else { f64::NAN };

        let eigs = eigenvalues_via_embedding(&g.gre, &g.gim);
        let c_norm: f64 = c_vec.iter().map(|x| x.norm_sqr()).sum::<f64>().sqrt();

        println!("  {:6.2} {:14.8} {:14.8} {:14.8} {:10.6} {:8.4}",
            alpha, d2c, d2s, d2q, eigs[0], c_norm);
    }

    // ────────── VERDICT ──────────
    println!("\n╔══════════════════════════════════════════════════════════════════╗");
    println!("║            DEFINITIVE NATIVE COMPLEX VERDICT                    ║");
    println!("╠══════════════════════════════════════════════════════════════════╣");
    println!("║                                                                ║");
    println!("║  Complex Cholesky solves Gc = b NATIVELY in ℂⁿ (no embedding) ║");
    println!("║  nalgebra gives eigenvalues via 2n×2n (verified correct)       ║");
    println!("║  Quadrature uses Cholesky's coefficients (no embedding)        ║");
    println!("║                                                                ║");
    println!("║  If Cholesky d² = quadrature d² → the REAL d²_N is found      ║");
    println!("║  If spectral d² ≠ Cholesky d² → embedding creates phantoms    ║");
    println!("║                                                                ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    println!("  Total time: {:.1}s\n", total_start.elapsed().as_secs_f64());
}
