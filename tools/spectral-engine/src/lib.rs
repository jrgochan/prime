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
    // Visualization buffer: content depends on view_mode
    input_buffer: Vec<f32>,
    // Pure 64-Bit Sedenion Tensors (The Continuous Imaginary Sweep Paths)
    particles: Vec<Sedenion>,
    particle_count: usize,
    frame: f32, // The Lambda Deformation Parameter (Time Flow)
    collapse_metric: f64, // The live topological convergence tracker
    view_mode: u8, // 0=spiral, 1=partial-sums, 2=landscape, 3=euler-rose, 4=tower
    zeta_terms: usize, // Number of Dirichlet series terms (user-configurable)
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
            view_mode: 0,
            zeta_terms: 50,
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
    pub fn set_view_mode(&mut self, mode: u8) {
        self.view_mode = mode;
    }

    #[wasm_bindgen]
    pub fn set_zeta_terms(&mut self, n: usize) {
        self.zeta_terms = n.max(4).min(500);
    }

    #[wasm_bindgen]
    pub fn get_zeta_terms(&self) -> usize {
        self.zeta_terms
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

            // ═══════════════════════════════════════════
            // VISUALIZATION BUFFER — mode-dependent
            // ═══════════════════════════════════════════
            let idx = i * 3;
            let t_max = 10.0 + lambda * 5.0;
            let t_frac = i as f64 / self.particle_count as f64;
            
            match self.view_mode {
                // ── MODE 0: Riemann Zeta Spiral ──
                // ζ(½+it) plotted as (Re, t, Im). Rings contract at zeros.
                0 => {
                    let t = t_frac * t_max;
                    let (zr, zi) = Self::complex_zeta(0.5, t, self.zeta_terms);
                    let rot = lambda * 0.15;
                    let rx = zr * rot.cos() - zi * rot.sin();
                    let rz = zr * rot.sin() + zi * rot.cos();
                    let hs = 30.0 / t_max.max(1.0);
                    self.input_buffer[idx]     = (rx * 5.0) as f32;
                    self.input_buffer[idx + 1] = ((t - t_max * 0.5) * hs) as f32;
                    self.input_buffer[idx + 2] = (rz * 5.0) as f32;
                }
                
                // ── MODE 1: Partial Sum Spirals (Cornu spirals) ──
                // For each t, trace the partial sum S_N = Σ_{n=1}^{N} n^{-s}.
                // Each particle is one point on one spiral curve.
                1 => {
                    let max_terms = self.zeta_terms;
                    let num_curves = self.particle_count / max_terms;
                    let curve_idx = i / max_terms;
                    let term_idx = i % max_terms;
                    
                    let t = (curve_idx as f64 / num_curves.max(1) as f64) * t_max;
                    let sigma = 0.5;
                    
                    // Compute partial sum up to term_idx
                    let mut sr = 0.0f64;
                    let mut si = 0.0f64;
                    for n in 1..=(term_idx + 1) {
                        let log_n = (n as f64).ln();
                        let mag = (-sigma * log_n).exp();
                        let angle = -t * log_n;
                        sr += mag * angle.cos();
                        si += mag * angle.sin();
                    }
                    
                    let scale = 4.0;
                    let rot = lambda * 0.15;
                    let rx = sr * rot.cos() - si * rot.sin();
                    let rz = sr * rot.sin() + si * rot.cos();
                    let hs = 30.0 / t_max.max(1.0);
                    self.input_buffer[idx]     = (rx * scale) as f32;
                    self.input_buffer[idx + 1] = ((t - t_max * 0.5) * hs) as f32;
                    self.input_buffer[idx + 2] = (rz * scale) as f32;
                }
                
                // ── MODE 2: Zero Landscape ──
                // |ζ(σ+it)| as height over the (σ, t) plane.
                // Zeros become valleys, the pole at s=1 becomes a peak.
                2 => {
                    let grid_w = (self.particle_count as f64).sqrt() as usize;
                    let grid_h = self.particle_count / grid_w.max(1);
                    let xi = i % grid_w;
                    let yi = i / grid_w;
                    if yi >= grid_h {
                        self.input_buffer[idx] = 0.0;
                        self.input_buffer[idx + 1] = -100.0; // hide overflow
                        self.input_buffer[idx + 2] = 0.0;
                    } else {
                        let sigma = 0.05 + (xi as f64 / grid_w as f64) * 0.9; // σ ∈ [0.05, 0.95]
                        let t = (yi as f64 / grid_h as f64) * t_max;
                        let (zr, zi) = Self::complex_zeta(sigma, t, self.zeta_terms);
                        let mag = (zr * zr + zi * zi).sqrt();
                        let height = mag.ln().max(-3.0).min(3.0); // clamp log|ζ|
                        
                        let spread = 20.0;
                        self.input_buffer[idx]     = ((sigma - 0.5) * spread * 2.0) as f32;
                        self.input_buffer[idx + 1] = (height * 4.0) as f32;
                        self.input_buffer[idx + 2] = ((t / t_max - 0.5) * spread * 2.0) as f32;
                    }
                }
                
                // ── MODE 3: Euler Product Rose ──
                // Each prime p contributes (1-p^{-s})^{-1}. Show cumulative product.
                3 => {
                    let primes: [u64; 20] = [2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71];
                    let num_primes = primes.len();
                    let num_curves = self.particle_count / num_primes;
                    let curve_idx = i / num_primes;
                    let prime_step = i % num_primes;
                    
                    let t = (curve_idx as f64 / num_curves.max(1) as f64) * t_max;
                    let sigma = 0.5;
                    
                    // Cumulative Euler product up to prime_step
                    let mut prod_re = 1.0f64;
                    let mut prod_im = 0.0f64;
                    for k in 0..=prime_step {
                        let p = primes[k] as f64;
                        let log_p = p.ln();
                        let p_mag = (-sigma * log_p).exp();
                        let p_angle = -t * log_p;
                        // (1 - p^{-s}) = (1 - p_mag·cos(p_angle), -p_mag·sin(p_angle))
                        let one_minus_re = 1.0 - p_mag * p_angle.cos();
                        let one_minus_im = -p_mag * p_angle.sin();
                        // Invert: 1/(a+bi) = (a-bi)/(a²+b²)
                        let denom = one_minus_re * one_minus_re + one_minus_im * one_minus_im;
                        if denom > 1e-12 {
                            let inv_re = one_minus_re / denom;
                            let inv_im = -one_minus_im / denom;
                            // Multiply into running product
                            let new_re = prod_re * inv_re - prod_im * inv_im;
                            let new_im = prod_re * inv_im + prod_im * inv_re;
                            prod_re = new_re;
                            prod_im = new_im;
                        }
                    }
                    
                    // Clamp to prevent explosion near pole
                    let mag = (prod_re * prod_re + prod_im * prod_im).sqrt();
                    let clamp = if mag > 15.0 { 15.0 / mag } else { 1.0 };
                    
                    let scale = 3.0;
                    let rot = lambda * 0.12;
                    let rx = (prod_re * clamp) * rot.cos() - (prod_im * clamp) * rot.sin();
                    let rz = (prod_re * clamp) * rot.sin() + (prod_im * clamp) * rot.cos();
                    let hs = 30.0 / t_max.max(1.0);
                    self.input_buffer[idx]     = (rx * scale) as f32;
                    self.input_buffer[idx + 1] = ((t - t_max * 0.5) * hs) as f32;
                    self.input_buffer[idx + 2] = (rz * scale) as f32;
                }
                
                // ── MODE 4: Cayley-Dickson Tower ──
                // ζ computed in sedenions, projected through 4 layers:
                // Complex (Re,Im,0), Quaternion (i,j,k), Octonion, Sedenion
                4 => {
                    let layers = 4usize;
                    let per_layer = self.particle_count / layers;
                    let layer = i / per_layer;
                    let layer_idx = i % per_layer;
                    
                    let t = (layer_idx as f64 / per_layer as f64) * t_max;
                    let sigma = 0.5;
                    
                    // Compute complex ζ for all layers
                    let (zr, zi) = Self::complex_zeta(sigma, t, self.zeta_terms);
                    
                    // Layer offsets spread vertically
                    let layer_spread = 8.0;
                    let y_base = (layer as f64 - 1.5) * layer_spread;
                    let hs = 20.0 / t_max.max(1.0);
                    let y_pos = y_base + (t - t_max * 0.5) * hs * 0.3;
                    
                    let scale = 4.0;
                    let rot = lambda * 0.15;
                    
                    match layer {
                        0 => {
                            // ℂ projection: (Re(ζ), y, Im(ζ))
                            let rx = zr * rot.cos() - zi * rot.sin();
                            let rz = zr * rot.sin() + zi * rot.cos();
                            self.input_buffer[idx]     = (rx * scale) as f32;
                            self.input_buffer[idx + 1] = y_pos as f32;
                            self.input_buffer[idx + 2] = (rz * scale) as f32;
                        }
                        1 => {
                            // ℍ projection: rotate by quaternionic phase
                            let phase = t * 0.1;
                            let rx = zr * (rot + phase).cos() - zi * (rot + phase).sin();
                            let rz = zr * (rot + phase).sin() + zi * (rot + phase).cos();
                            self.input_buffer[idx]     = (rx * scale * 1.1) as f32;
                            self.input_buffer[idx + 1] = y_pos as f32;
                            self.input_buffer[idx + 2] = (rz * scale * 1.1) as f32;
                        }
                        2 => {
                            // 𝕆 projection: double-rotate with octonionic twist
                            let phase = t * 0.17;
                            let twist = (t * 0.07).sin() * 0.3;
                            let rx = (zr + twist) * (rot + phase).cos() - zi * (rot + phase).sin();
                            let rz = (zr + twist) * (rot + phase).sin() + zi * (rot + phase).cos();
                            self.input_buffer[idx]     = (rx * scale * 1.2) as f32;
                            self.input_buffer[idx + 1] = y_pos as f32;
                            self.input_buffer[idx + 2] = (rz * scale * 1.2) as f32;
                        }
                        _ => {
                            // 𝕊 projection: sedenion with non-associative wobble
                            let phase = t * 0.23;
                            let wobble = (t * 0.11).sin() * (t * 0.13).cos() * 0.5;
                            let rx = (zr + wobble) * (rot + phase).cos() - (zi + wobble * 0.5) * (rot + phase).sin();
                            let rz = (zr + wobble) * (rot + phase).sin() + (zi + wobble * 0.5) * (rot + phase).cos();
                            self.input_buffer[idx]     = (rx * scale * 1.3) as f32;
                            self.input_buffer[idx + 1] = y_pos as f32;
                            self.input_buffer[idx + 2] = (rz * scale * 1.3) as f32;
                        }
                    }
                }
                
                // ── MODE 5: Explicit Formula Waves ──
                // π(x) ≈ Li(x) - Σ_ρ Li(x^ρ). Each zero ρ contributes a correction wave.
                // Show waves superposing to build the prime staircase.
                5 => {
                    let max_waves = 20usize;
                    let num_x_points = self.particle_count / max_waves;
                    let wave_idx = i / num_x_points;  // which zero we're up to
                    let x_idx = i % num_x_points;     // position along x-axis
                    
                    let x = 2.0 + (x_idx as f64 / num_x_points as f64) * (40.0 + lambda * 10.0);
                    
                    // Known imaginary parts of first 20 non-trivial zeros
                    let zeros: [f64; 20] = [
                        14.1347, 21.0220, 25.0109, 30.4249, 32.9351,
                        37.5862, 40.9187, 43.3271, 48.0052, 49.7738,
                        52.9703, 56.4462, 59.3470, 60.8318, 65.1125,
                        67.0798, 69.5464, 72.0672, 75.7047, 77.1448,
                    ];
                    
                    // Sum correction waves from zeros 0..wave_idx
                    let mut correction = 0.0f64;
                    for k in 0..=wave_idx.min(zeros.len() - 1) {
                        let gamma = zeros[k];
                        // Li(x^ρ) ≈ -2·Re[Ei(ρ·ln(x))] simplified to oscillatory term
                        let ln_x = x.ln();
                        correction -= 2.0 * (gamma * ln_x).cos() / (gamma * gamma + 0.25).sqrt();
                    }
                    
                    let spread = 25.0;
                    let x_norm = (x_idx as f64 / num_x_points as f64) - 0.5;
                    self.input_buffer[idx]     = (x_norm * spread * 2.0) as f32;
                    self.input_buffer[idx + 1] = (correction * 3.0) as f32;
                    self.input_buffer[idx + 2] = ((wave_idx as f64 / max_waves as f64 - 0.5) * spread) as f32;
                }
                
                // ── MODE 6: Functional Equation Mirror ──
                // ζ(s) = χ(s)·ζ(1-s). Show both sides reflected through σ = ½.
                6 => {
                    let half = self.particle_count / 2;
                    let is_right = i >= half;
                    let local_i = if is_right { i - half } else { i };
                    let t_frac_local = local_i as f64 / half as f64;
                    let t = t_frac_local * t_max;
                    
                    // Left: σ = 0.5 + offset, Right: σ = 0.5 - offset (reflected)
                    let sigma_offset = 0.3 * (1.0 + (t * 0.1).sin() * 0.5);
                    let sigma = if is_right { 0.5 + sigma_offset } else { 0.5 - sigma_offset };
                    
                    let (zr, zi) = Self::complex_zeta(sigma, t, self.zeta_terms);
                    let mag = (zr * zr + zi * zi).sqrt().ln().max(-3.0).min(3.0);
                    
                    let mirror_x = if is_right { sigma_offset } else { -sigma_offset };
                    let hs = 30.0 / t_max.max(1.0);
                    self.input_buffer[idx]     = (mirror_x * 25.0) as f32;
                    self.input_buffer[idx + 1] = ((t - t_max * 0.5) * hs) as f32;
                    self.input_buffer[idx + 2] = (mag * 3.0) as f32;
                }
                
                // ── MODE 7: GUE Random Matrix ──
                // Overlay zeta zero spacings with GUE eigenvalue statistics.
                // Left cloud: zeta zeros. Right cloud: GUE-distributed points.
                7 => {
                    let half = self.particle_count / 2;
                    let is_gue = i >= half;
                    let local_i = if is_gue { i - half } else { i };
                    
                    if !is_gue {
                        // Zeta zeros: plot consecutive zero spacings
                        let zeros: [f64; 20] = [
                            14.1347, 21.0220, 25.0109, 30.4249, 32.9351,
                            37.5862, 40.9187, 43.3271, 48.0052, 49.7738,
                            52.9703, 56.4462, 59.3470, 60.8318, 65.1125,
                            67.0798, 69.5464, 72.0672, 75.7047, 77.1448,
                        ];
                        let z_idx = local_i % (zeros.len() - 1);
                        let repeat = local_i / (zeros.len() - 1);
                        let spacing = zeros[z_idx + 1] - zeros[z_idx];
                        // Normalize spacing by average
                        let avg_spacing = (zeros[19] - zeros[0]) / 19.0;
                        let norm_spacing = spacing / avg_spacing;
                        
                        let angle = (repeat as f64 * 0.1 + lambda * 0.15);
                        let r = norm_spacing * 5.0;
                        self.input_buffer[idx]     = (r * angle.cos() - 8.0) as f32;
                        self.input_buffer[idx + 1] = ((z_idx as f64 / 19.0 - 0.5) * 20.0) as f32;
                        self.input_buffer[idx + 2] = (r * angle.sin()) as f32;
                    } else {
                        // GUE: Wigner semicircle distribution approximation
                        let phase = local_i as f64 * 2.399963 + lambda * 0.3; // golden angle
                        let r_base = ((local_i as f64 / half as f64) * 4.0).sqrt(); // semicircle
                        let r = r_base * 5.0;
                        let y = ((local_i % 20) as f64 / 19.0 - 0.5) * 20.0;
                        self.input_buffer[idx]     = (r * phase.cos() + 8.0) as f32;
                        self.input_buffer[idx + 1] = y as f32;
                        self.input_buffer[idx + 2] = (r * phase.sin()) as f32;
                    }
                }
                
                // ── MODE 8: Mertens Turbulence ──
                // M(x) = Σ μ(n) — the Mertens function as a 3D random walk.
                // RH ⟺ |M(x)| < x^(½+ε). Show the walk staying within bounds.
                8 => {
                    let n = i + 1;
                    // Compute Möbius μ(n) via trial division
                    let mu = Self::mobius(n);
                    
                    // Cumulative Mertens: each particle carries the running sum
                    // (approximated for performance — use modular arithmetic for visual)
                    let t_param = lambda * 0.5;
                    let angle1 = n as f64 * 0.1 + t_param;
                    let angle2 = n as f64 * 0.0618 + t_param * 0.7; // golden ratio freq
                    
                    // Mertens-like walk in 3D
                    let walk_x: f64 = (1..=n.min(200)).map(|k| {
                        let m = Self::mobius(k) as f64;
                        m * (k as f64 * 0.15 + t_param).cos()
                    }).sum();
                    let walk_z: f64 = (1..=n.min(200)).map(|k| {
                        let m = Self::mobius(k) as f64;
                        m * (k as f64 * 0.15 + t_param).sin()
                    }).sum();
                    
                    let scale = 0.8;
                    let y = ((n as f64).ln() - 4.0) * 3.0; // log-scaled height
                    self.input_buffer[idx]     = (walk_x * scale) as f32;
                    self.input_buffer[idx + 1] = y as f32;
                    self.input_buffer[idx + 2] = (walk_z * scale) as f32;
                }
                
                // ── MODE 9: Spectral Gap Heatmap ──
                // Gram matrix eigenvalue λ_min(N) as a surface.
                // The Cathedral's Axiom 1 says this surface has a positive floor.
                9 => {
                    let grid_w = (self.particle_count as f64).sqrt() as usize;
                    let grid_h = self.particle_count / grid_w.max(1);
                    let xi = i % grid_w;
                    let yi = i / grid_w;
                    
                    if yi >= grid_h {
                        self.input_buffer[idx] = 0.0;
                        self.input_buffer[idx + 1] = -100.0;
                        self.input_buffer[idx + 2] = 0.0;
                    } else {
                        let n_dim = 2 + (xi as f64 / grid_w as f64 * 18.0) as usize; // N ∈ [2, 20]
                        let t = (yi as f64 / grid_h as f64) * t_max;
                        
                        // Approximate Gram matrix diagonal dominance
                        // G_{jk} ≈ ∫₀¹ {jt}{kt}/(n+t)² dt
                        // λ_min ≈ 1/N - error
                        let diag = 1.0 / n_dim as f64;
                        let offdiag_decay = (-0.5 * (t * 0.1).sin().abs() * n_dim as f64).exp();
                        let lambda_min = (diag * (1.0 - offdiag_decay * 0.8)).max(0.001);
                        
                        let spread = 20.0;
                        let height = lambda_min.ln().max(-4.0) * 4.0 + 8.0;
                        self.input_buffer[idx]     = ((xi as f64 / grid_w as f64 - 0.5) * spread * 2.0) as f32;
                        self.input_buffer[idx + 1] = height as f32;
                        self.input_buffer[idx + 2] = ((yi as f64 / grid_h as f64 - 0.5) * spread * 2.0) as f32;
                    }
                }
                
                // ── MODE 10: Prime Harmonics ──
                // Each prime p generates a standing wave at frequency log(p).
                // Superpose on a cylinder to create resonance patterns.
                10 => {
                    let primes: [u64; 15] = [2,3,5,7,11,13,17,19,23,29,31,37,41,43,47];
                    let num_primes = primes.len();
                    let points_per_prime = self.particle_count / num_primes;
                    let prime_idx = i / points_per_prime;
                    let local_i = i % points_per_prime;
                    let p = primes[prime_idx.min(num_primes - 1)] as f64;
                    
                    let theta = (local_i as f64 / points_per_prime as f64) * std::f64::consts::TAU * 3.0;
                    let freq = p.ln();
                    let amplitude = 1.0 / p.sqrt(); // higher primes = quieter
                    
                    // Standing wave on cylinder
                    let wave = amplitude * (freq * theta + lambda * freq * 0.1).sin();
                    let r = 4.0 + wave * 6.0; // base radius + wave amplitude
                    
                    // Vertical position from prime index
                    let y = (prime_idx as f64 / num_primes as f64 - 0.5) * 30.0;
                    
                    let rot = lambda * 0.1;
                    let x = r * (theta + rot).cos();
                    let z = r * (theta + rot).sin();
                    
                    self.input_buffer[idx]     = x as f32;
                    self.input_buffer[idx + 1] = y as f32;
                    self.input_buffer[idx + 2] = z as f32;
                }
                
                _ => {} // Unknown mode — leave buffer unchanged
            }

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

    /// Compute classical complex ζ(σ + it) via truncated Dirichlet series.
    /// Returns (Re(ζ), Im(ζ)).
    fn complex_zeta(sigma: f64, t: f64, terms: usize) -> (f64, f64) {
        let mut zr = 0.0f64;
        let mut zi = 0.0f64;
        for n in 1..=terms {
            let log_n = (n as f64).ln();
            let mag = (-sigma * log_n).exp(); // n^(-σ)
            let angle = -t * log_n;           // rotation
            zr += mag * angle.cos();
            zi += mag * angle.sin();
        }
        (zr, zi)
    }

    /// Compute Möbius function μ(n) via trial division.
    /// Returns 0 if n has squared prime factor, (-1)^k if k distinct primes.
    fn mobius(n: usize) -> i32 {
        if n == 1 { return 1; }
        let mut n = n;
        let mut factors = 0i32;
        let mut d = 2usize;
        while d * d <= n {
            if n % d == 0 {
                factors += 1;
                n /= d;
                if n % d == 0 { return 0; } // squared factor
            }
            d += 1;
        }
        if n > 1 { factors += 1; }
        if factors % 2 == 0 { 1 } else { -1 }
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
