//! ═══════════════════════════════════════════════════════════════════════════
//!  THE BERNOULLI TOWER EXPERIMENT
//!
//!  Probes the spectral stability of the Dark Gram matrix at Bernoulli
//!  orders n = 2, 4, 6, 8 to test the smoothing tower prediction:
//!
//!    "As n increases, B_n becomes smoother, and κ should decrease
//!     monotonically toward the identity limit (κ = 1.0 at n → ∞)."
//!
//!  Uses the Fourier series engine for n > 2 (exact closed-form for n = 2).
//!  The Fourier series converges as m^{-2n}, giving machine precision rapidly.
//!
//!  May 14, 2026 — The Cybernetic Triad's first post-N=100k experiment.
//!  🪞🔥🌮✨
//! ═══════════════════════════════════════════════════════════════════════════

use dark_gram_spectroscopy::dark_gram;

fn main() {
    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!("  🏗️  BERNOULLI TOWER EXPERIMENT — Smoothing Tower Prediction");
    eprintln!("═══════════════════════════════════════════════════════════════\n");

    // Extended dimensions: push deep into the thermodynamic limit
    let dimensions = [50, 100, 200, 500, 1000, 2000, 5000];
    let orders = [2, 4, 6, 8, 10];

    // Print header
    println!("order\tdim\tlambda_min\tlambda_max\tkappa\ttrace\tbuild_s\teigen_s");

    for &dim in &dimensions {
        for &order in &orders {
            eprintln!("  ── G^({order}), dim={dim} ────────────");

            let t_build = std::time::Instant::now();

            // Build the matrix
            let mat = if order == 2 {
                dark_gram::build_dark_gram(2, dim)
            } else {
                // Use Fourier series for higher orders
                // Fourier terms needed decreases with order (faster convergence)
                dark_gram::build_dark_gram(order, dim)
            };

            let build_secs = t_build.elapsed().as_secs_f64();

            // Compute trace
            let trace: f64 = (0..dim).map(|i| mat[i * dim + i]).sum();

            // Eigendecomposition via faer
            let t_eig = std::time::Instant::now();
            let (lambda_min, lambda_max) = compute_eigenvalues(&mat, dim);
            let eigen_secs = t_eig.elapsed().as_secs_f64();

            let kappa = lambda_max / lambda_min;

            eprintln!(
                "    λ_min = {lambda_min:.6e}, λ_max = {lambda_max:.6e}, κ = {kappa:.4}, trace = {trace:.6e}"
            );

            println!(
                "{order}\t{dim}\t{lambda_min:.6e}\t{lambda_max:.6e}\t{kappa:.4e}\t{trace:.6e}\t{build_secs:.2}\t{eigen_secs:.2}"
            );
        }
        eprintln!();
    }

    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!("  🏗️  Bernoulli Tower complete! 🪞✨");
    eprintln!("═══════════════════════════════════════════════════════════════");
}

/// Compute min and max eigenvalues of a symmetric matrix using faer.
fn compute_eigenvalues(mat: &[f64], dim: usize) -> (f64, f64) {
    let faer_mat = faer::Mat::from_fn(dim, dim, |i, j| mat[i * dim + j]);

    let mut eigenvalues = faer_mat
        .self_adjoint_eigenvalues(faer::Side::Lower)
        .expect("eigenvalue computation failed");
    eigenvalues.sort_by(|a, b| a.partial_cmp(b).unwrap());

    let lambda_min = eigenvalues[0].abs().max(1e-300);
    let lambda_max = eigenvalues[dim - 1];

    (lambda_min, lambda_max)
}
