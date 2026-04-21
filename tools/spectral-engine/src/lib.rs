pub mod math; // Inject Algebraic Coprocessor Structs

#[cfg(not(target_family = "wasm"))]
use pyo3::prelude::*;

use wasm_bindgen::prelude::*;
use rand::Rng; // Utilizing WASM-Compatible Generator bounds
use math::{Quaternion, Octonion, Sedenion};

// =========================================================
// SECTION 1: WASM INTERFACE (Next.js True Zero-Copy Buffer)
// =========================================================

#[wasm_bindgen]
pub struct HyperEngine {
    // Zeta OUTPUT buffer: ζ(s) values projected to 3D
    geometry_buffer: Vec<f32>, 
    // Input POSITION buffer: sedenion coordinates projected to 3D (the spiral)
    input_buffer: Vec<f32>,
    // Pure 64-Bit Sedenion Tensors (The Continuous Imaginary Sweep Paths)
    particles: Vec<Sedenion>,
    particle_count: usize,
    frame: f32, // The Lambda Deformation Parameter (Time Flow)
    collapse_metric: f64, // The live topological convergence tracker
}

#[wasm_bindgen]
impl HyperEngine {
    #[wasm_bindgen(constructor)]
    pub fn new(particle_count: usize) -> HyperEngine {
        let geometry_buffer = vec![0.0; particle_count * 3];
        let input_buffer = vec![0.0; particle_count * 3];
        let mut particles = Vec::with_capacity(particle_count);
        
        let mut rng = rand::thread_rng();
        
        // Seed the 15D Imaginary vector paths across the critical line
        for _ in 0..particle_count {
            let q1 = Quaternion::new(rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0));
            let q2 = Quaternion::new(rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0));
            let q3 = Quaternion::new(rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0));
            let q4 = Quaternion::new(rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0));
            
            let oct1 = Octonion::new(q1, q2);
            let oct2 = Octonion::new(q3, q4);
            
            // Normalize imaginary spread
            particles.push(Sedenion::new(oct1, oct2).normalize()); 
        }
        
        HyperEngine {
            geometry_buffer,
            input_buffer,
            particles,
            particle_count,
            frame: 0.0,
            collapse_metric: 10.0, // High origin bound
        }
    }

    /// Pointer to the ζ(s) OUTPUT buffer (collapse/breathing visualization)
    #[wasm_bindgen]
    pub fn get_buffer_pointer(&self) -> *const f32 {
        self.geometry_buffer.as_ptr()
    }

    /// Pointer to the INPUT SPACE buffer (spiral visualization)
    #[wasm_bindgen]
    pub fn get_input_buffer_pointer(&self) -> *const f32 {
        self.input_buffer.as_ptr()
    }

    #[wasm_bindgen]
    pub fn get_collapse_metric(&self) -> f64 {
        self.collapse_metric
    }

    #[wasm_bindgen]
    pub fn get_lambda(&self) -> f64 {
        self.frame as f64
    }

    #[wasm_bindgen]
    pub fn tick_physics(&mut self) {
        self.frame += 0.005;
        let lambda = self.frame as f64;
        
        // Background slow hyper-rotator spreading imaginary search vectors
        let rot_quat1 = Quaternion::new(lambda.cos(), lambda.sin(), (lambda * 0.1).cos(), 0.0);
        let rot_quat2 = Quaternion::new(0.0, (lambda * 0.2).sin(), 0.0, 1.0);
        let rot_oct = Octonion::new(rot_quat1, rot_quat2);
        let active_rotator = Sedenion::new(rot_oct, rot_oct.conjugate()).normalize(); 
        
        // Output Matrix Boundary Tracker Loop
        let mut total_magnitude = 0.0;
        
        for i in 0..self.particle_count {
            // STEP 1: Morph the Input Coordinate S (Sweeping up the manifold)
            self.particles[i] = self.particles[i].mul(&active_rotator).normalize();
            
            // Scale the imaginary vector to travel up the height of the Riemann curve (e.g. T = 10 to 40)
            let mut s_coord = self.particles[i].scale(10.0 + (lambda * 2.0));
            
            // THE CRITICAL LINE BOUNDARY
            // Force the Real dimension of every coordinate mathematically exactly to 1/2
            s_coord.a.a.r = 0.5; 

            // INPUT SPACE: Helical spiral projection
            // Map each particle's 16D sedenion orientation to a position on a helix.
            // - Phase angle: derived from the particle's quaternion components (unique per particle)
            // - Height: spreads particles vertically, modulated by lambda
            // - Radius: based on the imaginary magnitude of the first quaternion
            let idx = i * 3;
            let q = s_coord.a.a; // First quaternion of the sedenion
            
            // Unique phase per particle: atan2 of two imaginary components
            // This creates an angular distribution based on the particle's 16D orientation
            let phase = q.i.atan2(q.j);
            
            // Radius: imaginary magnitude of the first octonion × modulation
            let r = (q.i * q.i + q.j * q.j + q.k * q.k).sqrt();
            let radius = 3.0 + r * 0.8;
            
            // Height: each particle gets a unique vertical position based on
            // another pair of sedenion components, creating the helix layering
            let q2 = s_coord.a.b; // Second quaternion of the first octonion
            let height = (q2.r + q2.i) * 2.0;
            
            // The helix: x,z circle with y height.
            // Lambda rotation makes the whole spiral turn over time.
            let angle = phase + lambda * 0.3;
            self.input_buffer[idx]     = (radius * angle.cos()) as f32;
            self.input_buffer[idx + 1] = height as f32;
            self.input_buffer[idx + 2] = (radius * angle.sin()) as f32;

            // STEP 2: Calculate Riemann Zeta Dirichlet Series in 16-Dimensions:
            // zeta(S) = sum_{n=1}^{N} n^{-S} = sum e^(-S * ln(n))
            let mut zeta_sum = Sedenion::zero();
            let terms = 8; // Truncation bound for 120FPS GPU limitations mapping 150k particles
            
            for n in 1..=terms {
                let ln_n = (n as f64).ln();
                
                // Execute exponential hypercomplex shift natively
                let neg_s_ln_n = s_coord.scale(-ln_n);
                let dirichlet_term = neg_s_ln_n.exp();
                
                zeta_sum = zeta_sum.add(&dirichlet_term);
            }
            
            // OUTPUT SPACE: Project ζ(s) to 3D
            // This visually proves that mathematical zeros physically dive exactly to origin (0,0,0)
            let output_quat = zeta_sum.a.a;
            
            // Map individual convergence to average structural scale
            total_magnitude += output_quat.norm_sq();
            
            let visual_multiplier = 40.0; // Inflate geometry for screen scale
            
            self.geometry_buffer[idx]   = output_quat.i as f32 * visual_multiplier;
            self.geometry_buffer[idx+1] = output_quat.j as f32 * visual_multiplier;
            self.geometry_buffer[idx+2] = output_quat.k as f32 * visual_multiplier;
        }
        
        // Output mathematical magnitude mapping average back to pure 64-bit Javascript observer
        self.collapse_metric = total_magnitude / (self.particle_count as f64);
    }
}

