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

    pub fn conjugate(&self) -> Self {
        Self::new(self.a.conjugate(), self.b.scale(-1.0))
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

// ═══════════════════════════════════════════════════════════
// Trigintaduonion (Pair of Sedenions) — 32D Hypercomplex
// The 5th Cayley-Dickson doubling: ℝ→ℂ→ℍ→𝕆→𝕊→𝕋
//
// 31 imaginary units → primes 2..127 each get a unique direction.
// Retains: flexibility (xy)x = x(yx), power-associativity.
// Lost: alternativity, Moufang identities, division.
// ═══════════════════════════════════════════════════════════

#[derive(Clone, Copy, Debug)]
pub struct Trigintaduonion {
    pub a: Sedenion,  // first sedenion (dims 0-15)
    pub b: Sedenion,  // second sedenion (dims 16-31)
}

impl Trigintaduonion {
    pub fn new(a: Sedenion, b: Sedenion) -> Self {
        Self { a, b }
    }

    pub fn zero() -> Self {
        Self::new(Sedenion::zero(), Sedenion::zero())
    }

    pub fn conjugate(&self) -> Self {
        Self::new(
            self.a.conjugate(),
            Self::negate_sed(&self.b),
        )
    }

    fn negate_sed(s: &Sedenion) -> Sedenion {
        s.scale(-1.0)
    }

    pub fn add(&self, other: &Self) -> Self {
        Self::new(self.a.add(&other.a), self.b.add(&other.b))
    }

    pub fn sub(&self, other: &Self) -> Self {
        Self::new(self.a.sub(&other.a), self.b.sub(&other.b))
    }

    /// Cayley-Dickson multiplication: (a,b)(c,d) = (ac - d̄b, da + bc̄)
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
        if n < 1e-15 {
            *self
        } else {
            self.scale(1.0 / n)
        }
    }

    /// Hypercomplex exponential e^T for trigintaduonions.
    /// e^T = e^r * (cos(|V|) + (V/|V|)*sin(|V|))
    /// where r = real part and V = 31D imaginary vector.
    pub fn exp(&self) -> Self {
        let r = self.a.a.a.r;

        let mut v = *self;
        v.a.a.a.r = 0.0; // isolate 31D imaginary vector

        let v_norm = v.norm_sq().sqrt();
        let exp_r = r.exp();

        if v_norm < 1e-15 {
            let mut res = Self::zero();
            res.a.a.a.r = exp_r;
            return res;
        }

        let cos_v = v_norm.cos();
        let sin_v_over_v = v_norm.sin() / v_norm;

        let mut scaled_v = v.scale(sin_v_over_v);
        scaled_v.a.a.a.r += cos_v;
        scaled_v.scale(exp_r)
    }

    /// Layer energy decomposition for 6 Cayley-Dickson levels.
    /// Returns [ℝ, ℂ, ℍ, 𝕆, 𝕊, 𝕋] energies.
    pub fn layer_energies(&self) -> [f64; 6] {
        // ℝ: real part only
        let e_real = self.a.a.a.r * self.a.a.a.r;
        // ℂ: first imaginary unit
        let e_complex = self.a.a.a.i * self.a.a.a.i;
        // ℍ: quaternion extensions j,k
        let e_quat = self.a.a.a.j * self.a.a.a.j + self.a.a.a.k * self.a.a.a.k;
        // 𝕆: second quaternion of first octonion
        let e_oct = self.a.a.b.norm_sq();
        // 𝕊: second octonion of first sedenion
        let e_sed = self.a.b.norm_sq();
        // 𝕋: second sedenion (dims 16-31)
        let e_trig = self.b.norm_sq();

        [e_real, e_complex, e_quat, e_oct, e_sed, e_trig]
    }

    /// Get the sedenion subspace (first 16 components).
    pub fn sedenion_part(&self) -> &Sedenion {
        &self.a
    }
}

// ═══════════════════════════════════════════════════════════
// PRIME HARMONIC ENCODING
// Maps zeta zeros to S³¹ via prime harmonic structure
// ═══════════════════════════════════════════════════════════

