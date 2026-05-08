//! Analysis panels: the seven interrogation dimensions.
//!
//! For N ≤ FULL_EIGEN_LIMIT: full eigendecomposition (O(N³))
//! For N > FULL_EIGEN_LIMIT: Lanczos partial spectrum + stride-based matrix ops
//!
//! At large N (>3000), all matrix operations use stride-based access directly
//! on the FullGram data to avoid allocating multi-GB submatrix copies.
//!
//! With --mpfr-eigen <bits>, the full eigendecomposition uses MPFR Jacobi
//! rotations instead of f64 nalgebra, eliminating spurious negative eigenvalues
//! at high condition numbers (κ > 10⁶).

use crate::build::{self, FullGram};
use cathedral_utils::jacobi;
use cathedral_utils::lanczos;
use cathedral_utils::mertens;
use rayon::prelude::*;

/// Threshold for switching from full eigendecomposition to Lanczos.
const FULL_EIGEN_LIMIT: usize = 3000;

/// Number of bottom eigenvalues to extract via Lanczos.
const LANCZOS_K: usize = 20;

/// Lanczos subspace dimension (larger = more accurate).
const LANCZOS_M: usize = 200;

/// Per-N results from all panels.
#[derive(Clone)]
pub struct NResult {
    pub n: usize,
    // Panel 1: Quadratic forms
    pub vt_gv: f64,
    pub bt_v: f64,
    pub vt_cv: f64,
    pub d2_n: f64,
    // Panel 2: Rayleigh quotient
    pub rayleigh_q: f64,
    pub vt_cv_times_ln: f64,
    // Panel 3: Eigenvalue spectrum
    pub lambda_min: f64,
    pub lambda_max: f64,
    pub condition_number: f64,
    pub eigenvalues: Vec<f64>,
    // Panel 4: Spectral projection
    pub top_modes: Vec<(usize, f64, f64)>, // (mode_idx, eigenvalue, energy_frac)
    pub pr_witness: f64, // participation ratio of v in eigenbasis
    pub eff_rank_90: usize, // modes needed for 90% energy
    // Panel 5: PNT sub-sums
    pub s1: f64,
    pub s2: f64,
    pub s3: f64,
    // Panel 6: Geometric alignment
    pub cos2_angle: f64, // cos²(angle between v and b in G-metric)
    // Panel 7: GCD structure
    pub coprime_frac: f64, // fraction of vᵀCv from gcd(j,k)=1 pairs
    // Route C: Spectral decoupling diagnostics
    pub rc_top_ratio: f64,    // c_max²/λ_max — top-mode spectral contribution
    pub rc_mean_ratio: f64,   // ⟨b²⟩/⟨G_diag⟩ — Perron-Frobenius prediction
    pub rc_tail_pct: f64,     // % of Σcₖ²/λₖ from non-top modes
    pub rc_spectral_sum: f64, // Σcₖ²/λₖ = bᵀG⁻¹b (should → 1)
    // Metadata
    pub used_lanczos: bool,
}

