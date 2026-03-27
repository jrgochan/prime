//! Cayley-Dickson Algebra Module
//! Implements strict 64-bit precision floating-point arithmetic for Non-Associative geometries.

#[derive(Clone, Copy, Debug)]
pub struct Quaternion {
    pub r: f64,
    pub i: f64,
    pub j: f64,
    pub k: f64,
}

impl Quaternion {
    pub fn new(r: f64, i: f64, j: f64, k: f64) -> Self {
        Self { r, i, j, k }
    }
    
    pub fn conjugate(&self) -> Self {
        Self::new(self.r, -self.i, -self.j, -self.k)
    }

    pub fn mul(&self, other: &Self) -> Self {
        Self::new(
            self.r * other.r - self.i * other.i - self.j * other.j - self.k * other.k,
            self.r * other.i + self.i * other.r + self.j * other.k - self.k * other.j,
            self.r * other.j - self.i * other.k + self.j * other.r + self.k * other.i,
            self.r * other.k + self.i * other.j - self.j * other.i + self.k * other.r,
        )
    }
    
    pub fn add(&self, other: &Self) -> Self {
        Self::new(self.r + other.r, self.i + other.i, self.j + other.j, self.k + other.k)
    }

    pub fn sub(&self, other: &Self) -> Self {
        Self::new(self.r - other.r, self.i - other.i, self.j - other.j, self.k - other.k)
    }

    pub fn norm_sq(&self) -> f64 {
        self.r * self.r + self.i * self.i + self.j * self.j + self.k * self.k
    }

    pub fn scale(&self, s: f64) -> Self {
        Self::new(self.r * s, self.i * s, self.j * s, self.k * s)
    }
}

// Octonion (Pair of Quaternions)
#[derive(Clone, Copy, Debug)]
pub struct Octonion {
    pub a: Quaternion,
    pub b: Quaternion,
}

impl Octonion {
    pub fn new(a: Quaternion, b: Quaternion) -> Self {
        Self { a, b }
    }

    pub fn conjugate(&self) -> Self {
        Self::new(self.a.conjugate(), Self::negate_quat(&self.b))
    }

    fn negate_quat(q: &Quaternion) -> Quaternion {
        Quaternion::new(-q.r, -q.i, -q.j, -q.k)
    }

    pub fn mul(&self, other: &Self) -> Self {
        let ac = self.a.mul(&other.a);
        let d_star = other.b.conjugate();
        let d_star_b = d_star.mul(&self.b);
        let first = ac.sub(&d_star_b);

        let da = other.b.mul(&self.a);
        let c_star = self.a.conjugate(); 
        let bc_star = self.b.mul(&c_star);
        let second = da.add(&bc_star);

        Self::new(first, second)
    }
    
    pub fn add(&self, other: &Self) -> Self {
        Self::new(self.a.add(&other.a), self.b.add(&other.b))
    }
    
    pub fn sub(&self, other: &Self) -> Self {
        let first_a = self.a.sub(&other.a);
        let second_b = self.b.sub(&other.b);
        Self::new(first_a, second_b)
    }

    pub fn norm_sq(&self) -> f64 {
        self.a.norm_sq() + self.b.norm_sq()
    }

    pub fn scale(&self, s: f64) -> Self {
        Self::new(self.a.scale(s), self.b.scale(s))
    }
}

// Sedenion (Pair of Octonions)
#[derive(Clone, Copy, Debug)]
pub struct Sedenion {
    pub a: Octonion,
    pub b: Octonion,
}

impl Sedenion {
    pub fn new(a: Octonion, b: Octonion) -> Self {
        Self { a, b }
    }
    
    pub fn zero() -> Self {
        Sedenion::new(
            Octonion::new(
                Quaternion::new(0.0, 0.0, 0.0, 0.0), 
                Quaternion::new(0.0, 0.0, 0.0, 0.0)
            ),
            Octonion::new(
                Quaternion::new(0.0, 0.0, 0.0, 0.0), 
                Quaternion::new(0.0, 0.0, 0.0, 0.0)
            )
        )
    }

    pub fn add(&self, other: &Self) -> Self {
        Self::new(self.a.add(&other.a), self.b.add(&other.b))
    }

    pub fn sub(&self, other: &Self) -> Self {
        Self::new(self.a.sub(&other.a), self.b.sub(&other.b))
    }

    pub fn mul(&self, other: &Self) -> Self {
        let ac = self.a.mul(&other.a);
        let d_star = other.b.conjugate();
        let d_star_b = d_star.mul(&self.b);
        let first = ac.sub(&d_star_b);

        let da = other.b.mul(&self.a);
        let c_star = self.a.conjugate();
        let bc_star = self.b.mul(&c_star);
        let second = da.add(&bc_star);

        Self::new(first, second)
    }

    pub fn norm_sq(&self) -> f64 {
        self.a.norm_sq() + self.b.norm_sq()
    }

    pub fn scale(&self, s: f64) -> Self {
        Self::new(self.a.scale(s), self.b.scale(s))
    }

    pub fn normalize(&self) -> Self {
        let n = self.norm_sq().sqrt();
        if n == 0.0 {
            *self
        } else {
            self.scale(1.0 / n)
        }
    }

