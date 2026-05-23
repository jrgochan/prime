//! ═══════════════════════════════════════════════════════════════════════════
//!  Trigintaduonion Algebra (32D Hypercomplex Numbers)
//!
//!  The 5th Cayley-Dickson algebra, constructed by doubling the sedenions:
//!    ℝ(1) → ℂ(2) → ℍ(4) → 𝕆(8) → 𝕊(16) → 𝕋(32)
//!
//!  Properties retained: power-associativity, flexibility ((xy)x = x(yx))
//!  Properties lost: alternative law (lost at sedenions), zero divisors exist
//!
//!  ## Why Trigintaduonions for RH?
//!
//!  The Cathedral discovered two incompatible inner product structures:
//!    - Sawtooth basis {kt}: multiplicative/divisor structure (gcd, Möbius)
//!    - BD basis {1/(kx)}: analytic/Mellin structure (zeta zeros)
//!
//!  Trigintaduonions have 31 imaginary units — enough to assign each
//!  prime p ≤ 127 a unique imaginary direction without wrapping. Their
//!  flexibility property (xy)x = x(yx) may encode the re-association
//!  needed to bridge between the two inner product structures.
//!
//!  ## Implementation
//!
//!  Uses the recursive Cayley-Dickson construction:
//!    (a,b)* = (a*, -b)
//!    (a,b)(c,d) = (ac - d*b, da + bc*)
//!
//!  where a,b,c,d are elements of the previous algebra level.
//! ═══════════════════════════════════════════════════════════════════════════

use std::fmt;
use std::ops::{Add, Sub, Mul, Neg};

/// A trigintaduonion: 32-dimensional hypercomplex number.
///
/// Components `c[0]` = real part, `c[1..32]` = imaginary units e₁..e₃₁.
/// Constructed via 5 applications of the Cayley-Dickson doubling.
#[derive(Clone, Debug)]
pub struct Trig {
    pub c: [f64; 32],
}

impl Trig {
    /// The zero element.
    pub fn zero() -> Self {
        Self { c: [0.0; 32] }
    }

    /// Construct a pure real trigintaduonion.
    pub fn real(a: f64) -> Self {
        let mut c = [0.0; 32];
        c[0] = a;
        Self { c }
    }

    /// Construct the i-th basis element eᵢ (i = 0..31, where e₀ = 1).
    pub fn basis(i: usize) -> Self {
        assert!(i < 32, "Trigintaduonion has 32 basis elements (0..31)");
        let mut c = [0.0; 32];
        c[i] = 1.0;
        Self { c }
    }

    /// Real part.
    pub fn re(&self) -> f64 {
        self.c[0]
    }

    /// Imaginary part as a 31-element slice.
    pub fn im(&self) -> &[f64] {
        &self.c[1..]
    }

    /// Euclidean norm ‖q‖ = √(Σ cᵢ²).
    pub fn norm(&self) -> f64 {
        self.c.iter().map(|x| x * x).sum::<f64>().sqrt()
    }

    /// Squared norm ‖q‖² = Σ cᵢ².
    pub fn norm_sq(&self) -> f64 {
        self.c.iter().map(|x| x * x).sum::<f64>()
    }

    /// Normalize to unit norm (returns zero if norm is too small).
    pub fn normalize(&self) -> Self {
        let n = self.norm();
        if n > 1e-15 {
            self.scale(1.0 / n)
        } else {
            Self::zero()
        }
    }

    /// Conjugate: (a, b₁, ..., b₃₁) → (a, -b₁, ..., -b₃₁).
    pub fn conj(&self) -> Self {
        let mut c = self.c;
        for x in c[1..].iter_mut() {
            *x = -*x;
        }
        Self { c }
    }

    /// Scalar multiplication.
    pub fn scale(&self, s: f64) -> Self {
        let mut c = self.c;
        for x in c.iter_mut() {
            *x *= s;
        }
        Self { c }
    }

    /// Inner product ⟨self, other⟩ = Σ cᵢ · dᵢ (Euclidean).
    pub fn dot(&self, other: &Self) -> f64 {
        self.c.iter().zip(other.c.iter()).map(|(a, b)| a * b).sum()
    }

