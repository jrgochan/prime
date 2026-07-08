//! # Scaling Mode: Dense d²_opt sweep from HPDF Gram matrices
//!
//! Reads the largest available HPDF .h5 file (e.g. N=55440), then
//! computes d²_opt for EVERY integer N from 2 to `--max` by extracting
//! the leading (N-1)×(N-1) submatrix of the stored Gram data.
//!
//! Key insight: G(j,k) = ∫₀¹ {1/(jx)}{1/(kx)} dx is independent of N,
//! so the Gram matrix for any N' ≤ N is just the top-left subblock.
//!
//! PARALLELIZED via rayon — each N is independent.
//!
//! Created: May 30, 2026 — The Scaling Law Hunt

use nalgebra::{DMatrix, DVector};
use rayon::prelude::*;
use std::path::Path;
use std::sync::Arc;
use std::time::Instant;

pub fn run(h5_dir: &str, max_n: usize) {
    eprintln!();
    eprintln!("{}", "═".repeat(70));
    eprintln!("SCALING MODE — Dense d²_opt sweep (PARALLEL)");
    eprintln!("{}", "═".repeat(70));
    eprintln!();

    // Find the smallest H5 file that covers our max_n
    let dir = Path::new(h5_dir);
    let mut files: Vec<(usize, std::path::PathBuf)> = std::fs::read_dir(dir)
        .expect("Cannot read H5 directory")
        .filter_map(|e| e.ok())
        .filter(|e| {
            let name = e.file_name();
            let name = name.to_string_lossy();
            name.starts_with("gram_N") && name.ends_with(".h5")
        })
        .map(|e| {
            let name = e.file_name();
            let name = name.to_string_lossy().to_string();
            let n: usize = name
                .strip_prefix("gram_N")
                .unwrap()
                .strip_suffix(".h5")
                .unwrap()
                .parse()
                .unwrap_or(0);
            (n, e.path())
        })
        .collect();
    files.sort_by_key(|(n, _)| *n);

    // Pick the smallest file >= max_n, or the largest available
    let (file_n, file_path) = files
        .iter()
        .find(|(n, _)| *n >= max_n)
        .or_else(|| files.last())
        .expect("No HPDF files found!");

    let effective_max = max_n.min(*file_n);

    eprintln!("Using HPDF file: N={file_n} ({})", file_path.display());
    eprintln!("Sweep range: N = 2 to {effective_max}");
    eprintln!("Threads: {}", rayon::current_num_threads());
    eprintln!();

    // ═══ Load data ═══
    let t_load = Instant::now();

    let h5_file = hdf5::File::open(file_path).expect("Failed to open H5 file");
    let file_dim: u64 = h5_file
        .attr("dim")
        .expect("no dim attr")
        .read_scalar()
        .expect("read dim");
    let file_dim = file_dim as usize;

    // Read upper triangle into Arc for sharing across threads
    let ds = h5_file
        .dataset("gram/upper_triangle")
        .expect("No upper_triangle");
    let tri_arr: ndarray::Array1<f64> = ds.read_1d().expect("Failed to read triangle");
    let tri: Arc<Vec<f64>> = Arc::new(tri_arr.to_vec());

    // Read b_vector
    let b_ds = h5_file.dataset("b_vector").expect("No b_vector");
    let b_arr: ndarray::Array1<f64> = b_ds.read_1d().expect("Failed to read b_vector");
    let b_full: Arc<Vec<f64>> = Arc::new(b_arr.to_vec());

    let load_time = t_load.elapsed().as_secs_f64();
    eprintln!(
        "Loaded: dim={file_dim}, triangle={} entries, b={} entries ({load_time:.1}s)",
        tri.len(),
        b_full.len()
    );

    // ═══ Precompute number theory ═══
    let t_nt = Instant::now();

    // Sieve of Eratosthenes
    let mut is_prime = vec![true; effective_max + 1];
    is_prime[0] = false;
    if effective_max >= 1 {
        is_prime[1] = false;
    }
    for i in 2..=effective_max {
        if is_prime[i] {
            let mut j = i * i;
            while j <= effective_max {
                is_prime[j] = false;
                j += i;
            }
        }
    }

    // Divisor count τ(n)
    let mut tau = vec![0u32; effective_max + 1];
    for i in 1..=effective_max {
        let mut j = i;
        while j <= effective_max {
            tau[j] += 1;
            j += i;
        }
    }

    // Classify: is this an HCN? (record-breaking τ)
    let mut is_hcn = vec![false; effective_max + 1];
    let mut max_tau: u32 = 0;
    for n in 1..=effective_max {
        if tau[n] > max_tau {
            max_tau = tau[n];
            is_hcn[n] = true;
        }
    }

    let nt_time = t_nt.elapsed().as_secs_f64();
    let hcn_count = is_hcn.iter().filter(|&&x| x).count();
    let prime_count = is_prime[2..].iter().filter(|&&x| x).count();
    eprintln!("Number theory: {prime_count} primes, {hcn_count} HCNs ({nt_time:.3}s)");
    eprintln!();

    // ═══ Parallel sweep ═══
    eprintln!("Computing d²_opt for N=2..{effective_max} ...");
    let t_sweep = Instant::now();

    // Result struct for each N
    struct ScalingResult {
        n: usize,
        d2: f64,
        ln_n: f64,
    }

    // Process all N values in parallel using rayon
    let results: Vec<ScalingResult> = (2..=effective_max)
        .into_par_iter()
        .map(|n| {
            let dim = n - 1;
            let tri = &tri;
            let b_full = &b_full;

            // Helper: get G(row, col) from flat upper triangle (0-indexed)
            let gram_entry = |row: usize, col: usize| -> f64 {
                let (r, c) = if row <= col { (row, col) } else { (col, row) };
                let idx = r * file_dim - r * (r.wrapping_sub(1)) / 2 + (c - r);
                tri[idx]
            };

            // Build leading dim×dim submatrix
            let g_sub = DMatrix::from_fn(dim, dim, gram_entry);
            let b_sub = DVector::from_fn(dim, |i, _| b_full[i]);

            // Cholesky solve
            let d2 = match g_sub.clone().cholesky() {
                Some(chol) => {
                    let v = chol.solve(&b_sub);
                    1.0 - b_sub.dot(&v)
                }
                None => match g_sub.lu().solve(&b_sub) {
                    Some(v) => 1.0 - b_sub.dot(&v),
                    None => f64::NAN,
                },
            };

            ScalingResult {
                n,
                d2,
                ln_n: (n as f64).ln(),
            }
        })
        .collect();

    let sweep_time = t_sweep.elapsed().as_secs_f64();
    let rate = results.len() as f64 / sweep_time;
    eprintln!(
        "Done: {} values in {sweep_time:.1}s ({rate:.0} N/s)",
        results.len()
    );
    eprintln!();

    // ═══ Output ═══
    println!("# Dense d²_opt scaling sweep (PARALLEL)");
    println!("# Source: gram_N{file_n}.h5 (dim={file_dim})");
    println!("N\td2_opt\tln_N\td2_lnN\td2_ln2N\tis_prime\tis_hcn\ttau\tclass");

    for r in &results {
        let n = r.n;
        let d2 = r.d2;
        let ln_n = r.ln_n;
        let d2_ln = d2 * ln_n;
        let d2_ln2 = d2 * ln_n * ln_n;
        let p = if is_prime[n] { 1 } else { 0 };
        let h = if is_hcn[n] { 1 } else { 0 };
        let t = tau[n];
        let class = if is_hcn[n] {
            "HCN"
        } else if is_prime[n] {
            "prime"
        } else {
            "comp"
        };

        println!("{n}\t{d2:.12e}\t{ln_n:.6}\t{d2_ln:.10}\t{d2_ln2:.10}\t{p}\t{h}\t{t}\t{class}");
    }
}