    /// Evaluates the Euler Hypercomplex Exponential e^S
    /// e^S = e^r * (cos(|V|) + (V / |V|) * sin(|V|))
    pub fn exp(&self) -> Self {
        let r = self.a.a.r; // The real scalar boundary
        
        let mut v = *self;
        v.a.a.r = 0.0; // Isolate the 15-Dimensional Imaginary Vector V

        let v_norm = v.norm_sq().sqrt();
        let exp_r = r.exp();

        if v_norm == 0.0 {
            // Strictly real bound return
            let mut res = Sedenion::zero();
            res.a.a.r = exp_r;
            return res;
        }

        let cos_v = v_norm.cos();
        let sin_v_over_v = v_norm.sin() / v_norm;

        // V * (sin(|V|) / |V|)
        let mut scaled_v = v.scale(sin_v_over_v);
        
        // Add cos(|V|) to the real axis position
        scaled_v.a.a.r += cos_v;

        // Multiply magnitude entirely by e^R exponential drift
        scaled_v.scale(exp_r)
    }
}


// ==========================================================
// SECTION: Quaternion Extended Operations (Division Algebra)
// ==========================================================

impl Quaternion {
    /// Quaternion exponential: e^q = e^r (cos|v| + v̂ sin|v|)
    pub fn exp(&self) -> Self {
        let r = self.r;
        let v_norm = (self.i * self.i + self.j * self.j + self.k * self.k).sqrt();
        let exp_r = r.exp();

        if v_norm < 1e-15 {
            return Self::new(exp_r, 0.0, 0.0, 0.0);
        }

        let cos_v = v_norm.cos();
        let sin_v_over_v = v_norm.sin() / v_norm;

        Self::new(
            exp_r * cos_v,
            exp_r * sin_v_over_v * self.i,
            exp_r * sin_v_over_v * self.j,
            exp_r * sin_v_over_v * self.k,
        )
    }

    /// Multiplicative inverse: q^(-1) = conj(q) / |q|²
    /// This ALWAYS exists for non-zero quaternions (division algebra!)
    pub fn inverse(&self) -> Self {
        let n = self.norm_sq();
        if n < 1e-30 {
            return Self::new(0.0, 0.0, 0.0, 0.0);
        }
        let c = self.conjugate();
        Self::new(c.r / n, c.i / n, c.j / n, c.k / n)
    }

    /// Create quaternion from complex number (embed ℂ ↪ ℍ)
    pub fn from_complex(re: f64, im: f64) -> Self {
        Self::new(re, im, 0.0, 0.0)
    }

    /// One element
    pub fn one() -> Self {
        Self::new(1.0, 0.0, 0.0, 0.0)
    }

    pub fn from_real(r: f64) -> Self {
        Self::new(r, 0.0, 0.0, 0.0)
    }
}

impl Octonion {
    pub fn from_complex(re: f64, im: f64) -> Self {
        Self::new(Quaternion::from_complex(re, im), Quaternion::new(0.0, 0.0, 0.0, 0.0))
    }

    pub fn one() -> Self {
        Self::new(Quaternion::one(), Quaternion::new(0.0, 0.0, 0.0, 0.0))
    }

    /// Octonion inverse: o^(-1) = conj(o) / |o|² (exists for all nonzero — division algebra!)
    pub fn inverse(&self) -> Self {
        let n = self.norm_sq();
        if n < 1e-30 {
            return Self::new(Quaternion::new(0.0,0.0,0.0,0.0), Quaternion::new(0.0,0.0,0.0,0.0));
        }
        let c = self.conjugate();
        c.scale(1.0 / n)
    }

    /// Octonion exponential
    pub fn exp(&self) -> Self {
        let r = self.a.r;
        let mut v = *self;
        v.a.r = 0.0;
        let v_norm = v.norm_sq().sqrt();
        let exp_r = r.exp();

        if v_norm < 1e-15 {
            return Self::new(Quaternion::new(exp_r, 0.0, 0.0, 0.0), Quaternion::new(0.0,0.0,0.0,0.0));
        }

        let cos_v = v_norm.cos();
        let sin_v_over_v = v_norm.sin() / v_norm;
        let mut result = v.scale(sin_v_over_v);
        result.a.r += cos_v;
        result.scale(exp_r)
    }
}

impl Sedenion {
    pub fn from_complex(re: f64, im: f64) -> Self {
        Self::new(
            Octonion::from_complex(re, im),
            Octonion::new(Quaternion::new(0.0,0.0,0.0,0.0), Quaternion::new(0.0,0.0,0.0,0.0)),
        )
    }

    pub fn one() -> Self {
        Self::new(
            Octonion::one(),
            Octonion::new(Quaternion::new(0.0,0.0,0.0,0.0), Quaternion::new(0.0,0.0,0.0,0.0)),
        )
    }
}