/// The first 127 primes — one per imaginary direction up to dim 128.
/// Level 5 (𝕋): uses primes[0..31]   (2..127)
/// Level 6 (𝕍): uses primes[0..63]   (2..307)
/// Level 7 (∞): uses primes[0..127]  (2..709) — THE GLASS CLEARS
const PRIMES_127: [f64; 127] = [
    // 𝕋 layer (0-30): primes 2..127
    2.0, 3.0, 5.0, 7.0, 11.0, 13.0, 17.0, 19.0, 23.0, 29.0,
    31.0, 37.0, 41.0, 43.0, 47.0, 53.0, 59.0, 61.0, 67.0, 71.0,
    73.0, 79.0, 83.0, 89.0, 97.0, 101.0, 103.0, 107.0, 109.0, 113.0,
    127.0,
    // 𝕍 layer (31-62): primes 131..307
    131.0, 137.0, 139.0, 149.0, 151.0, 157.0, 163.0, 167.0, 173.0, 179.0,
    181.0, 191.0, 193.0, 197.0, 199.0, 211.0, 223.0, 227.0, 229.0, 233.0,
    239.0, 241.0, 251.0, 257.0, 263.0, 269.0, 271.0, 277.0, 281.0, 283.0,
    293.0, 307.0,
    // ∞ layer (63-126): primes 311..709 — where the glass clears
    311.0, 313.0, 317.0, 331.0, 337.0, 347.0, 349.0, 353.0, 359.0, 367.0,
    373.0, 379.0, 383.0, 389.0, 397.0, 401.0, 409.0, 419.0, 421.0, 431.0,
    433.0, 439.0, 443.0, 449.0, 457.0, 461.0, 463.0, 467.0, 479.0, 487.0,
    491.0, 499.0, 503.0, 509.0, 521.0, 523.0, 541.0, 547.0, 557.0, 563.0,
    569.0, 571.0, 577.0, 587.0, 593.0, 599.0, 601.0, 607.0, 613.0, 617.0,
    619.0, 631.0, 641.0, 643.0, 647.0, 653.0, 659.0, 661.0, 673.0, 677.0,
    683.0, 691.0, 701.0, 709.0,
];

/// Compute prime harmonic energies for height t.
/// Returns 127 values: sin²(t·ln(pₖ)) for each prime pₖ.
pub fn prime_harmonic_energies(t: f64) -> [f64; 127] {
    let mut energies = [0.0; 127];
    for (k, &p) in PRIMES_127.iter().enumerate() {
        let phase = t * p.ln();
        energies[k] = phase.sin().powi(2);
    }
    energies
}

/// Encode imaginary height t as a unit trigintaduonion on S³¹.
/// c₀ = cos(t·ln2), cₖ = sin(t·ln(pₖ))/√31
pub fn height_to_trig(t: f64) -> Trigintaduonion {
    let scale = 1.0 / (31.0f64).sqrt();
    
    // Build from quaternion components up
    // Dims 0-3: a.a.a = Quaternion(cos(t·ln2), sin(t·ln2)/√31, sin(t·ln3)/√31, sin(t·ln5)/√31)
    let q1 = Quaternion::new(
        (t * PRIMES_127[0].ln()).cos(),
        (t * PRIMES_127[0].ln()).sin() * scale,
        (t * PRIMES_127[1].ln()).sin() * scale,
        (t * PRIMES_127[2].ln()).sin() * scale,
    );
    // Dims 4-7: a.a.b
    let q2 = Quaternion::new(
        (t * PRIMES_127[3].ln()).sin() * scale,
        (t * PRIMES_127[4].ln()).sin() * scale,
        (t * PRIMES_127[5].ln()).sin() * scale,
        (t * PRIMES_127[6].ln()).sin() * scale,
    );
    // Dims 8-11: a.b.a
    let q3 = Quaternion::new(
        (t * PRIMES_127[7].ln()).sin() * scale,
        (t * PRIMES_127[8].ln()).sin() * scale,
        (t * PRIMES_127[9].ln()).sin() * scale,
        (t * PRIMES_127[10].ln()).sin() * scale,
    );
    // Dims 12-15: a.b.b
    let q4 = Quaternion::new(
        (t * PRIMES_127[11].ln()).sin() * scale,
        (t * PRIMES_127[12].ln()).sin() * scale,
        (t * PRIMES_127[13].ln()).sin() * scale,
        (t * PRIMES_127[14].ln()).sin() * scale,
    );
    // Dims 16-19: b.a.a
    let q5 = Quaternion::new(
        (t * PRIMES_127[15].ln()).sin() * scale,
        (t * PRIMES_127[16].ln()).sin() * scale,
        (t * PRIMES_127[17].ln()).sin() * scale,
        (t * PRIMES_127[18].ln()).sin() * scale,
    );
    // Dims 20-23: b.a.b
    let q6 = Quaternion::new(
        (t * PRIMES_127[19].ln()).sin() * scale,
        (t * PRIMES_127[20].ln()).sin() * scale,
        (t * PRIMES_127[21].ln()).sin() * scale,
        (t * PRIMES_127[22].ln()).sin() * scale,
    );
    // Dims 24-27: b.b.a
    let q7 = Quaternion::new(
        (t * PRIMES_127[23].ln()).sin() * scale,
        (t * PRIMES_127[24].ln()).sin() * scale,
        (t * PRIMES_127[25].ln()).sin() * scale,
        (t * PRIMES_127[26].ln()).sin() * scale,
    );
    // Dims 28-31: b.b.b
    let q8 = Quaternion::new(
        (t * PRIMES_127[27].ln()).sin() * scale,
        (t * PRIMES_127[28].ln()).sin() * scale,
        (t * PRIMES_127[29].ln()).sin() * scale,
        (t * PRIMES_127[30].ln()).sin() * scale,
    );

    let oct1 = Octonion::new(q1, q2);
    let oct2 = Octonion::new(q3, q4);
    let oct3 = Octonion::new(q5, q6);
    let oct4 = Octonion::new(q7, q8);
    let sed1 = Sedenion::new(oct1, oct2);
    let sed2 = Sedenion::new(oct3, oct4);

    Trigintaduonion::new(sed1, sed2).normalize()
}

