pub mod math;

use wasm_bindgen::prelude::*;
use rand::Rng;
use math::{Quaternion, Octonion, Sedenion};

// =========================================================
// Project HYPERZETA: Explorer Engine
// May 15, 2026 — The Cayley-Dickson Tower Visualization
//
// Extended from the Origin engine with three new modes:
//   Mode 0: Origin (classic sedenion sweep)
//   Mode 1: Teardrop Sphere (Riemann sphere stereographic)
//   Mode 2: Glass Staircase (Cayley-Dickson layer decomposition)
//   Mode 3: Division by Zero (Möbius inverse 1/ζ)
// =========================================================

/// Möbius function μ(n) for small n
fn moebius(n: u32) -> i32 {
    match n {
        1 => 1,
        2 => -1,
        3 => -1,
        4 => 0,  // 2²
        5 => -1,
        6 => 1,  // 2·3
        7 => -1,
        8 => 0,  // 2³
        9 => 0,  // 3²
        10 => 1, // 2·5
        11 => -1,
        12 => 0, // 2²·3
        13 => -1,
        14 => 1, // 2·7
        15 => 1, // 3·5
        16 => 0, // 2⁴
        _ => 0,
    }
}

#[wasm_bindgen]
pub struct HyperEngine {
    geometry_buffer: Vec<f32>,
    /// Second buffer for layer energy data (Glass Staircase)
    layer_buffer: Vec<f32>,
    particles: Vec<Sedenion>,
    particle_count: usize,
    frame: f32,
    collapse_metric: f64,
    /// 0=Origin, 1=Teardrop, 2=GlassStaircase, 3=DivisionByZero
    view_mode: u32,
    /// Layer energies: [ℝ, ℂ, ℍ, 𝕆, 𝕊] accumulated per frame
    layer_energies: [f64; 5],
}

