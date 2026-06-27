//! ═══════════════════════════════════════════════════════════════════════════
//!  BLOCK SPECTRAL ANALYSIS — ACCELERATED
//!
//!  For each GCD class d, extract the Gram submatrix G^{(d)} and compute
//!  eigenvalues using Apple Accelerate's LAPACK.
//!
//!  OPTIMIZATIONS:
//!    1. dsyevd via Apple Accelerate — 10-50x faster than pure Rust
//!    2. dsyevr for SELECTIVE eigenvalues — compute ONLY λ_min without
//!       full decomposition (orders of magnitude faster for large matrices)
//!    3. Blocks sorted largest-first — better load balancing for small blocks
//!    4. Large matrices processed sequentially — LAPACK uses all cores
//!       internally via Accelerate, so rayon parallelism hurts for dim > 1000
//!    5. Works directly with raw Vec<f64> — no DMatrix copy
//!
//! ═══════════════════════════════════════════════════════════════════════════

use crate::gcd_decomp::GcdDecomposition;
use rayon::prelude::*;

// ═══════════════════════════════════════════════════════════════
// LAPACK FFI — Apple Accelerate framework
// ═══════════════════════════════════════════════════════════════

extern "C" {
    /// LAPACK dsyevd: Divide-and-conquer symmetric eigendecomposition.
    /// Computes ALL eigenvalues. Good for medium matrices.
    fn dsyevd_(
        jobz: *const u8,
        uplo: *const u8,
        n: *const i32,
        a: *mut f64,
        lda: *const i32,
        w: *mut f64,
        work: *mut f64,
        lwork: *const i32,
        iwork: *mut i32,
        liwork: *const i32,
        info: *mut i32,
    );

    /// LAPACK dsyevr: Relatively Robust Representations.
    /// Can compute a SUBSET of eigenvalues (e.g., just the smallest).
    /// Much faster than dsyevd when you only need a few eigenvalues.
    fn dsyevr_(
        jobz: *const u8,
        range: *const u8,
        uplo: *const u8,
        n: *const i32,
        a: *mut f64,
        lda: *const i32,
        vl: *const f64,
        vu: *const f64, // value range (for range='V')
        il: *const i32,
        iu: *const i32, // index range (for range='I')
        abstol: *const f64,
        m: *mut i32, // num eigenvalues found
        w: *mut f64,
        z: *mut f64,
        ldz: *const i32,
        isuppz: *mut i32,
        work: *mut f64,
        lwork: *const i32,
        iwork: *mut i32,
        liwork: *const i32,
        info: *mut i32,
    );
}

/// Compute ALL eigenvalues of a symmetric matrix using dsyevd.
fn eigenvalues_all(mat: &[f64], n: usize) -> Vec<f64> {
    if n == 0 {
        return vec![];
    }
    let mut a = mat.to_vec();
    let mut w = vec![0.0f64; n];
    let n_i32 = n as i32;
    let mut info: i32 = 0;

    // Workspace query
    let mut work_q = [0.0f64; 1];
    let mut iwork_q = [0i32; 1];
    let neg1: i32 = -1;
    unsafe {
        dsyevd_(
            b"N".as_ptr(),
            b"U".as_ptr(),
            &n_i32,
            a.as_mut_ptr(),
            &n_i32,
            w.as_mut_ptr(),
            work_q.as_mut_ptr(),
            &neg1,
            iwork_q.as_mut_ptr(),
            &neg1,
            &mut info,
        );
    }
    if info != 0 {
        return vec![];
    }

    let lwork = work_q[0] as i32;
    let liwork = iwork_q[0];
    let mut work = vec![0.0f64; lwork as usize];
    let mut iwork = vec![0i32; liwork as usize];

    unsafe {
        dsyevd_(
            b"N".as_ptr(),
            b"U".as_ptr(),
            &n_i32,
            a.as_mut_ptr(),
            &n_i32,
            w.as_mut_ptr(),
            work.as_mut_ptr(),
            &lwork,
            iwork.as_mut_ptr(),
            &liwork,
            &mut info,
        );
    }
    if info != 0 {
        return vec![];
    }
    w
}

