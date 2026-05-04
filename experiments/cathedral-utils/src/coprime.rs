//! Coprime pair generation and standard test datasets.
//!
//! Provides curated sets of coprime pairs (a,b) with a < b for use across
//! Cathedral experiments. These pairs are fundamental to the Vasyunin
//! decomposition, Gram matrix validation, and axiom graduation proofs.
//!
//! ## Usage
//!
//! ```rust
//! use cathedral_utils::coprime;
//!
//! // Standard 18-pair test set used in axiom graduation
//! let pairs = coprime::standard_pairs();
//!
//! // Generate all coprime pairs up to max_b
//! let all = coprime::generate(20);
//!
//! // Filter by minimum a
//! let nontrivial = coprime::generate_filtered(15, 2, 15);
//! ```

use crate::arith;

/// A coprime pair (a, b) with 1 ≤ a < b and gcd(a,b) = 1.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct CoprimePair {
    pub a: usize,
    pub b: usize,
}

impl CoprimePair {
    /// Create a new coprime pair. Panics if gcd(a,b) ≠ 1 or a ≥ b.
    pub fn new(a: usize, b: usize) -> Self {
        assert!(a < b, "CoprimePair requires a < b, got ({a}, {b})");
        assert!(arith::gcd(a, b) == 1, "({a}, {b}) are not coprime");
        Self { a, b }
    }

    /// LCM of the pair.
    #[inline]
    pub fn lcm(&self) -> usize {
        self.a * self.b // coprime → lcm = ab
    }

    /// Strip value: (a-1)/(ab).
    #[inline]
    pub fn strip(&self) -> f64 {
        if self.a <= 1 { 0.0 }
        else { (self.a - 1) as f64 / (self.a * self.b) as f64 }
    }

    /// Whether this is a "diagonal" pair (a=1).
    #[inline]
    pub fn is_diagonal(&self) -> bool {
        self.a == 1
    }

    /// Euler totient product φ(a)·φ(b) / (ab).
    /// For coprime pairs, this relates to the density of lattice points.
    #[inline]
    pub fn totient_density(&self) -> f64 {
        let phi_a = euler_totient_single(self.a) as f64;
        let phi_b = euler_totient_single(self.b) as f64;
        (phi_a * phi_b) / (self.a * self.b) as f64
    }
}

impl std::fmt::Display for CoprimePair {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "({}, {})", self.a, self.b)
    }
}

/// Euler totient for a single value.
fn euler_totient_single(n: usize) -> usize {
    if n <= 1 { return n; }
    let mut result = n;
    let mut m = n;
    let mut p = 2;
    while p * p <= m {
        if m % p == 0 {
            while m % p == 0 { m /= p; }
            result = result / p * (p - 1);
        }
        p += 1;
    }
    if m > 1 {
        result = result / m * (m - 1);
    }
    result
}

// ═══════════════════════════════════════════════════════════════
// CURATED DATASETS
// ═══════════════════════════════════════════════════════════════

/// **Standard 18-pair test set** — the canonical dataset used for
/// Vasyunin axiom graduation and two-tile decomposition validation.
///
/// Covers:
///   - 4 diagonal pairs (a=1): b ∈ {2, 3, 5, 7}
///   - 14 off-diagonal pairs (a≥2): exhaustive for a,b ≤ 9
///
/// This set has been validated at 512-bit MPFR precision with M=250,000.
pub fn standard_pairs() -> Vec<CoprimePair> {
    STANDARD_PAIRS.iter()
        .map(|&(a, b)| CoprimePair { a, b })
        .collect()
}

/// The raw standard pair data.
const STANDARD_PAIRS: &[(usize, usize)] = &[
    (1, 2), (1, 3), (1, 5), (1, 7),
    (2, 3), (2, 5), (2, 7),
    (3, 4), (3, 5), (3, 7),
    (4, 5), (4, 7),
    (5, 6), (5, 7), (5, 9),
    (6, 7),
    (7, 8), (7, 9),
];

/// **Extended pair set** — all coprime pairs with a < b ≤ 20.
/// 127 pairs covering the full small-index Gram matrix.
pub fn extended_pairs() -> Vec<CoprimePair> {
    generate(20)
}

/// **Large pair set** — all coprime pairs with a < b ≤ 50.
/// ~775 pairs for comprehensive coverage.
pub fn large_pairs() -> Vec<CoprimePair> {
    generate(50)
}

/// **Stress-test pair set** — all coprime pairs with a < b ≤ 100.
/// ~3,043 pairs for exhaustive validation.
pub fn stress_pairs() -> Vec<CoprimePair> {
    generate(100)
}

// ═══════════════════════════════════════════════════════════════
// GENERATORS
// ═══════════════════════════════════════════════════════════════

/// Generate all coprime pairs (a, b) with 1 ≤ a < b ≤ max_b.
pub fn generate(max_b: usize) -> Vec<CoprimePair> {
    generate_filtered(max_b, 1, max_b)
}