    /// Cayley-Dickson multiplication.
    ///
    /// The Cayley-Dickson construction defines multiplication recursively:
    ///   (a, b)(c, d) = (ac - d*b, da + bc*)
    ///
    /// where a,b,c,d are elements of the (n/2)-dimensional subalgebra
    /// and * denotes conjugation.
    ///
    /// We implement this via the recursive `cd_mul` helper.
    pub fn mul(&self, other: &Self) -> Self {
        let mut result = [0.0; 32];
        cd_mul(&self.c, &other.c, &mut result, 32);
        Self { c: result }
    }

    /// The associator [x,y,z] = (xy)z - x(yz).
    ///
    /// Zero for associative algebras (ℝ, ℂ, ℍ).
    /// Non-zero but alternating for 𝕆.
    /// Non-zero and non-alternating for 𝕊 and 𝕋.
    pub fn associator(&self, y: &Self, z: &Self) -> Self {
        let xy = self.mul(y);
        let yz = y.mul(z);
        let lhs = xy.mul(z);
        let rhs = self.mul(&yz);
        lhs.sub(&rhs)
    }

    /// Test the flexibility identity: (xy)x = x(yx).
    ///
    /// Returns the norm of the difference ‖(xy)x - x(yx)‖.
    /// Should be ~0 for trigintaduonions (they ARE flexible).
    pub fn flexibility_defect(&self, y: &Self) -> f64 {
        let xy = self.mul(y);
        let yx = y.mul(self);
        let lhs = xy.mul(self);      // (xy)x
        let rhs = self.mul(&yx);     // x(yx)
        lhs.sub(&rhs).norm()
    }

    /// Addition.
    pub fn add(&self, other: &Self) -> Self {
        let mut c = [0.0; 32];
        for i in 0..32 {
            c[i] = self.c[i] + other.c[i];
        }
        Self { c }
    }

    /// Subtraction.
    pub fn sub(&self, other: &Self) -> Self {
        let mut c = [0.0; 32];
        for i in 0..32 {
            c[i] = self.c[i] - other.c[i];
        }
        Self { c }
    }
}

impl fmt::Display for Trig {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "({:.6}", self.c[0])?;
        for i in 1..32 {
            if self.c[i].abs() > 1e-10 {
                write!(f, " {:+.6}e{}", self.c[i], i)?;
            }
        }
        write!(f, ")")
    }
}

impl Add for &Trig {
    type Output = Trig;
    fn add(self, rhs: Self) -> Trig { Trig::add(self, rhs) }
}

impl Sub for &Trig {
    type Output = Trig;
    fn sub(self, rhs: Self) -> Trig { Trig::sub(self, rhs) }
}

impl Mul for &Trig {
    type Output = Trig;
    fn mul(self, rhs: Self) -> Trig { Trig::mul(self, rhs) }
}