pub fn analyze_n(
    n: usize, gram_full: &FullGram, mu: &[i8],
    mpfr_eigen_prec: Option<u32>, mpfr_eigen_limit: Option<usize>,
) -> NResult {
    let b = build::mean_vector(n);
    let v = build::witness_vector(n, mu);

    // ── Panel 1: Quadratic form decomposition ────────────────────
    // Always use stride-based access (no submatrix copy needed)
    let vt_gv = gram_full.quad_form_strided(&v, n);
    let bt_v: f64 = b.iter().zip(v.iter()).map(|(bi, vi)| bi * vi).sum();
    let vt_cv = vt_gv - bt_v * bt_v;
    let d2_n = 1.0 - 2.0 * bt_v + vt_gv;
    let ln_n = (n as f64).ln();
    let vt_cv_times_ln = vt_cv * ln_n;
    let rayleigh_q = if vt_cv.abs() > 1e-30 { bt_v * bt_v / vt_cv } else { f64::INFINITY };

    eprintln!("    vᵀGv={vt_gv:.10}  bᵀv={bt_v:.10}  vᵀCv={vt_cv:.10}");
    eprintln!("    d²_N={d2_n:.10}  Q={rayleigh_q:.4}  vᵀCv·ln(N)={vt_cv_times_ln:.6}");

    // ── Panel 6: Geometric alignment (cheap, always compute) ─────
    let v_norm_sq: f64 = v.iter().map(|x| x * x).sum();
    let b_norm_sq: f64 = b.iter().map(|x| x * x).sum();
    let cos2_angle = (bt_v * bt_v) / (b_norm_sq * v_norm_sq);

    // ── Panel 5: PNT sub-sums (cheap, always compute) ────────────
    let s1 = mertens::pnt_s1(mu, n);
    let s2 = mertens::pnt_s2(mu, n);
    let s3 = mertens::pnt_s3(mu, n);

    // ── Route C: Analytic Perron-Frobenius ratio (cheap, always) ──
    let mean_b2 = b.iter().map(|x| x * x).sum::<f64>() / n as f64;
    let mean_gdiag = (0..n).map(|i| gram_full.entry(i + 1, i + 1)).sum::<f64>() / n as f64;
    let rc_mean_ratio = if mean_gdiag > 0.0 { mean_b2 / mean_gdiag } else { 0.0 };

    // ── Determine eigen limit ────────────────────────────────────
    let eigen_limit = mpfr_eigen_limit.unwrap_or(FULL_EIGEN_LIMIT);

    // ── Branch: full eigen vs Lanczos ────────────────────────────
    if n <= eigen_limit {
        // Small N: extract dense submatrix for full eigendecomposition
        let g = gram_full.submatrix(n);

        if let Some(prec) = mpfr_eigen_prec {
            // MPFR Jacobi eigendecomposition path
            eprintln!("    [MPFR mode: {prec}-bit Jacobi]");
            analyze_mpfr_eigen(n, &g, &b, &v, vt_gv, bt_v, vt_cv, d2_n,
                rayleigh_q, vt_cv_times_ln, v_norm_sq, cos2_angle,
                s1, s2, s3, rc_mean_ratio, prec)
        } else {
            // Default f64 nalgebra path
            analyze_full_eigen(n, &g, &b, &v, vt_gv, bt_v, vt_cv, d2_n,
                rayleigh_q, vt_cv_times_ln, v_norm_sq, cos2_angle,
                s1, s2, s3, rc_mean_ratio)
        }
    } else {
        // Large N: use stride-based access + Lanczos
        analyze_lanczos(n, gram_full, &b, &v, vt_gv, bt_v, vt_cv, d2_n,
            rayleigh_q, vt_cv_times_ln, v_norm_sq, cos2_angle,
            s1, s2, s3, rc_mean_ratio)
    }
}

