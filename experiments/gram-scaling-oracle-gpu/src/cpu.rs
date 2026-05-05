//! ═══════════════════════════════════════════════════════════════════════════
//!  CPU EIGENDECOMPOSITION — OpenBLAS LAPACK
//!
//!  Fallback path using OpenBLAS dsyevr for λ_min-only computation.
//!  Uses all 16 cores of the Ryzen 9 7950X3D via OpenBLAS threading.
//!
//!  dsyevr is ideal for extracting just a few eigenvalues — it's
//!  orders of magnitude faster than full decomposition for large N.
//! ═══════════════════════════════════════════════════════════════════════════

use std::ffi::c_int;
use std::time::Instant;

// ═══════════════════════════════════════════════════════════════
// LAPACK FFI — OpenBLAS
// ═══════════════════════════════════════════════════════════════

#[link(name = "openblas")]
extern "C" {
    /// LAPACK dsyevd: Divide-and-conquer symmetric eigendecomposition.
    /// Computes ALL eigenvalues. Used for full spectrum analysis.
    fn dsyevd_(
        jobz: *const u8, uplo: *const u8, n: *const c_int,
        a: *mut f64, lda: *const c_int, w: *mut f64,
        work: *mut f64, lwork: *const c_int,
        iwork: *mut c_int, liwork: *const c_int,
        info: *mut c_int,
    );

    /// LAPACK dsyevr: Relatively Robust Representations.
    /// Can compute a SUBSET of eigenvalues (e.g., just the smallest).
    /// Much faster than dsyevd when you only need a few eigenvalues.
    fn dsyevr_(
        jobz: *const u8, range: *const u8, uplo: *const u8,
        n: *const c_int, a: *mut f64, lda: *const c_int,
        vl: *const f64, vu: *const f64,
        il: *const c_int, iu: *const c_int,
        abstol: *const f64, m: *mut c_int,
        w: *mut f64, z: *mut f64, ldz: *const c_int,
        isuppz: *mut c_int,
        work: *mut f64, lwork: *const c_int,
        iwork: *mut c_int, liwork: *const c_int,
        info: *mut c_int,
    );
}

// ═══════════════════════════════════════════════════════════════
// PUBLIC API
// ═══════════════════════════════════════════════════════════════

/// Compute ALL eigenvalues of a symmetric matrix using dsyevd.
pub fn eigenvalues_all(mat: &[f64], n: usize) -> Vec<f64> {
    if n == 0 { return vec![]; }
    let mut a = mat.to_vec();
    let mut w = vec![0.0f64; n];
    let n_i32 = n as c_int;
    let mut info: c_int = 0;

    // Workspace query
    let mut work_q = [0.0f64; 1];
    let mut iwork_q = [0i32; 1];
    let neg1: c_int = -1;
    unsafe {
        dsyevd_(b"N".as_ptr(), b"L".as_ptr(), &n_i32,
                a.as_mut_ptr(), &n_i32, w.as_mut_ptr(),
                work_q.as_mut_ptr(), &neg1, iwork_q.as_mut_ptr(), &neg1,
                &mut info);
    }
    if info != 0 { return vec![]; }

    let lwork = work_q[0] as c_int;
    let liwork = iwork_q[0];
    let mut work = vec![0.0f64; lwork as usize];
    let mut iwork = vec![0i32; liwork as usize];

    unsafe {
        dsyevd_(b"N".as_ptr(), b"L".as_ptr(), &n_i32,
                a.as_mut_ptr(), &n_i32, w.as_mut_ptr(),
                work.as_mut_ptr(), &lwork, iwork.as_mut_ptr(), &liwork,
                &mut info);
    }
    if info != 0 { return vec![]; }
    w
}

