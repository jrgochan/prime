//! # Scaling Mode v2: Incremental Cholesky for dense d²_opt sweep
//!
//! Instead of rebuilding the Cholesky from scratch for each N (O(N³)),
//! we use the RANK-1 UPDATE identity:
//!
//!   G(N+1) = [ G(N)   g  ]     where g = [G(2,N+1), ..., G(N,N+1)]ᵀ
//!            [ gᵀ    a  ]             a = G(N+1, N+1)
//!
//! If G(N) = L·Lᵀ, then G(N+1) = L'·L'ᵀ where:
//!
//!   L' = [ L    0 ]     with  w = L⁻¹g  (forward solve, O(N²))
//!        [ wᵀ   √(a - ‖w‖²) ]          s = √(a - wᵀw)   (scalar)
//!
//! Similarly, d²(N+1) = 1 - bᵀG⁻¹b can be updated incrementally:
//!
//!   Let z = L⁻¹b, so bᵀG⁻¹b = ‖z‖² = Σ zᵢ².
//!   When going from N to N+1:
//!     z' = [z₁, ..., z_N, (b_{N+1} - wᵀz_old) / s]
//!     bᵀG(N+1)⁻¹b = ‖z'‖² = ‖z‖² + ((b_{N+1} - wᵀz) / s)²
//!
//! Total cost per step: O(N²) for the forward solve L⁻¹g.
//! Total cost for sweep N=2..M: O(M³/3) — same as ONE Cholesky at N=M!
//!
//! This is the OPTIMAL algorithm: we get d²_opt for EVERY integer
//! in the time it takes to do a single factorization at the max N.
//!
//! Created: May 30, 2026 — The Incremental Breakthrough

use std::path::Path;
use std::time::Instant;