/// MPFR Jacobi eigendecomposition path — extended precision.
///
/// Uses MPFR cyclic Jacobi rotations to compute ALL eigenvalues and
/// eigenvectors at `prec`-bit precision, then projects back to f64
/// for the analysis panels. This eliminates spurious negative eigenvalues
/// that appear in f64 nalgebra at high condition numbers.
#[allow(clippy::too_many_arguments)]
fn analyze_mpfr_eigen(
    n: usize, g: &[f64], b: &[f64], v: &[f64],
    vt_gv: f64, bt_v: f64, vt_cv: f64, d2_n: f64,
    rayleigh_q: f64, vt_cv_times_ln: f64, v_norm_sq: f64,
    cos2_angle: f64, s1: f64, s2: f64, s3: f64,
    rc_mean_ratio: f64, prec: u32,
) -> NResult {
    let dim = n;
    let t0 = std::time::Instant::now();
    let result = jacobi::eigen_jacobi_mpfr(g, dim, prec);
    let eigen_time = t0.elapsed().as_secs_f64();

    let eigenvalues = result.eigenvalues;
    let eigenvectors = result.eigenvectors;

    let lambda_min = eigenvalues[0];
    let lambda_max = *eigenvalues.last().unwrap();
    let condition_number = if lambda_min.abs() > 1e-30 { lambda_max / lambda_min } else { f64::INFINITY };

    // Check for negative eigenvalues (the whole point of MPFR)
    let n_negative = eigenvalues.iter().filter(|&&x| x < 0.0).count();
    if n_negative > 0 {
        eprintln!("    ⚠ MPFR Jacobi: {n_negative} negative eigenvalues (smallest: {:.6e})", lambda_min);
    } else {
        eprintln!("    ✓ MPFR Jacobi: all eigenvalues positive (λ_min = {:.6e})", lambda_min);
    }
    eprintln!("    λ_min={lambda_min:.8e}  λ_max={lambda_max:.6}  κ={condition_number:.1}  ({eigen_time:.1}s, {} sweeps)",
        result.sweeps);

    // Spectral projection of witness (parallelized over eigenvectors)
    let projections: Vec<(usize, f64, f64)> = eigenvectors.par_iter()
        .enumerate()
        .map(|(idx, evec)| {
            let c_i: f64 = evec.iter().zip(v.iter()).map(|(e, vi)| e * vi).sum();
            let energy = c_i * c_i / v_norm_sq;
            (idx, eigenvalues[idx], energy)
        })
        .collect();
    let mut projections = projections;
    projections.sort_by(|a, b| b.2.partial_cmp(&a.2).unwrap());

    let top_modes: Vec<(usize, f64, f64)> = projections.iter().take(5).cloned().collect();
    let ipr: f64 = projections.iter().map(|(_, _, e)| e * e).sum();
    let pr_witness = if ipr > 0.0 { 1.0 / ipr } else { 0.0 };

    let mut cum = 0.0;
    let mut eff_rank_90 = 0;
    for (_, _, e) in &projections {
        cum += e;
        eff_rank_90 += 1;
        if cum >= 0.9 { break; }
    }

    eprintln!("    PR(v)={pr_witness:.1}  eff_rank_90={eff_rank_90}  top_mode_energy={:.1}%",
        top_modes[0].2 * 100.0);

    // GCD decomposition (feasible for small N)
    let coprime_frac = if n <= 3000 { gcd_decomposition(g, v, dim) } else { 0.0 };
    if n <= 3000 {
        eprintln!("    coprime_frac={coprime_frac:.4}");
    }

    // ── Route C: Target projections cₖ = ⟨b, uₖ⟩ (parallelized) ────
    let spectral_contributions: Vec<f64> = eigenvectors.par_iter()
        .enumerate()
        .map(|(idx, evec)| {
            let c_k: f64 = evec.iter().zip(b.iter()).map(|(e, bi)| e * bi).sum();
            let lam = eigenvalues[idx];
            if lam.abs() > 1e-30 { c_k * c_k / lam } else { 0.0 }
        })
        .collect();
    let rc_spectral_sum: f64 = spectral_contributions.iter().sum();
    // Top mode is last (eigenvalues sorted ascending)
    let rc_top_contrib = *spectral_contributions.last().unwrap_or(&0.0);
    let rc_top_ratio = if lambda_max > 0.0 {
        let c_max: f64 = eigenvectors.last().unwrap().iter()
            .zip(b.iter()).map(|(e, bi)| e * bi).sum();
        c_max * c_max / lambda_max
    } else { 0.0 };
    let rc_tail_pct = if rc_spectral_sum > 0.0 {
        (1.0 - rc_top_contrib / rc_spectral_sum) * 100.0
    } else { 0.0 };

    eprintln!("    [Route C] Σcₖ²/λₖ={rc_spectral_sum:.8}  top={rc_top_ratio:.8}  tail={rc_tail_pct:.2}%  ⟨b²⟩/⟨G⟩={rc_mean_ratio:.8}");

    NResult {
        n, vt_gv, bt_v, vt_cv, d2_n,
        rayleigh_q, vt_cv_times_ln,
        lambda_min, lambda_max, condition_number, eigenvalues,
        top_modes, pr_witness, eff_rank_90,
        s1, s2, s3, cos2_angle, coprime_frac,
        rc_top_ratio, rc_mean_ratio, rc_tail_pct, rc_spectral_sum,
        used_lanczos: false,
    }
}