/// Compute only the K smallest eigenvalues using dsyevr.
/// Much faster than full decomposition for large matrices.
fn eigenvalues_smallest(mat: &[f64], n: usize, k: usize) -> Vec<f64> {
    if n == 0 || k == 0 {
        return vec![];
    }
    let k = k.min(n);
    let mut a = mat.to_vec();
    let n_i32 = n as i32;
    let il: i32 = 1;
    let iu: i32 = k as i32;
    let abstol: f64 = 0.0; // Use default (safe) tolerance
    let mut m: i32 = 0;
    let mut w = vec![0.0f64; n]; // eigenvalue output
    let ldz: i32 = 1;
    let mut z = vec![0.0f64; 1]; // no eigenvectors needed
    let mut isuppz = vec![0i32; 2 * k];
    let mut info: i32 = 0;
    let vl: f64 = 0.0;
    let vu: f64 = 0.0;

    // Workspace query
    let mut work_q = [0.0f64; 1];
    let mut iwork_q = [0i32; 1];
    let neg1: i32 = -1;
    unsafe {
        dsyevr_(
            b"N".as_ptr(),
            b"I".as_ptr(),
            b"U".as_ptr(),
            &n_i32,
            a.as_mut_ptr(),
            &n_i32,
            &vl,
            &vu,
            &il,
            &iu,
            &abstol,
            &mut m,
            w.as_mut_ptr(),
            z.as_mut_ptr(),
            &ldz,
            isuppz.as_mut_ptr(),
            work_q.as_mut_ptr(),
            &neg1,
            iwork_q.as_mut_ptr(),
            &neg1,
            &mut info,
        );
    }
    if info != 0 {
        eprintln!("  ⚠ dsyevr workspace query failed (info={info}, n={n})");
        return eigenvalues_all(mat, n); // fallback
    }

    let lwork = work_q[0] as i32;
    let liwork = iwork_q[0];
    let mut work = vec![0.0f64; lwork as usize];
    let mut iwork = vec![0i32; liwork as usize];

    unsafe {
        dsyevr_(
            b"N".as_ptr(),
            b"I".as_ptr(),
            b"U".as_ptr(),
            &n_i32,
            a.as_mut_ptr(),
            &n_i32,
            &vl,
            &vu,
            &il,
            &iu,
            &abstol,
            &mut m,
            w.as_mut_ptr(),
            z.as_mut_ptr(),
            &ldz,
            isuppz.as_mut_ptr(),
            work.as_mut_ptr(),
            &lwork,
            iwork.as_mut_ptr(),
            &liwork,
            &mut info,
        );
    }
    if info != 0 {
        eprintln!("  ⚠ dsyevr failed (info={info}, n={n}), falling back to dsyevd");
        return eigenvalues_all(mat, n);
    }

    w[..m as usize].to_vec()
}

/// Compute λ_min of a large matrix using dsyevr (fastest path).
pub fn lambda_min_only(mat: &[f64], n: usize) -> f64 {
    let evals = eigenvalues_smallest(mat, n, 1);
    evals.first().copied().unwrap_or(f64::NAN)
}

/// Compute λ_min and λ_max using dsyevr (compute 3 smallest + 3 largest).
pub fn lambda_min_max(mat: &[f64], n: usize) -> (f64, f64) {
    if n == 0 {
        return (0.0, 0.0);
    }
    let smallest = eigenvalues_smallest(mat, n, 3);
    let lmin = smallest.first().copied().unwrap_or(0.0);

    // For λ_max, compute eigenvalues n-2..n (the 3 largest)
    let k = 3.min(n);
    let mut a = mat.to_vec();
    let n_i32 = n as i32;
    let il: i32 = (n - k + 1) as i32;
    let iu: i32 = n as i32;
    let abstol: f64 = 0.0;
    let mut m: i32 = 0;
    let mut w = vec![0.0f64; n];
    let ldz: i32 = 1;
    let mut z = vec![0.0f64; 1];
    let mut isuppz = vec![0i32; 2 * k];
    let mut info: i32 = 0;
    let vl: f64 = 0.0;
    let vu: f64 = 0.0;

    let mut work_q = [0.0f64; 1];
    let mut iwork_q = [0i32; 1];
    let neg1: i32 = -1;
    unsafe {
        dsyevr_(
            b"N".as_ptr(),
            b"I".as_ptr(),
            b"U".as_ptr(),
            &n_i32,
            a.as_mut_ptr(),
            &n_i32,
            &vl,
            &vu,
            &il,
            &iu,
            &abstol,
            &mut m,
            w.as_mut_ptr(),
            z.as_mut_ptr(),
            &ldz,
            isuppz.as_mut_ptr(),
            work_q.as_mut_ptr(),
            &neg1,
            iwork_q.as_mut_ptr(),
            &neg1,
            &mut info,
        );
    }
    if info != 0 {
        return (lmin, lmin);
    }

    let lwork = work_q[0] as i32;
    let liwork = iwork_q[0];
    let mut work = vec![0.0f64; lwork as usize];
    let mut iwork = vec![0i32; liwork as usize];
    unsafe {
        dsyevr_(
            b"N".as_ptr(),
            b"I".as_ptr(),
            b"U".as_ptr(),
            &n_i32,
            a.as_mut_ptr(),
            &n_i32,
            &vl,
            &vu,
            &il,
            &iu,
            &abstol,
            &mut m,
            w.as_mut_ptr(),
            z.as_mut_ptr(),
            &ldz,
            isuppz.as_mut_ptr(),
            work.as_mut_ptr(),
            &lwork,
            iwork.as_mut_ptr(),
            &liwork,
            &mut info,
        );
    }
    let lmax = if info == 0 && m > 0 {
        w[(m - 1) as usize]
    } else {
        lmin
    };
    (lmin, lmax)
}

