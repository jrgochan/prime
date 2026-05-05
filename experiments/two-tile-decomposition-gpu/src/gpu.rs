//! ═══════════════════════════════════════════════════════════════════════════
//!  GPU MODULE — CUDA FFI for Skeleton Key Certification
//!
//!  Calls the CUDA kernel `launch_skeleton_keys` to certify all coprime
//!  pairs in parallel on GPU. Falls back to CPU if CUDA not available.
//! ═══════════════════════════════════════════════════════════════════════════

use std::ffi::c_int;

// ────────────────────────────────────────────────
// FFI types matching CUDA kernel
// ────────────────────────────────────────────────

/// Full certification result — matches CPU experiment's GraduationResult 1:1.
#[repr(C)]
#[derive(Debug, Clone, Default)]
pub struct PairResult {
    pub a: c_int,
    pub b: c_int,
    pub n_two_tile: c_int,

    // Structural invariants
    pub beta_bijection: c_int,
    pub s_permutation: c_int,
    pub overshoot_identity: c_int,

    // Gauss formula verification
    pub gauss_loggamma_a_err: f64,
    pub gauss_loggamma_b_err: f64,
    pub gauss_digamma_a_err: f64,
    pub gauss_digamma_b_err: f64,

    // Staircase Telescope (Gemini Key 1)
    pub telescope_lg_err: f64,
    pub telescope_psi_err: f64,

    // Beta Modulo Duality (Gemini Key 2)
    pub beta_duality_pw: c_int,
    pub beta_duality_sum_err: f64,

    // Graduation identity
    pub sum_pcl: f64,
    pub delta_target: f64,
    pub identity_err: f64,

    // §11. Abel Cancellation: S₁ + (1/a)·FT = (1/b)·GaussB + (1/(ab))·Σ{ar/b}·ψ((r+1)/b)
    pub abel_cancel_err: f64,

    // §12. Weighted Digamma Reflection: Σ{ar/b}·ψ(r/b) = (1/2)·(Σψ - π·V(b,a))
    pub wdr_err: f64,

    // §13. Coprime Complement: {a(b-r)/b} = 1 - {ar/b}
    pub coprime_complement_ok: c_int,

    // §14. Four-Way Assembly: S₁+S₂+S₃+S₄ individually evaluated = target
    pub fourway_err: f64,

    // Pass/fail
    pub certified: c_int,
}

// ────────────────────────────────────────────────
// CUDA FFI
// ────────────────────────────────────────────────

#[cfg(target_os = "linux")]
extern "C" {
    fn launch_skeleton_keys(
        h_pairs: *const c_int,
        h_results: *mut PairResult,
        n_pairs: c_int,
        max_b: c_int,
    );
}

// ────────────────────────────────────────────────
// CUDA runtime for GPU detection
// ────────────────────────────────────────────────

#[cfg(target_os = "linux")]
#[link(name = "cudart")]
extern "C" {
    fn cudaGetDeviceProperties_v2(prop: *mut CudaDeviceProp, device: c_int) -> c_int;
}

#[cfg(target_os = "linux")]
#[repr(C)]
struct CudaDeviceProp {
    name: [u8; 256],
    total_global_mem: usize,
    _padding: [u8; 1024],
}

pub struct GpuInfo {
    pub name: String,
    pub vram_mb: usize,
}

/// Detect GPU. Returns None on macOS or if CUDA unavailable.
pub fn detect_gpu() -> Option<GpuInfo> {
    #[cfg(target_os = "linux")]
    unsafe {
        let mut prop: CudaDeviceProp = std::mem::zeroed();
        let status = cudaGetDeviceProperties_v2(&mut prop, 0);
        if status != 0 { return None; }
        let name = std::ffi::CStr::from_ptr(prop.name.as_ptr() as *const i8)
            .to_string_lossy().to_string();
        let vram_mb = prop.total_global_mem / (1024 * 1024);
        return Some(GpuInfo { name, vram_mb });
    }

    #[cfg(not(target_os = "linux"))]
    None
}

/// Launch GPU certification for all pairs.
pub fn gpu_certify(pairs: &[(usize, usize)]) -> Vec<PairResult> {
    let n = pairs.len();
    let _max_b = pairs.iter().map(|&(_, b)| b).max().unwrap_or(3);

    // Flatten pairs into c_int array
    let _flat_pairs: Vec<c_int> = pairs.iter()
        .flat_map(|&(a, b)| vec![a as c_int, b as c_int])
        .collect();

    let mut results = vec![PairResult::default(); n];

    #[cfg(target_os = "linux")]
    unsafe {
        launch_skeleton_keys(
            _flat_pairs.as_ptr(),
            results.as_mut_ptr(),
            n as c_int,
            _max_b as c_int,
        );
    }

    #[cfg(not(target_os = "linux"))]
    {
        eprintln!("WARNING: GPU not available. Use CPU mode (--cpu).");
        let _ = &mut results; // suppress warning
    }

    results
}
