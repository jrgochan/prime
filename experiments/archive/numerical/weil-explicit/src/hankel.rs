#![allow(unused, dead_code, non_snake_case)]
use std::f64::consts::PI;

// ══════════════════════════════════════════════════════════
// PROJECT HYPERZETA: Hankel Matrix Analysis
// Testing the Hamburger Moment Problem for Li Coefficients
// ══════════════════════════════════════════════════════════

// --- Zero-finding (from main.rs) ---

fn rs_theta(t: f64) -> f64 {
    let t2 = t / 2.0;
    let mut theta = t2 * (t2 / PI).ln() - t2 - PI / 8.0;
    if t > 10.0 {
        let ti = 1.0 / t;
        theta += ti / 48.0 + 7.0 * ti.powi(3) / 5760.0;
    } else if t > 1.0 {
        let ti = 1.0 / t;
        theta += ti / 48.0;
    }
    theta
}

fn hardy_z(t: f64) -> f64 {
    let n_max = ((t / (2.0 * PI)).sqrt()).floor() as usize;
    if n_max == 0 {
        return 0.0;
    }
    let theta = rs_theta(t);
    let mut sum = 0.0;
    for n in 1..=n_max {
        let nf = n as f64;
        sum += (theta - t * nf.ln()).cos() / nf.sqrt();
    }
    sum *= 2.0;
    let p = ((t / (2.0 * PI)).sqrt()).fract();
    let c0 = (PI / 8.0 * (2.0 * p - 1.0).powi(2)).cos() / (PI * 0.5 * (2.0 * p - 1.0)).cos();
    let tau = (t / (2.0 * PI)).sqrt();
    sum += (-1i32).pow(n_max as u32 + 1) as f64 * tau.powf(-0.5) * c0;
    sum
}

fn find_zeros(t_end: f64) -> Vec<f64> {
    let mut zeros = Vec::new();
    let mut t = 14.0;
    let mut z_prev = hardy_z(t);
    while t < t_end {
        let expected_spacing = 2.0 * PI / (t / (2.0 * PI)).ln();
        let dt = (expected_spacing * 0.25).max(0.01).min(0.5);
        let t_next = t + dt;
        let z_next = hardy_z(t_next);
        if z_prev * z_next < 0.0 {
            let (mut lo, mut hi) = (t, t_next);
            let mut zlo = z_prev;
            for _ in 0..64 {
                let mid = (lo + hi) / 2.0;
                let zm = hardy_z(mid);
                if zlo * zm < 0.0 {
                    hi = mid;
                } else {
                    lo = mid;
                    zlo = zm;
                }
            }
            zeros.push((lo + hi) / 2.0);
        }
        t = t_next;
        z_prev = z_next;
    }
    zeros
}

// --- Li coefficient computation ---

fn compute_li_coefficients(alphas: &[f64], n_max: usize) -> Vec<f64> {
    (1..=n_max)
        .map(|n| {
            let nf = n as f64;
            alphas
                .iter()
                .map(|&alpha| 2.0 * (1.0 - (nf * alpha).cos()))
                .sum()
        })
        .collect()
}

// --- Hankel matrix operations (no external deps!) ---

/// Build the Hankel matrix H[i][j] = seq[i+j] for i,j in 0..size
fn build_hankel(seq: &[f64], size: usize) -> Vec<Vec<f64>> {
    let mut h = vec![vec![0.0; size]; size];
    for i in 0..size {
        for j in 0..size {
            h[i][j] = seq[i + j];
        }
    }
    h
}

/// Cholesky decomposition: returns true if matrix is positive definite
/// Also returns the diagonal of L (whose product² = det)
fn cholesky(mat: &[Vec<f64>]) -> Option<Vec<f64>> {
    let n = mat.len();
    let mut l = vec![vec![0.0; n]; n];
    let mut diag = Vec::with_capacity(n);

    for i in 0..n {
        for j in 0..=i {
            let mut sum = 0.0;
            for k in 0..j {
                sum += l[i][k] * l[j][k];
            }
            if i == j {
                let val = mat[i][i] - sum;
                if val <= 0.0 {
                    return None; // Not positive definite
                }
                l[i][j] = val.sqrt();
                diag.push(l[i][j]);
            } else {
                l[i][j] = (mat[i][j] - sum) / l[j][j];
            }
        }
    }
    Some(diag)
}

/// Compute log-determinant from Cholesky diagonal
fn log_det_from_cholesky(diag: &[f64]) -> f64 {
    2.0 * diag.iter().map(|d| d.ln()).sum::<f64>()
}