// ═══════════════════════════════════════════════════════════════
// BLOCK SPECTRAL RESULTS
// ═══════════════════════════════════════════════════════════════

/// Result of spectral analysis on a single GCD block.
#[derive(Debug, Clone)]
pub struct BlockSpectralResult {
    pub gcd_class: usize,
    pub dim: usize,
    pub lambda_min: f64,
    pub lambda_max: f64,
    pub eigenvalues: Vec<f64>,
    pub trace: f64,
    pub frobenius_norm: f64,
}

/// Threshold for storing full eigenvalue vector vs just min/max.
const STORE_EVALS_THRESHOLD: usize = 500;

/// Threshold above which blocks run sequentially (LAPACK uses all cores internally).
const SEQUENTIAL_THRESHOLD: usize = 1000;

// ═══════════════════════════════════════════════════════════════
// SUBMATRIX EXTRACTION
// ═══════════════════════════════════════════════════════════════

fn extract_submatrix_raw(
    data: &[f64],
    full_dim: usize,
    indices: &[usize],
    max_n: usize,
) -> (Vec<f64>, usize) {
    let valid: Vec<usize> = indices
        .iter()
        .filter(|&&j| j >= 2 && j <= max_n && (j - 2) < full_dim)
        .cloned()
        .collect();
    let n = valid.len();
    if n < 2 {
        return (vec![], 0);
    }
    let mut sub = vec![0.0f64; n * n];
    for (i, &ri) in valid.iter().enumerate() {
        let row = ri - 2;
        for (j, &ci) in valid.iter().enumerate() {
            let col = ci - 2;
            sub[i * n + j] = data[row * full_dim + col];
        }
    }
    (sub, n)
}

// ═══════════════════════════════════════════════════════════════
// BLOCK ANALYSIS — HYBRID PARALLEL/SEQUENTIAL
// ═══════════════════════════════════════════════════════════════

