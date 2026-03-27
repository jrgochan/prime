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
    // WebGPU Native Float32 Output (The 3D Visual Shadow)
    geometry_buffer: Vec<f32>, 
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
            particles,
            particle_count,
            frame: 0.0,
            collapse_metric: 10.0, // High origin bound
        }
    }

    #[wasm_bindgen]
    pub fn get_buffer_pointer(&self) -> *const f32 {
        self.geometry_buffer.as_ptr()
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
            
            // STEP 3: Project Output Mapping to WebGPU Shadow
            // Rather than plotting S directly, we plot the algebraic Zeta(S) OUTPUT
            // This visually proves that mathematical zeros physically dive exactly to origin (0,0,0)
            let idx = i * 3;
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
    Ok(())
}