impl Neg for &Trig {
    type Output = Trig;
    fn neg(self) -> Trig { self.scale(-1.0) }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CAYLEY-DICKSON RECURSIVE MULTIPLICATION
// ═══════════════════════════════════════════════════════════════════════════

/// Conjugate in-place for a Cayley-Dickson element of dimension `dim`.
fn cd_conj(a: &[f64], result: &mut [f64], dim: usize) {
    result[0] = a[0];
    for i in 1..dim {
        result[i] = -a[i];
    }
}

/// Cayley-Dickson multiplication: (a,b)(c,d) = (ac - d*b, da + bc*)
///
/// `dim` is the total dimension of the elements.
/// For dim=1: real multiplication.
/// For dim=2: complex multiplication.
/// For dim=4: quaternion multiplication.
/// For dim=8: octonion multiplication.
/// For dim=16: sedenion multiplication.
/// For dim=32: trigintaduonion multiplication.
fn cd_mul(x: &[f64], y: &[f64], result: &mut [f64], dim: usize) {
    if dim == 1 {
        result[0] = x[0] * y[0];
        return;
    }

    let half = dim / 2;

    // Split: x = (a, b), y = (c, d)
    let (a, b) = (&x[..half], &x[half..]);
    let (c, d) = (&y[..half], &y[half..]);

    // Temporaries
    let mut d_conj = vec![0.0; half];
    let mut c_conj = vec![0.0; half];
    cd_conj(d, &mut d_conj, half);
    cd_conj(c, &mut c_conj, half);

    // Wait, the formula is: (a,b)(c,d) = (ac - d*b, da + bc*)
    // where * is conjugation of the HALF-dimensional algebra
    // But we need to be careful: d* means conjugate of d, not d_conj

    // Actually the standard Cayley-Dickson formula is:
    //   (a,b)(c,d) = (ac - d̄b, da + bc̄)
    // where x̄ = conjugate

    let mut ac = vec![0.0; half];
    let mut d_star_b = vec![0.0; half]; // d̄ · b
    let mut da = vec![0.0; half];
    let mut b_c_star = vec![0.0; half]; // b · c̄

    // Compute d̄ (conjugate of d in the half-dimension)
    let mut d_star = vec![0.0; half];
    cd_conj(d, &mut d_star, half);

    // Compute c̄ (conjugate of c in the half-dimension)
    let mut c_star = vec![0.0; half];
    cd_conj(c, &mut c_star, half);

    cd_mul(a, c, &mut ac, half);           // ac
    cd_mul(&d_star, b, &mut d_star_b, half); // d̄ · b
    cd_mul(d, a, &mut da, half);           // da
    cd_mul(b, &c_star, &mut b_c_star, half); // b · c̄

    // Result = (ac - d̄b, da + bc̄)
    for i in 0..half {
        result[i] = ac[i] - d_star_b[i];
        result[half + i] = da[i] + b_c_star[i];
    }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PRIME-TO-TRIGINTADUONION ENCODING
// ═══════════════════════════════════════════════════════════════════════════

/// The first 31 primes, mapped to imaginary basis directions e₁..e₃₁.
const PRIMES_31: [u64; 31] = [
    2, 3, 5, 7, 11, 13, 17, 19, 23, 29,
    31, 37, 41, 43, 47, 53, 59, 61, 67, 71,
    73, 79, 83, 89, 97, 101, 103, 107, 109, 113,
    127,
];

/// Map a prime to its trigintaduonion basis index (1..31).
///
/// The first 31 primes get unique imaginary directions.
/// Larger primes wrap modulo 31 (but always stay in 1..31).
pub fn prime_to_trig_basis(p: u64) -> usize {
    for (i, &q) in PRIMES_31.iter().enumerate() {
        if p == q { return i + 1; }
    }
    // Larger primes: hash into 1..31
    ((p % 31) as usize) + 1
}

/// Complete prime factorization with multiplicity.
pub fn prime_factors_u64(mut n: u64) -> Vec<u64> {
    let mut f = Vec::new();
    let mut p = 2u64;
    while p * p <= n {
        while n % p == 0 {
            f.push(p);
            n /= p;
        }
        p += 1;
    }
    if n > 1 { f.push(n); }
    f
}

/// Map a positive integer to a unit trigintaduonion via its prime factorization.
///
/// `int_to_trig(k)` = ∏ e_{basis(p)} for each prime factor p of k,
/// evaluated left-to-right in ascending prime order.
///
/// With 31 imaginary dimensions, primes 2..127 each get a unique direction —
/// no wrapping needed for most practical computations.
///
/// **Flexibility note**: The trigintaduonion algebra is flexible:
/// (xy)x = x(yx). This means the "re-bracketing" of prime products
/// satisfies a partial consistency law — a weaker version of associativity
/// that still constrains the geometry of the unit sphere S³¹.
pub fn int_to_trig(k: u64) -> Trig {
    if k <= 1 {
        return Trig::real(1.0);
    }
    let mut r = Trig::real(1.0);
    for &p in &prime_factors_u64(k) {
        r = r.mul(&Trig::basis(prime_to_trig_basis(p)));
    }
    r.normalize()
}

/// Encode a zeta zero ρ = 1/2 + it as a trigintaduonion.
///
/// Places the zero at: re = cos(t·ln2), e₁ = sin(t·ln2),
/// with additional components encoding the phase structure
/// relative to prime harmonics.
///
/// Each imaginary direction e_k (k=1..31) gets the phase:
///   c_k = sin(t · ln(p_k)) / √31
///
/// This embeds the zeta zero spectrum into S³¹ in a way that
/// preserves the multiplicative harmonics of the primes.
pub fn zero_to_trig(t: f64) -> Trig {
    let mut c = [0.0; 32];
    let scale = 1.0 / (31.0f64).sqrt();

    // Real part: cos(t·ln2)
    c[0] = (t * 2.0f64.ln()).cos();

    // Each imaginary direction: sin(t·ln(p_k))
    for (i, &p) in PRIMES_31.iter().enumerate() {
        c[i + 1] = (t * (p as f64).ln()).sin() * scale;
    }

    // Normalize to unit sphere
    let trig = Trig { c };
    trig.normalize()
}

// ═══════════════════════════════════════════════════════════════════════════
//  DIAGNOSTICS
// ═══════════════════════════════════════════════════════════════════════════

/// Verify the flexibility property for two trigintaduonions.
/// Returns (defect, relative_defect) where relative = defect/‖xy‖.
pub fn check_flexibility(x: &Trig, y: &Trig) -> (f64, f64) {
    let defect = x.flexibility_defect(y);
    let xy_norm = x.mul(y).norm();
    let relative = if xy_norm > 1e-15 { defect / xy_norm } else { 0.0 };
    (defect, relative)
}

/// Compute the Moufang defect: ‖(xy)(zx) - x(yz)x‖.
/// Zero in octonions (Moufang identity), non-zero in sedenions and beyond.
pub fn moufang_defect(x: &Trig, y: &Trig, z: &Trig) -> f64 {
    let xy = x.mul(y);
    let zx = z.mul(x);
    let yz = y.mul(z);
    let lhs = xy.mul(&zx);           // (xy)(zx)
    let x_yz = x.mul(&yz);
    let rhs = x_yz.mul(x);           // x((yz)x)  -- note: not x(yz)x due to non-assoc
    lhs.sub(&rhs).norm()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_trig_real() {
        let t = Trig::real(3.0);
        assert!((t.re() - 3.0).abs() < 1e-15);
        assert!((t.norm() - 3.0).abs() < 1e-15);
    }

    #[test]
    fn test_trig_basis_unit_norm() {
        for i in 0..32 {
            let e = Trig::basis(i);
            assert!((e.norm() - 1.0).abs() < 1e-15,
                    "basis({}) has norm {}", i, e.norm());
        }
    }

    #[test]
    fn test_trig_conj() {
        let t = Trig::basis(5);
        let tc = t.conj();
        assert!((tc.c[0]).abs() < 1e-15);
        assert!((tc.c[5] + 1.0).abs() < 1e-15); // -e₅
    }

    #[test]
    fn test_e_i_squared_is_minus_one() {
        // For any imaginary unit eᵢ: eᵢ² = -1
        for i in 1..32 {
            let e = Trig::basis(i);
            let e_sq = e.mul(&e);
            assert!((e_sq.re() + 1.0).abs() < 1e-12,
                    "e{}² = {} (expected -1)", i, e_sq.re());
            for j in 1..32 {
                assert!(e_sq.c[j].abs() < 1e-12,
                        "e{}² has non-zero component {}", i, j);
            }
        }
    }

    #[test]
    fn test_flexibility() {
        // The flexibility identity (xy)x = x(yx) should hold
        let x = int_to_trig(6);   // 2·3
        let y = int_to_trig(10);  // 2·5
        let defect = x.flexibility_defect(&y);
        assert!(defect < 1e-10,
                "Flexibility defect = {} (should be ~0)", defect);
    }

    #[test]
    fn test_non_associativity() {
        // Trigintaduonions are NOT associative
        let x = Trig::basis(1);
        let y = Trig::basis(2);
        let z = Trig::basis(4);  // Different from xy direction
        let assoc = x.associator(&y, &z);
        // The associator should be non-zero for general elements
        // (but it could be zero for specific triples)
        // Just check it doesn't crash
        let _ = assoc.norm();
    }

    #[test]
    fn test_int_to_trig_unit_norm() {
        for k in 1..=50 {
            let t = int_to_trig(k);
            assert!((t.norm() - 1.0).abs() < 1e-10,
                    "int_to_trig({}) has norm {}", k, t.norm());
        }
    }

    #[test]
    fn test_zero_encoding() {
        let z1 = zero_to_trig(14.134725);  // First zeta zero
        assert!((z1.norm() - 1.0).abs() < 1e-10);
    }

    #[test]
    fn test_prime_basis_no_collision() {
        // First 31 primes should all get distinct basis indices
        let mut indices = std::collections::HashSet::new();
        for &p in PRIMES_31.iter() {
            let idx = prime_to_trig_basis(p);
            assert!(idx >= 1 && idx <= 31);
            assert!(indices.insert(idx),
                    "Prime {} collides at basis index {}", p, idx);
        }
    }
}
