//! ═══════════════════════════════════════════════════════════════════════════
//!  BLOCK SPECTRAL ANALYSIS — ACCELERATED
//!
//!  For each GCD class d, extract the Gram submatrix G^{(d)} and compute
//!  eigenvalues using Apple Accelerate's LAPACK dsyevd (divide-and-conquer).
//!
//!  OPTIMIZATIONS:
//!    1. Direct LAPACK dsyevd via Apple Accelerate — 10-50x faster than
//!       nalgebra's pure Rust implementation for large matrices
//!    2. Blocks sorted largest-first — better load balancing across cores
//!    3. Only store λ_min/λ_max — no huge eigenvalue vector allocations
//!    4. Works directly with raw Vec<f64> — no DMatrix copy for 12+ GB data
//! ═══════════════════════════════════════════════════════════════════════════

use rayon::prelude::*;
use crate::gcd_decomp::GcdDecomposition;

// ═══════════════════════════════════════════════════════════════
// LAPACK FFI — Apple Accelerate framework (always available on macOS)
// ═══════════════════════════════════════════════════════════════

extern "C" {
    /// LAPACK dsyevd: Divide-and-conquer symmetric eigendecomposition.
    /// Much faster than QR-based dsyev for large matrices.
    /// Computes all eigenvalues (and optionally eigenvectors) of a real
    /// symmetric matrix A.
    fn dsyevd_(
        jobz: *const u8,   // 'N' = eigenvalues only, 'V' = + eigenvectors
        uplo: *const u8,   // 'U' = upper triangle, 'L' = lower
        n: *const i32,     // matrix dimension
        a: *mut f64,       // [in/out] matrix data (column-major!)
        lda: *const i32,   // leading dimension of a
        w: *mut f64,       // [out] eigenvalues in ascending order
        work: *mut f64,    // workspace
        lwork: *const i32, // workspace size (-1 for query)
        iwork: *mut i32,   // integer workspace
        liwork: *const i32, // integer workspace size (-1 for query)
        info: *mut i32,    // 0 = success
    );
}

/// Compute all eigenvalues of a symmetric matrix using LAPACK dsyevd.
///
/// Input: `mat` in ROW-major order (will be transposed — symmetric so OK).
/// Returns eigenvalues sorted ascending, or empty vec on failure.
fn eigenvalues_lapack(mat: &[f64], n: usize) -> Vec<f64> {
    if n == 0 { return vec![]; }

    // dsyevd operates in-place on column-major data.
    // For symmetric matrices, row-major == column-major, so we can use directly.
    let mut a = mat.to_vec();
    let mut w = vec![0.0f64; n];
    let n_i32 = n as i32;
    let mut info: i32 = 0;

    // Workspace query
    let mut work_query = [0.0f64; 1];
    let mut iwork_query = [0i32; 1];
    let lwork_query: i32 = -1;
    let liwork_query: i32 = -1;

    unsafe {
        dsyevd_(
            b"N".as_ptr(), b"U".as_ptr(),
            &n_i32, a.as_mut_ptr(), &n_i32,
            w.as_mut_ptr(),
            work_query.as_mut_ptr(), &lwork_query,
            iwork_query.as_mut_ptr(), &liwork_query,
            &mut info,
        );
    }

    if info != 0 {
        eprintln!("  ⚠ dsyevd workspace query failed (info={info})");
        return vec![];
    }

    let lwork = work_query[0] as i32;
    let liwork = iwork_query[0];
    let mut work = vec![0.0f64; lwork as usize];
    let mut iwork = vec![0i32; liwork as usize];

    unsafe {
        dsyevd_(
            b"N".as_ptr(), b"U".as_ptr(),
            &n_i32, a.as_mut_ptr(), &n_i32,
            w.as_mut_ptr(),
            work.as_mut_ptr(), &lwork,
            iwork.as_mut_ptr(), &liwork,
            &mut info,
        );
    }

    if info != 0 {
        eprintln!("  ⚠ dsyevd failed (info={info}, n={n})");
        return vec![];
    }

    w
}

/// Result of spectral analysis on a single GCD block.
#[derive(Debug, Clone)]
pub struct BlockSpectralResult {
    /// The GCD class divisor d.
    pub gcd_class: usize,
    /// Dimension of the block.
    pub dim: usize,
    /// Minimum eigenvalue of the block submatrix.
    pub lambda_min: f64,
    /// Maximum eigenvalue of the block submatrix.
    pub lambda_max: f64,
    /// All eigenvalues (sorted ascending). Only stored for small blocks.
    pub eigenvalues: Vec<f64>,
    /// Trace of the block submatrix.
    pub trace: f64,
    /// Frobenius norm of the block submatrix.
    pub frobenius_norm: f64,
}