#[wasm_bindgen]
impl HyperEngine {
    #[wasm_bindgen(constructor)]
    pub fn new(particle_count: usize) -> HyperEngine {
        let geometry_buffer = vec![0.0; particle_count * 3];
        let layer_buffer = vec![0.0; particle_count * 3];
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
            layer_buffer,
            particles,
            particle_count,
            frame: 0.0,
            collapse_metric: 10.0,
            view_mode: 0,
            layer_energies: [0.0; 5],
        }
    }

    #[wasm_bindgen]
    pub fn get_buffer_pointer(&self) -> *const f32 {
        self.geometry_buffer.as_ptr()
    }

    #[wasm_bindgen]
    pub fn get_layer_buffer_pointer(&self) -> *const f32 {
        self.layer_buffer.as_ptr()
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
    pub fn set_view_mode(&mut self, mode: u32) {
        self.view_mode = mode;
    }

    #[wasm_bindgen]
    pub fn get_view_mode(&self) -> u32 {
        self.view_mode
    }

    /// Get layer energy for the given Cayley-Dickson level (0-4)
    #[wasm_bindgen]
    pub fn get_layer_energy(&self, level: usize) -> f64 {
        if level < 5 { self.layer_energies[level] } else { 0.0 }
    }

    #[wasm_bindgen]
    pub fn tick_physics(&mut self) {
        self.frame += 0.005;
        let lambda = self.frame as f64;

        // Background slow hyper-rotator
        let rot_quat1 = Quaternion::new(lambda.cos(), lambda.sin(), (lambda * 0.1).cos(), 0.0);
        let rot_quat2 = Quaternion::new(0.0, (lambda * 0.2).sin(), 0.0, 1.0);
        let rot_oct = Octonion::new(rot_quat1, rot_quat2);
        let active_rotator = Sedenion::new(rot_oct, rot_oct.conjugate()).normalize();

        let mut total_magnitude = 0.0;
        let mut layer_e = [0.0f64; 5];

        let terms = 16; // Extended to 16 terms for Möbius mode

        for i in 0..self.particle_count {
            // STEP 1: Morph the Input Coordinate S
            self.particles[i] = self.particles[i].mul(&active_rotator).normalize();
            let mut s_coord = self.particles[i].scale(10.0 + (lambda * 2.0));
            s_coord.a.a.r = 0.5; // THE CRITICAL LINE BOUNDARY

            match self.view_mode {
                // ─────────────────────────────────────────────
                // MODE 0: Origin (classic)
                // ─────────────────────────────────────────────
                0 => {
                    let mut zeta_sum = Sedenion::zero();
                    for n in 1..=8 {
                        let ln_n = (n as f64).ln();
                        let neg_s_ln_n = s_coord.scale(-ln_n);
                        let dirichlet_term = neg_s_ln_n.exp();
                        zeta_sum = zeta_sum.add(&dirichlet_term);
                    }

                    let idx = i * 3;
                    let oq = zeta_sum.a.a;
                    total_magnitude += oq.norm_sq();
                    let vm = 40.0;
                    self.geometry_buffer[idx]     = oq.i as f32 * vm;
                    self.geometry_buffer[idx + 1] = oq.j as f32 * vm;
                    self.geometry_buffer[idx + 2] = oq.k as f32 * vm;
                }

                // ─────────────────────────────────────────────
                // MODE 1: Teardrop Sphere (Stereographic)
                // Maps ζ output → Riemann sphere via stereographic projection
                // Zeros appear as symmetric pairs across equator
                // ─────────────────────────────────────────────
                1 => {
                    let mut zeta_sum = Sedenion::zero();
                    for n in 1..=terms {
                        let ln_n = (n as f64).ln();
                        let neg_s_ln_n = s_coord.scale(-ln_n);
                        let dirichlet_term = neg_s_ln_n.exp();
                        zeta_sum = zeta_sum.add(&dirichlet_term);
                    }

                    let oq = zeta_sum.a.a;
                    // Use (i,j) as complex output, stereographic project to sphere
                    let z_re = oq.i;
                    let z_im = oq.j;
                    let r_sq = z_re * z_re + z_im * z_im;

                    // Stereographic projection: (x,y) → (X,Y,Z) on S²
                    let denom = 1.0 + r_sq;
                    let sphere_x = 2.0 * z_re / denom;
                    let sphere_y = 2.0 * z_im / denom;
                    let sphere_z = (r_sq - 1.0) / denom;

                    total_magnitude += oq.norm_sq();

                    let idx = i * 3;
                    let vm = 20.0;
                    self.geometry_buffer[idx]     = sphere_x as f32 * vm;
                    self.geometry_buffer[idx + 1] = sphere_y as f32 * vm;
                    self.geometry_buffer[idx + 2] = sphere_z as f32 * vm;
                }

                // ─────────────────────────────────────────────
                // MODE 2: Glass Staircase (Layer Decomposition)
                // X = imaginary height t, Y = CD level, Z = energy at that level
                // Shows energy flow through ℝ → ℂ → ℍ → 𝕆 → 𝕊
                // ─────────────────────────────────────────────
                2 => {
                    let mut zeta_sum = Sedenion::zero();
                    for n in 1..=terms {
                        let ln_n = (n as f64).ln();
                        let neg_s_ln_n = s_coord.scale(-ln_n);
                        let dirichlet_term = neg_s_ln_n.exp();
                        zeta_sum = zeta_sum.add(&dirichlet_term);
                    }

                    // Decompose output by Cayley-Dickson layer:
                    // Layer 0 (ℝ): a.a.r
                    let e_real = zeta_sum.a.a.r * zeta_sum.a.a.r;
                    // Layer 1 (ℂ): a.a.i
                    let e_complex = zeta_sum.a.a.i * zeta_sum.a.a.i;
                    // Layer 2 (ℍ): a.a.j, a.a.k
                    let e_quat = zeta_sum.a.a.j * zeta_sum.a.a.j
                               + zeta_sum.a.a.k * zeta_sum.a.a.k;
                    // Layer 3 (𝕆): a.b (second quaternion of first octonion)
                    let e_oct = zeta_sum.a.b.norm_sq();
                    // Layer 4 (𝕊): b (second octonion)
                    let e_sed = zeta_sum.b.norm_sq();

                    layer_e[0] += e_real;
                    layer_e[1] += e_complex;
                    layer_e[2] += e_quat;
                    layer_e[3] += e_oct;
                    layer_e[4] += e_sed;

                    total_magnitude += e_real + e_complex + e_quat + e_oct + e_sed;

                    // Map particle to staircase: assign each particle a CD level
                    // based on which level dominates its output
                    let energies = [e_real, e_complex, e_quat, e_oct, e_sed];
                    let max_level = energies.iter()
                        .enumerate()
                        .max_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap())
                        .map(|(i, _)| i)
                        .unwrap_or(0);

                    let total_e = (e_real + e_complex + e_quat + e_oct + e_sed).sqrt();

                    let idx = i * 3;
                    // X = spread within level (use particle's imaginary component)
                    let spread = zeta_sum.a.a.i * 8.0 + zeta_sum.a.a.j * 4.0;
                    // Y = Cayley-Dickson level (stepped)
                    let level_y = (max_level as f64) * 8.0 - 16.0;
                    // Z = energy magnitude (depth)
                    let depth = total_e * 3.0;

                    self.geometry_buffer[idx]     = spread as f32;
                    self.geometry_buffer[idx + 1] = level_y as f32;
                    self.geometry_buffer[idx + 2] = depth as f32;

                    // Store layer info for coloring
                    self.layer_buffer[idx]     = max_level as f32;
                    self.layer_buffer[idx + 1] = total_e as f32;
                    self.layer_buffer[idx + 2] = (energies[max_level] / total_e.max(1e-10)) as f32;
                }

                // ─────────────────────────────────────────────
                // MODE 3: Division by Zero (Möbius Inverse)
                // Computes 1/ζ(s) = Σ μ(n)/n^s
                // μ(n) ∈ {-1, 0, +1} — the shadow through the glass
                // ─────────────────────────────────────────────
                3 => {
                    let mut mobius_sum = Sedenion::zero();
                    for n in 1..=terms {
                        let mu = moebius(n as u32);
                        if mu == 0 { continue; } // Skip non-squarefree

                        let ln_n = (n as f64).ln();
                        let neg_s_ln_n = s_coord.scale(-ln_n);
                        let dirichlet_term = neg_s_ln_n.exp();

                        if mu == 1 {
                            mobius_sum = mobius_sum.add(&dirichlet_term);
                        } else {
                            // mu == -1: subtract
                            mobius_sum = mobius_sum.sub(&dirichlet_term);
                        }
                    }

                    let idx = i * 3;
                    let oq = mobius_sum.a.a;
                    total_magnitude += oq.norm_sq();
                    let vm = 40.0;
                    self.geometry_buffer[idx]     = oq.i as f32 * vm;
                    self.geometry_buffer[idx + 1] = oq.j as f32 * vm;
                    self.geometry_buffer[idx + 2] = oq.k as f32 * vm;

                    // Store Möbius character for coloring
                    // Re-use layer buffer: .x = dominant sign contribution
                    let real_part = mobius_sum.a.a.r;
                    self.layer_buffer[idx]     = if real_part > 0.0 { 1.0 } else { -1.0 };
                    self.layer_buffer[idx + 1] = oq.norm_sq().sqrt() as f32;
                    self.layer_buffer[idx + 2] = real_part as f32;
                }

                _ => {}
            }
        }

        self.collapse_metric = total_magnitude / (self.particle_count as f64);
        self.layer_energies = layer_e.map(|e| e / self.particle_count as f64);
    }
}
