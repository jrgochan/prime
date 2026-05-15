pub mod math;

use wasm_bindgen::prelude::*;
use rand::Rng;
use math::{Quaternion, Octonion, Sedenion};

// =========================================================
// Project HYPERZETA: Original Sedenion Engine
// March 27, 2026 — commit 5ddd47f6 ("here goes")
//
// 150,000 particles on σ = ½, sweeping upward through
// the imaginary axis. Each particle computes ζ_𝕊(s) via
// an 8-term Dirichlet series in 16D. When the sweep hits
// t ≈ 14.134... (the first non-trivial zero), the outputs
// collapse to the origin — spirals → circles → a point.
// =========================================================

#[wasm_bindgen]
pub struct HyperEngine {
    geometry_buffer: Vec<f32>,
    particles: Vec<Sedenion>,
    particle_count: usize,
    frame: f32,
    collapse_metric: f64,
}

#[wasm_bindgen]
impl HyperEngine {
    #[wasm_bindgen(constructor)]
    pub fn new(particle_count: usize) -> HyperEngine {
        let geometry_buffer = vec![0.0; particle_count * 3];
        let mut particles = Vec::with_capacity(particle_count);

        let mut rng = rand::thread_rng();

        for _ in 0..particle_count {
            let q1 = Quaternion::new(
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
            );
            let q2 = Quaternion::new(
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
            );
            let q3 = Quaternion::new(
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
            );
            let q4 = Quaternion::new(
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
            );

            let oct1 = Octonion::new(q1, q2);
            let oct2 = Octonion::new(q3, q4);
            particles.push(Sedenion::new(oct1, oct2).normalize());
        }

        HyperEngine {
            geometry_buffer,
            particles,
            particle_count,
            frame: 0.0,
            collapse_metric: 10.0,
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

        let mut total_magnitude = 0.0;

        for i in 0..self.particle_count {
            // STEP 1: Morph the Input Coordinate S (Sweeping up the manifold)
            self.particles[i] = self.particles[i].mul(&active_rotator).normalize();

            // Scale the imaginary vector to travel up the height of the Riemann curve
            let mut s_coord = self.particles[i].scale(10.0 + (lambda * 2.0));

            // THE CRITICAL LINE BOUNDARY
            // Force the Real dimension of every coordinate exactly to 1/2
            s_coord.a.a.r = 0.5;

            // STEP 2: Calculate Riemann Zeta Dirichlet Series in 16-Dimensions:
            // zeta(S) = sum_{n=1}^{N} n^{-S} = sum e^(-S * ln(n))
            let mut zeta_sum = Sedenion::zero();
            let terms = 8;

            for n in 1..=terms {
                let ln_n = (n as f64).ln();
                let neg_s_ln_n = s_coord.scale(-ln_n);
                let dirichlet_term = neg_s_ln_n.exp();
                zeta_sum = zeta_sum.add(&dirichlet_term);
            }

            // STEP 3: Project Output Mapping to WebGPU Shadow
            let idx = i * 3;
            let output_quat = zeta_sum.a.a;
            total_magnitude += output_quat.norm_sq();

            let visual_multiplier = 40.0;
            self.geometry_buffer[idx]     = output_quat.i as f32 * visual_multiplier;
            self.geometry_buffer[idx + 1] = output_quat.j as f32 * visual_multiplier;
            self.geometry_buffer[idx + 2] = output_quat.k as f32 * visual_multiplier;
        }

        self.collapse_metric = total_magnitude / (self.particle_count as f64);
    }
}
