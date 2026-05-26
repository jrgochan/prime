// ═══════════════════════════════════════════════════════════════════════════
//  𝔽₁ HODGE EXPLORER — Eigenvalue structure of the Arakelov decomposition
//
//  Uses high-precision HPDF Gram matrices to explore:
//    G(j,k) = B₁(j,k) + L₁(j,k)
//    B₁(j,k) = gcd(j,k)² / (12·j·k)   [arithmetic skeleton, PSD by Smith 1876]
//    L₁(j,k) = G(j,k) - B₁(j,k)       [archimedean perturbation]
//
//  Key questions:
//    1. Is L₁ negative on the Möbius witness? (Yes! — discovered in the probe)
//    2. How many positive eigenvalues does L₁ have on degree-0? (~5, constant!)
//    3. What ARE those ~5 positive eigenvalues? What eigenvectors do they have?
//    4. How does deg(v) = Σ v_k evolve with N? (→ 0 by PNT)
//    5. What is the Smith decomposition: vᵀB₁v = Σ J₂(d) y_d² ?
// ═══════════════════════════════════════════════════════════════════════════

use cathedral_utils::arith;
use cathedral_utils::mertens;
use nalgebra::{DMatrix, DVector};
use std::path::{Path, PathBuf};

#[cfg(feature = "hpdf")]
use cathedral_utils::hpdf::reader::HpdfReader;

/// Build the B₁ skeleton matrix: B₁(j,k) = gcd(j,k)² / (12·j·k)
fn build_b1_skeleton(n: usize) -> DMatrix<f64> {
    let mut b1 = DMatrix::zeros(n, n);
    for j in 0..n {
        for k in j..n {
            let jj = (j + 1) as u64;
            let kk = (k + 1) as u64;
            let g = arith::gcd(jj as usize, kk as usize) as f64;
            let val = g * g / (12.0 * jj as f64 * kk as f64);
            b1[(j, k)] = val;
            b1[(k, j)] = val;
        }
    }
    b1
}

/// Build the Möbius witness vector: v_k = μ(k) · log(N/k) / (k · log(N))
fn build_mobius_witness(n: usize, mu: &[i8]) -> DVector<f64> {
    let ln_n = (n as f64).ln();
    let mut v = DVector::zeros(n);
    for k in 1..=n {
        let mu_k = mu[k] as f64;
        if mu_k != 0.0 {
            v[k - 1] = mu_k * ((n as f64) / (k as f64)).ln() / (k as f64 * ln_n);
        }
    }
    v
}

/// Project a matrix to the degree-0 subspace {v : Σ v_k = 0}
/// Returns the projected matrix P·M·P where P = I - (1/N)·11ᵀ
fn project_to_degree_zero(m: &DMatrix<f64>) -> DMatrix<f64> {
    let n = m.nrows();
    let ones = DVector::from_element(n, 1.0 / (n as f64).sqrt());
    // P = I - 11ᵀ/N = I - ones·onesᵀ
    let proj = DMatrix::identity(n, n) - &ones * ones.transpose();
    &proj * m * &proj
}

/// Compute Jordan totient J₂(d) = d² · Π_{p|d} (1 - 1/p²)
fn jordan_totient_2(d: usize) -> f64 {
    if d == 0 {
        return 0.0;
    }
    let mut result = (d * d) as f64;
    let mut n = d;
    let mut p = 2;
    while p * p <= n {
        if n % p == 0 {
            result *= 1.0 - 1.0 / (p * p) as f64;
            while n % p == 0 {
                n /= p;
            }
        }
        p += 1;
    }
    if n > 1 {
        result *= 1.0 - 1.0 / (n * n) as f64;
    }
    result
}

/// Smith decomposition: vᵀB₁v = Σ_d J₂(d)/(12) · y_d²
/// where y_d = Σ_{d|k, k≤N} v_{k-1} / k
fn smith_decomposition(v: &DVector<f64>, n: usize) -> Vec<(usize, f64, f64)> {
    let mut results = Vec::new();
    for d in 1..=n {
        let mut y_d = 0.0;
        let mut k = d;
        while k <= n {
            y_d += v[k - 1] / k as f64;
            k += d;
        }
        let j2 = jordan_totient_2(d);
        let contribution = j2 / 12.0 * y_d * y_d;
        if contribution.abs() > 1e-15 {
            results.push((d, y_d, contribution));
        }
    }
    results.sort_by(|a, b| b.2.partial_cmp(&a.2).unwrap());
    results
}

