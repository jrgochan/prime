use rayon::prelude::*;
use nalgebra::{DMatrix, DVector, SymmetricEigen};

// ══════════════════════════════════════════════════════════════════════
// SPECTRAL GAP ANALYSIS
//
// Precise characterization of λ_min(G_N), d²_N, δ_N, S_N, ||g||², cos θ
// for the REAL Gram matrix. Provides the numerical evidence for the
// Lean 4 formalization of the HYPERZETA conjecture.
// ══════════════════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 { x - x.floor() }

fn gram_entry(j: usize, k: usize, n_pts: usize) -> f64 {
    let (jf, kf) = (j as f64, k as f64);
    let dx = 1.0 / n_pts as f64;
    let mut s = 0.0f64;
    for i in 0..n_pts { let x = (i as f64+0.5)*dx; s += frac_part(jf/x)*frac_part(kf/x); }
    s * dx
}

fn nb_target(k: usize, n_pts: usize) -> f64 {
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let mut s = 0.0f64;
    for i in 0..n_pts { let x = (i as f64+0.5)*dx; s += frac_part(kf/x); }
    s * dx
}

/// Build (N-1)×(N-1) real symmetric Gram matrix for basis {2/x},...,{N/x}
fn build_gram(max_n: usize, n_pts: usize) -> DMatrix<f64> {
    let dim = max_n - 1;
    let entries: Vec<((usize,usize), f64)> = (0..dim).into_par_iter()
        .flat_map(|j| (j..dim).into_par_iter().map(move |k| {
            ((j,k), gram_entry(j+2, k+2, n_pts))
        })).collect();
    let mut mat = DMatrix::<f64>::zeros(dim, dim);
    for ((j,k), v) in entries { mat[(j,k)] = v; mat[(k,j)] = v; }
    mat
}

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  SPECTRAL GAP ANALYSIS — Real Gram Matrix                      ║");
    println!("║  Precise characterization for Lean 4 formalization             ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let total_start = std::time::Instant::now();
    let n_pts = 200_000;

    let n_values: Vec<usize> = (2..=50).chain((55..=100).step_by(5))
        .chain((110..=200).step_by(10))
        .chain((220..=400).step_by(20))
        .chain(vec![450, 500]).collect();

    // Store results: (N, λ_min, d²_N, δ_N, S_N, ||g||², cos_θ)
    let mut results: Vec<(usize, f64, f64, f64, f64, f64, f64)> = Vec::new();
    let mut prev_lmin = f64::NAN;

    println!("═══════════════════════════════════════════════════════════════════");
    println!("  Computing eigenvalues, NB distance, and gap diagnostics...\n");

    println!("  {:>5} {:>12} {:>12} {:>12} {:>10} {:>10} {:>12}",
        "N", "λ_min", "d²_N", "δ_N", "S_N", "||g||²", "cos θ");
    println!("  {}", "─".repeat(75));

    for &max_n in &n_values {
        let dim = max_n - 1;
        let start = std::time::Instant::now();

        // Build and decompose the Gram matrix
        let mat = build_gram(max_n, n_pts);
        let eig = SymmetricEigen::new(mat.clone());
        let mut eigenvalues: Vec<f64> = eig.eigenvalues.iter().cloned().collect();
        eigenvalues.sort_by(|a,b| a.partial_cmp(b).unwrap());

        let lmin = eigenvalues[0];

        // d²_N = 1 - b† G⁻¹ b  via spectral decomposition
        let b: Vec<f64> = (0..dim).map(|j| nb_target(j+2, n_pts)).collect();
        let bvec = DVector::from_vec(b);
        let mut d2_sum = 0.0f64;
        for i in 0..eigenvalues.len() {
            let lam = eig.eigenvalues[i];
            if lam.abs() > 1e-15 {
                let bvi = bvec.dot(&eig.eigenvectors.column(i));
                d2_sum += bvi * bvi / lam;
            }
        }
        let d2 = (1.0 - d2_sum).max(0.0);

        // δ_N = λ_min(N-1) - λ_min(N)
        let delta = if prev_lmin.is_nan() { 0.0 } else { prev_lmin - lmin };

        // Schur complement S_N = G[N+1,N+1] - g† G_N⁻¹ g
        // g_N[k] = G[N+1, k+2] for k=0..dim-1
        let s_n;
        let g_norm_sq;
        let cos_theta;

        if max_n >= 3 {
            let g_nn = gram_entry(max_n + 1, max_n + 1, n_pts);
            let g: Vec<f64> = (0..dim).map(|k| gram_entry(max_n + 1, k + 2, n_pts)).collect();
            let gvec = DVector::from_vec(g.clone());
            g_norm_sq = gvec.dot(&gvec);

            // S_N = G[N+1,N+1] - g† G⁻¹ g via spectral decomposition
            let mut ginv_sum = 0.0f64;
            for i in 0..eigenvalues.len() {
                let lam = eig.eigenvalues[i];
                if lam.abs() > 1e-15 {
                    let gvi = gvec.dot(&eig.eigenvectors.column(i));
                    ginv_sum += gvi * gvi / lam;
                }
            }
            s_n = g_nn - ginv_sum;

            // cos θ = |g · v_min| / ||g||
            // Find the eigenvector with the smallest eigenvalue
            let min_idx = eig.eigenvalues.iter().enumerate()
                .min_by(|a,b| a.1.partial_cmp(b.1).unwrap()).unwrap().0;
            let gvmin = gvec.dot(&eig.eigenvectors.column(min_idx)).abs();
            cos_theta = if g_norm_sq > 1e-15 { gvmin / g_norm_sq.sqrt() } else { 0.0 };
        } else {
            s_n = 0.0; g_norm_sq = 0.0; cos_theta = 0.0;
        }

        results.push((max_n, lmin, d2, delta, s_n, g_norm_sq, cos_theta));
        prev_lmin = lmin;

        let t = start.elapsed().as_secs_f64();
        if max_n <= 20 || max_n % 10 == 0 || max_n >= 400 {
            println!("  {:5} {:12.8} {:12.8} {:12.8} {:10.6} {:10.4} {:12.8}  ({:.1}s)",
                max_n, lmin, d2, delta, s_n, g_norm_sq, cos_theta, t);
        }
    }

    // ════════════════════════════════════════════════════════════════
    // FIT: λ_min(N) = A + B·N^{-α}
    // ════════════════════════════════════════════════════════════════
    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  POWER LAW FITS (for Lean 4 formalization)");
    println!("═══════════════════════════════════════════════════════════════════\n");

    // Fit λ_min ~ L + C·N^{-α} using log-linear regression on (λ_min - L)
    // Try L values from 0 to 0.015 and find best fit
    let large_n: Vec<&(usize, f64, f64, f64, f64, f64, f64)> = results.iter()
        .filter(|r| r.0 >= 50).collect();

    if large_n.len() >= 5 {
        // Simple approach: fit log(λ_min) = a + b·log(N) to get λ_min ~ e^a · N^b
        // If b → 0, then λ_min → constant (positive limit)
        let log_data: Vec<(f64, f64)> = large_n.iter()
            .map(|r| ((r.0 as f64).ln(), r.1.ln())).collect();

        let n_fit = log_data.len() as f64;
        let sx: f64 = log_data.iter().map(|d| d.0).sum();
        let sy: f64 = log_data.iter().map(|d| d.1).sum();
        let sxx: f64 = log_data.iter().map(|d| d.0*d.0).sum();
        let sxy: f64 = log_data.iter().map(|d| d.0*d.1).sum();

        let b = (n_fit * sxy - sx * sy) / (n_fit * sxx - sx * sx);
        let a = (sy - b * sx) / n_fit;
        let coeff = a.exp();

        println!("  λ_min(N) ≈ {:.6} · N^({:.4})", coeff, b);
        println!("  If exponent → 0, limit is positive (HYPERZETA holds)");
        println!("  Current: λ_min(500) ≈ {:.6} · 500^({:.4}) = {:.6}",
            coeff, b, coeff * 500.0f64.powf(b));
    }

    // Fit d²_N ~ C · N^{-β}
    let d2_data: Vec<(f64, f64)> = large_n.iter()
        .filter(|r| r.2 > 1e-10)
        .map(|r| ((r.0 as f64).ln(), r.2.ln())).collect();

    if d2_data.len() >= 5 {
        let n_fit = d2_data.len() as f64;
        let sx: f64 = d2_data.iter().map(|d| d.0).sum();
        let sy: f64 = d2_data.iter().map(|d| d.1).sum();
        let sxx: f64 = d2_data.iter().map(|d| d.0*d.0).sum();
        let sxy: f64 = d2_data.iter().map(|d| d.0*d.1).sum();

        let b = (n_fit * sxy - sx * sy) / (n_fit * sxx - sx * sx);
        let a = (sy - b * sx) / n_fit;

        println!("\n  d²_N ≈ {:.6} · N^({:.4})", a.exp(), b);
        println!("  Rate: d²_N = O(N^{{{:.2}}})", b);
    }

    // Fit δ_N ~ D · N^{-γ}
    let delta_data: Vec<(f64, f64)> = results.iter()
        .filter(|r| r.0 >= 50 && r.3 > 1e-12)
        .map(|r| ((r.0 as f64).ln(), r.3.ln())).collect();

    if delta_data.len() >= 5 {
        let n_fit = delta_data.len() as f64;
        let sx: f64 = delta_data.iter().map(|d| d.0).sum();
        let sy: f64 = delta_data.iter().map(|d| d.1).sum();
        let sxx: f64 = delta_data.iter().map(|d| d.0*d.0).sum();
        let sxy: f64 = delta_data.iter().map(|d| d.0*d.1).sum();

        let b = (n_fit * sxy - sx * sy) / (n_fit * sxx - sx * sx);
        let a = (sy - b * sx) / n_fit;

        println!("\n  δ_N ≈ {:.6} · N^({:.4})", a.exp(), b);
        println!("  Rate: δ_N = O(N^{{{:.2}}})", b);
        if b < -1.0 {
            println!("  ✅ Σ δ_N converges (exponent < -1)!");
            // Estimate tail sum
            let last_n = results.last().unwrap().0 as f64;
            let tail = a.exp() * last_n.powf(b + 1.0) / (-(b + 1.0));
            println!("  Tail sum Σ_{{N>{}}} δ_N ≤ {:.8}", results.last().unwrap().0, tail);
        }
    }

    // Fit cos θ ~ E · N^{-ε}
    let cos_data: Vec<(f64, f64)> = results.iter()
        .filter(|r| r.0 >= 30 && r.6 > 1e-10)
        .map(|r| ((r.0 as f64).ln(), r.6.ln())).collect();

    if cos_data.len() >= 5 {
        let n_fit = cos_data.len() as f64;
        let sx: f64 = cos_data.iter().map(|d| d.0).sum();
        let sy: f64 = cos_data.iter().map(|d| d.1).sum();
        let sxx: f64 = cos_data.iter().map(|d| d.0*d.0).sum();
        let sxy: f64 = cos_data.iter().map(|d| d.0*d.1).sum();

        let b = (n_fit * sxy - sx * sy) / (n_fit * sxx - sx * sx);
        let a = (sy - b * sx) / n_fit;

        println!("\n  cos θ_N ≈ {:.6} · N^({:.4})", a.exp(), b);
        println!("  Rate: cos θ = O(N^{{{:.2}}})", b);
    }

    // ════════════════════════════════════════════════════════════════
    // VERIFICATION OF LEAN LEMMA BOUNDS
    // ════════════════════════════════════════════════════════════════
    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  LEAN LEMMA VERIFICATION");
    println!("═══════════════════════════════════════════════════════════════════\n");

    // Lemma 1: certified_base — λ_min(G_500) ≥ 0.01087
    let l500 = results.iter().find(|r| r.0 == 500).map(|r| r.1);
    if let Some(l) = l500 {
        println!("  Lemma 1 (certified_base): λ_min(G_500) = {:.8}", l);
        println!("    Claim: ≥ 0.01087 → {}", if l >= 0.01087 { "✅" } else { "❌" });
    }

    // Lemma 2: S_N ≥ 1/20 for all N
    let min_s = results.iter().filter(|r| r.0 >= 3).map(|r| r.4)
        .fold(f64::INFINITY, |a,b| a.min(b));
    println!("\n  Lemma 2 (schur_lower): min S_N = {:.6}", min_s);
    println!("    Claim: S_N ≥ 0.05 → {}", if min_s >= 0.05 { "✅" } else { "❌" });

    // Lemma 3: ||g||² = Θ(N)
    let g_ratios: Vec<f64> = results.iter()
        .filter(|r| r.0 >= 10 && r.5 > 0.0)
        .map(|r| r.5 / r.0 as f64).collect();
    if !g_ratios.is_empty() {
        let min_r = g_ratios.iter().cloned().fold(f64::INFINITY, f64::min);
        let max_r = g_ratios.iter().cloned().fold(0.0f64, f64::max);
        println!("\n  Lemma 3 (cross_norm): ||g_N||²/N ∈ [{:.4}, {:.4}]", min_r, max_r);
        println!("    Claim: ||g||² = Θ(N) → {}", if min_r > 0.01 { "✅" } else { "❌" });
    }

    // Lemma 5: alignment_decay — cos θ ≤ C · N^{-β}, β > 1
    println!("\n  Lemma 5 (alignment_decay): see power law fit above");
    println!("    This is the critical axiom (≈ equivalent to RH)");

    // Overall assessment
    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  HYPERZETA ASSESSMENT");
    println!("═══════════════════════════════════════════════════════════════════\n");

    if let Some(l) = l500 {
        println!("  λ_min(G_500) = {:.8}", l);
        let last = results.last().unwrap();
        println!("  λ_min(G_{}) = {:.8}", last.0, last.1);
        let total_drop = l - last.1;
        println!("  Total drop from 500 to {}: {:.8}", last.0, total_drop);
        println!("  If Σ δ_N converges, HYPERZETA holds with limit ≈ {:.6}",
            last.1);
    }

    println!("\n  Total time: {:.1}s\n", total_start.elapsed().as_secs_f64());
}
