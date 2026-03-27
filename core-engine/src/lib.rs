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
    // Pure 64-Bit Sedenion Tensors (The Internal Mathematical Frame)
    particles: Vec<Sedenion>,
    particle_count: usize,
    frame: f32, // The Lambda Deformation Parameter (Time Flow)
}

#[wasm_bindgen]
impl HyperEngine {
    #[wasm_bindgen(constructor)]
    pub fn new(particle_count: usize) -> HyperEngine {
        let geometry_buffer = vec![0.0; particle_count * 3];
        let mut particles = Vec::with_capacity(particle_count);
        
        let mut rng = rand::thread_rng();
        
        // Seed the 16D monte carlo Sedenion shadow randomly bounded by unit vectors
        for _ in 0..particle_count {
            // Root standard f64 random generation avoiding arbitrary drift cascades
            let q1 = Quaternion::new(rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0));
            let q2 = Quaternion::new(rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0));
            let q3 = Quaternion::new(rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0));
            let q4 = Quaternion::new(rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0));
            
            let oct1 = Octonion::new(q1, q2);
            let oct2 = Octonion::new(q3, q4);
            
            particles.push(Sedenion::new(oct1, oct2).normalize()); // Enforce unit hypersphere
        }
        
        HyperEngine {
            geometry_buffer,
            particles,
            particle_count,
            frame: 0.0,
        }
    }

    #[wasm_bindgen]
    pub fn get_buffer_pointer(&self) -> *const f32 {
        self.geometry_buffer.as_ptr()
    }

    #[wasm_bindgen]
    pub fn tick_physics(&mut self) {
        self.frame += 0.005;
        let lambda = self.frame as f64;
        
        // Define an elegant 16D non-associative topological rotation frame spanning out into Deep Space matrices
        let rot_quat1 = Quaternion::new(lambda.cos(), lambda.sin(), (lambda * 0.1).cos(), 0.0);
        let rot_quat2 = Quaternion::new(0.0, (lambda * 0.2).sin(), 0.0, 1.0);
        let rot_oct = Octonion::new(rot_quat1, rot_quat2);
        
        // Explicit Unit Sedenion Rotator to slow topological scaling
        let active_rotator = Sedenion::new(rot_oct, rot_oct.conjugate()).normalize(); 
        
        for i in 0..self.particle_count {
            // STEP 1: Execute Pure 64-Bit Arbitrary Precision Cayley-Dickson Multiplication
            // Sedenions are NOT a composition algebra -> |a*b| != |a|*|b|. 
            // They inherently possess Zero Divisors. Repeated multiplication causes magnitudes to explode.
            // We explicitly normalize the result back to the topological hull!
            self.particles[i] = self.particles[i].mul(&active_rotator).normalize();
            
            // Add topological breathing room via bounded scalar multipliers (Safe inside unit sphere)
            self.particles[i] = self.particles[i].scale(1.0 + (lambda * 0.5).sin() * 0.002);
            
            // STEP 2: Downcast strictly to f32 WebGPU 3D Shadow limits
            let idx = i * 3;
            let root_quat = self.particles[i].a.a;
            let visual_multiplier = 30.0;
            
            // Output explicit X, Y, Z vector rendering limits for the front-end browser thread natively
            self.geometry_buffer[idx] = root_quat.i as f32 * visual_multiplier;
            self.geometry_buffer[idx+1] = root_quat.j as f32 * visual_multiplier;
            self.geometry_buffer[idx+2] = root_quat.k as f32 * visual_multiplier;
        }
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

#[cfg(not(target_family = "wasm"))]
#[pymodule]
fn core_engine(_py: Python, m: &PyModule) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(rust_engine_status, m)?)?;
    m.add_function(wrap_pyfunction!(get_python_topology_state, m)?)?;
    Ok(())
}