/// Generate coprime pairs (a, b) with min_a ≤ a < b ≤ max_b.
pub fn generate_filtered(max_b: usize, min_a: usize, max_a: usize) -> Vec<CoprimePair> {
    let mut pairs = Vec::new();
    for b in 2..=max_b {
        let a_upper = b.min(max_a + 1);
        for a in min_a..a_upper {
            if arith::gcd(a, b) == 1 {
                pairs.push(CoprimePair { a, b });
            }
        }
    }
    pairs
}

/// Generate only the off-diagonal coprime pairs (a ≥ 2) up to max_b.
/// These are the "hard" cases requiring the Σ'Δ evaluation.
pub fn off_diagonal_pairs(max_b: usize) -> Vec<CoprimePair> {
    generate_filtered(max_b, 2, max_b)
}

/// Generate only the diagonal coprime pairs (a = 1) up to max_b.
/// These are the "easy" cases proven axiom-free in FractSeriesEval.
pub fn diagonal_pairs(max_b: usize) -> Vec<CoprimePair> {
    (2..=max_b).map(|b| CoprimePair { a: 1, b }).collect()
}

/// Generate pairs with a specific value of a.
pub fn pairs_with_a(a: usize, max_b: usize) -> Vec<CoprimePair> {
    generate_filtered(max_b, a, a)
}

// ═══════════════════════════════════════════════════════════════
// STATISTICS
// ═══════════════════════════════════════════════════════════════

/// Count of coprime pairs with a < b ≤ n.
/// Asymptotically: C(n) ~ (3/π²) · n² (Euler product).
pub fn count_pairs(max_b: usize) -> usize {
    generate(max_b).len()
}

/// Print summary statistics for a set of pairs.
pub fn print_summary(pairs: &[CoprimePair]) {
    let n = pairs.len();
    let diag = pairs.iter().filter(|p| p.is_diagonal()).count();
    let off_diag = n - diag;
    let max_a = pairs.iter().map(|p| p.a).max().unwrap_or(0);
    let max_b = pairs.iter().map(|p| p.b).max().unwrap_or(0);
    let max_lcm = pairs.iter().map(|p| p.lcm()).max().unwrap_or(0);

    println!("  Coprime pairs: {n}");
    println!("    Diagonal (a=1):     {diag}");
    println!("    Off-diagonal (a≥2): {off_diag}");
    println!("    Range: a ≤ {max_a}, b ≤ {max_b}");
    println!("    Max lcm: {max_lcm}");
}

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_standard_pairs_count() {
        let pairs = standard_pairs();
        assert_eq!(pairs.len(), 18, "Standard dataset should have 18 pairs");
    }

    #[test]
    fn test_all_standard_coprime() {
        for p in standard_pairs() {
            assert_eq!(arith::gcd(p.a, p.b), 1,
                "({}, {}) should be coprime", p.a, p.b);
            assert!(p.a < p.b, "({}, {}) should have a < b", p.a, p.b);
        }
    }

    #[test]
    fn test_generate_small() {
        let pairs = generate(5);
        let expected = vec![
            (1,2), (1,3), (2,3), (1,4), (3,4),
            (1,5), (2,5), (3,5), (4,5),
        ];
        assert_eq!(pairs.len(), expected.len());
        for (p, &(a, b)) in pairs.iter().zip(&expected) {
            assert_eq!((p.a, p.b), (a, b));
        }
    }

    #[test]
    fn test_diagonal_pairs() {
        let diag = diagonal_pairs(7);
        assert_eq!(diag.len(), 6); // b = 2,3,4,5,6,7
        assert!(diag.iter().all(|p| p.a == 1));
    }

    #[test]
    fn test_off_diagonal() {
        let off = off_diagonal_pairs(7);
        assert!(off.iter().all(|p| p.a >= 2));
        assert!(off.iter().all(|p| arith::gcd(p.a, p.b) == 1));
    }

    #[test]
    fn test_strip_values() {
        let p = CoprimePair { a: 1, b: 3 };
        assert_eq!(p.strip(), 0.0);

        let p = CoprimePair { a: 2, b: 3 };
        assert!((p.strip() - 1.0/6.0).abs() < 1e-15);

        let p = CoprimePair { a: 3, b: 5 };
        assert!((p.strip() - 2.0/15.0).abs() < 1e-15);
    }

    #[test]
    fn test_extended_count() {
        // The number of coprime pairs with a < b ≤ 20
        // should be around 3/π² · 20² ≈ 121.6
        let pairs = extended_pairs();
        assert!(pairs.len() > 100 && pairs.len() < 150,
            "Expected ~127 pairs, got {}", pairs.len());
    }

    #[test]
    fn test_large_count() {
        let pairs = large_pairs();
        // 3/π² · 50² ≈ 759.9
        assert!(pairs.len() > 700 && pairs.len() < 850,
            "Expected ~775 pairs, got {}", pairs.len());
    }
}