/// Full eigendecomposition path (N ≤ 3000).
#[allow(clippy::too_many_arguments)]
fn analyze_full_eigen(
    n: usize, g: &[f64], b: &[f64], v: &[f64],
    vt_gv: f64, bt_v: f64, vt_cv: f64, d2_n: f64,
    rayleigh_q: f64, vt_cv_times_ln: f64, v_norm_sq: f64,
    cos2_angle: f64, s1: f64, s2: f64, s3: f64,
    rc_mean_ratio: f64,
) -> NResult {
    let dim = n;
    let (eigenvalues, eigenvectors) = full_eigen_all(g, dim);
    let lambda_min = eigenvalues[0];
    let lambda_max = *eigenvalues.last().unwrap();
    let condition_number = if lambda_min.abs() > 1e-30 { lambda_max / lambda_min } else { f64::INFINITY };

    eprintln!("    λ_min={lambda_min:.8e}  λ_max={lambda_max:.6}  κ={condition_number:.1}");

    // Spectral projection of witness (parallelized over eigenvectors)
    let projections: Vec<(usize, f64, f64)> = eigenvectors.par_iter()
        .enumerate()
        .map(|(idx, evec)| {
            let c_i: f64 = evec.iter().zip(v.iter()).map(|(e, vi)| e * vi).sum();
            let energy = c_i * c_i / v_norm_sq;
            (idx, eigenvalues[idx], energy)
        })
        .collect();
    let mut projections = projections;
    projections.sort_by(|a, b| b.2.partial_cmp(&a.2).unwrap());

    let top_modes: Vec<(usize, f64, f64)> = projections.iter().take(5).cloned().collect();
    let ipr: f64 = projections.iter().map(|(_, _, e)| e * e).sum();
    let pr_witness = if ipr > 0.0 { 1.0 / ipr } else { 0.0 };

    let mut cum = 0.0;
    let mut eff_rank_90 = 0;
    for (_, _, e) in &projections {
        cum += e;
        eff_rank_90 += 1;
        if cum >= 0.9 { break; }
    }

    eprintln!("    PR(v)={pr_witness:.1}  eff_rank_90={eff_rank_90}  top_mode_energy={:.1}%",
        top_modes[0].2 * 100.0);

    // GCD decomposition (feasible for small N)
    let coprime_frac = gcd_decomposition(g, v, dim);
    eprintln!("    coprime_frac={coprime_frac:.4}");

    // ── Route C: Target projections cₖ = ⟨b, uₖ⟩ (parallelized) ────
    let spectral_contributions: Vec<f64> = eigenvectors.par_iter()
        .enumerate()
        .map(|(idx, evec)| {
            let c_k: f64 = evec.iter().zip(b.iter()).map(|(e, bi)| e * bi).sum();
            let lam = eigenvalues[idx];
            if lam.abs() > 1e-30 { c_k * c_k / lam } else { 0.0 }
        })
        .collect();
    let rc_spectral_sum: f64 = spectral_contributions.iter().sum();
    // Top mode is last (eigenvalues sorted ascending)
    let rc_top_contrib = *spectral_contributions.last().unwrap_or(&0.0);
    let rc_top_ratio = if lambda_max > 0.0 {
        let c_max: f64 = eigenvectors.last().unwrap().iter()
            .zip(b.iter()).map(|(e, bi)| e * bi).sum();
        c_max * c_max / lambda_max
    } else { 0.0 };
    let rc_tail_pct = if rc_spectral_sum > 0.0 {
        (1.0 - rc_top_contrib / rc_spectral_sum) * 100.0
    } else { 0.0 };

    eprintln!("    [Route C] Σcₖ²/λₖ={rc_spectral_sum:.8}  top={rc_top_ratio:.8}  tail={rc_tail_pct:.2}%  ⟨b²⟩/⟨G⟩={rc_mean_ratio:.8}");

    NResult {
        n, vt_gv, bt_v, vt_cv, d2_n,
        rayleigh_q, vt_cv_times_ln,
        lambda_min, lambda_max, condition_number, eigenvalues,
        top_modes, pr_witness, eff_rank_90,
        s1, s2, s3, cos2_angle, coprime_frac,
        rc_top_ratio, rc_mean_ratio, rc_tail_pct, rc_spectral_sum,
        used_lanczos: false,
    }
}

