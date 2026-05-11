#![allow(unused, dead_code, non_snake_case)]
use rayon::prelude::*;
use std::f64::consts::PI;

// ══════════════════════════════════════════════════════════════════════
// PHASE BOUNDARY SCAN
//
// Fine-grained scan of the Fourier phase parameter α to find:
// 1. The exact boundary where d²_N transitions from 0 to >0
// 2. The condition number of the Gram matrix at each α
// 3. Whether d²_N = 0 is genuine or numerical artifact
// 4. The relationship between α, β (repulsion), and d²_N
// ══════════════════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 {
    x - x.floor()
}

fn big_omega(n: usize) -> usize {
    if n <= 1 {
        return 0;
    }
    let mut count = 0;
    let mut m = n;
    let mut p = 2;
    while p * p <= m {
        while m % p == 0 {
            count += 1;
            m /= p;
        }
        p += 1;
    }
    if m > 1 {
        count += 1;
    }
    count
}

fn liouville(n: usize) -> f64 {
    if big_omega(n) % 2 == 0 {
        1.0
    } else {
        -1.0
    }
}

fn gram_entry_real(j: usize, k: usize, n_pts: usize) -> f64 {
    let (jf, kf) = (j as f64, k as f64);
    let dx = 1.0 / n_pts as f64;
    let mut s = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        s += frac_part(jf / x) * frac_part(kf / x);
    }
    s * dx
}

fn gram_entry_fourier(j: usize, k: usize, alpha: f64, n_pts: usize) -> (f64, f64) {
    let (jf, kf) = (j as f64, k as f64);
    let diff = (j as f64 - k as f64) * alpha;
    let dx = 1.0 / n_pts as f64;
    let (mut sr, mut si) = (0.0f64, 0.0f64);
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        let base = frac_part(jf / x) * frac_part(kf / x);
        let phase = diff / x;
        sr += base * phase.cos();
        si += base * phase.sin();
    }
    (sr * dx, si * dx)
}

fn nb_target_real(k: usize, n_pts: usize) -> f64 {
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let mut s = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        s += frac_part(kf / x);
    }
    s * dx
}

fn nb_target_complex(k: usize, alpha: f64, n_pts: usize) -> (f64, f64) {
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let (mut sr, mut si) = (0.0f64, 0.0f64);
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        let f = frac_part(kf / x);
        let phase = -alpha * kf / x;
        sr += f * phase.cos();
        si += f * phase.sin();
    }
    (sr * dx, si * dx)
}

// ── Linear algebra ───────────────────────────────────────────────────

fn lu_decompose(a: &mut Vec<Vec<f64>>) -> Vec<usize> {
    let n = a.len();
    let mut piv: Vec<usize> = (0..n).collect();
    for col in 0..n {
        let mut mr = col;
        for row in (col + 1)..n {
            if a[row][col].abs() > a[mr][col].abs() {
                mr = row;
            }
        }
        if mr != col {
            a.swap(col, mr);
            piv.swap(col, mr);
        }
        if a[col][col].abs() < 1e-15 {
            continue;
        }
        for row in (col + 1)..n {
            a[row][col] /= a[col][col];
            let f = a[row][col];
            for j in (col + 1)..n {
                a[row][j] -= f * a[col][j];
            }
        }
    }
    piv
}

fn lu_solve(lu: &[Vec<f64>], piv: &[usize], b: &[f64]) -> Vec<f64> {
    let n = b.len();
    let mut x: Vec<f64> = piv.iter().map(|&i| b[i]).collect();
    for i in 1..n {
        for j in 0..i {
            let f = lu[i][j];
            x[i] -= f * x[j];
        }
    }
    for i in (0..n).rev() {
        for j in (i + 1)..n {
            x[i] -= lu[i][j] * x[j];
        }
        x[i] /= lu[i][i];
    }
    x
}