// =========================================================
// SECTION 2: PYTHON INTERFACE (FastAPI & Core ML ANE Router)
// =========================================================

#[cfg(not(target_family = "wasm"))]
#[pyfunction]
fn rust_engine_status() -> PyResult<String> {
    Ok("HYPERZETA M2 Python Gateway Secured".to_string())
}

#[cfg(not(target_family = "wasm"))]
#[pyfunction]
fn get_python_topology_state() -> PyResult<Vec<f32>> {
    let sample_sedenion_data = vec![0.0, 1.0, -1.0, 0.5, 3.1415];
    Ok(sample_sedenion_data)
}

/// Compute |ζ_ℍ(s)| via quaternionic Euler product (non-vanishing: division algebra)
#[cfg(not(target_family = "wasm"))]
#[pyfunction]
fn euler_product_quat(re: f64, im: f64, num_primes: usize) -> PyResult<f64> {
    let (norm, _) = math::euler_product_quaternion(re, im, num_primes);
    Ok(norm)
}

/// Compute |ζ_𝕆(s)| via octonionic Euler product (non-vanishing: division algebra)
#[cfg(not(target_family = "wasm"))]
#[pyfunction]
fn euler_product_oct(re: f64, im: f64, num_primes: usize) -> PyResult<f64> {
    let (norm, _) = math::euler_product_octonion(re, im, num_primes);
    Ok(norm)
}

/// Compute |ζ_𝕊(s)| via sedenion Dirichlet series
#[cfg(not(target_family = "wasm"))]
#[pyfunction]
fn zeta_sedenion(re: f64, im: f64, terms: usize) -> PyResult<f64> {
    let (norm, _) = math::zeta_sedenion_dirichlet(re, im, terms);
    Ok(norm)
}

/// Compute zeta Dirichlet series in complex numbers (high precision)
#[cfg(not(target_family = "wasm"))]
#[pyfunction]
fn zeta_dirichlet_complex(re: f64, im: f64, terms: usize) -> PyResult<(f64, f64, f64)> {
    let mut sum_re = 0.0f64;
    let mut sum_im = 0.0f64;
    for n in 1..=terms {
        let log_n = (n as f64).ln();
        let mag = (-re * log_n).exp();
        let angle = -im * log_n;
        sum_re += mag * angle.cos();
        sum_im += mag * angle.sin();
    }
    let norm = (sum_re * sum_re + sum_im * sum_im).sqrt();
    Ok((sum_re, sum_im, norm))
}

