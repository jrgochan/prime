#![allow(unused, dead_code, non_snake_case)]
use rayon::prelude::*;
use std::f64::consts::PI;

// ══════════════════════════════════════════════════════════════════════
// ENRICHED NYMAN-BEURLING VERIFICATION
//
// Three critical tests at scale (N up to 300):
//
// 1. GUE PERSISTENCE: Does ⟨r⟩ ≈ 0.5996 hold as N grows?
// 2. ENRICHED d_N: Does the NB distance still → 0 in the enriched space?
// 3. LIOUVILLE EIGENVECTOR: Does v_min still correlate with λ(k)?
//
// If all three pass, the enriched approach is a viable proof strategy.
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
        while m.is_multiple_of(p) {
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
    if big_omega(n).is_multiple_of(2) {
        1.0
    } else {
        -1.0
    }
}

// ══════════════════════════════════════════════════════════════════════
// GRAM MATRIX COMPUTATION
// ══════════════════════════════════════════════════════════════════════

fn gram_entry_real(j: usize, k: usize, n_pts: usize) -> f64 {
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

/// Fourier-enriched Gram entry: ∫₀¹ {j/x}·{k/x}·e^{iα(j-k)/x} dx
fn gram_entry_fourier(j: usize, k: usize, alpha: f64, n_pts: usize) -> (f64, f64) {
    let jf = j as f64;
    let kf = k as f64;
    let diff = (j as f64 - k as f64) * alpha;
    let dx = 1.0 / n_pts as f64;
    let mut sr = 0.0f64;
    let mut si = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        let base = frac_part(jf / x) * frac_part(kf / x);
        let phase = diff / x;
        sr += base * phase.cos();
        si += base * phase.sin();
    }
    (sr * dx, si * dx)
}

/// NB target vector: b_k = ∫₀¹ {k/x} dx (real case)
fn nb_target_real(k: usize, n_pts: usize) -> f64 {
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let mut sum = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        sum += frac_part(kf / x);
    }
    sum * dx
}

/// NB target vector: b^ℂ_k = ∫₀¹ {k/x}·e^{-iαk/x} dx (enriched case)
fn nb_target_complex(k: usize, alpha: f64, n_pts: usize) -> (f64, f64) {
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let mut sr = 0.0f64;
    let mut si = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        let f = frac_part(kf / x);
        let phase = -alpha * kf / x;
        sr += f * phase.cos();
        si += f * phase.sin();
    }
    (sr * dx, si * dx)
}

// ══════════════════════════════════════════════════════════════════════
// LINEAR ALGEBRA
// ══════════════════════════════════════════════════════════════════════

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

fn jacobi_eigenvalues(mat: &[Vec<f64>], max_sweeps: usize, tol: f64) -> Vec<f64> {
    let n = mat.len();
    let mut a: Vec<Vec<f64>> = mat.to_vec();
    for _sweep in 0..max_sweeps {
        let mut max_off = 0.0f64;
        for i in 0..n {
            for j in (i + 1)..n {
                max_off = max_off.max(a[i][j].abs());
            }
        }
        if max_off < tol {
            break;
        }
        for p in 0..n {
            for q in (p + 1)..n {
                if a[p][q].abs() < tol * 0.01 {
                    continue;
                }
                let (app, aqq, apq) = (a[p][p], a[q][q], a[p][q]);
                let theta = if (app - aqq).abs() < 1e-30 {
                    PI / 4.0
                } else {
                    0.5 * (2.0 * apq / (app - aqq)).atan()
                };
                let (c, s) = (theta.cos(), theta.sin());
                for i in 0..n {
                    if i != p && i != q {
                        let (aip, aiq) = (a[i][p], a[i][q]);
                        a[i][p] = c * aip + s * aiq;
                        a[p][i] = a[i][p];
                        a[i][q] = -s * aip + c * aiq;
                        a[q][i] = a[i][q];
                    }
                }
                a[p][p] = c * c * app + 2.0 * s * c * apq + s * s * aqq;
                a[q][q] = s * s * app - 2.0 * s * c * apq + c * c * aqq;
                a[p][q] = 0.0;
                a[q][p] = 0.0;
            }
        }
    }
    let mut ev: Vec<f64> = (0..n).map(|i| a[i][i]).collect();
    ev.sort_by(|a, b| a.partial_cmp(b).unwrap());
    ev
}

