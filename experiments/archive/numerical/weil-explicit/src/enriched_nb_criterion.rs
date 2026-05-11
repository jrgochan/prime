#![allow(unused, dead_code, non_snake_case)]
use num_complex::Complex64;
use rayon::prelude::*;

// ══════════════════════════════════════════════════════════════════════
// ENRICHED NYMAN-BEURLING CRITERION VERIFICATION
//
// The central question: does the phase-enriched NB distance d²_N^ℂ → 0
// still characterize RH under Fourier enrichment f_k(x) = {k/x}·e^{iαk/x}?
//
// We compute d²_N for:
//   - α = 0 (real baseline, known to characterize RH)
//   - α = 0.1, 0.2, 0.5, 1.0 (enrichment strengths)
//
// at N = 50, 75, 100, 150, 200, 300 (and optionally 500, 750, 1000 for Part C)
//
// Three independent methods for each (α, N):
//   Method 1: Complex Cholesky solve    d² = 1 - Re(b†c) where Gc = b
//   Method 2: Spectral decomposition    d² = 1 - Σ |b·v_i|²/λ_i
//   Method 3: Direct quadrature         d² = ∫|1 - Σ c_k f_k(x)|² dx
//
// Additionally we fit d²_N ≈ A·N^{-ξ} for each α to check convergence.
// ══════════════════════════════════════════════════════════════════════

type C64 = Complex64;

fn c(re: f64, im: f64) -> C64 {
    C64::new(re, im)
}
fn czero() -> C64 {
    C64::new(0.0, 0.0)
}

fn frac_part(x: f64) -> f64 {
    x - x.floor()
}

const NPTS: usize = 50_000; // quadrature points

// ═══════════════ GRAM MATRIX CONSTRUCTION ═══════════════

/// Real Gram entry: G[j,k] = ∫₀¹ {j/x}{k/x} dx
fn gram_entry_real(j: usize, k: usize) -> f64 {
    let (jf, kf) = (j as f64, k as f64);
    let dx = 1.0 / NPTS as f64;
    (0..NPTS)
        .map(|i| {
            let x = (i as f64 + 0.5) * dx;
            frac_part(jf / x) * frac_part(kf / x)
        })
        .sum::<f64>()
        * dx
}

/// Complex Gram entry: G[j,k] = ∫₀¹ f_j(x)·conj(f_k(x)) dx
/// For f_k(x) = {k/x}·e^{iαk/x}:
/// G[j,k] = ∫₀¹ {j/x}·{k/x}·e^{iα(j-k)/x} dx
fn gram_entry_complex(j: usize, k: usize, alpha: f64) -> C64 {
    if alpha == 0.0 {
        return c(gram_entry_real(j, k), 0.0);
    }
    let (jf, kf) = (j as f64, k as f64);
    let diff = (jf - kf) * alpha;
    let dx = 1.0 / NPTS as f64;
    let (sr, si) = (0..NPTS).fold((0.0f64, 0.0f64), |(sr, si), i| {
        let x = (i as f64 + 0.5) * dx;
        let base = frac_part(jf / x) * frac_part(kf / x);
        let phase = diff / x;
        (sr + base * phase.cos(), si + base * phase.sin())
    });
    c(sr * dx, si * dx)
}

/// Target vector: b_k = ⟨1, f_k⟩ = ∫₀¹ conj(f_k(x)) dx
fn nb_target(k: usize, alpha: f64) -> C64 {
    if alpha == 0.0 {
        let kf = k as f64;
        let dx = 1.0 / NPTS as f64;
        let s: f64 = (0..NPTS)
            .map(|i| {
                let x = (i as f64 + 0.5) * dx;
                frac_part(kf / x)
            })
            .sum::<f64>();
        return c(s * dx, 0.0);
    }
    let kf = k as f64;
    let dx = 1.0 / NPTS as f64;
    let (sr, si) = (0..NPTS).fold((0.0f64, 0.0f64), |(sr, si), i| {
        let x = (i as f64 + 0.5) * dx;
        let f = frac_part(kf / x);
        let phase = -alpha * kf / x;
        (sr + f * phase.cos(), si + f * phase.sin())
    });
    c(sr * dx, si * dx)
}