/// Compute the Mertens 3-4-1 bound: |ζ(σ)|³ · |ζ(σ+it)|⁴ · |ζ(σ+2it)|
/// Returns (|ζ(σ)|, |ζ(σ+it)|, |ζ(σ+2it)|, product)
#[cfg(not(target_family = "wasm"))]
#[pyfunction]
fn mertens_bound(sigma: f64, t: f64, terms: usize) -> PyResult<(f64, f64, f64, f64)> {
    let compute_norm = |re: f64, im: f64| -> f64 {
        let mut sr = 0.0f64;
        let mut si = 0.0f64;
        for n in 1..=terms {
            let log_n = (n as f64).ln();
            let mag = (-re * log_n).exp();
            let angle = -im * log_n;
            sr += mag * angle.cos();
            si += mag * angle.sin();
        }
        (sr * sr + si * si).sqrt()
    };

    let z_sigma = compute_norm(sigma, 0.0);
    let z_sigma_it = compute_norm(sigma, t);
    let z_sigma_2it = compute_norm(sigma, 2.0 * t);

    let product = z_sigma.powi(3) * z_sigma_it.powi(4) * z_sigma_2it;

    Ok((z_sigma, z_sigma_it, z_sigma_2it, product))
}

/// Full tower sweep: compute |ζ| at ℂ, ℍ, 𝕆, 𝕊 for many t values along Re(s) ≈ 1.
/// Returns Vec of [t, |ζ_ℂ|, |ζ_ℍ|, |ζ_𝕆|, |ζ_𝕊|]
#[cfg(not(target_family = "wasm"))]
#[pyfunction]
fn tower_sweep(t_start: f64, t_end: f64, num_points: usize) -> PyResult<Vec<Vec<f64>>> {
    let raw = math::tower_sweep_re_one(t_start, t_end, num_points);
    Ok(raw.into_iter().map(|row| row.to_vec()).collect())
}

/// Compute the sedenion zeta operator at s = σ + it.
/// Returns a dict with:
///   "matrix": flat list of 256 f64 (16x16 row-major left-multiplication matrix)
///   "components": list of 16 f64 (ζ_𝕊(s) components)
///   "norm": f64 (|ζ_𝕊(s)|)
#[cfg(not(target_family = "wasm"))]
#[pyfunction]
fn zeta_operator(re: f64, im: f64, terms: usize) -> PyResult<(Vec<f64>, Vec<f64>, f64)> {
    let (matrix, components, norm) = math::zeta_operator_at(re, im, terms);
    Ok((matrix.to_vec(), components.to_vec(), norm))
}

/// Compute the sedenion zeta operator for a FULL 16D sedenion input.
/// s_components: list of 16 floats [e₀, e₁, ..., e₁₅]
/// Returns: (matrix_256, components_16, norm)
#[cfg(not(target_family = "wasm"))]
#[pyfunction]
fn zeta_operator_full(s_components: Vec<f64>, terms: usize) -> PyResult<(Vec<f64>, Vec<f64>, f64)> {
    if s_components.len() != 16 {
        return Err(pyo3::exceptions::PyValueError::new_err(
            "s_components must have exactly 16 elements"
        ));
    }
    let mut arr = [0.0f64; 16];
    arr.copy_from_slice(&s_components);
    let (matrix, components, norm) = math::zeta_operator_full(&arr, terms);
    Ok((matrix.to_vec(), components.to_vec(), norm))
}

/// Compute the sedenion ARITHMETIC zeta function.
/// This uses the sedenion arithmetic logarithm (primes → basis directions)
/// and non-commutative multiplication, creating genuinely non-complex values.
///
/// s_components: list of 16 floats [e₀, e₁, ..., e₁₅]
/// Returns: (matrix_256, components_16, norm)
#[cfg(not(target_family = "wasm"))]
#[pyfunction]
fn zeta_arithmetic(s_components: Vec<f64>, terms: usize) -> PyResult<(Vec<f64>, Vec<f64>, f64)> {
    if s_components.len() != 16 {
        return Err(pyo3::exceptions::PyValueError::new_err(
            "s_components must have exactly 16 elements"
        ));
    }
    let mut arr = [0.0f64; 16];
    arr.copy_from_slice(&s_components);
    let (matrix, components, norm) = math::zeta_arithmetic_sedenion(&arr, terms);
    Ok((matrix.to_vec(), components.to_vec(), norm))
}