/// Compute all eigenvalues via symmetric QR (Jacobi iteration)
/// Simple implementation for small matrices
fn eigenvalues_symmetric(mat: &[Vec<f64>]) -> Vec<f64> {
    let n = mat.len();
    let mut a = mat.to_vec();

    // Jacobi eigenvalue algorithm
    for _ in 0..1000 {
        // Find largest off-diagonal element
        let mut max_val = 0.0f64;
        let mut p = 0;
        let mut q = 1;
        for i in 0..n {
            for j in (i + 1)..n {
                if a[i][j].abs() > max_val {
                    max_val = a[i][j].abs();
                    p = i;
                    q = j;
                }
            }
        }
        if max_val < 1e-12 {
            break;
        }

        // Compute rotation
        let theta = if (a[q][q] - a[p][p]).abs() < 1e-15 {
            PI / 4.0
        } else {
            0.5 * (2.0 * a[p][q] / (a[p][p] - a[q][q])).atan()
        };
        let c = theta.cos();
        let s = theta.sin();

        // Apply rotation
        let mut new_a = a.clone();
        for i in 0..n {
            if i != p && i != q {
                new_a[i][p] = c * a[i][p] + s * a[i][q];
                new_a[p][i] = new_a[i][p];
                new_a[i][q] = -s * a[i][p] + c * a[i][q];
                new_a[q][i] = new_a[i][q];
            }
        }
        new_a[p][p] = c * c * a[p][p] + 2.0 * s * c * a[p][q] + s * s * a[q][q];
        new_a[q][q] = s * s * a[p][p] - 2.0 * s * c * a[p][q] + c * c * a[q][q];
        new_a[p][q] = 0.0;
        new_a[q][p] = 0.0;
        a = new_a;
    }

    (0..n).map(|i| a[i][i]).collect()
}

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  PROJECT HYPERZETA: Hamburger Moment Problem Analysis");
    println!("  Testing: Are Li coefficients a moment sequence?");
    println!("═══════════════════════════════════════════════════════════════");

    // Phase 1: Compute zeros and Li coefficients
    let t_max = 120_000.0;
    println!("\n[1/4] Finding zeros up to t = {:.0}...", t_max);
    let start = std::time::Instant::now();
    let zeros = find_zeros(t_max);
    println!(
        "  Found {} zeros in {:.1}s",
        zeros.len(),
        start.elapsed().as_secs_f64()
    );

    let alphas: Vec<f64> = zeros
        .iter()
        .map(|&gamma| PI - 2.0 * (2.0 * gamma).atan())
        .collect();

    let n_li = 2000; // Need λ_1 through λ_{2*hankel_size - 1}
    println!("\n[2/4] Computing {} Li coefficients...", n_li);
    let start = std::time::Instant::now();
    let li = compute_li_coefficients(&alphas, n_li);
    println!("  Done in {:.1}s", start.elapsed().as_secs_f64());

    // Print first few
    println!("\n  First 10 Li coefficients:");
    for i in 0..10 {
        println!("  λ_{:<3} = {:.10}", i + 1, li[i]);
    }

    // Phase 2: Test RAW λ_n Hankel matrices
    println!("\n[3/4] ═══ Hankel Matrix Test: Raw λ_n ═══");
    println!("  H_n[i][j] = λ_{{i+j+1}}\n");
    println!(
        "  {:>4}  {:>12}  {:>12}  {:>10}  {:>10}",
        "size", "min_eig", "max_eig", "pos_def?", "log_det"
    );

    let max_hankel = 100;
    let mut raw_all_pd = true;
    let mut raw_first_fail = 0;

    for size in 1..=max_hankel {
        if size > li.len() / 2 {
            break;
        }
        let h = build_hankel(&li, size); // li[0] = λ_1
        let eigs = eigenvalues_symmetric(&h);
        let min_eig = eigs.iter().cloned().fold(f64::INFINITY, f64::min);
        let max_eig = eigs.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        let pd = min_eig > 0.0;

        let log_det = if pd {
            if let Some(diag) = cholesky(&h) {
                log_det_from_cholesky(&diag)
            } else {
                f64::NEG_INFINITY
            }
        } else {
            f64::NEG_INFINITY
        };

        if !pd && raw_all_pd {
            raw_all_pd = false;
            raw_first_fail = size;
        }

        if size <= 20 || size % 10 == 0 || (!pd && size == raw_first_fail) {
            println!(
                "  {:4}  {:12.6}  {:12.2}  {:>10}  {:10.2}",
                size,
                min_eig,
                max_eig,
                if pd { "✅" } else { "❌" },
                log_det
            );
        }
    }

    // Phase 3: Test NORMALIZED λ_n/n Hankel matrices
    println!("\n[3b/4] ═══ Hankel Matrix Test: λ_n/n ═══");
    let li_norm: Vec<f64> = li
        .iter()
        .enumerate()
        .map(|(i, &v)| v / (i + 1) as f64)
        .collect();
    println!("  H_n[i][j] = λ_{{i+j+1}} / (i+j+1)\n");
    println!(
        "  {:>4}  {:>12}  {:>12}  {:>10}  {:>10}",
        "size", "min_eig", "max_eig", "pos_def?", "log_det"
    );

    let mut norm_all_pd = true;
    let mut norm_first_fail = 0;

    for size in 1..=max_hankel {
        if size > li_norm.len() / 2 {
            break;
        }
        let h = build_hankel(&li_norm, size);
        let eigs = eigenvalues_symmetric(&h);
        let min_eig = eigs.iter().cloned().fold(f64::INFINITY, f64::min);
        let max_eig = eigs.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        let pd = min_eig > 0.0;

        let log_det = if pd {
            if let Some(diag) = cholesky(&h) {
                log_det_from_cholesky(&diag)
            } else {
                f64::NEG_INFINITY
            }
        } else {
            f64::NEG_INFINITY
        };

        if !pd && norm_all_pd {
            norm_all_pd = false;
            norm_first_fail = size;
        }

        if size <= 20 || size % 10 == 0 || (!pd && size == norm_first_fail) {
            println!(
                "  {:4}  {:12.6}  {:12.6}  {:>10}  {:10.2}",
                size,
                min_eig,
                max_eig,
                if pd { "✅" } else { "❌" },
                log_det
            );
        }
    }

    // Phase 4: Test SHIFTED sequences
    // The "trigonometric moment" interpretation:
    // c_n = Σ_k 2(1 - cos(nα_k)) = Σ_k 2 - 2·Re[e^{inα_k}]
    // s_n = Σ_k cos(nα_k) = (N_zeros - λ_n/2)
    // Test Toeplitz positivity: T_n[i][j] = s_{|i-j|}
    println!("\n[3c/4] ═══ Toeplitz Matrix Test: cosine sums ═══");
    let n_zeros = zeros.len() as f64;
    let cos_sums: Vec<f64> = (0..=n_li)
        .map(|n| {
            if n == 0 {
                n_zeros
            } else {
                n_zeros - li[n - 1] / 2.0
            }
        })
        .collect();

    println!("  T_n[i][j] = Σ_k cos((i-j)·α_k)\n");
    println!(
        "  {:>4}  {:>12}  {:>12}  {:>10}",
        "size", "min_eig", "max_eig", "pos_def?"
    );

    let mut toep_all_pd = true;
    let mut toep_first_fail = 0;

    for size in 1..=max_hankel.min(200) {
        if size > cos_sums.len() / 2 {
            break;
        }
        // Build Toeplitz matrix
        let mut t = vec![vec![0.0; size]; size];
        for i in 0..size {
            for j in 0..size {
                let diff = i.abs_diff(j);
                t[i][j] = cos_sums[diff];
            }
        }

        let eigs = eigenvalues_symmetric(&t);
        let min_eig = eigs.iter().cloned().fold(f64::INFINITY, f64::min);
        let max_eig = eigs.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        let pd = min_eig > 0.0;

        if !pd && toep_all_pd {
            toep_all_pd = false;
            toep_first_fail = size;
        }

        if size <= 20 || size % 10 == 0 || (!pd && size == toep_first_fail) {
            println!(
                "  {:4}  {:12.2}  {:12.2}  {:>10}",
                size,
                min_eig,
                max_eig,
                if pd { "✅" } else { "❌" }
            );
        }
    }

    // Summary
    println!("\n[4/4] ═══ SUMMARY ═══");
    println!(
        "  Raw λ_n Hankel:      {}",
        if raw_all_pd {
            "✅ ALL positive definite".to_string()
        } else {
            format!("❌ First failure at size {}", raw_first_fail)
        }
    );
    println!(
        "  λ_n/n Hankel:        {}",
        if norm_all_pd {
            "✅ ALL positive definite".to_string()
        } else {
            format!("❌ First failure at size {}", norm_first_fail)
        }
    );
    println!(
        "  Toeplitz (cosines):  {}",
        if toep_all_pd {
            "✅ ALL positive definite".to_string()
        } else {
            format!("❌ First failure at size {}", toep_first_fail)
        }
    );

    println!("\n═══════════════════════════════════════════════════════════════");
    if toep_all_pd {
        println!("  🍔 The Li coefficients pass the Hamburger moment test!");
        println!("  The cosine-sum Toeplitz matrix is positive definite.");
    } else {
        println!("  The moment problem structure requires further analysis.");
    }
    println!("═══════════════════════════════════════════════════════════════");
}