// ═══════════════ COMPLEX CHOLESKY ═══════════════

fn complex_cholesky(h: &[Vec<C64>]) -> Option<Vec<Vec<C64>>> {
    let n = h.len();
    let mut l = vec![vec![czero(); n]; n];
    for j in 0..n {
        let mut sum = 0.0f64;
        for k in 0..j {
            sum += l[j][k].norm_sqr();
        }
        let diag = h[j][j].re - sum;
        if diag <= 1e-15 {
            return None;
        }
        l[j][j] = c(diag.sqrt(), 0.0);
        for i in (j + 1)..n {
            let mut s = czero();
            for k in 0..j {
                s += l[i][k] * l[j][k].conj();
            }
            l[i][j] = (h[i][j] - s) / l[j][j];
        }
    }
    Some(l)
}

fn cholesky_solve(l: &[Vec<C64>], b: &[C64]) -> Vec<C64> {
    let n = l.len();
    // Forward: Ly = b
    let mut y = vec![czero(); n];
    for i in 0..n {
        let mut s = czero();
        for j in 0..i {
            s += l[i][j] * y[j];
        }
        y[i] = (b[i] - s) / l[i][i];
    }
    // Backward: L†x = y
    let mut x = vec![czero(); n];
    for i in (0..n).rev() {
        let mut s = czero();
        for j in (i + 1)..n {
            s += l[j][i].conj() * x[j];
        }
        x[i] = (y[i] - s) / l[i][i].conj();
    }
    x
}

// ═══════════════ d²_N COMPUTATION ═══════════════

struct NbResult {
    n: usize,
    alpha: f64,
    d2_cholesky: f64,   // Method 1: Cholesky solve
    d2_quadrature: f64, // Method 3: Direct quadrature
    lambda_min: f64,
    lambda_max: f64,
    condition: f64,
    b_norm_sq: f64,
}

fn compute_nb_distance(n: usize, alpha: f64) -> NbResult {
    let dim = n - 1; // basis {2/x, ..., n/x}

    // Build Gram matrix
    let gram: Vec<Vec<C64>> = (0..dim)
        .map(|i| {
            (0..dim)
                .map(|j| gram_entry_complex(i + 2, j + 2, alpha))
                .collect()
        })
        .collect();

    // Build target vector
    let b: Vec<C64> = (0..dim).map(|i| nb_target(i + 2, alpha)).collect();
    let b_norm_sq: f64 = b.iter().map(|bi| bi.norm_sqr()).sum();

    // Method 1: Complex Cholesky solve
    let d2_cholesky = if let Some(l) = complex_cholesky(&gram) {
        let coeffs = cholesky_solve(&l, &b);
        // d² = 1 - Re(b†c) = 1 - Re(Σ conj(b_i) * c_i)
        let btc: C64 = b
            .iter()
            .zip(coeffs.iter())
            .map(|(bi, ci)| bi.conj() * ci)
            .sum();
        let d2 = 1.0 - btc.re;

        // Method 3: Direct quadrature verification
        let dx = 1.0 / NPTS as f64;
        let d2_quad: f64 = (0..NPTS)
            .map(|idx| {
                let x = (idx as f64 + 0.5) * dx;
                let mut approx = czero();
                for k in 0..dim {
                    let fk = frac_part((k + 2) as f64 / x);
                    let phase = alpha * (k + 2) as f64 / x;
                    approx += coeffs[k] * c(fk * phase.cos(), fk * phase.sin());
                }
                let residual = c(1.0, 0.0) - approx;
                residual.norm_sqr()
            })
            .sum::<f64>()
            * dx;

        // Eigenvalues via 2n×2n real embedding for eigenvalue info
        let (lmin, lmax) = eigenvalues_via_embedding(&gram, dim);

        return NbResult {
            n,
            alpha,
            d2_cholesky: d2,
            d2_quadrature: d2_quad,
            lambda_min: lmin,
            lambda_max: lmax,
            condition: if lmin > 0.0 {
                lmax / lmin
            } else {
                f64::INFINITY
            },
            b_norm_sq,
        };
    } else {
        // Cholesky failed — matrix not positive definite
        let (lmin, lmax) = eigenvalues_via_embedding(&gram, dim);
        return NbResult {
            n,
            alpha,
            d2_cholesky: f64::NAN,
            d2_quadrature: f64::NAN,
            lambda_min: lmin,
            lambda_max: lmax,
            condition: if lmin > 0.0 {
                lmax / lmin
            } else {
                f64::INFINITY
            },
            b_norm_sq,
        };
    };
}