fn min_eigenpair(mat: &[Vec<f64>], n_iter: usize) -> (f64, Vec<f64>) {
    let n = mat.len();
    let mut lu = mat.to_vec();
    let piv = lu_decompose(&mut lu);
    let mut v = vec![1.0 / (n as f64).sqrt(); n];
    for i in 0..n {
        v[i] += 0.001 * ((i * 7 + 3) % 11) as f64 / 11.0;
    }
    let n0: f64 = v.iter().map(|x| x * x).sum::<f64>().sqrt();
    for x in v.iter_mut() {
        *x /= n0;
    }
    for _ in 0..n_iter {
        let w = lu_solve(&lu, &piv, &v);
        let nm: f64 = w.iter().map(|x| x * x).sum::<f64>().sqrt();
        if nm < 1e-15 {
            break;
        }
        v = w.iter().map(|x| x / nm).collect();
    }
    let mut w = vec![0.0; n];
    for i in 0..n {
        for j in 0..n {
            w[i] += mat[i][j] * v[j];
        }
    }
    let lam: f64 = v.iter().zip(w.iter()).map(|(a, b)| a * b).sum();
    let sign = if v[0] >= 0.0 { 1.0 } else { -1.0 };
    (lam, v.iter().map(|x| x * sign).collect())
}

/// Compute max eigenvalue via power iteration
fn max_eigenvalue(mat: &[Vec<f64>], n_iter: usize) -> f64 {
    let n = mat.len();
    let mut v = vec![1.0 / (n as f64).sqrt(); n];
    for _ in 0..n_iter {
        let mut w = vec![0.0; n];
        for i in 0..n {
            for j in 0..n {
                w[i] += mat[i][j] * v[j];
            }
        }
        let nm: f64 = w.iter().map(|x| x * x).sum::<f64>().sqrt();
        if nm < 1e-15 {
            break;
        }
        v = w.iter().map(|x| x / nm).collect();
    }
    let mut w = vec![0.0; n];
    for i in 0..n {
        for j in 0..n {
            w[i] += mat[i][j] * v[j];
        }
    }
    v.iter().zip(w.iter()).map(|(a, b)| a * b).sum()
}

fn embed_hermitian(re: &[Vec<f64>], im: &[Vec<f64>]) -> Vec<Vec<f64>> {
    let n = re.len();
    let m = 2 * n;
    let mut r = vec![vec![0.0; m]; m];
    for i in 0..n {
        for j in 0..n {
            r[i][j] = re[i][j];
            r[i][n + j] = -im[i][j];
            r[n + i][j] = im[i][j];
            r[n + i][n + j] = re[i][j];
        }
    }
    r
}

fn nb_distance_real(gram: &[Vec<f64>], b: &[f64]) -> f64 {
    let mut lu = gram.to_vec();
    let piv = lu_decompose(&mut lu);
    let c = lu_solve(&lu, &piv, b);
    let btc: f64 = b.iter().zip(c.iter()).map(|(a, b)| a * b).sum();
    (1.0 - btc).max(0.0)
}

fn nb_distance_complex(gre: &[Vec<f64>], gim: &[Vec<f64>], bre: &[f64], bim: &[f64]) -> f64 {
    let n = gre.len();
    let m = 2 * n;
    let mut emb = vec![vec![0.0; m]; m];
    for i in 0..n {
        for j in 0..n {
            emb[i][j] = gre[i][j];
            emb[i][n + j] = -gim[i][j];
            emb[n + i][j] = gim[i][j];
            emb[n + i][n + j] = gre[i][j];
        }
    }
    let mut b_emb = vec![0.0; m];
    for i in 0..n {
        b_emb[i] = bre[i];
        b_emb[n + i] = bim[i];
    }
    let mut lu = emb;
    let piv = lu_decompose(&mut lu);
    let c = lu_solve(&lu, &piv, &b_emb);
    let btc: f64 = b_emb.iter().zip(c.iter()).map(|(a, b)| a * b).sum();
    (1.0 - btc).max(0.0)
}

/// Compute the actual residual ||1 - Σ c_k f_k||² directly by quadrature
fn nb_residual_direct(
    coeffs_re: &[f64],
    coeffs_im: &[f64],
    alpha: f64,
    dim: usize,
    n_pts: usize,
) -> f64 {
    let dx = 1.0 / n_pts as f64;
    let mut sum = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        // Evaluate Σ c_k · {k/x} · e^{iα·k/x}
        let mut approx_re = 0.0f64;
        let mut approx_im = 0.0f64;
        for j in 0..dim {
            let k = j + 2;
            let fv = frac_part(k as f64 / x);
            let phase = alpha * k as f64 / x;
            let (cp, sp) = (phase.cos(), phase.sin());
            // c_k · f_k = (c_re + i·c_im) · fv · (cos + i·sin)
            approx_re += fv * (coeffs_re[j] * cp - coeffs_im[j] * sp);
            approx_im += fv * (coeffs_re[j] * sp + coeffs_im[j] * cp);
        }
        // |1 - approx|² = (1 - Re)² + Im²
        sum += (1.0 - approx_re).powi(2) + approx_im.powi(2);
    }
    sum * dx
}

