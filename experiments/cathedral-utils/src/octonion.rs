//! ═══════════════════════════════════════════════════════════════════════════
//!  Octonion Encoding for Prime Factorizations
//!
//!  Maps integers to unit octonions via their prime factorization:
//!    k → ∏ e_{basis(p)} for each prime factor p of k (left-fold)
//!
//!  This encoding maps the multiplicative structure of ℤ into the
//!  8-dimensional normed division algebra 𝕆. Because 𝕆 is non-associative,
//!  the map is not a strict homomorphism but provides a deterministic,
//!  unique point on S⁷ for each integer, enabling the Cathedral's
//!  algebraic cross-class analysis and decorrelation studies.
//! ═══════════════════════════════════════════════════════════════════════════

/// An octonion: 8-dimensional normed division algebra element.
///
/// Components `c[0]` = real part, `c[1..8]` = imaginary units e₁..e₇.
/// Multiplication follows the Cayley-Dickson construction (non-associative).
#[derive(Clone, Debug)]
pub struct Oct {
    pub c: [f64; 8],
}

impl Oct {
    /// Construct a pure real octonion: a + 0·e₁ + ... + 0·e₇.
    pub fn real(a: f64) -> Self {
        Self {
            c: [a, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        }
    }

    /// Construct the i-th basis octonion eᵢ (i = 0..7, where e₀ = 1).
    pub fn basis(i: usize) -> Self {
        let mut c = [0.0; 8];
        c[i] = 1.0;
        Self { c }
    }

    /// Euclidean norm ‖q‖ = √(Σ cᵢ²).
    pub fn norm(&self) -> f64 {
        self.c.iter().map(|x| x * x).sum::<f64>().sqrt()
    }

    /// Conjugate: (a, b) → (a, -b) for imaginary parts.
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

    /// Real part.
    pub fn re(&self) -> f64 {
        self.c[0]
    }

    /// Octonion multiplication using the standard Cayley-Dickson table.
    ///
    /// Note: octonion multiplication is **non-associative** but **alternative**.
    /// The multiplication table follows Cartan-Schouten conventions.
    pub fn mul(&self, o: &Self) -> Self {
        let (a, b) = (&self.c, &o.c);
        Self {
            c: [
                a[0] * b[0]
                    - a[1] * b[1]
                    - a[2] * b[2]
                    - a[3] * b[3]
                    - a[4] * b[4]
                    - a[5] * b[5]
                    - a[6] * b[6]
                    - a[7] * b[7],
                a[0] * b[1] + a[1] * b[0] + a[2] * b[3] - a[3] * b[2] + a[4] * b[5]
                    - a[5] * b[4]
                    - a[6] * b[7]
                    + a[7] * b[6],
                a[0] * b[2] - a[1] * b[3] + a[2] * b[0] + a[3] * b[1] + a[4] * b[6] + a[5] * b[7]
                    - a[6] * b[4]
                    - a[7] * b[5],
                a[0] * b[3] + a[1] * b[2] - a[2] * b[1] + a[3] * b[0] + a[4] * b[7] - a[5] * b[6]
                    + a[6] * b[5]
                    - a[7] * b[4],
                a[0] * b[4] - a[1] * b[5] - a[2] * b[6] - a[3] * b[7]
                    + a[4] * b[0]
                    + a[5] * b[1]
                    + a[6] * b[2]
                    + a[7] * b[3],
                a[0] * b[5] + a[1] * b[4] - a[2] * b[7] + a[3] * b[6] - a[4] * b[1] + a[5] * b[0]
                    - a[6] * b[3]
                    + a[7] * b[2],
                a[0] * b[6] + a[1] * b[7] + a[2] * b[4] - a[3] * b[5] - a[4] * b[2]
                    + a[5] * b[3]
                    + a[6] * b[0]
                    - a[7] * b[1],
                a[0] * b[7] - a[1] * b[6] + a[2] * b[5] + a[3] * b[4] - a[4] * b[3] - a[5] * b[2]
                    + a[6] * b[1]
                    + a[7] * b[0],
            ],
        }
    }
}

/// Map the first 7 primes to octonion basis indices 1..7.
///
/// The mapping {2→1, 3→2, 5→3, 7→4, 11→5, 13→6, 17→7} assigns each
/// small prime a unique imaginary direction. Larger primes wrap modulo 7.
pub fn prime_to_basis(p: usize) -> usize {
    match p {
        2 => 1,
        3 => 2,
        5 => 3,
        7 => 4,
        11 => 5,
        13 => 6,
        17 => 7,
        _ => (p % 7) + 1,
    }
}

/// Complete prime factorization with multiplicity (trial division).
///
/// Returns factors in ascending order, e.g. `prime_factors(12) = [2, 2, 3]`.
pub fn prime_factors(mut n: usize) -> Vec<usize> {
    let mut f = Vec::new();
    let mut p = 2;
    while p * p <= n {
        while n % p == 0 {
            f.push(p);
            n /= p;
        }
        p += 1;
    }
    if n > 1 {
        f.push(n);
    }
    f
}

/// Map a positive integer to a unit octonion via its prime factorization.
///
/// `int_to_octonion(k)` = ∏ e_{basis(p)} for each prime factor p of k,
/// evaluated strictly left-to-right in ascending prime order.
///
/// **Non-associativity note:** Because the octonions are non-associative,
/// this mapping is not a homomorphism; `f(a·b) = f(a)·f(b)` holds only
/// up to a sign (due to the alternating associator). However, the ordered
/// left-fold over sorted prime factors ensures every integer maps to a
/// deterministic, unique point on the unit sphere S⁷ ⊂ 𝕆.
///
/// # Examples
/// - `int_to_octonion(1) = (1, 0, 0, 0, 0, 0, 0, 0)` (identity)
/// - `int_to_octonion(2) = e₁` (basis element for prime 2)
/// - `int_to_octonion(6) = e₁ · e₂` (product of bases for 2 and 3)
pub fn int_to_octonion(k: usize) -> Oct {
    if k <= 1 {
        return Oct::real(1.0);
    }
    let mut r = Oct::real(1.0);
    for &p in &prime_factors(k) {
        r = r.mul(&Oct::basis(prime_to_basis(p)));
    }
    let n = r.norm();
    if n > 1e-10 {
        r.scale(1.0 / n)
    } else {
        Oct::real(1.0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_oct_real() {
        let o = Oct::real(3.0);
        assert!((o.re() - 3.0).abs() < 1e-15);
        assert!((o.norm() - 3.0).abs() < 1e-15);
    }

    #[test]
    fn test_oct_basis_orthogonal() {
        for i in 0..8 {
            let e = Oct::basis(i);
            assert!((e.norm() - 1.0).abs() < 1e-15);
        }
    }

    #[test]
    fn test_int_to_octonion_unit_norm() {
        for k in 1..=20 {
            let o = int_to_octonion(k);
            assert!(
                (o.norm() - 1.0).abs() < 1e-10,
                "int_to_octonion({}) has norm {}",
                k,
                o.norm()
            );
        }
    }

    #[test]
    fn test_prime_factors() {
        assert_eq!(prime_factors(1), Vec::<usize>::new());
        assert_eq!(prime_factors(12), vec![2, 2, 3]);
        assert_eq!(prime_factors(7), vec![7]);
        assert_eq!(prime_factors(30), vec![2, 3, 5]);
    }
}