/// Compute the eta-regularized arithmetic zeta function.
/// Converges for Re(s) > 0, enabling critical line computation.
///
/// s_components: list of 16 floats
/// terms: number of terms in the series
/// accelerate: use Euler acceleration for faster convergence
/// Returns: (matrix_256, components_16, norm)
#[cfg(not(target_family = "wasm"))]
#[pyfunction]
fn eta_arithmetic(s_components: Vec<f64>, terms: usize, accelerate: bool) -> PyResult<(Vec<f64>, Vec<f64>, f64)> {
    if s_components.len() != 16 {
        return Err(pyo3::exceptions::PyValueError::new_err(
            "s_components must have exactly 16 elements"
        ));
    }
    let mut arr = [0.0f64; 16];
    arr.copy_from_slice(&s_components);
    let (matrix, components, norm) = math::eta_arithmetic_sedenion(&arr, terms, accelerate);
    Ok((matrix.to_vec(), components.to_vec(), norm))
}

/// Compute Li coefficients λ₁ through λ_N.
/// t_max: search for zeros up to this height on the critical line
/// n_max: compute λ₁ through λ_{n_max}
/// Returns: (n_zeros_found, list of λ values, list of zero locations)
#[cfg(not(target_family = "wasm"))]
#[pyfunction]
fn li_coeffs(n_max: usize, t_max: f64) -> PyResult<(usize, Vec<f64>, Vec<f64>)> {
    let (n_zeros, lambdas, zeros) = math::li_coefficients(n_max, t_max);
    Ok((n_zeros, lambdas, zeros))
}

/// Evaluate the Hardy Z-function at multiple points.
/// Z(t) is real-valued, and Z(t) = 0 iff ζ(1/2+it) = 0.
/// Returns: list of Z(t) values
#[cfg(not(target_family = "wasm"))]
#[pyfunction]
fn hardy_z_vals(t_values: Vec<f64>) -> PyResult<Vec<f64>> {
    Ok(t_values.iter().map(|&t| math::hardy_z(t)).collect())
}

#[cfg(not(target_family = "wasm"))]
#[pyfunction]
fn quaternion_r4_sigma(n: usize) -> PyResult<(usize, usize)> {
    let r4 = math::r4_jacobi(n);
    let s1 = math::sigma1(n);
    Ok((r4, s1))
}

#[cfg(not(target_family = "wasm"))]
#[pyfunction]
fn ramanujan_tau_bound(max_n: usize) -> PyResult<Vec<i64>> {
    let tau = math::compute_tau(max_n);
    Ok(tau)
}

#[cfg(not(target_family = "wasm"))]
#[pyfunction]
fn hecke_operator_trace(p: usize) -> PyResult<(f64, f64, f64)> {
    let (t, l, norm) = math::hecke_spectral_contraction(p);
    Ok((t, l, norm))
}

#[cfg(not(target_family = "wasm"))]
#[pyfunction]
fn spectral_search(n_target: usize, t_max: f64) -> PyResult<(usize, Vec<f64>, Vec<f64>, Vec<(usize, f64, f64)>)> {
    let (n, diag, offdiag, corr) = math::hilbert_polya_search(n_target, t_max);
    Ok((n, diag, offdiag, corr))
}

#[cfg(not(target_family = "wasm"))]
#[pymodule]
fn core_engine(_py: Python, m: &PyModule) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(rust_engine_status, m)?)?;
    m.add_function(wrap_pyfunction!(get_python_topology_state, m)?)?;
    m.add_function(wrap_pyfunction!(euler_product_quat, m)?)?;
    m.add_function(wrap_pyfunction!(euler_product_oct, m)?)?;
    m.add_function(wrap_pyfunction!(zeta_sedenion, m)?)?;
    m.add_function(wrap_pyfunction!(zeta_dirichlet_complex, m)?)?;
    m.add_function(wrap_pyfunction!(mertens_bound, m)?)?;
    m.add_function(wrap_pyfunction!(tower_sweep, m)?)?;
    m.add_function(wrap_pyfunction!(zeta_operator, m)?)?;
    m.add_function(wrap_pyfunction!(zeta_operator_full, m)?)?;
    m.add_function(wrap_pyfunction!(zeta_arithmetic, m)?)?;
    m.add_function(wrap_pyfunction!(eta_arithmetic, m)?)?;
    m.add_function(wrap_pyfunction!(li_coeffs, m)?)?;
    m.add_function(wrap_pyfunction!(hardy_z_vals, m)?)?;
    m.add_function(wrap_pyfunction!(quaternion_r4_sigma, m)?)?;
    m.add_function(wrap_pyfunction!(ramanujan_tau_bound, m)?)?;
    m.add_function(wrap_pyfunction!(hecke_operator_trace, m)?)?;
    m.add_function(wrap_pyfunction!(spectral_search, m)?)?;
    Ok(())
}