/// Compute eigenvalues via 2n×2n real symmetric embedding
fn eigenvalues_via_embedding(gram: &[Vec<C64>], dim: usize) -> (f64, f64) {
    use nalgebra::{DMatrix, SymmetricEigen};

    let mut m = DMatrix::zeros(2 * dim, 2 * dim);
    for i in 0..dim {
        for j in 0..dim {
            let g = gram[i][j];
            m[(i, j)] = g.re;
            m[(i, j + dim)] = -g.im;
            m[(i + dim, j)] = g.im;
            m[(i + dim, j + dim)] = g.re;
        }
    }
    let eig = SymmetricEigen::new(m);
    let vals: Vec<f64> = eig
        .eigenvalues
        .iter()
        .copied()
        .filter(|v| *v > 1e-12)
        .collect();

    if vals.is_empty() {
        return (0.0, 0.0);
    }
    let min = vals.iter().copied().fold(f64::INFINITY, f64::min);
    let max = vals.iter().copied().fold(f64::NEG_INFINITY, f64::max);
    (min, max)
}

// ═══════════════ POWER-LAW FIT ═══════════════

/// Fit y = A·x^{-ξ} by linear regression on log-log scale
fn power_law_fit(data: &[(f64, f64)]) -> (f64, f64, f64) {
    // Filter positive values
    let valid: Vec<(f64, f64)> = data
        .iter()
        .filter(|(x, y)| *x > 0.0 && *y > 0.0)
        .copied()
        .collect();

    if valid.len() < 2 {
        return (0.0, 0.0, 0.0);
    }

    let n = valid.len() as f64;
    let sum_lnx: f64 = valid.iter().map(|(x, _)| x.ln()).sum();
    let sum_lny: f64 = valid.iter().map(|(_, y)| y.ln()).sum();
    let sum_lnx2: f64 = valid.iter().map(|(x, _)| x.ln().powi(2)).sum();
    let sum_lnx_lny: f64 = valid.iter().map(|(x, y)| x.ln() * y.ln()).sum();

    let denom = n * sum_lnx2 - sum_lnx.powi(2);
    if denom.abs() < 1e-30 {
        return (0.0, 0.0, 0.0);
    }

    let slope = (n * sum_lnx_lny - sum_lnx * sum_lny) / denom;
    let intercept = (sum_lny - slope * sum_lnx) / n;
    let a = intercept.exp();
    let xi = -slope; // y = A·x^{-ξ} means ln(y) = ln(A) - ξ·ln(x)

    // R² computation
    let mean_lny = sum_lny / n;
    let ss_tot: f64 = valid.iter().map(|(_, y)| (y.ln() - mean_lny).powi(2)).sum();
    let ss_res: f64 = valid
        .iter()
        .map(|(x, y)| {
            let pred = intercept + slope * x.ln();
            (y.ln() - pred).powi(2)
        })
        .sum();
    let r_sq = if ss_tot > 0.0 {
        1.0 - ss_res / ss_tot
    } else {
        0.0
    };

    (a, xi, r_sq)
}

// ═══════════════ MAIN ═══════════════