pub fn run(h5_dir: &str, max_n: usize) {
    eprintln!();
    eprintln!("{}", "═".repeat(70));
    eprintln!("SCALING v2 — Incremental Cholesky (O(N²) per step)");
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
                .strip_prefix("gram_N").unwrap()
                .strip_suffix(".h5").unwrap()
                .parse().unwrap_or(0);
            (n, e.path())
        })
        .collect();
    files.sort_by_key(|(n, _)| *n);

    let (file_n, file_path) = files.iter()
        .find(|(n, _)| *n >= max_n)
        .or_else(|| files.last())
        .expect("No HPDF files found!");

    let effective_max = max_n.min(*file_n);

    eprintln!("Using HPDF file: N={file_n} ({})", file_path.display());
    eprintln!("Incremental sweep: N = 2 to {effective_max}");
    eprintln!();

    // ═══ Load data ═══
    let t_load = Instant::now();

    let h5_file = hdf5::File::open(file_path).expect("Failed to open H5 file");
    let file_dim: u64 = h5_file.attr("dim").expect("no dim").read_scalar().expect("read dim");
    let file_dim = file_dim as usize;

    let ds = h5_file.dataset("gram/upper_triangle").expect("No upper_triangle");
    let tri_arr: ndarray::Array1<f64> = ds.read_1d().expect("Failed to read triangle");
    let tri: Vec<f64> = tri_arr.to_vec();

    let b_ds = h5_file.dataset("b_vector").expect("No b_vector");
    let b_arr: ndarray::Array1<f64> = b_ds.read_1d().expect("Failed to read b_vector");
    let b_full: Vec<f64> = b_arr.to_vec();

    let load_time = t_load.elapsed().as_secs_f64();
    eprintln!("Loaded: dim={file_dim}, triangle={} entries ({load_time:.1}s)", tri.len());

    // Helper: get G(row, col) from flat upper triangle (0-indexed into file_dim×file_dim)
    let gram = |row: usize, col: usize| -> f64 {
        let (r, c) = if row <= col { (row, col) } else { (col, row) };
        let idx = r * file_dim - r * (r.wrapping_sub(1)) / 2 + (c - r);
        tri[idx]
    };

    // ═══ Precompute number theory ═══
    let mut is_prime = vec![true; effective_max + 1];
    is_prime[0] = false;
    if effective_max >= 1 { is_prime[1] = false; }
    for i in 2..=effective_max {
        if is_prime[i] {
            let mut j = i * i;
            while j <= effective_max {
                is_prime[j] = false;
                j += i;
            }
        }
    }

    let mut tau = vec![0u32; effective_max + 1];
    for i in 1..=effective_max {
        let mut j = i;
        while j <= effective_max {
            tau[j] += 1;
            j += i;
        }
    }

    let mut is_hcn = vec![false; effective_max + 1];
    let mut max_tau: u32 = 0;
    for n in 1..=effective_max {
        if tau[n] > max_tau {
            max_tau = tau[n];
            is_hcn[n] = true;
        }
    }

    // ═══ Incremental Cholesky sweep ═══
    //
    // We maintain:
    //   L: lower triangular Cholesky factor (stored as flat Vec, row-major)
    //   z: the vector L⁻¹b (so bᵀG⁻¹b = ‖z‖²)
    //   norm_z_sq: = ‖z‖² = bᵀG⁻¹b
    //
    // At each step N → N+1 (adding column/row for k=N+1):
    //   1. w = L⁻¹ g  where g = [G(0,dim), ..., G(dim-1,dim)]  (forward solve)
    //   2. s = sqrt(G(dim,dim) - ‖w‖²)                           (new diagonal)
    //   3. Append row [w, s] to L
    //   4. z_new = (b[dim] - wᵀz) / s
    //   5. norm_z_sq += z_new²

    let max_dim = effective_max - 1; // dim = N-1, N goes from 2 to effective_max

    // Allocate L as a flat lower-triangular matrix
    // L[i][j] stored at l_data[i*(i+1)/2 + j] for j <= i
    let tri_size = max_dim * (max_dim + 1) / 2;
    let mut l_data: Vec<f64> = vec![0.0; tri_size];
    let mut z: Vec<f64> = Vec::with_capacity(max_dim);
    let mut norm_z_sq: f64 = 0.0;

    // Helper: index into packed lower triangle
    let l_idx = |row: usize, col: usize| -> usize {
        debug_assert!(col <= row);
        row * (row + 1) / 2 + col
    };

    println!("# Dense d²_opt — Incremental Cholesky v2");
    println!("# Source: gram_N{file_n}.h5 (dim={file_dim})");
    println!("N\td2_opt\tln_N\td2_lnN\td2_ln2N\tis_prime\tis_hcn\ttau\tclass");

    let t_sweep = Instant::now();

    for dim in 1..=max_dim {
        let n = dim + 1; // N = dim + 1 (k ranges from 2 to N, dim = N-1)
        let new_row = dim - 1; // 0-indexed row being added

        if new_row == 0 {
            // First entry: L[0,0] = sqrt(G(0,0))
            let g00 = gram(0, 0);
            let s = g00.sqrt();
            l_data[l_idx(0, 0)] = s;

            // z[0] = b[0] / L[0,0]
            let z0 = b_full[0] / s;
            z.push(z0);
            norm_z_sq = z0 * z0;
        } else {
            // Step 1: Forward solve L * w = g
            // g[j] = G(j, new_row) for j = 0..new_row-1
            let mut w: Vec<f64> = Vec::with_capacity(new_row);
            for i in 0..new_row {
                let mut sum = gram(i, new_row);
                for j in 0..i {
                    sum -= l_data[l_idx(i, j)] * w[j];
                }
                w.push(sum / l_data[l_idx(i, i)]);
            }

            // Step 2: s = sqrt(G(new_row, new_row) - ‖w‖²)
            let w_norm_sq: f64 = w.iter().map(|x| x * x).sum();
            let diag = gram(new_row, new_row);
            let s_sq = diag - w_norm_sq;

            if s_sq <= 0.0 {
                eprintln!("  ⚠ N={n}: Cholesky breakdown (s²={s_sq:.2e}), skipping");
                // Push dummy values to keep dimensions aligned
                for j in 0..new_row {
                    l_data[l_idx(new_row, j)] = w[j];
                }
                l_data[l_idx(new_row, new_row)] = 1e-15; // avoid div by zero
                z.push(0.0);
                continue;
            }
            let s = s_sq.sqrt();

            // Step 3: Store new row of L
            for j in 0..new_row {
                l_data[l_idx(new_row, j)] = w[j];
            }
            l_data[l_idx(new_row, new_row)] = s;

            // Step 4: z_new = (b[new_row] - wᵀz) / s
            let wt_z: f64 = w.iter().zip(z.iter()).map(|(wi, zi)| wi * zi).sum();
            let z_new = (b_full[new_row] - wt_z) / s;

            // Step 5: update
            z.push(z_new);
            norm_z_sq += z_new * z_new;
        }

        let d2 = 1.0 - norm_z_sq;
        let ln_n = (n as f64).ln();
        let d2_ln = d2 * ln_n;
        let d2_ln2 = d2 * ln_n * ln_n;
        let p = if n <= effective_max && is_prime[n] { 1 } else { 0 };
        let h = if n <= effective_max && is_hcn[n] { 1 } else { 0 };
        let t = if n <= effective_max { tau[n] } else { 0 };
        let class = if n <= effective_max && is_hcn[n] { "HCN" }
            else if n <= effective_max && is_prime[n] { "prime" }
            else { "comp" };

        println!("{n}\t{d2:.12e}\t{ln_n:.6}\t{d2_ln:.10}\t{d2_ln2:.10}\t{p}\t{h}\t{t}\t{class}");

        if dim % 5000 == 0 {
            let elapsed = t_sweep.elapsed().as_secs_f64();
            eprintln!("  N={n} (dim={dim}) d²={d2:.8} ({elapsed:.1}s)");
        }
    }

    let total = t_sweep.elapsed().as_secs_f64();
    let rate = max_dim as f64 / total;
    eprintln!();
    eprintln!("Done: {} values in {total:.1}s ({rate:.0} N/s)", max_dim);
    eprintln!("Memory: L triangle = {} entries ({:.1} MB)",
        tri_size, tri_size as f64 * 8.0 / 1e6);
}