/// Lanczos fast-path for large N (N > 3000).
/// Uses stride-based matrix access directly on FullGram — zero extra allocations.
#[allow(clippy::too_many_arguments)]
fn analyze_lanczos(
    n: usize, gram_full: &FullGram, b: &[f64], v: &[f64],
    vt_gv: f64, bt_v: f64, vt_cv: f64, d2_n: f64,
    rayleigh_q: f64, vt_cv_times_ln: f64, v_norm_sq: f64,
    cos2_angle: f64, s1: f64, s2: f64, s3: f64,
    rc_mean_ratio: f64,
) -> NResult {
    eprintln!("    [Lanczos mode: k={LANCZOS_K}, m={LANCZOS_M}]");

    let dim = n;

    // Matvec closure using stride-based access (no submatrix allocation)
    let matvec = |x: &[f64], out: &mut [f64]| {
        gram_full.matvec_strided(x, out, dim);
    };

    // Bottom-k eigenvalues via Lanczos
    let lanczos_result = lanczos::lanczos_bottom_k(&matvec, dim, LANCZOS_K, LANCZOS_M);
    let lambda_min = lanczos_result.eigenvalues[0];

    eprintln!("    Lanczos bottom-{LANCZOS_K} converged in {} iterations",
        lanczos_result.iterations);
    eprintln!("    Residual norms: min={:.2e} max={:.2e}",
        lanczos_result.residual_norms.iter().cloned().fold(f64::INFINITY, f64::min),
        lanczos_result.residual_norms.iter().cloned().fold(0.0, f64::max));

    // λ_max and top eigenvector via power iteration
    let (lambda_max, top_evec) = power_iteration_with_vec(gram_full, dim, 100);

    let condition_number = if lambda_min.abs() > 1e-30 { lambda_max / lambda_min } else { f64::INFINITY };

    eprintln!("    λ_min={lambda_min:.8e}  λ_max={lambda_max:.6}  κ={condition_number:.1}");

    // Spectral projection: project v onto the Lanczos eigenvectors (partial)
    let mut top_modes: Vec<(usize, f64, f64)> = Vec::new();
    let mut captured_energy = 0.0f64;
    for (idx, evec) in lanczos_result.eigenvectors.iter().enumerate() {
        let c_i: f64 = evec.iter().zip(v.iter()).map(|(e, vi)| e * vi).sum();
        let energy = c_i * c_i / v_norm_sq;
        captured_energy += energy;
        top_modes.push((idx, lanczos_result.eigenvalues[idx], energy));
    }
    top_modes.sort_by(|a, b| b.2.partial_cmp(&a.2).unwrap());
    top_modes.truncate(5);

    // For Lanczos mode, PR and eff_rank are estimates
    let pr_witness = 0.0; // Not available without full spectrum
    let eff_rank_90 = 0;  // Not available without full spectrum
    let coprime_frac = 0.0; // Too expensive for large N

    eprintln!("    Bottom-{LANCZOS_K} energy capture: {:.2}%", captured_energy * 100.0);
    if !top_modes.is_empty() {
        eprintln!("    Top mode energy: {:.2}%", top_modes[0].2 * 100.0);
    }

    // ── Route C: Top-mode spectral ratio via power iteration vector ──
    let c_max: f64 = top_evec.iter().zip(b.iter()).map(|(e, bi)| e * bi).sum();
    let rc_top_ratio = if lambda_max > 0.0 { c_max * c_max / lambda_max } else { 0.0 };
    // Without full eigendecomposition, spectral sum and tail are unavailable
    let rc_spectral_sum = 0.0;
    let rc_tail_pct = 0.0;

    eprintln!("    [Route C] top c²/λ={rc_top_ratio:.8}  ⟨b²⟩/⟨G⟩={rc_mean_ratio:.8}");

    let eigenvalues = lanczos_result.eigenvalues;

    NResult {
        n, vt_gv, bt_v, vt_cv, d2_n,
        rayleigh_q, vt_cv_times_ln,
        lambda_min, lambda_max, condition_number, eigenvalues,
        top_modes, pr_witness, eff_rank_90,
        s1, s2, s3, cos2_angle, coprime_frac,
        rc_top_ratio, rc_mean_ratio, rc_tail_pct, rc_spectral_sum,
        used_lanczos: true,
    }
}