// ══════════════════════════════════════════════════════════════════════

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  PHASE BOUNDARY SCAN: Finding the d²_N = 0 transition          ║");
    println!("║  Fine α scan with diagnostics at N = 100                       ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let total_start = std::time::Instant::now();
    let n_pts = 150_000;
    let max_n: usize = 100;
    let dim = max_n - 1;

    // ── Precompute real Gram matrix (baseline) ───────────────────────
    print!("  Precomputing {}×{} real Gram matrix... ", dim, dim);
    let start = std::time::Instant::now();
    let gram_upper: Vec<Vec<f64>> = (0..dim)
        .into_par_iter()
        .map(|j| {
            let mut row = vec![0.0; dim];
            for k in j..dim {
                row[k] = gram_entry_real(j + 2, k + 2, n_pts);
            }
            row
        })
        .collect();
    let mut gram_real = vec![vec![0.0; dim]; dim];
    for j in 0..dim {
        for k in j..dim {
            gram_real[j][k] = gram_upper[j][k];
            gram_real[k][j] = gram_upper[j][k];
        }
    }
    println!("{:.1}s", start.elapsed().as_secs_f64());

    let b_real: Vec<f64> = (0..dim).map(|j| nb_target_real(j + 2, n_pts)).collect();
    let d2_real = nb_distance_real(&gram_real, &b_real);
    let (lmin_real, _) = min_eigenpair(&gram_real, 500);
    let lmax_real = max_eigenvalue(&gram_real, 500);

    println!(
        "  Real baseline: d²_N = {:.10}, λ_min = {:.8}, λ_max = {:.4}, κ = {:.1}\n",
        d2_real,
        lmin_real,
        lmax_real,
        lmax_real / lmin_real
    );

    // ════════════════════════════════════════════════════════════════
    // PHASE 1: COARSE SCAN α = 0 to 2.0 in steps of 0.02
    // ════════════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════════");
    println!(
        "  PHASE 1: Coarse scan α = 0.00 to 2.00, step = 0.02 (N={})",
        max_n
    );
    println!("═══════════════════════════════════════════════════════════════════\n");

    println!(
        "  {:>6} {:>12} {:>12} {:>12} {:>12} {:>12} {:>20}",
        "α", "d²_N", "λ_min", "λ_max", "κ = λ_max/λ_min", "||b||²", "Status"
    );
    println!("  {}", "─".repeat(95));

    let coarse_alphas: Vec<f64> = (0..=100).map(|i| i as f64 * 0.02).collect();
    let mut transition_alpha = 0.0f64;
    let mut found_transition = false;

    let mut scan_results: Vec<(f64, f64, f64, f64, f64)> = Vec::new();

    for &alpha in &coarse_alphas {
        // Compute complex Gram matrix
        let entries: Vec<((usize, usize), (f64, f64))> = (0..dim)
            .into_par_iter()
            .flat_map(|j| {
                (j..dim).into_par_iter().map(move |k| {
                    let (re, im) = gram_entry_fourier(j + 2, k + 2, alpha, n_pts);
                    ((j, k), (re, im))
                })
            })
            .collect();

        let mut gre = vec![vec![0.0; dim]; dim];
        let mut gim = vec![vec![0.0; dim]; dim];
        for ((j, k), (re, im)) in &entries {
            gre[*j][*k] = *re;
            gre[*k][*j] = *re;
            gim[*j][*k] = *im;
            gim[*k][*j] = -*im;
        }

        // Target vector
        let b_c: Vec<(f64, f64)> = (0..dim)
            .map(|j| nb_target_complex(j + 2, alpha, n_pts))
            .collect();
        let bre: Vec<f64> = b_c.iter().map(|x| x.0).collect();
        let bim: Vec<f64> = b_c.iter().map(|x| x.1).collect();

        // b norm
        let b_norm_sq: f64 = bre.iter().zip(bim.iter()).map(|(r, i)| r * r + i * i).sum();

        // NB distance
        let d2 = nb_distance_complex(&gre, &gim, &bre, &bim);

        // Eigenvalues via embedding
        let emb = embed_hermitian(&gre, &gim);
        let (lmin, _) = min_eigenpair(&emb, 300);
        let lmax = max_eigenvalue(&emb, 300);
        let kappa = if lmin.abs() > 1e-15 {
            lmax / lmin
        } else {
            f64::INFINITY
        };

        scan_results.push((alpha, d2, lmin, lmax, b_norm_sq));

        let status = if d2 < 1e-10 {
            "✅ d²=0 (exact)"
        } else if d2 < 0.01 {
            "⚡ d²≈0 (near-exact)"
        } else {
            if !found_transition && alpha > 0.01 {
                transition_alpha = alpha;
                found_transition = true;
            }
            "❌ d²>0"
        };

        // Print every 5th point plus transition region
        if (alpha * 50.0).round() % 5.0 < 0.1
            || (d2 > 1e-10 && !found_transition)
            || (found_transition && (alpha - transition_alpha).abs() < 0.1)
        {
            println!(
                "  {:6.3} {:12.8} {:12.8} {:12.4} {:12.1} {:12.6} {:>20}",
                alpha, d2, lmin, lmax, kappa, b_norm_sq, status
            );
        }
    }

    // Find the transition point more precisely
    let transition_candidates: Vec<&(f64, f64, f64, f64, f64)> = scan_results
        .iter()
        .filter(|(_, d2, _, _, _)| *d2 > 1e-10)
        .collect();
    let first_nonzero = transition_candidates.first();

    let zero_side: Vec<&(f64, f64, f64, f64, f64)> = scan_results
        .iter()
        .filter(|(_, d2, _, _, _)| *d2 < 1e-10)
        .collect();
    let last_zero = zero_side.last();

    println!("\n  ═══ TRANSITION POINT ═══");
    if let (Some(lz), Some(fn_)) = (last_zero, first_nonzero) {
        println!("  Last α with d²=0:  α = {:.4} (d² = {:.2e})", lz.0, lz.1);
        println!("  First α with d²>0: α = {:.4} (d² = {:.2e})", fn_.0, fn_.1);
        println!("  Transition at α ∈ [{:.4}, {:.4}]", lz.0, fn_.0);

        // ════════════════════════════════════════════════════════════════
        // PHASE 2: FINE SCAN around the transition
        // ════════════════════════════════════════════════════════════════
        let lo = (lz.0 - 0.01).max(0.0);
        let hi = fn_.0 + 0.01;

        println!("\n═══════════════════════════════════════════════════════════════════");
        println!(
            "  PHASE 2: Fine scan α = {:.4} to {:.4}, step = 0.001",
            lo, hi
        );
        println!("═══════════════════════════════════════════════════════════════════\n");

        println!(
            "  {:>8} {:>14} {:>12} {:>12} {:>12}",
            "α", "d²_N", "λ_min", "κ", "||b||²"
        );
        println!("  {}", "─".repeat(65));

        let n_fine = ((hi - lo) / 0.001) as usize + 1;
        for i in 0..=n_fine {
            let alpha = lo + i as f64 * 0.001;
            if alpha > hi {
                break;
            }

            let entries: Vec<((usize, usize), (f64, f64))> = (0..dim)
                .into_par_iter()
                .flat_map(|j| {
                    (j..dim).into_par_iter().map(move |k| {
                        let (re, im) = gram_entry_fourier(j + 2, k + 2, alpha, n_pts);
                        ((j, k), (re, im))
                    })
                })
                .collect();

            let mut gre = vec![vec![0.0; dim]; dim];
            let mut gim = vec![vec![0.0; dim]; dim];
            for ((j, k), (re, im)) in &entries {
                gre[*j][*k] = *re;
                gre[*k][*j] = *re;
                gim[*j][*k] = *im;
                gim[*k][*j] = -*im;
            }

            let b_c: Vec<(f64, f64)> = (0..dim)
                .map(|j| nb_target_complex(j + 2, alpha, n_pts))
                .collect();
            let bre: Vec<f64> = b_c.iter().map(|x| x.0).collect();
            let bim: Vec<f64> = b_c.iter().map(|x| x.1).collect();
            let b_norm_sq: f64 = bre.iter().zip(bim.iter()).map(|(r, i)| r * r + i * i).sum();

            let d2 = nb_distance_complex(&gre, &gim, &bre, &bim);

            let emb = embed_hermitian(&gre, &gim);
            let (lmin, _) = min_eigenpair(&emb, 300);
            let lmax = max_eigenvalue(&emb, 300);
            let kappa = if lmin.abs() > 1e-15 {
                lmax / lmin
            } else {
                f64::INFINITY
            };

            let marker = if d2 < 1e-10 { "✅" } else { "❌" };

            println!(
                "  {:8.4} {:14.10} {:12.8} {:12.1} {:12.6}  {}",
                alpha, d2, lmin, kappa, b_norm_sq, marker
            );
        }
    }

    // ════════════════════════════════════════════════════════════════
    // PHASE 3: VERIFICATION — Direct residual computation
    // ════════════════════════════════════════════════════════════════
    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  PHASE 3: DIRECT RESIDUAL VERIFICATION");
    println!("  Computing ||1 - Σ c_k f_k||² by direct quadrature");
    println!("═══════════════════════════════════════════════════════════════════\n");

    let verify_alphas = vec![0.0, 0.1, 0.2, 0.5, 1.0];

    for &alpha in &verify_alphas {
        let entries: Vec<((usize, usize), (f64, f64))> = (0..dim)
            .into_par_iter()
            .flat_map(|j| {
                (j..dim).into_par_iter().map(move |k| {
                    if alpha == 0.0 {
                        ((j, k), (gram_entry_real(j + 2, k + 2, n_pts), 0.0))
                    } else {
                        let (re, im) = gram_entry_fourier(j + 2, k + 2, alpha, n_pts);
                        ((j, k), (re, im))
                    }
                })
            })
            .collect();

        let mut gre = vec![vec![0.0; dim]; dim];
        let mut gim = vec![vec![0.0; dim]; dim];
        for ((j, k), (re, im)) in &entries {
            gre[*j][*k] = *re;
            gre[*k][*j] = *re;
            gim[*j][*k] = *im;
            gim[*k][*j] = -*im;
        }

        // Get optimal coefficients c = G⁻¹ b
        let b_c: Vec<(f64, f64)> = (0..dim)
            .map(|j| {
                if alpha == 0.0 {
                    (nb_target_real(j + 2, n_pts), 0.0)
                } else {
                    nb_target_complex(j + 2, alpha, n_pts)
                }
            })
            .collect();
        let bre: Vec<f64> = b_c.iter().map(|x| x.0).collect();
        let bim: Vec<f64> = b_c.iter().map(|x| x.1).collect();

        let m = 2 * dim;
        let mut emb = vec![vec![0.0; m]; m];
        for i in 0..dim {
            for j in 0..dim {
                emb[i][j] = gre[i][j];
                emb[i][dim + j] = -gim[i][j];
                emb[dim + i][j] = gim[i][j];
                emb[dim + i][dim + j] = gre[i][j];
            }
        }
        let mut b_emb = vec![0.0; m];
        for i in 0..dim {
            b_emb[i] = bre[i];
            b_emb[dim + i] = bim[i];
        }

        let mut lu = emb;
        let piv = lu_decompose(&mut lu);
        let c_emb = lu_solve(&lu, &piv, &b_emb);

        // Extract complex coefficients
        let c_re: Vec<f64> = c_emb[..dim].to_vec();
        let c_im: Vec<f64> = c_emb[dim..].to_vec();

        // Algebraic d²
        let d2_algebraic: f64 = 1.0
            - b_emb
                .iter()
                .zip(c_emb.iter())
                .map(|(a, b)| a * b)
                .sum::<f64>();

        // Direct residual by quadrature
        let d2_direct = nb_residual_direct(&c_re, &c_im, alpha, dim, n_pts);

        // Coefficient stats
        let c_norm: f64 = c_re
            .iter()
            .zip(c_im.iter())
            .map(|(r, i)| r * r + i * i)
            .sum::<f64>()
            .sqrt();
        let c_max: f64 = c_re
            .iter()
            .zip(c_im.iter())
            .map(|(r, i)| (r * r + i * i).sqrt())
            .fold(0.0f64, |a, b| a.max(b));

        println!("  α = {:.1}:", alpha);
        println!("    d²_N (algebraic):  {:14.10}", d2_algebraic);
        println!("    d²_N (quadrature): {:14.10}", d2_direct);
        println!("    ||c||:             {:14.6}", c_norm);
        println!("    max|c_k|:          {:14.6}", c_max);

        // Show first 10 coefficients
        print!("    c[2..11] = [");
        for j in 0..10.min(dim) {
            let mag = (c_re[j] * c_re[j] + c_im[j] * c_im[j]).sqrt();
            print!("{:.4}", mag);
            if j < 9 {
                print!(", ");
            }
        }
        println!("]");
        println!();
    }

    // ════════════════════════════════════════════════════════════════
    // PHASE 4: N-DEPENDENCE at the transition
    // ════════════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════════");
    println!("  PHASE 4: Does the transition point shift with N?");
    println!("═══════════════════════════════════════════════════════════════════\n");

    let n_sizes = vec![50, 75, 100, 150, 200];
    let probe_alphas = vec![0.0, 0.1, 0.2, 0.3, 0.5, 0.7, 1.0, 1.5, 2.0];

    println!("  {:>5} {:>60}", "N", "d²_N at each α");
    print!("  {:>5}", "");
    for &a in &probe_alphas {
        print!(" {:>8.1}", a);
    }
    println!();
    println!("  {}", "─".repeat(80));

    for &max_n in &n_sizes {
        let dim = max_n - 1;
        print!("  {:5}", max_n);

        for &alpha in &probe_alphas {
            let entries: Vec<((usize, usize), (f64, f64))> = (0..dim)
                .into_par_iter()
                .flat_map(|j| {
                    (j..dim).into_par_iter().map(move |k| {
                        if alpha == 0.0 {
                            ((j, k), (gram_entry_real(j + 2, k + 2, n_pts), 0.0))
                        } else {
                            let (re, im) = gram_entry_fourier(j + 2, k + 2, alpha, n_pts);
                            ((j, k), (re, im))
                        }
                    })
                })
                .collect();

            let mut gre = vec![vec![0.0; dim]; dim];
            let mut gim = vec![vec![0.0; dim]; dim];
            for ((j, k), (re, im)) in &entries {
                gre[*j][*k] = *re;
                gre[*k][*j] = *re;
                gim[*j][*k] = *im;
                gim[*k][*j] = -*im;
            }

            let b_c: Vec<(f64, f64)> = (0..dim)
                .map(|j| {
                    if alpha == 0.0 {
                        (nb_target_real(j + 2, n_pts), 0.0)
                    } else {
                        nb_target_complex(j + 2, alpha, n_pts)
                    }
                })
                .collect();
            let bre: Vec<f64> = b_c.iter().map(|x| x.0).collect();
            let bim: Vec<f64> = b_c.iter().map(|x| x.1).collect();

            let d2 = nb_distance_complex(&gre, &gim, &bre, &bim);

            if d2 < 1e-10 {
                print!("    {:>4}", "≡0");
            } else {
                print!(" {:8.4}", d2);
            }
        }
        println!();
    }

    println!("\n╔══════════════════════════════════════════════════════════════════╗");
    println!("║                    PHASE BOUNDARY VERDICT                       ║");
    println!("╠══════════════════════════════════════════════════════════════════╣");
    println!("║                                                                ║");
    println!("║  The transition α* where d²_N goes from 0 to >0 reveals:      ║");
    println!("║                                                                ║");
    println!("║  • If α* is independent of N → structural mathematical result  ║");
    println!("║  • If α* grows with N → finite-size effect                     ║");
    println!("║  • If d²(direct) ≠ d²(algebraic) → numerical artifact         ║");
    println!("║                                                                ║");
    println!("║  The direct quadrature verification in Phase 3 is the          ║");
    println!("║  definitive test: it computes ||1 - Σc_k f_k||² independently. ║");
    println!("║                                                                ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");

    println!(
        "\n  Total time: {:.1}s\n",
        total_start.elapsed().as_secs_f64()
    );
}