/// Maximum block dimension for which we store the full eigenvalue vector.
const STORE_EVALS_THRESHOLD: usize = 500;

/// Extract a submatrix from raw row-major f64 storage.
/// Returns the sub-matrix as a flat Vec<f64> (row-major) and its dimension.
fn extract_submatrix_raw(data: &[f64], full_dim: usize, indices: &[usize], max_n: usize) -> (Vec<f64>, usize) {
    let valid: Vec<usize> = indices.iter()
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

/// Analyze GCD-class blocks using raw matrix data + LAPACK.
///
/// Blocks are sorted LARGEST FIRST for optimal load balancing —
/// the huge blocks start immediately on different cores.
pub fn analyze_blocks_raw(
    data: &[f64],
    full_dim: usize,
    decomp: &GcdDecomposition,
    max_n: usize,
    max_eigen_dim: usize,
) -> Vec<BlockSpectralResult> {
    // Collect eligible classes with precomputed dimensions
    let mut classes: Vec<(usize, &Vec<usize>, usize)> = decomp.classes.iter()
        .filter_map(|(&d, indices)| {
            let valid = indices.iter()
                .filter(|&&j| j >= 2 && j <= max_n && (j - 2) < full_dim)
                .count();
            if valid >= 2 && valid <= max_eigen_dim {
                Some((d, indices, valid))
            } else {
                None
            }
        })
        .collect();

    // Sort LARGEST FIRST — critical for load balancing!
    // Without this, rayon processes tiny blocks first while large blocks
    // queue up and create a long serial tail.
    classes.sort_by(|a, b| b.2.cmp(&a.2));

    let total = classes.len();
    let done = std::sync::atomic::AtomicUsize::new(0);
    let t0 = std::time::Instant::now();

    let results: Vec<BlockSpectralResult> = classes.par_iter()
        .filter_map(|&(d, indices, expected_dim)| {
            let (sub_data, n) = extract_submatrix_raw(data, full_dim, indices, max_n);
            if n < 2 { return None; }

            // Compute trace and Frobenius norm from raw data (no eigendecomp needed)
            let trace: f64 = (0..n).map(|i| sub_data[i * n + i]).sum();
            let frobenius_norm = sub_data.iter().map(|x| x * x).sum::<f64>().sqrt();

            // LAPACK eigendecomposition (hardware-accelerated via Accelerate)
            let eigenvalues = eigenvalues_lapack(&sub_data, n);
            if eigenvalues.is_empty() { return None; }

            let lambda_min = eigenvalues[0];
            let lambda_max = eigenvalues[eigenvalues.len() - 1];

            // Only store full eigenvalue vector for small blocks
            let stored_evals = if n <= STORE_EVALS_THRESHOLD {
                eigenvalues
            } else {
                vec![] // Save memory for large blocks
            };

            let count = done.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
            if total > 20 && (count % (total / 20).max(1) == 0 || n > 1000) {
                let elapsed = t0.elapsed().as_secs_f64();
                eprint!("\r  \x1b[2m     {count}/{total} blocks ({:.0}%) · {elapsed:.1}s · last: d={d} dim={n}\x1b[0m          ",
                        count as f64 / total as f64 * 100.0);
            }

            Some(BlockSpectralResult {
                gcd_class: d,
                dim: n,
                lambda_min,
                lambda_max,
                eigenvalues: stored_evals,
                trace,
                frobenius_norm,
            })
        })
        .collect();

    if total > 20 { eprintln!(); }

    let mut results = results;
    results.sort_by_key(|r| r.gcd_class);
    results
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_eigenvalues_lapack_identity() {
        // 3×3 identity
        let mat = vec![1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0];
        let evals = eigenvalues_lapack(&mat, 3);
        assert_eq!(evals.len(), 3);
        for &e in &evals {
            assert!((e - 1.0).abs() < 1e-10, "eigenvalue {e} != 1.0");
        }
    }

    #[test]
    fn test_eigenvalues_lapack_diagonal() {
        // diag(1, 2, 3)
        let mat = vec![1.0, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0, 0.0, 3.0];
        let evals = eigenvalues_lapack(&mat, 3);
        assert_eq!(evals.len(), 3);
        assert!((evals[0] - 1.0).abs() < 1e-10);
        assert!((evals[1] - 2.0).abs() < 1e-10);
        assert!((evals[2] - 3.0).abs() < 1e-10);
    }

    #[test]
    fn test_extract_submatrix_raw() {
        let data = vec![1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0];
        let indices = vec![2, 4];
        let (sub, n) = extract_submatrix_raw(&data, 3, &indices, 4);
        assert_eq!(n, 2);
        assert_eq!(sub[0], 1.0); // G(2,2)
        assert_eq!(sub[3], 1.0); // G(4,4)
    }
}