/// Load Gram matrix from HPDF file or compute for small N.
///
/// HPDF convention: gram_N{X}.h5 stores a (X-1)×(X-1) matrix for k=2..X.
/// We need k=1..N, so we read the (N-1)×(N-1) block for k=2..N from H5,
/// then compute the k=1 row/column using cathedral-utils gram_entry_f64.
fn load_or_compute_gram(n: usize, hpdf_dir: &Path) -> DMatrix<f64> {
    #[cfg(feature = "hpdf")]
    {
        let h5_path = hpdf_dir.join(format!("gram_N{}.h5", n));
        if h5_path.exists() {
            eprintln!("  📂 Loading G_{} from HPDF...", n);
            match HpdfReader::open(&h5_path) {
                Ok(reader) => {
                    let h5_dim = reader.dim(); // = N-1, for k=2..N
                    match reader.read_gram_full() {
                        Ok(data) => {
                            let mut g = DMatrix::zeros(n, n);

                            // Fill k=2..N block from H5 (rows/cols 1..N-1 in our 0-indexed matrix)
                            let block_size = (n - 1).min(h5_dim);
                            for j in 0..block_size {
                                for k in 0..block_size {
                                    g[(j + 1, k + 1)] = data[j * h5_dim + k];
                                }
                            }

                            // Compute k=1 row/column using direct f64 engine
                            for k in 0..n {
                                let val = cathedral_utils::gram::gram_entry_f64(1, k + 1);
                                g[(0, k)] = val;
                                g[(k, 0)] = val;
                            }

                            eprintln!("  ✅ Loaded G_{} from HPDF ({}×{} H5 + k=1 row)", n, h5_dim, h5_dim);
                            return g;
                        }
                        Err(e) => eprintln!("  ⚠ HPDF read error: {}", e),
                    }
                }
                Err(e) => eprintln!("  ⚠ HPDF open error: {}", e),
            }
        }
    }

    // Fallback: compute directly using cathedral-utils f64 engine
    eprintln!("  🔧 Computing G_{} directly (f64 engine)...", n);
    let t0 = std::time::Instant::now();
    let mut g = DMatrix::zeros(n, n);
    for j in 0..n {
        for k in j..n {
            let val = cathedral_utils::gram::gram_entry_f64(j + 1, k + 1);
            g[(j, k)] = val;
            g[(k, j)] = val;
        }
    }
    eprintln!(
        "  ✅ Computed G_{} in {:.2}s",
        n,
        t0.elapsed().as_secs_f64()
    );
    g
}