/// Analyze GCD-class blocks with hybrid parallelism.
///
/// - Small blocks (dim ≤ SEQUENTIAL_THRESHOLD): parallel via rayon
/// - Large blocks (dim > SEQUENTIAL_THRESHOLD): sequential, each gets all cores
///
/// This prevents LAPACK calls from fighting over CPU cores.
pub fn analyze_blocks_raw(
    data: &[f64],
    full_dim: usize,
    decomp: &GcdDecomposition,
    max_n: usize,
    max_eigen_dim: usize,
) -> Vec<BlockSpectralResult> {
    // Precompute valid dimensions
    let mut classes: Vec<(usize, &Vec<usize>, usize)> = decomp
        .classes
        .iter()
        .filter_map(|(&d, indices)| {
            let valid = indices
                .iter()
                .filter(|&&j| j >= 2 && j <= max_n && (j - 2) < full_dim)
                .count();
            if valid >= 2 && valid <= max_eigen_dim {
                Some((d, indices, valid))
            } else {
                None
            }
        })
        .collect();

    // Sort largest first
    classes.sort_by(|a, b| b.2.cmp(&a.2));

    let total = classes.len();
    let t0 = std::time::Instant::now();

    // Split into large (sequential) and small (parallel) groups
    let (large, small): (Vec<_>, Vec<_>) = classes
        .into_iter()
        .partition(|&(_, _, dim)| dim > SEQUENTIAL_THRESHOLD);

    let mut results = Vec::with_capacity(total);

    // Process LARGE blocks SEQUENTIALLY — each LAPACK call uses all cores
    if !large.is_empty() {
        eprintln!("  \x1b[2m     Processing {} large blocks sequentially (dim > {SEQUENTIAL_THRESHOLD})...\x1b[0m",
                  large.len());
    }
    for (i, (d, indices, _)) in large.iter().enumerate() {
        let (sub_data, n) = extract_submatrix_raw(data, full_dim, indices, max_n);
        if n < 2 {
            continue;
        }

        let trace: f64 = (0..n).map(|k| sub_data[k * n + k]).sum();
        let frobenius_norm = sub_data.iter().map(|x| x * x).sum::<f64>().sqrt();

        eprint!(
            "\r  \x1b[2m     [{}/{}] d={d} dim={n} → dsyevr(λ_min, λ_max)...\x1b[0m          ",
            i + 1,
            large.len()
        );

        // Use dsyevr for just λ_min and λ_max (much faster than full decomp)
        let (lambda_min, lambda_max) = lambda_min_max(&sub_data, n);

        eprintln!("\r  \x1b[2m     [{}/{}] d={d} dim={n} → λ_min={lambda_min:.6e}  ({:.1}s)\x1b[0m          ",
                  i + 1, large.len(), t0.elapsed().as_secs_f64());

        results.push(BlockSpectralResult {
            gcd_class: *d,
            dim: n,
            lambda_min,
            lambda_max,
            eigenvalues: vec![],
            trace,
            frobenius_norm,
        });
    }

    // Process SMALL blocks in PARALLEL via rayon
    if !small.is_empty() {
        eprint!(
            "\r  \x1b[2m     Processing {} small blocks in parallel...\x1b[0m          ",
            small.len()
        );
    }
    let done = std::sync::atomic::AtomicUsize::new(0);
    let small_results: Vec<BlockSpectralResult> = small
        .par_iter()
        .filter_map(|&(d, indices, _)| {
            let (sub_data, n) = extract_submatrix_raw(data, full_dim, indices, max_n);
            if n < 2 {
                return None;
            }

            let trace: f64 = (0..n).map(|k| sub_data[k * n + k]).sum();
            let frobenius_norm = sub_data.iter().map(|x| x * x).sum::<f64>().sqrt();

            // Full eigendecomp for small blocks (fast enough)
            let eigenvalues = eigenvalues_all(&sub_data, n);
            if eigenvalues.is_empty() {
                return None;
            }
            let lambda_min = eigenvalues[0];
            let lambda_max = eigenvalues[eigenvalues.len() - 1];

            let stored = if n <= STORE_EVALS_THRESHOLD {
                eigenvalues
            } else {
                vec![]
            };

            let count = done.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
            if small.len() > 100 && count.is_multiple_of((small.len() / 10).max(1)) {
                eprint!(
                    "\r  \x1b[2m     small: {count}/{} ({:.0}%)\x1b[0m          ",
                    small.len(),
                    count as f64 / small.len() as f64 * 100.0
                );
            }

            Some(BlockSpectralResult {
                gcd_class: d,
                dim: n,
                lambda_min,
                lambda_max,
                eigenvalues: stored,
                trace,
                frobenius_norm,
            })
        })
        .collect();

    results.extend(small_results);
    if total > 20 {
        eprintln!();
    }

    results.sort_by_key(|r| r.gcd_class);
    results
}

/// Compute λ_min of the FULL Gram matrix at a given N.
/// Uses dsyevr to extract only the smallest eigenvalue.
/// The matrix data is raw row-major f64 with dimension `dim`.
pub fn full_matrix_lambda_min(data: &[f64], dim: usize) -> f64 {
    lambda_min_only(data, dim)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_eigenvalues_all_identity() {
        let mat = vec![1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0];
        let evals = eigenvalues_all(&mat, 3);
        assert_eq!(evals.len(), 3);
        for &e in &evals {
            assert!((e - 1.0).abs() < 1e-10);
        }
    }

    #[test]
    fn test_eigenvalues_smallest() {
        let mat = vec![1.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0, 0.0, 3.0];
        let evals = eigenvalues_smallest(&mat, 3, 2);
        assert_eq!(evals.len(), 2);
        assert!((evals[0] - 1.0).abs() < 1e-10);
        assert!((evals[1] - 2.0).abs() < 1e-10);
    }

    #[test]
    fn test_lambda_min_max() {
        let mat = vec![1.0, 0.0, 0.0, 0.0, 5.0, 0.0, 0.0, 0.0, 3.0];
        let (lmin, lmax) = lambda_min_max(&mat, 3);
        assert!((lmin - 1.0).abs() < 1e-10);
        assert!((lmax - 5.0).abs() < 1e-10);
    }
}
