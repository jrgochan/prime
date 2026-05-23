pub mod math;

use wasm_bindgen::prelude::*;
use rand::Rng;
use math::{Quaternion, Octonion, Sedenion, Trigintaduonion, height_to_trig, prime_harmonic_energies};

// =========================================================
// Project HYPERZETA: Explorer Engine
// May 22, 2026 — The Cayley-Dickson Tower, Extended to 𝕋
//
// Six visualization modes across the full Cayley-Dickson tower:
//   Mode 0: Origin (classic sedenion sweep)
//   Mode 1: Teardrop Sphere (Riemann sphere stereographic)
//   Mode 2: Glass Staircase (Cayley-Dickson layer decomposition)
//   Mode 3: Division by Zero (Möbius inverse 1/ζ)
//   Mode 4: Spectrometer (spectral lift grid)
//   Mode 5: Prime Democracy (S³¹ zero distribution)
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
    particles: Vec<Trigintaduonion>,
    particle_count: usize,
    frame: f32,
    collapse_metric: f64,
    /// 0=Origin, 1=Teardrop, 2=GlassStaircase, 3=DivisionByZero, 4=Spectrometer, 5=PrimeDemocracy
    view_mode: u32,
    /// Layer energies: [ℝ, ℂ, ℍ, 𝕆, 𝕊, 𝕋] accumulated per frame
    layer_energies: [f64; 6],
    /// Prime harmonic energies (127 primes) for current frame
    prime_energies: [f64; 127],
    /// Uniformity score: how evenly distributed across prime directions (0=uneven, 1=perfect)
    prime_uniformity: f64,

    // ═══════════════════════════════════════════════
    // TimeDomainBridge: PCA + Geometric Detection
    // ═══════════════════════════════════════════════

    /// PCA eigenvalues of the 3D output cloud (sorted descending)
    pca_eigenvalues: [f64; 3],
    /// Centroid of output cloud
    centroid: [f64; 3],
    /// Cumulative fluctuation energy E_S = Σ(collapse - mean_collapse)
    fluctuation_energy: f64,
    /// Running mean of collapse_metric for fluctuation computation
    collapse_mean: f64,
    /// Frame count for running mean
    total_frames: u64,
    /// Peak |E_S| seen so far (for bound computation)
    peak_fluctuation: f64,
    /// The Gram form bound: |vᵀGv - asymptotic| ≤ peak_E_S / T²
    gram_bound: f64,
    /// Tower level for Prime Democracy: 0=ℝ(1), 1=ℂ(2), 2=ℍ(4), 3=𝕆(8), 4=𝕊(16), 5=𝕋(32)
    /// Controls how many prime directions are active
    tower_level: u32,
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
            // Initialize as full 32D trigintaduonions
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
            let q5 = Quaternion::new(
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
            );
            let q6 = Quaternion::new(
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
            );
            let q7 = Quaternion::new(
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
            );
            let q8 = Quaternion::new(
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
            );

            let oct1 = Octonion::new(q1, q2);
            let oct2 = Octonion::new(q3, q4);
            let oct3 = Octonion::new(q5, q6);
            let oct4 = Octonion::new(q7, q8);
            let sed1 = Sedenion::new(oct1, oct2);
            let sed2 = Sedenion::new(oct3, oct4);
            particles.push(Trigintaduonion::new(sed1, sed2).normalize());
        }

        HyperEngine {
            geometry_buffer,
            layer_buffer,
            particles,
            particle_count,
            frame: 0.0,
            collapse_metric: 10.0,
            view_mode: 0,
            layer_energies: [0.0; 6],
            prime_energies: [0.0; 127],
            prime_uniformity: 0.0,
            // TimeDomainBridge fields
            pca_eigenvalues: [1.0, 1.0, 1.0],
            centroid: [0.0; 3],
            fluctuation_energy: 0.0,
            collapse_mean: 0.0,
            total_frames: 0,
            peak_fluctuation: 0.0,
            gram_bound: f64::INFINITY,
            tower_level: 5, // default to full trigintaduonion
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

    /// Set Cayley-Dickson tower level (0-7):
    /// 0=ℝ(0), 1=ℂ(1), 2=ℍ(3), 3=𝕆(7), 4=𝕊(15), 5=𝕋(31), 6=𝕍(63), 7=∞(127)
    #[wasm_bindgen]
    pub fn set_tower_level(&mut self, level: u32) {
        self.tower_level = level.min(7);
    }

    #[wasm_bindgen]
    pub fn get_tower_level(&self) -> u32 {
        self.tower_level
    }

    /// Get layer energy for the given Cayley-Dickson level (0-5)
    #[wasm_bindgen]
    pub fn get_layer_energy(&self, level: usize) -> f64 {
        if level < 6 { self.layer_energies[level] } else { 0.0 }
    }

    /// Get prime harmonic energy for prime index k (0-126)
    #[wasm_bindgen]
    pub fn get_prime_energy(&self, k: usize) -> f64 {
        if k < 127 { self.prime_energies[k] } else { 0.0 }
    }

    /// Get prime uniformity score (0-1, 1 = perfectly uniform)
    #[wasm_bindgen]
    pub fn get_prime_uniformity(&self) -> f64 {
        self.prime_uniformity
    }

    #[wasm_bindgen]
    pub fn tick_physics(&mut self) {
        self.frame += 0.005;
        let lambda = self.frame as f64;

        // Background slow hyper-rotator (32D trigintaduonion)
        let rot_quat1 = Quaternion::new(lambda.cos(), lambda.sin(), (lambda * 0.1).cos(), 0.0);
        let rot_quat2 = Quaternion::new(0.0, (lambda * 0.2).sin(), 0.0, 1.0);
        let rot_oct = Octonion::new(rot_quat1, rot_quat2);
        let rot_sed = Sedenion::new(rot_oct, rot_oct.conjugate());
        let active_rotator = Trigintaduonion::new(rot_sed, Sedenion::zero()).normalize();

        let mut total_magnitude = 0.0;
        let mut layer_e = [0.0f64; 6];
        let mut prime_e = [0.0f64; 127];

        let terms = 16;

        for i in 0..self.particle_count {
            // STEP 1: Morph the Input Coordinate
            self.particles[i] = self.particles[i].mul(&active_rotator).normalize();
            // Use the sedenion subspace for zeta computation (modes 0-4)
            let s_sed = *self.particles[i].sedenion_part();
            let mut s_coord = s_sed.scale(10.0 + (lambda * 2.0));
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
                // Shows energy flow through ℝ → ℂ → ℍ → 𝕆 → 𝕊 → 𝕋
                // ─────────────────────────────────────────────
                2 => {
                    // Compute zeta sum in full 32D trigintaduonion
                    let mut s_trig = self.particles[i].scale(10.0 + (lambda * 2.0));
                    s_trig.a.a.a.r = 0.5; // Critical line
                    let mut zeta_sum = Trigintaduonion::zero();
                    for n in 1..=terms {
                        let ln_n = (n as f64).ln();
                        let neg_s_ln_n = s_trig.scale(-ln_n);
                        let dirichlet_term = neg_s_ln_n.exp();
                        zeta_sum = zeta_sum.add(&dirichlet_term);
                    }

                    // Decompose output by all 6 Cayley-Dickson layers
                    let energies = zeta_sum.layer_energies();
                    for lev in 0..6 {
                        layer_e[lev] += energies[lev];
                    }

                    let total_e_sq: f64 = energies.iter().sum();
                    total_magnitude += total_e_sq;
                    let total_e = total_e_sq.sqrt();

                    // Assign particle to dominant CD level
                    let max_level = energies.iter()
                        .enumerate()
                        .max_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap())
                        .map(|(i, _)| i)
                        .unwrap_or(0);

                    let idx = i * 3;
                    let spread = zeta_sum.a.a.a.i * 8.0 + zeta_sum.a.a.a.j * 4.0;
                    // Y = Cayley-Dickson level (6 levels now)
                    let level_y = (max_level as f64) * 7.0 - 17.5;
                    let depth = total_e * 3.0;

                    self.geometry_buffer[idx]     = spread as f32;
                    self.geometry_buffer[idx + 1] = level_y as f32;
                    self.geometry_buffer[idx + 2] = depth as f32;

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

                // ─────────────────────────────────────────────
                // MODE 5: Prime Democracy (S³¹ Zero Distribution)
                // Maps each particle's height to prime harmonics,
                // projects pairs of prime directions to 3D.
                // ─────────────────────────────────────────────
                5 => {
                    // Tower level determines how many prime directions are active:
                    // Level 0 (ℝ): 0 primes  (2^0 - 1 = 0 imaginary dims)
                    // Level 1 (ℂ): 1 prime   (2^1 - 1 = 1)
                    // Level 2 (ℍ): 3 primes  (2^2 - 1 = 3)
                    // Level 3 (𝕆): 7 primes  (2^3 - 1 = 7)
                    // Level 4 (𝕊): 15 primes (2^4 - 1 = 15)
                    // Level 5 (𝕋): 31 primes (2^5 - 1 = 31)
                    let active_primes = match self.tower_level {
                        0 => 0usize,
                        1 => 1,
                        2 => 3,
                        3 => 7,
                        4 => 15,
                        5 => 31,
                        6 => 63,
                        _ => 127,
                    };

                    let t = 10.0 + lambda * 2.0 + (i as f64) * 0.01;
                    let trig_zero = height_to_trig(t);
                    let pe = prime_harmonic_energies(t);

                    // Only accumulate energies for active primes
                    for k in 0..active_primes.min(127) {
                        prime_e[k] += pe[k];
                    }

                    // Project to 3D using active prime pairs
                    // At low levels, use fewer oscillations
                    let vm = 25.0;
                    let idx = i * 3;

                    if active_primes == 0 {
                        // ℝ: just the real axis
                        let c = (t * 2.0f64.ln()).cos();
                        self.geometry_buffer[idx]     = (c * 20.0) as f32;
                        self.geometry_buffer[idx + 1] = ((t * 0.1).sin() * 5.0) as f32;
                        self.geometry_buffer[idx + 2] = 0.0;
                    } else if active_primes == 1 {
                        // ℂ: one prime (2) — a circle
                        let p2c = (t * 2.0f64.ln()).cos();
                        let p2s = (t * 2.0f64.ln()).sin();
                        self.geometry_buffer[idx]     = (p2c * vm) as f32;
                        self.geometry_buffer[idx + 1] = (p2s * vm) as f32;
                        self.geometry_buffer[idx + 2] = 0.0;
                    } else if active_primes <= 3 {
                        // ℍ: primes 2,3,5 — 3D Lissajous
                        let p2 = (t * 2.0f64.ln()).sin();
                        let p3 = (t * 3.0f64.ln()).sin();
                        let p5 = (t * 5.0f64.ln()).sin();
                        self.geometry_buffer[idx]     = (p2 * vm) as f32;
                        self.geometry_buffer[idx + 1] = (p3 * vm) as f32;
                        self.geometry_buffer[idx + 2] = (p5 * vm) as f32;
                    } else if active_primes <= 7 {
                        // 𝕆: primes 2..17 — pairs projected
                        let p2 = (t * 2.0f64.ln()).sin();
                        let p3 = (t * 3.0f64.ln()).sin();
                        let p5 = (t * 5.0f64.ln()).sin();
                        let p7 = (t * 7.0f64.ln()).sin();
                        let p11 = (t * 11.0f64.ln()).sin();
                        let p13 = (t * 13.0f64.ln()).sin();
                        self.geometry_buffer[idx]     = ((p2 + p3 * 0.5) * vm * 0.7) as f32;
                        self.geometry_buffer[idx + 1] = ((p5 + p7 * 0.5) * vm * 0.7) as f32;
                        self.geometry_buffer[idx + 2] = ((p11 + p13 * 0.5) * vm * 0.7) as f32;
                    } else if active_primes <= 15 {
                        // 𝕊: sedenion — 15 primes, moderate mixing
                        let p2 = (t * 2.0f64.ln()).sin();
                        let p3 = (t * 3.0f64.ln()).sin();
                        let p5 = (t * 5.0f64.ln()).sin();
                        let p7 = (t * 7.0f64.ln()).sin();
                        let p11 = (t * 11.0f64.ln()).sin();
                        let p13 = (t * 13.0f64.ln()).sin();
                        self.geometry_buffer[idx]     = ((p2 + p3 * 0.3) * vm) as f32;
                        self.geometry_buffer[idx + 1] = ((p5 + p7 * 0.3) * vm) as f32;
                        self.geometry_buffer[idx + 2] = ((p11 + p13 * 0.3) * vm) as f32;
                    } else if active_primes <= 31 {
                        // 𝕋: trigintaduonion — 31 primes, full mixing
                        let p2 = (t * 2.0f64.ln()).sin();
                        let p3 = (t * 3.0f64.ln()).sin();
                        let p5 = (t * 5.0f64.ln()).sin();
                        let p7 = (t * 7.0f64.ln()).sin();
                        let p11 = (t * 11.0f64.ln()).sin();
                        let p13 = (t * 13.0f64.ln()).sin();
                        let p17 = (t * 17.0f64.ln()).sin();
                        let p19 = (t * 19.0f64.ln()).sin();
                        let p23 = (t * 23.0f64.ln()).sin();
                        self.geometry_buffer[idx]     = ((p2 + p3 * 0.3 + p17 * 0.15 + p19 * 0.1) * vm) as f32;
                        self.geometry_buffer[idx + 1] = ((p5 + p7 * 0.3 + p23 * 0.1) * vm) as f32;
                        self.geometry_buffer[idx + 2] = ((p11 + p13 * 0.3 + p17 * 0.1) * vm) as f32;
                    } else {
                        // 𝕍: 64-nion — 63 primes — THE FULL DEMOCRACY
                        // Upper primes create dense interference fringes
                        let p2 = (t * 2.0f64.ln()).sin();
                        let p3 = (t * 3.0f64.ln()).sin();
                        let p5 = (t * 5.0f64.ln()).sin();
                        let p7 = (t * 7.0f64.ln()).sin();
                        let p11 = (t * 11.0f64.ln()).sin();
                        let p13 = (t * 13.0f64.ln()).sin();
                        // Mid-range primes (𝕋 layer)
                        let p29 = (t * 29.0f64.ln()).sin();
                        let p59 = (t * 59.0f64.ln()).sin();
                        let p97 = (t * 97.0f64.ln()).sin();
                        // Upper primes (𝕍 layer — these are the NEW voices)
                        let p131 = (t * 131.0f64.ln()).sin();
                        let p179 = (t * 179.0f64.ln()).sin();
                        let p233 = (t * 233.0f64.ln()).sin();
                        let p277 = (t * 277.0f64.ln()).sin();
                        let p307 = (t * 307.0f64.ln()).sin();
                        // The upper primes create micro-texture on top of the base shape
                        let ux = p131 * 0.12 + p233 * 0.08 + p307 * 0.05;
                        let uy = p179 * 0.12 + p277 * 0.08 + p131 * 0.05;
                        let uz = p233 * 0.12 + p307 * 0.08 + p179 * 0.05;
                        self.geometry_buffer[idx]     = ((p2 + p3 * 0.3 + p29 * 0.15 + p59 * 0.1 + ux) * vm) as f32;
                        self.geometry_buffer[idx + 1] = ((p5 + p7 * 0.3 + p59 * 0.15 + p97 * 0.1 + uy) * vm) as f32;
                        self.geometry_buffer[idx + 2] = ((p11 + p13 * 0.3 + p97 * 0.15 + p29 * 0.1 + uz) * vm) as f32;
                    }

                    total_magnitude += trig_zero.norm_sq();

                    // Layer buffer: store dominant active prime and energy
                    let max_prime = if active_primes > 0 {
                        pe[..active_primes.min(127)].iter()
                            .enumerate()
                            .max_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap())
                            .map(|(i, _)| i)
                            .unwrap_or(0)
                    } else { 0 };
                    self.layer_buffer[idx]     = max_prime as f32;
                    self.layer_buffer[idx + 1] = if active_primes > 0 { pe[max_prime] } else { 0.0 } as f32;
                    self.layer_buffer[idx + 2] = trig_zero.a.a.a.r as f32;

                    // Accumulate layer energies
                    let le = trig_zero.layer_energies();
                    for lev in 0..6 {
                        layer_e[lev] += le[lev];
                    }
                }

                _ => {}
            }
        }

        self.collapse_metric = total_magnitude / (self.particle_count as f64);
        self.layer_energies = layer_e.map(|e| e / self.particle_count as f64);

        // Prime energy normalization and uniformity computation
        let prime_total: f64 = prime_e.iter().sum();
        if prime_total > 0.0 {
            for k in 0..127 {
                self.prime_energies[k] = prime_e[k] / prime_total;
            }
            // Uniformity: 1 - normalized standard deviation
            let active = match self.tower_level {
                0 => 1usize, 1 => 1, 2 => 3, 3 => 7, 4 => 15, 5 => 31, 6 => 63, _ => 127,
            }.max(1);
            let mean = 1.0 / active as f64;
            let variance: f64 = self.prime_energies[..active].iter()
                .map(|&e| (e - mean).powi(2))
                .sum::<f64>() / active as f64;
            self.prime_uniformity = (1.0 - (variance.sqrt() / mean)).max(0.0).min(1.0);
        }

        // ═══════════════════════════════════════════════
        // TimeDomainBridge: PCA Eigenvalue Computation
        // ═══════════════════════════════════════════════
        // Compute covariance matrix of the 3D output cloud, then
        // extract eigenvalues via Cardano's closed-form solution.
        // This runs at full f64 precision in Rust (not f32 JS).

        let n = self.particle_count;
        if n > 10 {
            // Step size for sampling (sample up to 5000 particles)
            let step = if n > 5000 { n / 5000 } else { 1 };
            let mut cx: f64 = 0.0;
            let mut cy: f64 = 0.0;
            let mut cz: f64 = 0.0;
            let mut count: usize = 0;

            // Pass 1: centroid
            let mut i = 0;
            while i < n {
                let idx = i * 3;
                cx += self.geometry_buffer[idx] as f64;
                cy += self.geometry_buffer[idx + 1] as f64;
                cz += self.geometry_buffer[idx + 2] as f64;
                count += 1;
                i += step;
            }
            let cf = count as f64;
            cx /= cf; cy /= cf; cz /= cf;
            self.centroid = [cx, cy, cz];

            // Pass 2: covariance matrix (upper triangle)
            let mut sxx: f64 = 0.0;
            let mut syy: f64 = 0.0;
            let mut szz: f64 = 0.0;
            let mut sxy: f64 = 0.0;
            let mut sxz: f64 = 0.0;
            let mut syz: f64 = 0.0;

            i = 0;
            while i < n {
                let idx = i * 3;
                let dx = self.geometry_buffer[idx] as f64 - cx;
                let dy = self.geometry_buffer[idx + 1] as f64 - cy;
                let dz = self.geometry_buffer[idx + 2] as f64 - cz;
                sxx += dx * dx;
                syy += dy * dy;
                szz += dz * dz;
                sxy += dx * dy;
                sxz += dx * dz;
                syz += dy * dz;
                i += step;
            }
            sxx /= cf; syy /= cf; szz /= cf;
            sxy /= cf; sxz /= cf; syz /= cf;

            // Cardano's method for eigenvalues of 3x3 symmetric matrix
            // Matrix: [[sxx, sxy, sxz], [sxy, syy, syz], [sxz, syz, szz]]
            let p1 = sxy * sxy + sxz * sxz + syz * syz;
            if p1 < 1e-12 {
                // Already diagonal
                let mut vals = [sxx, syy, szz];
                vals.sort_by(|a, b| b.partial_cmp(a).unwrap_or(std::cmp::Ordering::Equal));
                self.pca_eigenvalues = vals;
            } else {
                let q = (sxx + syy + szz) / 3.0;
                let p2 = (sxx - q).powi(2) + (syy - q).powi(2) + (szz - q).powi(2) + 2.0 * p1;
                let p = (p2 / 6.0).sqrt();

                // B = (1/p) * (A - qI)
                let ba = (sxx - q) / p;
                let bb = (syy - q) / p;
                let bc = (szz - q) / p;
                let bd = sxy / p;
                let be = syz / p;
                let bf = sxz / p;

                let det_b = ba * (bb * bc - be * be)
                          - bd * (bd * bc - be * bf)
                          + bf * (bd * be - bb * bf);
                let r = (det_b / 2.0).clamp(-1.0, 1.0);
                let phi = r.acos() / 3.0;

                let e1 = q + 2.0 * p * phi.cos();
                let e3 = q + 2.0 * p * (phi + 2.0 * std::f64::consts::PI / 3.0).cos();
                let e2 = 3.0 * q - e1 - e3;

                let mut vals = [e1, e2, e3];
                vals.sort_by(|a, b| b.partial_cmp(a).unwrap_or(std::cmp::Ordering::Equal));
                self.pca_eigenvalues = vals;
            }

            // ─── TimeDomainBridge: Fluctuation Energy ───
            // E_S(t) ≈ cumulative (collapse - mean) weighted by dt
            self.total_frames += 1;
            let tf = self.total_frames as f64;
            // Update running mean: μ_n = μ_{n-1} + (x - μ_{n-1})/n
            self.collapse_mean += (self.collapse_metric - self.collapse_mean) / tf;
            // Accumulate fluctuation: E_S += (collapse - mean) * dt
            let dt = 0.005; // matches frame increment
            self.fluctuation_energy += (self.collapse_metric - self.collapse_mean) * dt;
            // Track peak |E_S|
            let abs_e = self.fluctuation_energy.abs();
            if abs_e > self.peak_fluctuation {
                self.peak_fluctuation = abs_e;
            }
            // Gram bound: ‖E_S‖∞ / T² where T = current height
            let t = 10.0 + (self.frame as f64) * 2.0;
            self.gram_bound = if t > 1.0 {
                self.peak_fluctuation / (t * t)
            } else {
                f64::INFINITY
            };
        }
    }

    // ═══════════════════════════════════════════════════════
    // TimeDomainBridge Getters
    // ═══════════════════════════════════════════════════════

    /// PCA eigenvalue λ₁ (largest — dominant direction)
    #[wasm_bindgen]
    pub fn get_pca_lambda1(&self) -> f64 {
        self.pca_eigenvalues[0]
    }

    /// PCA eigenvalue λ₂ (second)
    #[wasm_bindgen]
    pub fn get_pca_lambda2(&self) -> f64 {
        self.pca_eigenvalues[1]
    }

    /// PCA eigenvalue λ₃ (smallest)
    #[wasm_bindgen]
    pub fn get_pca_lambda3(&self) -> f64 {
        self.pca_eigenvalues[2]
    }

    /// Elongation ratio λ₁/λ₂ — spikes when particles form a line
    #[wasm_bindgen]
    pub fn get_elongation(&self) -> f64 {
        let l2 = self.pca_eigenvalues[1].max(1e-10);
        self.pca_eigenvalues[0] / l2
    }

    /// Flatness ratio λ₁/λ₃ — spikes when particles form a disc or line
    #[wasm_bindgen]
    pub fn get_flatness(&self) -> f64 {
        let l3 = self.pca_eigenvalues[2].max(1e-10);
        self.pca_eigenvalues[0] / l3
    }

    /// Fluctuation energy E_S(t) — the TimeDomainBridge primitive
    #[wasm_bindgen]
    pub fn get_fluctuation_energy(&self) -> f64 {
        self.fluctuation_energy
    }

    /// Peak |E_S| seen so far
    #[wasm_bindgen]
    pub fn get_peak_fluctuation(&self) -> f64 {
        self.peak_fluctuation
    }

    /// Gram form bound: |vᵀGv - asymptotic| ≤ this value
    #[wasm_bindgen]
    pub fn get_gram_bound(&self) -> f64 {
        self.gram_bound
    }

    /// Running mean of collapse metric
    #[wasm_bindgen]
    pub fn get_collapse_mean(&self) -> f64 {
        self.collapse_mean
    }

    /// Centroid X of output cloud
    #[wasm_bindgen]
    pub fn get_centroid_x(&self) -> f64 {
        self.centroid[0]
    }

    /// Centroid Y of output cloud
    #[wasm_bindgen]
    pub fn get_centroid_y(&self) -> f64 {
        self.centroid[1]
    }

    /// Centroid Z of output cloud
    #[wasm_bindgen]
    pub fn get_centroid_z(&self) -> f64 {
        self.centroid[2]
    }
}