/// Compute only the K smallest eigenvalues using dsyevr.
/// Much faster than full decomposition for large matrices.
pub fn eigenvalues_smallest(mat: &[f64], n: usize, k: usize) -> Vec<f64> {
    if n == 0 || k == 0 { return vec![]; }
    let k = k.min(n);
    let mut a = mat.to_vec();
    let n_i32 = n as c_int;
    let il: c_int = 1;
    let iu: c_int = k as c_int;
    let abstol: f64 = 0.0;
    let mut m: c_int = 0;
    let mut w = vec![0.0f64; n];
    let ldz: c_int = 1;
    let mut z = vec![0.0f64; 1];
    let mut isuppz = vec![0i32; 2 * k];
    let mut info: c_int = 0;
    let vl: f64 = 0.0;
    let vu: f64 = 0.0;

    // Workspace query
    let mut work_q = [0.0f64; 1];
    let mut iwork_q = [0i32; 1];
    let neg1: c_int = -1;
    unsafe {
        dsyevr_(b"N".as_ptr(), b"I".as_ptr(), b"L".as_ptr(),
                &n_i32, a.as_mut_ptr(), &n_i32,
                &vl, &vu, &il, &iu, &abstol, &mut m,
                w.as_mut_ptr(), z.as_mut_ptr(), &ldz, isuppz.as_mut_ptr(),
                work_q.as_mut_ptr(), &neg1, iwork_q.as_mut_ptr(), &neg1,
                &mut info);
    }
    if info != 0 {
        eprintln!("  ⚠ dsyevr workspace query failed (info={info}, n={n})");
        return eigenvalues_all(mat, n);
    }

    let lwork = work_q[0] as c_int;
    let liwork = iwork_q[0];
    let mut work = vec![0.0f64; lwork as usize];
    let mut iwork = vec![0i32; liwork as usize];

    unsafe {
        dsyevr_(b"N".as_ptr(), b"I".as_ptr(), b"L".as_ptr(),
                &n_i32, a.as_mut_ptr(), &n_i32,
                &vl, &vu, &il, &iu, &abstol, &mut m,
                w.as_mut_ptr(), z.as_mut_ptr(), &ldz, isuppz.as_mut_ptr(),
                work.as_mut_ptr(), &lwork, iwork.as_mut_ptr(), &liwork,
                &mut info);
    }
    if info != 0 {
        eprintln!("  ⚠ dsyevr failed (info={info}, n={n}), falling back to dsyevd");
        return eigenvalues_all(mat, n);
    }

    w[..m as usize].to_vec()
}

/// Compute λ_min using dsyevr (fastest CPU path).
pub fn cpu_lambda_min(mat: &[f64], n: usize) -> f64 {
    let evals = eigenvalues_smallest(mat, n, 1);
    evals.first().copied().unwrap_or(f64::NAN)
}

/// Compute λ_min and λ_max using dsyevr.
pub fn cpu_lambda_min_max(mat: &[f64], n: usize) -> (f64, f64) {
    if n == 0 { return (0.0, 0.0); }
    let smallest = eigenvalues_smallest(mat, n, 3);
    let lmin = smallest.first().copied().unwrap_or(0.0);

    // For λ_max, compute eigenvalues n-2..n (the 3 largest)
    let k = 3.min(n);
    let mut a = mat.to_vec();
    let n_i32 = n as c_int;
    let il: c_int = (n - k + 1) as c_int;
    let iu: c_int = n as c_int;
    let abstol: f64 = 0.0;
    let mut m: c_int = 0;
    let mut w = vec![0.0f64; n];
    let ldz: c_int = 1;
    let mut z = vec![0.0f64; 1];
    let mut isuppz = vec![0i32; 2 * k];
    let mut info: c_int = 0;
    let vl: f64 = 0.0;
    let vu: f64 = 0.0;

    let mut work_q = [0.0f64; 1];
    let mut iwork_q = [0i32; 1];
    let neg1: c_int = -1;
    unsafe {
        dsyevr_(b"N".as_ptr(), b"I".as_ptr(), b"L".as_ptr(),
                &n_i32, a.as_mut_ptr(), &n_i32,
                &vl, &vu, &il, &iu, &abstol, &mut m,
                w.as_mut_ptr(), z.as_mut_ptr(), &ldz, isuppz.as_mut_ptr(),
                work_q.as_mut_ptr(), &neg1, iwork_q.as_mut_ptr(), &neg1,
                &mut info);
    }
    if info != 0 { return (lmin, lmin); }

    let lwork = work_q[0] as c_int;
    let liwork = iwork_q[0];
    let mut work = vec![0.0f64; lwork as usize];
    let mut iwork = vec![0i32; liwork as usize];
    unsafe {
        dsyevr_(b"N".as_ptr(), b"I".as_ptr(), b"L".as_ptr(),
                &n_i32, a.as_mut_ptr(), &n_i32,
                &vl, &vu, &il, &iu, &abstol, &mut m,
                w.as_mut_ptr(), z.as_mut_ptr(), &ldz, isuppz.as_mut_ptr(),
                work.as_mut_ptr(), &lwork, iwork.as_mut_ptr(), &liwork,
                &mut info);
    }
    let lmax = if info == 0 && m > 0 { w[(m - 1) as usize] } else { lmin };
    (lmin, lmax)
}

/// Compute λ_min of a full matrix with timing.
pub fn full_matrix_lambda_min(data: &[f64], dim: usize) -> (f64, f64) {
    let t = Instant::now();
    let lmin = cpu_lambda_min(data, dim);
    (lmin, t.elapsed().as_secs_f64())
}