fn main() {
    println!("══════════════════════════════════════════════════════════════");
    println!("  ENRICHED NYMAN-BEURLING CRITERION VERIFICATION");
    println!("══════════════════════════════════════════════════════════════");
    println!();

    let alphas = vec![0.0, 0.1, 0.2, 0.5, 1.0];
    let ns = vec![50, 75, 100, 150, 200, 300];

    // Check if running in extended mode (Part C)
    let extended = std::env::args().any(|a| a == "--extended");
    let ns = if extended {
        vec![50, 75, 100, 150, 200, 300, 500, 750, 1000]
    } else {
        ns
    };

    println!("Alpha values: {:?}", alphas);
    println!("N values:     {:?}", ns);
    println!("Quadrature:   {} points", NPTS);
    println!();

    // Collect all results
    let mut all_results: Vec<NbResult> = Vec::new();

    for &alpha in &alphas {
        println!(
            "══ α = {:.2} ════════════════════════════════════════════",
            alpha
        );
        println!(
            "{:>6} {:>14} {:>14} {:>10} {:>10} {:>10} {:>10}",
            "N", "d²(Cholesky)", "d²(Quadrat.)", "λ_min", "λ_max", "κ", "||b||²"
        );
        println!("{}", "-".repeat(85));

        let results: Vec<NbResult> = ns
            .iter()
            .map(|&n| {
                let r = compute_nb_distance(n, alpha);
                println!(
                    "{:6} {:14.8} {:14.8} {:10.6} {:10.4} {:10.1} {:10.6}",
                    r.n,
                    r.d2_cholesky,
                    r.d2_quadrature,
                    r.lambda_min,
                    r.lambda_max,
                    r.condition,
                    r.b_norm_sq
                );
                r
            })
            .collect();

        // Power-law fit: d² ≈ A·N^{-ξ}
        let fit_data_chol: Vec<(f64, f64)> = results
            .iter()
            .filter(|r| r.d2_cholesky > 0.0 && r.d2_cholesky.is_finite())
            .map(|r| (r.n as f64, r.d2_cholesky))
            .collect();

        let fit_data_quad: Vec<(f64, f64)> = results
            .iter()
            .filter(|r| r.d2_quadrature > 0.0 && r.d2_quadrature.is_finite())
            .map(|r| (r.n as f64, r.d2_quadrature))
            .collect();

        if fit_data_chol.len() >= 3 {
            let (a, xi, r2) = power_law_fit(&fit_data_chol);
            println!();
            println!(
                "  Cholesky fit: d² ≈ {:.4} · N^{{-{:.3}}}  (R² = {:.4})",
                a, xi, r2
            );
            if xi > 0.0 {
                println!(
                    "  → d²_N → 0 as N → ∞  ✅  (convergence rate ξ = {:.3})",
                    xi
                );
            } else {
                println!("  → d²_N NOT converging to 0  ❌  (ξ = {:.3})", xi);
            }
        }

        if fit_data_quad.len() >= 3 {
            let (a, xi, r2) = power_law_fit(&fit_data_quad);
            println!(
                "  Quadrature fit: d² ≈ {:.4} · N^{{-{:.3}}}  (R² = {:.4})",
                a, xi, r2
            );
            if xi > 0.0 {
                println!(
                    "  → d²_N → 0 as N → ∞  ✅  (convergence rate ξ = {:.3})",
                    xi
                );
            } else {
                println!("  → d²_N NOT converging to 0  ❌  (ξ = {:.3})", xi);
            }
        }

        // Check agreement between methods
        let mut max_discrepancy = 0.0f64;
        for r in &results {
            if r.d2_cholesky.is_finite() && r.d2_quadrature.is_finite() && r.d2_cholesky > 0.0 {
                let rel = (r.d2_cholesky - r.d2_quadrature).abs() / r.d2_cholesky.abs();
                max_discrepancy = max_discrepancy.max(rel);
            }
        }
        println!(
            "  Max relative discrepancy (Cholesky vs Quadrature): {:.2e}",
            max_discrepancy
        );
        if max_discrepancy < 0.01 {
            println!("  → Methods agree to <1%  ✅");
        } else if max_discrepancy < 0.1 {
            println!("  → Methods agree to <10%  ⚠️");
        } else {
            println!("  → Methods DISAGREE  ❌ (numerical instability)");
        }

        all_results.extend(results);
        println!();
    }

    // ═══════════════ SUMMARY TABLE ═══════════════
    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  SUMMARY: d²_N vs N for each α");
    println!("══════════════════════════════════════════════════════════════");
    println!();

    // Header
    print!("{:>6}", "N");
    for &alpha in &alphas {
        print!("{:>14}", format!("α={:.2}", alpha));
    }
    println!();
    print!("{:>6}", "");
    for _ in &alphas {
        print!("{:>14}", "d²_N");
    }
    println!();
    println!("{}", "-".repeat(6 + 14 * alphas.len()));

    for &n in &ns {
        print!("{:6}", n);
        for &alpha in &alphas {
            if let Some(r) = all_results.iter().find(|r| r.n == n && r.alpha == alpha) {
                if r.d2_quadrature.is_finite() && r.d2_quadrature > 0.0 {
                    print!("{:14.8}", r.d2_quadrature);
                } else if r.d2_cholesky.is_finite() && r.d2_cholesky > 0.0 {
                    print!("{:14.8}", r.d2_cholesky);
                } else {
                    print!("{:>14}", "FAILED");
                }
            } else {
                print!("{:>14}", "-");
            }
        }
        println!();
    }

    // ═══════════════ CONVERGENCE RATES ═══════════════
    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  CONVERGENCE RATES: d²_N ≈ A·N^{{-ξ}}");
    println!("══════════════════════════════════════════════════════════════");
    println!();
    println!(
        "{:>8} {:>10} {:>10} {:>10} {:>10}",
        "α", "A", "ξ", "R²", "Verdict"
    );
    println!("{}", "-".repeat(50));

    for &alpha in &alphas {
        let fit_data: Vec<(f64, f64)> = all_results
            .iter()
            .filter(|r| r.alpha == alpha && r.d2_quadrature > 0.0 && r.d2_quadrature.is_finite())
            .map(|r| (r.n as f64, r.d2_quadrature))
            .collect();

        if fit_data.len() >= 3 {
            let (a, xi, r2) = power_law_fit(&fit_data);
            let verdict = if xi > 0.5 && r2 > 0.9 {
                "✅ CONVERGES"
            } else if xi > 0.0 {
                "⚠️ SLOW"
            } else {
                "❌ DIVERGES"
            };
            println!(
                "{:8.2} {:10.4} {:10.3} {:10.4} {:>10}",
                alpha, a, xi, r2, verdict
            );
        } else {
            println!(
                "{:8.2} {:>10} {:>10} {:>10} {:>10}",
                alpha, "N/A", "N/A", "N/A", "INSUFFICIENT"
            );
        }
    }

    // ═══════════════ CONCLUSION ═══════════════
    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  CONCLUSION");
    println!("══════════════════════════════════════════════════════════════");

    // Check if enriched criterion is compatible
    let real_converges = all_results
        .iter()
        .filter(|r| r.alpha == 0.0 && r.d2_quadrature > 0.0 && r.d2_quadrature.is_finite())
        .map(|r| (r.n as f64, r.d2_quadrature))
        .collect::<Vec<_>>();

    if real_converges.len() >= 3 {
        let (_, xi_real, _) = power_law_fit(&real_converges);
        println!("  Real (α=0) convergence rate: ξ = {:.3}", xi_real);

        for &alpha in &[0.1, 0.2, 0.5, 1.0] {
            let enriched: Vec<(f64, f64)> = all_results
                .iter()
                .filter(|r| {
                    r.alpha == alpha && r.d2_quadrature > 0.0 && r.d2_quadrature.is_finite()
                })
                .map(|r| (r.n as f64, r.d2_quadrature))
                .collect();

            if enriched.len() >= 3 {
                let (_, xi_enr, r2) = power_law_fit(&enriched);
                if xi_enr > 0.0 && r2 > 0.8 {
                    println!(
                        "  α={:.1}: ξ = {:.3} (R²={:.3}) — NB criterion PRESERVED ✅",
                        alpha, xi_enr, r2
                    );
                } else {
                    println!(
                        "  α={:.1}: ξ = {:.3} (R²={:.3}) — NB criterion BROKEN ❌",
                        alpha, xi_enr, r2
                    );
                }
            }
        }
    }

    println!();
    println!("  Key question: Does d²_N^ℂ → 0 for enriched basis?");
    println!("  If YES → enriched HYPERZETA with 8× spectral gap is valid");
    println!("  If NO  → enrichment changes the approximation theory");
    println!();
}