fn main() {
    eprintln!("═══════════════════════════════════════════════════════════════");
    eprintln!("  𝔽₁ HODGE EXPLORER — Arakelov Decomposition Analysis");
    eprintln!("═══════════════════════════════════════════════════════════════");

    // HPDF cache path — relative to repo root (standard convention)
    let hpdf_dir = PathBuf::from("experiments/cache/hpdf");

    // Sieve for Möbius function — go big enough for HPDF files
    let max_n = 10080;
    let mu = arith::mobius_table(max_n + 1);

    // Test schedule: small N first, then ramp up using HPDF
    let test_ns: Vec<usize> = vec![12, 24, 36, 60, 120, 240, 360, 720, 840, 1260, 2520, 5040];

    println!(
        "\n{:<6} {:>10} {:>10} {:>10} {:>10} {:>8} {:>6} {:>6} {:>6}",
        "N", "vᵀGv", "vᵀB₁v", "vᵀL₁v", "deg(v)", "L₁+eig", "L₁-eig", "L₁dim0", "G_eig+"
    );
    println!("{}", "─".repeat(96));

    for &n in &test_ns {
        if n > max_n {
            break;
        }

        let g = load_or_compute_gram(n, &hpdf_dir);
        let b1 = build_b1_skeleton(n);
        let l1 = &g - &b1; // perturbation

        let v = build_mobius_witness(n, &mu);

        // Key quantities
        let vtgv = v.dot(&(&g * &v));
        let vtb1v = v.dot(&(&b1 * &v));
        let vtl1v = v.dot(&(&l1 * &v));
        let deg_v: f64 = v.iter().sum();

        // Eigenvalue analysis of L₁ on degree-0 subspace
        let l1_deg0 = project_to_degree_zero(&l1);
        let l1_eig = l1_deg0.symmetric_eigenvalues();
        let n_pos_l1 = l1_eig.iter().filter(|&&e| e > 1e-12).count();
        let n_neg_l1 = l1_eig.iter().filter(|&&e| e < -1e-12).count();

        // Eigenvalue analysis of G on degree-0
        let g_deg0 = project_to_degree_zero(&g);
        let g_eig = g_deg0.symmetric_eigenvalues();
        let n_pos_g = g_eig.iter().filter(|&&e| e > 1e-12).count();

        // Dimension of L₁ degree-0 "kernel" (near-zero eigenvalues)
        let l1_dim0 = l1_eig
            .iter()
            .filter(|&&e| e.abs() <= 1e-12)
            .count();

        println!(
            "{:<6} {:>10.6} {:>10.6} {:>10.6} {:>10.6} {:>8} {:>6} {:>6} {:>6}",
            n, vtgv, vtb1v, vtl1v, deg_v, n_pos_l1, n_neg_l1, l1_dim0, n_pos_g
        );
    }

    // Detailed analysis at N=120
    println!("\n═══════════════════════════════════════════════════════════════");
    println!("  DETAILED ANALYSIS at N=120");
    println!("═══════════════════════════════════════════════════════════════");

    let n = 120;
    let g = load_or_compute_gram(n, &hpdf_dir);
    let b1 = build_b1_skeleton(n);
    let l1 = &g - &b1;
    let v = build_mobius_witness(n, &mu);

    // Smith decomposition: vᵀB₁v = Σ J₂(d)/12 · y_d²
    println!("\n--- Smith Decomposition: vᵀB₁v = Σ J₂(d)/12 · y_d² ---");
    let smith = smith_decomposition(&v, n);
    println!("  Top 10 contributors:");
    println!("  {:>6} {:>12} {:>12} {:>12}", "d", "y_d", "J₂(d)/12", "contribution");
    for (i, (d, y_d, contrib)) in smith.iter().take(10).enumerate() {
        println!(
            "  {:>6} {:>12.8} {:>12.6} {:>12.8}{}",
            d,
            y_d,
            jordan_totient_2(*d) / 12.0,
            contrib,
            if i == 0 { " ← dominant" } else { "" }
        );
    }
    let b1_total: f64 = smith.iter().map(|(_, _, c)| c).sum();
    println!("  Total vᵀB₁v = {:.8} (sum of {} nonzero terms)", b1_total, smith.len());

    // L₁ eigenvalue spectrum on degree-0
    println!("\n--- L₁ Eigenvalues on Degree-0 Subspace ---");
    let l1_deg0 = project_to_degree_zero(&l1);
    let l1_eig_full = l1_deg0.symmetric_eigen();
    let mut eig_pairs: Vec<(f64, usize)> = l1_eig_full
        .eigenvalues
        .iter()
        .enumerate()
        .map(|(i, &e)| (e, i))
        .filter(|(e, _)| e.abs() > 1e-12)
        .collect();
    eig_pairs.sort_by(|a, b| b.0.partial_cmp(&a.0).unwrap());

    let n_pos = eig_pairs.iter().filter(|(e, _)| *e > 0.0).count();
    println!(
        "  Positive eigenvalues: {} (the 'mystery' constant count)",
        n_pos
    );
    println!("  Top 5 positive:");
    for (e, _idx) in eig_pairs.iter().take(5) {
        if *e > 0.0 {
            println!("    λ = {:.8}", e);
        }
    }
    println!("  Bottom 5 negative:");
    for (e, _idx) in eig_pairs.iter().rev().take(5) {
        println!("    λ = {:.8}", e);
    }

    // Degree evolution
    println!("\n--- Degree Functional: deg(v) = Σ v_k ---");
    println!("  {:>6} {:>12} {:>12}", "N", "deg(v)", "|deg(v)|/deg₀");
    let deg_0 = {
        let v0 = build_mobius_witness(12, &mu);
        v0.iter().sum::<f64>().abs()
    };
    for &n in &test_ns {
        if n > max_n {
            break;
        }
        let v = build_mobius_witness(n, &mu);
        let deg: f64 = v.iter().sum();
        println!(
            "  {:>6} {:>12.8} {:>12.4}",
            n,
            deg,
            deg.abs() / deg_0
        );
    }

    // Mertens connection
    println!("\n--- PNT Connection: Σ μ(k)/k and Mertens sums ---");
    for &n in &[100, 500, 1000, 2000] {
        if n > max_n {
            break;
        }
        let s1 = mertens::pnt_s1(&mu, n);
        let s2 = mertens::pnt_s2(&mu, n);
        println!(
            "  N={:>5}: S₁ = Σ μ(k)/k = {:>12.8}, S₂ = Σ μ(k)ln(k)/k = {:>12.8}",
            n, s1, s2
        );
    }

    println!("\n═══════════════════════════════════════════════════════════════");
    println!("  𝔽₁ HODGE EXPLORER — Complete");
    println!("═══════════════════════════════════════════════════════════════");
}