fn extract_distinct(eigenvalues: &[f64], tol: f64) -> Vec<f64> {
    let mut d = Vec::new();
    let mut i = 0;
    while i < eigenvalues.len() {
        d.push(eigenvalues[i]);
        if i + 1 < eigenvalues.len() && (eigenvalues[i + 1] - eigenvalues[i]).abs() < tol {
            i += 2;
        } else {
            i += 1;
        }
    }
    d
}

/// LU decomposition with partial pivoting
fn lu_decompose(a: &mut Vec<Vec<f64>>) -> Vec<usize> {
    let n = a.len();
    let mut piv: Vec<usize> = (0..n).collect();
    for col in 0..n {
        let mut max_row = col;
        for row in (col + 1)..n {
            if a[row][col].abs() > a[max_row][col].abs() {
                max_row = row;
            }
        }
        if max_row != col {
            a.swap(col, max_row);
            piv.swap(col, max_row);
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

/// Inverse iteration for minimum eigenvalue + eigenvector
fn min_eigenpair(mat: &[Vec<f64>], n_iter: usize) -> (f64, Vec<f64>) {
    let n = mat.len();
    let mut lu = mat.to_vec();
    let piv = lu_decompose(&mut lu);
    let mut v = vec![1.0 / (n as f64).sqrt(); n];
    for i in 0..n {
        v[i] += 0.001 * ((i * 7 + 3) % 11) as f64 / 11.0;
    }
    let norm0: f64 = v.iter().map(|x| x * x).sum::<f64>().sqrt();
    for x in v.iter_mut() {
        *x /= norm0;
    }

    for _ in 0..n_iter {
        let w = lu_solve(&lu, &piv, &v);
        let norm: f64 = w.iter().map(|x| x * x).sum::<f64>().sqrt();
        if norm < 1e-15 {
            break;
        }
        v = w.iter().map(|x| x / norm).collect();
    }
    let mut w = vec![0.0; n];
    for i in 0..n {
        for j in 0..n {
            w[i] += mat[i][j] * v[j];
        }
    }
    let lam: f64 = v.iter().zip(w.iter()).map(|(a, b)| a * b).sum();
    // Ensure consistent sign
    let sign = if v[0] >= 0.0 { 1.0 } else { -1.0 };
    let v_signed: Vec<f64> = v.iter().map(|x| x * sign).collect();
    (lam, v_signed)
}

/// Compute NB distance: d_N² = 1 - b^T G⁻¹ b (real case)
fn nb_distance_real(gram: &[Vec<f64>], b: &[f64]) -> f64 {
    let mut lu = gram.to_vec();
    let piv = lu_decompose(&mut lu);
    let c = lu_solve(&lu, &piv, b);
    let btc: f64 = b.iter().zip(c.iter()).map(|(a, b)| a * b).sum();
    (1.0 - btc).max(0.0)
}

/// Compute NB distance for complex case: d_N² = 1 - Re(b†·G⁻¹·b)
/// Using 2n×2n real embedding
fn nb_distance_complex(
    gram_re: &[Vec<f64>],
    gram_im: &[Vec<f64>],
    b_re: &[f64],
    b_im: &[f64],
) -> f64 {
    let n = gram_re.len();
    let m = 2 * n;

    // Embed Hermitian matrix
    let mut emb = vec![vec![0.0; m]; m];
    for i in 0..n {
        for j in 0..n {
            emb[i][j] = gram_re[i][j];
            emb[i][n + j] = -gram_im[i][j];
            emb[n + i][j] = gram_im[i][j];
            emb[n + i][n + j] = gram_re[i][j];
        }
    }

    // Embed b vector: [b_re; b_im]
    let mut b_emb = vec![0.0; m];
    for i in 0..n {
        b_emb[i] = b_re[i];
        b_emb[n + i] = b_im[i];
    }

    let mut lu = emb;
    let piv = lu_decompose(&mut lu);
    let c = lu_solve(&lu, &piv, &b_emb);

    // b† · c = Σ (b_re[i]*c_re[i] + b_im[i]*c_im[i])
    let btc: f64 = b_emb.iter().zip(c.iter()).map(|(a, b)| a * b).sum();
    (1.0 - btc).max(0.0)
}

fn compute_ratios(eigenvalues: &[f64]) -> Vec<f64> {
    let n = eigenvalues.len();
    if n < 3 {
        return vec![];
    }
    let mut ratios = Vec::with_capacity(n - 2);
    for i in 0..(n - 2) {
        let s1 = eigenvalues[i + 1] - eigenvalues[i];
        let s2 = eigenvalues[i + 2] - eigenvalues[i + 1];
        if s1 > 1e-15 && s2 > 1e-15 {
            ratios.push(s1.min(s2) / s1.max(s2));
        }
    }
    ratios
}

fn ratio_mean(ev: &[f64]) -> f64 {
    let r = compute_ratios(ev);
    if r.is_empty() {
        0.0
    } else {
        r.iter().sum::<f64>() / r.len() as f64
    }
}

fn classify(rm: f64) -> &'static str {
    let d = [
        ("Poisson", 0.3863),
        ("GOE", 0.5307),
        ("GUE", 0.5996),
        ("GSE", 0.6744),
    ];
    d.iter()
        .min_by(|a, b| (rm - a.1).abs().partial_cmp(&(rm - b.1).abs()).unwrap())
        .unwrap()
        .0
}

fn estimate_beta(rm: f64) -> f64 {
    if rm < 0.4 {
        0.0
    } else if rm < 0.54 {
        (rm - 0.3863) / (0.5307 - 0.3863)
    } else if rm < 0.64 {
        1.0 + (rm - 0.5307) / (0.5996 - 0.5307)
    } else {
        2.0 + 2.0 * (rm - 0.5996) / (0.6744 - 0.5996)
    }
}

// ══════════════════════════════════════════════════════════════════════
// MAIN
// ══════════════════════════════════════════════════════════════════════

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║    ENRICHED NYMAN-BEURLING VERIFICATION AT SCALE               ║");
    println!("║    Testing GUE persistence, d_N convergence, Liouville v_min   ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let total_start = std::time::Instant::now();
    let n_pts = 150_000;
    let test_sizes = vec![50, 100, 150, 200, 250, 300];
    let alpha_gue = 0.2; // Sweet spot for GUE (β≈2)
    let alpha_gap = 1.0; // Best spectral gap improvement

    // ════════════════════════════════════════════════════════════════
    // TEST 1: GUE PERSISTENCE AS N GROWS
    // ════════════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════════");
    println!("  TEST 1: GUE PERSISTENCE — Does ⟨r⟩ ≈ 0.5996 hold at large N?");
    println!("═══════════════════════════════════════════════════════════════════\n");

    println!(
        "  {:>5} │ {:>10} {:>8} {:>8} │ {:>10} {:>8} {:>8} │ {:>10} {:>8} {:>8}",
        "N", "⟨r⟩ real", "class", "β", "⟨r⟩ α=0.2", "class", "β", "⟨r⟩ α=1.0", "class", "β"
    );
    println!(
        "  {}┼{}┼{}┼{}",
        "─".repeat(6),
        "─".repeat(30),
        "─".repeat(30),
        "─".repeat(30)
    );

    // Store data for later analysis
    let mut all_data: Vec<(usize, f64, f64, f64, f64, f64, f64, f64, f64)> = Vec::new();

    for &max_n in &test_sizes {
        let dim = max_n - 1;
        let phase_start = std::time::Instant::now();

        // Compute real Gram matrix
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

        // Real eigenvalues + ratio
        let eigs_real = jacobi_eigenvalues(&gram_real, 200, 1e-12);
        let r_real = ratio_mean(&eigs_real);

        // Enriched α=0.2 (GUE sweet spot)
        let entries_02: Vec<((usize, usize), (f64, f64))> = (0..dim)
            .into_par_iter()
            .flat_map(|j| {
                (j..dim).into_par_iter().map(move |k| {
                    let (re, im) = gram_entry_fourier(j + 2, k + 2, alpha_gue, n_pts);
                    ((j, k), (re, im))
                })
            })
            .collect();
        let mut gre02 = vec![vec![0.0; dim]; dim];
        let mut gim02 = vec![vec![0.0; dim]; dim];
        for ((j, k), (re, im)) in &entries_02 {
            gre02[*j][*k] = *re;
            gre02[*k][*j] = *re;
            gim02[*j][*k] = *im;
            gim02[*k][*j] = -*im;
        }
        let emb02 = embed_hermitian(&gre02, &gim02);
        let eigs02 = jacobi_eigenvalues(&emb02, 200, 1e-12);
        let eigs02d = extract_distinct(&eigs02, 1e-8);
        let r_02 = ratio_mean(&eigs02d);

        // Enriched α=1.0 (best spectral gap)
        let entries_10: Vec<((usize, usize), (f64, f64))> = (0..dim)
            .into_par_iter()
            .flat_map(|j| {
                (j..dim).into_par_iter().map(move |k| {
                    let (re, im) = gram_entry_fourier(j + 2, k + 2, alpha_gap, n_pts);
                    ((j, k), (re, im))
                })
            })
            .collect();
        let mut gre10 = vec![vec![0.0; dim]; dim];
        let mut gim10 = vec![vec![0.0; dim]; dim];
        for ((j, k), (re, im)) in &entries_10 {
            gre10[*j][*k] = *re;
            gre10[*k][*j] = *re;
            gim10[*j][*k] = *im;
            gim10[*k][*j] = -*im;
        }
        let emb10 = embed_hermitian(&gre10, &gim10);
        let eigs10 = jacobi_eigenvalues(&emb10, 200, 1e-12);
        let eigs10d = extract_distinct(&eigs10, 1e-8);
        let r_10 = ratio_mean(&eigs10d);

        let lmin_real = eigs_real[0];
        let lmin_02 = eigs02d[0];
        let lmin_10 = eigs10d[0];

        all_data.push((
            max_n,
            r_real,
            estimate_beta(r_real),
            lmin_real,
            r_02,
            estimate_beta(r_02),
            lmin_02,
            r_10,
            estimate_beta(r_10),
        ));

        println!(
            "  {:5} │ {:10.6} {:>8} {:8.2} │ {:10.6} {:>8} {:8.2} │ {:10.6} {:>8} {:8.2}  ({:.1}s)",
            max_n,
            r_real,
            classify(r_real),
            estimate_beta(r_real),
            r_02,
            classify(r_02),
            estimate_beta(r_02),
            r_10,
            classify(r_10),
            estimate_beta(r_10),
            phase_start.elapsed().as_secs_f64()
        );
    }

    // ════════════════════════════════════════════════════════════════
    // TEST 2: NYMAN-BEURLING DISTANCE d_N
    // ════════════════════════════════════════════════════════════════
    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  TEST 2: NYMAN-BEURLING DISTANCE d_N² = 1 - b†·G⁻¹·b");
    println!("  (RH ⟺ d_N → 0. Does enrichment preserve this?)");
    println!("═══════════════════════════════════════════════════════════════════\n");

    println!(
        "  {:>5} │ {:>12} {:>12} │ {:>12} {:>12} │ {:>12} {:>12}",
        "N", "d²_N real", "λ_min real", "d²_N α=0.2", "λ_min α=0.2", "d²_N α=1.0", "λ_min α=1.0"
    );
    println!(
        "  {}┼{}┼{}┼{}",
        "─".repeat(6),
        "─".repeat(26),
        "─".repeat(26),
        "─".repeat(26)
    );

    for &max_n in &test_sizes {
        let dim = max_n - 1;

        // Real Gram matrix
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

        // Real NB target: b_k = ∫₀¹ {k/x} dx
        let b_real: Vec<f64> = (0..dim).map(|j| nb_target_real(j + 2, n_pts)).collect();

        // Real d_N² and λ_min
        let d2_real = nb_distance_real(&gram_real, &b_real);
        let (lmin_real, _) = min_eigenpair(&gram_real, 500);

        // Enriched α=0.2
        let entries_02: Vec<((usize, usize), (f64, f64))> = (0..dim)
            .into_par_iter()
            .flat_map(|j| {
                (j..dim).into_par_iter().map(move |k| {
                    let (re, im) = gram_entry_fourier(j + 2, k + 2, alpha_gue, n_pts);
                    ((j, k), (re, im))
                })
            })
            .collect();
        let mut gre02 = vec![vec![0.0; dim]; dim];
        let mut gim02 = vec![vec![0.0; dim]; dim];
        for ((j, k), (re, im)) in &entries_02 {
            gre02[*j][*k] = *re;
            gre02[*k][*j] = *re;
            gim02[*j][*k] = *im;
            gim02[*k][*j] = -*im;
        }
        let b02: Vec<(f64, f64)> = (0..dim)
            .map(|j| nb_target_complex(j + 2, alpha_gue, n_pts))
            .collect();
        let b02_re: Vec<f64> = b02.iter().map(|x| x.0).collect();
        let b02_im: Vec<f64> = b02.iter().map(|x| x.1).collect();
        let d2_02 = nb_distance_complex(&gre02, &gim02, &b02_re, &b02_im);
        let emb02 = embed_hermitian(&gre02, &gim02);
        let (lmin_02, _) = min_eigenpair(&emb02, 500);

        // Enriched α=1.0
        let entries_10: Vec<((usize, usize), (f64, f64))> = (0..dim)
            .into_par_iter()
            .flat_map(|j| {
                (j..dim).into_par_iter().map(move |k| {
                    let (re, im) = gram_entry_fourier(j + 2, k + 2, alpha_gap, n_pts);
                    ((j, k), (re, im))
                })
            })
            .collect();
        let mut gre10 = vec![vec![0.0; dim]; dim];
        let mut gim10 = vec![vec![0.0; dim]; dim];
        for ((j, k), (re, im)) in &entries_10 {
            gre10[*j][*k] = *re;
            gre10[*k][*j] = *re;
            gim10[*j][*k] = *im;
            gim10[*k][*j] = -*im;
        }
        let b10: Vec<(f64, f64)> = (0..dim)
            .map(|j| nb_target_complex(j + 2, alpha_gap, n_pts))
            .collect();
        let b10_re: Vec<f64> = b10.iter().map(|x| x.0).collect();
        let b10_im: Vec<f64> = b10.iter().map(|x| x.1).collect();
        let d2_10 = nb_distance_complex(&gre10, &gim10, &b10_re, &b10_im);
        let emb10 = embed_hermitian(&gre10, &gim10);
        let (lmin_10, _) = min_eigenpair(&emb10, 500);

        println!(
            "  {:5} │ {:12.8} {:12.8} │ {:12.8} {:12.8} │ {:12.8} {:12.8}",
            max_n, d2_real, lmin_real, d2_02, lmin_02, d2_10, lmin_10
        );
    }

    // ════════════════════════════════════════════════════════════════
    // TEST 3: LIOUVILLE EIGENVECTOR CORRELATION
    // ════════════════════════════════════════════════════════════════
    println!("\n═══════════════════════════════════════════════════════════════════");
    println!("  TEST 3: LIOUVILLE EIGENVECTOR — Does v_min ∝ λ(k)·ln(k)/k?");
    println!("═══════════════════════════════════════════════════════════════════\n");

    for &max_n in &[100, 200, 300] {
        let dim = max_n - 1;
        println!("  ─── N = {} ───\n", max_n);

        // Real Gram matrix + v_min
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

        let (lmin_real, v_real) = min_eigenpair(&gram_real, 500);

        // Liouville correlation (real)
        let liou_corr_real = liouville_correlation(&v_real, dim);

        // Enriched α=0.2 — v_min from 2n×2n embedding
        let entries: Vec<((usize, usize), (f64, f64))> = (0..dim)
            .into_par_iter()
            .flat_map(|j| {
                (j..dim).into_par_iter().map(move |k| {
                    let (re, im) = gram_entry_fourier(j + 2, k + 2, alpha_gue, n_pts);
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
        let emb = embed_hermitian(&gre, &gim);
        let (lmin_02, v_02_full) = min_eigenpair(&emb, 500);

        // Extract the "real" part of the complex eigenvector (first n components)
        let v_02_re: Vec<f64> = v_02_full[..dim].to_vec();
        let v_02_im: Vec<f64> = v_02_full[dim..].to_vec();
        let v_02_abs: Vec<f64> = (0..dim)
            .map(|i| (v_02_re[i] * v_02_re[i] + v_02_im[i] * v_02_im[i]).sqrt())
            .collect();

        let liou_corr_02 = liouville_correlation_complex(&v_02_re, &v_02_im, dim);

        println!(
            "    Real Gram:     λ_min = {:.8}, Liouville sign corr = {:.4}",
            lmin_real, liou_corr_real
        );
        println!(
            "    Enriched α=0.2: λ_min = {:.8}, Liouville sign corr = {:.4}",
            lmin_02, liou_corr_02
        );

        // Show v_min entries for small k
        println!("\n    k  λ(k)  v_real[k]     |v_02[k]|    ψ(k)=λ(k)ln(k)/k");
        for idx in 0..20.min(dim) {
            let k = idx + 2;
            let psi = liouville(k) * (k as f64).ln() / k as f64;
            println!(
                "    {:3} {:+2}  {:+12.6}  {:12.6}  {:+12.6}",
                k,
                liouville(k) as i32,
                v_real[idx],
                v_02_abs[idx],
                psi
            );
        }
        println!();
    }

    // ════════════════════════════════════════════════════════════════
    // TEST 4: SPECTRAL GAP CONVERGENCE
    // ════════════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════════");
    println!("  TEST 4: SPECTRAL GAP λ_min(N) — Convergence as N → ∞");
    println!("═══════════════════════════════════════════════════════════════════\n");

    println!(
        "  {:>5} {:>12} {:>12} {:>12} {:>12}",
        "N", "λ_min real", "λ_min α=0.2", "λ_min α=1.0", "ratio 0.2/real"
    );
    println!("  {}", "─".repeat(62));

    for &(n, _, _, lr, _, _, l02, _, _) in &all_data {
        let ratio = if lr > 1e-15 { l02 / lr } else { 0.0 };
        let l10 = all_data
            .iter()
            .find(|x| x.0 == n)
            .map(|x| x.8)
            .unwrap_or(0.0);
        // We don't have lmin stored in all_data directly for the gap.
        // Print from the GUE persistence data
    }

    // Re-run with just λ_min (fast inverse iteration)
    for &max_n in &test_sizes {
        let dim = max_n - 1;
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
        let mut gram = vec![vec![0.0; dim]; dim];
        for j in 0..dim {
            for k in j..dim {
                gram[j][k] = gram_upper[j][k];
                gram[k][j] = gram_upper[j][k];
            }
        }
        let (lr, _) = min_eigenpair(&gram, 500);

        // α=0.2
        let ent: Vec<((usize, usize), (f64, f64))> = (0..dim)
            .into_par_iter()
            .flat_map(|j| {
                (j..dim).into_par_iter().map(move |k| {
                    let (re, im) = gram_entry_fourier(j + 2, k + 2, 0.2, n_pts);
                    ((j, k), (re, im))
                })
            })
            .collect();
        let mut gre = vec![vec![0.0; dim]; dim];
        let mut gim = vec![vec![0.0; dim]; dim];
        for ((j, k), (re, im)) in &ent {
            gre[*j][*k] = *re;
            gre[*k][*j] = *re;
            gim[*j][*k] = *im;
            gim[*k][*j] = -*im;
        }
        let emb = embed_hermitian(&gre, &gim);
        let (l02, _) = min_eigenpair(&emb, 500);

        // α=1.0
        let ent1: Vec<((usize, usize), (f64, f64))> = (0..dim)
            .into_par_iter()
            .flat_map(|j| {
                (j..dim).into_par_iter().map(move |k| {
                    let (re, im) = gram_entry_fourier(j + 2, k + 2, 1.0, n_pts);
                    ((j, k), (re, im))
                })
            })
            .collect();
        let mut gre1 = vec![vec![0.0; dim]; dim];
        let mut gim1 = vec![vec![0.0; dim]; dim];
        for ((j, k), (re, im)) in &ent1 {
            gre1[*j][*k] = *re;
            gre1[*k][*j] = *re;
            gim1[*j][*k] = *im;
            gim1[*k][*j] = -*im;
        }
        let emb1 = embed_hermitian(&gre1, &gim1);
        let (l10, _) = min_eigenpair(&emb1, 500);

        let ratio = if lr.abs() > 1e-15 { l02 / lr } else { 0.0 };
        println!(
            "  {:5} {:12.8} {:12.8} {:12.8} {:12.2}×",
            max_n, lr, l02, l10, ratio
        );
    }

    // ════════════════════════════════════════════════════════════════
    // FINAL VERDICT
    // ════════════════════════════════════════════════════════════════
    println!("\n╔══════════════════════════════════════════════════════════════════╗");
    println!("║                  ENRICHED NB VERIFICATION VERDICT               ║");
    println!("╠══════════════════════════════════════════════════════════════════╣");
    println!("║                                                                ║");
    println!("║  TEST 1 (GUE persistence):                                     ║");
    println!("║    → Check: ⟨r⟩ ≈ 0.5996 at all N for α=0.2?                 ║");
    println!("║                                                                ║");
    println!("║  TEST 2 (d_N convergence):                                     ║");
    println!("║    → Check: d²_N → 0 for enriched basis?                      ║");
    println!("║    → If YES: enriched NB still characterizes RH!               ║");
    println!("║                                                                ║");
    println!("║  TEST 3 (Liouville eigenvector):                               ║");
    println!("║    → Check: v_min ∝ λ(k)·ln(k)/k in enriched case?           ║");
    println!("║    → If YES: same arithmetic mechanism, stronger framework     ║");
    println!("║                                                                ║");
    println!("║  TEST 4 (spectral gap):                                        ║");
    println!("║    → Check: λ_min(enriched) >> λ_min(real) at all N?          ║");
    println!("║    → If YES: HYPERZETA is easier in enriched space!            ║");
    println!("║                                                                ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");

    println!(
        "\n  Total time: {:.1}s\n",
        total_start.elapsed().as_secs_f64()
    );
}

/// Correlation between v_min and Liouville function λ(k)
fn liouville_correlation(v: &[f64], dim: usize) -> f64 {
    let mut agree = 0;
    let mut total = 0;
    for i in 0..dim {
        let k = i + 2;
        let lio = liouville(k);
        if v[i].abs() > 1e-10 {
            if (v[i] > 0.0 && lio > 0.0) || (v[i] < 0.0 && lio < 0.0) {
                agree += 1;
            }
            total += 1;
        }
    }
    if total == 0 {
        0.0
    } else {
        agree as f64 / total as f64
    }
}

/// Correlation for complex eigenvector: use Re(v) sign vs Liouville
fn liouville_correlation_complex(v_re: &[f64], v_im: &[f64], dim: usize) -> f64 {
    // Use the magnitude-weighted phase correlation
    let mut weighted_agree = 0.0;
    let mut total_weight = 0.0;
    for i in 0..dim {
        let k = i + 2;
        let lio = liouville(k);
        let mag = (v_re[i] * v_re[i] + v_im[i] * v_im[i]).sqrt();
        if mag > 1e-10 {
            // Check if Re(v[i]) has same sign as λ(k)
            if (v_re[i] > 0.0 && lio > 0.0) || (v_re[i] < 0.0 && lio < 0.0) {
                weighted_agree += mag;
            }
            total_weight += mag;
        }
    }
    if total_weight < 1e-15 {
        0.0
    } else {
        weighted_agree / total_weight
    }
}