// ═══════════════════════════════════════════════════════════
// SECTION: Cayley-Dickson Tower Euler Product Analysis
// ═══════════════════════════════════════════════════════════
//
// The Euler product ζ(s) = ∏_p (1 - p^(-s))^(-1) is structurally
// non-vanishing in DIVISION ALGEBRAS (ℍ, 𝕆) because:
//   1. Each factor (1 - p^(-s)) is non-zero (bounded away from 0)
//   2. Each inverse exists (division algebra guarantees this)
//   3. The product of non-zero elements is non-zero (no zero divisors)
//
// In sedenions (𝕊), this guarantee BREAKS because zero divisors exist.
// This analysis tracks the norm of ζ at each tower level.

/// First 25 primes for Euler product
const PRIMES: [u64; 25] = [
    2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47,
    53, 59, 61, 67, 71, 73, 79, 83, 89, 97,
];

/// Quaternionic Euler product: ∏_p (1 - p^(-s))^(-1) in ℍ
/// Non-vanishing guaranteed by division algebra structure.
pub fn euler_product_quaternion(re: f64, im: f64, num_primes: usize) -> (f64, Quaternion) {
    let s = Quaternion::from_complex(re, im);
    let mut product = Quaternion::one();

    for &p in PRIMES.iter().take(num_primes) {
        let ln_p = (p as f64).ln();
        let neg_s_ln_p = Quaternion::new(-s.r * ln_p, -s.i * ln_p, -s.j * ln_p, -s.k * ln_p);
        let p_neg_s = neg_s_ln_p.exp(); // p^(-s) = e^{-s·ln(p)}

        // (1 - p^(-s))
        let factor = Quaternion::new(1.0 - p_neg_s.r, -p_neg_s.i, -p_neg_s.j, -p_neg_s.k);

        // (1 - p^(-s))^(-1) — ALWAYS EXISTS in ℍ (division algebra!)
        let factor_inv = factor.inverse();

        product = product.mul(&factor_inv);
    }

    (product.norm_sq().sqrt(), product)
}

/// Octonionic Euler product: ∏_p (1 - p^(-s))^(-1) in 𝕆
/// Non-vanishing guaranteed by division algebra structure.
pub fn euler_product_octonion(re: f64, im: f64, num_primes: usize) -> (f64, Octonion) {
    let s = Octonion::from_complex(re, im);
    let mut product = Octonion::one();

    for &p in PRIMES.iter().take(num_primes) {
        let ln_p = (p as f64).ln();
        let neg_s_ln_p = s.scale(-ln_p);
        let p_neg_s = neg_s_ln_p.exp();

        // (1 - p^(-s))
        let factor = Octonion::one().sub(&p_neg_s);

        // (1 - p^(-s))^(-1) — ALWAYS EXISTS in 𝕆 (division algebra!)
        let factor_inv = factor.inverse();

        product = product.mul(&factor_inv);
    }

    (product.norm_sq().sqrt(), product)
}

/// Sedenion Dirichlet series: ζ_𝕊(s) = Σ n^(-s) in 𝕊
/// Note: The Euler product may not factor cleanly due to non-associativity
/// and zero divisors, but the Dirichlet series is well-defined.
pub fn zeta_sedenion_dirichlet(re: f64, im: f64, terms: usize) -> (f64, Sedenion) {
    let s = Sedenion::from_complex(re, im);
    let mut sum = Sedenion::zero();

    for n in 1..=terms {
        let ln_n = (n as f64).ln();
        let neg_s_ln_n = s.scale(-ln_n);
        let term = neg_s_ln_n.exp();
        sum = sum.add(&term);
    }

    (sum.norm_sq().sqrt(), sum)
}

/// Tower analysis: compute |ζ| at all 4 levels along Re(s) = 1.
/// Returns: Vec of (t, |ζ_ℂ|, |ζ_ℍ|, |ζ_𝕆|, |ζ_𝕊|)
pub fn tower_sweep_re_one(t_start: f64, t_end: f64, num_points: usize) -> Vec<[f64; 5]> {
    let mut results = Vec::with_capacity(num_points);
    let sigma = 1.001; // Just above Re(s) = 1 for convergence

    for i in 0..num_points {
        let t = t_start + (t_end - t_start) * (i as f64) / ((num_points - 1).max(1) as f64);

        // Complex ζ via Dirichlet series (50 terms for speed)
        let s = std::f64::consts::E; // placeholder
        let _ = s;
        let mut zeta_c = (0.0f64, 0.0f64); // (re, im)
        for n in 1..=50usize {
            let log_n = (n as f64).ln();
            let mag = (-sigma * log_n).exp();
            let angle = -t * log_n;
            zeta_c.0 += mag * angle.cos();
            zeta_c.1 += mag * angle.sin();
        }
        let norm_c = (zeta_c.0 * zeta_c.0 + zeta_c.1 * zeta_c.1).sqrt();

        // Quaternion Euler product
        let (norm_h, _) = euler_product_quaternion(sigma, t, 25);

        // Octonion Euler product
        let (norm_o, _) = euler_product_octonion(sigma, t, 25);

        // Sedenion Dirichlet (50 terms)
        let (norm_s, _) = zeta_sedenion_dirichlet(sigma, t, 50);

        results.push([t, norm_c, norm_h, norm_o, norm_s]);
    }

    results
}