/// Full eigendecomposition returning ALL eigenvalues and eigenvectors.
fn full_eigen_all(mat: &[f64], dim: usize) -> (Vec<f64>, Vec<Vec<f64>>) {
    let m = nalgebra::DMatrix::from_row_slice(dim, dim, mat);
    let eigen = m.symmetric_eigen();

    let mut indexed: Vec<(f64, usize)> = eigen.eigenvalues.iter()
        .enumerate()
        .map(|(i, &v)| (v, i))
        .collect();
    indexed.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());

    let eigenvalues: Vec<f64> = indexed.iter().map(|(v, _)| *v).collect();
    let eigenvectors: Vec<Vec<f64>> = indexed.iter()
        .map(|(_, idx)| {
            eigen.eigenvectors.column(*idx).iter().copied().collect()
        })
        .collect();

    (eigenvalues, eigenvectors)
}


/// Power iteration returning both eigenvalue and eigenvector.
fn power_iteration_with_vec(gram: &FullGram, dim: usize, max_iter: usize) -> (f64, Vec<f64>) {
    let mut x = vec![1.0 / (dim as f64).sqrt(); dim];
    let mut y = vec![0.0f64; dim];

    for _ in 0..max_iter {
        gram.matvec_strided(&x, &mut y, dim);
        let norm = y.iter().map(|v| v * v).sum::<f64>().sqrt();
        if norm < 1e-30 { break; }
        for i in 0..dim {
            x[i] = y[i] / norm;
        }
    }

    // Final Rayleigh quotient: xᵀAx / xᵀx
    gram.matvec_strided(&x, &mut y, dim);
    let xtax: f64 = x.iter().zip(y.iter()).map(|(a, b)| a * b).sum();
    let xtx: f64 = x.iter().map(|v| v * v).sum();
    (xtax / xtx, x)
}

/// Decompose vᵀGv into contributions from coprime vs non-coprime pairs.
/// Parallelized over rows — each row computes its contribution independently.
fn gcd_decomposition(g: &[f64], v: &[f64], dim: usize) -> f64 {
    let (coprime_sum, total_sum) = (0..dim).into_par_iter()
        .map(|i| {
            let mut cop = 0.0f64;
            let mut tot = 0.0f64;
            for j in 0..dim {
                let contrib = v[i] * g[i * dim + j] * v[j];
                tot += contrib;
                if cathedral_utils::arith::gcd(i + 1, j + 1) == 1 {
                    cop += contrib;
                }
            }
            (cop, tot)
        })
        .reduce(|| (0.0, 0.0), |(c1, t1), (c2, t2)| (c1 + c2, t1 + t2));

    if total_sum.abs() > 1e-30 {
        coprime_sum / total_sum
    } else {
        0.0
    }
}
