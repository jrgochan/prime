//! ═══════════════════════════════════════════════════════════════════════════
//!  GCD-CLASS DECOMPOSITION (shared module)
//!
//!  The Gram matrix G_{jk} = ∫₀¹ {j/t}{k/t} dt has rich structure
//!  arising from gcd(j,k). We decompose {1,...,N} into equivalence
//!  classes based on their coprimality structure.
//!
//!  Class d: all indices j such that the "maximal coprime core" of j
//!           (relative to N) involves divisor d.
//!
//!  For the Gram matrix, the key observation is:
//!    G_{jk} depends fundamentally on gcd(j,k).
//!    When gcd(j,k) = d, G_{jk} can be expressed in terms of G_{j/d, k/d}
//!    plus correction terms involving the Euler totient.
//!
//!  This decomposition reveals the block structure that controls λ_min.
//! ═══════════════════════════════════════════════════════════════════════════

use crate::arith::{gcd, mobius_table};
use std::collections::BTreeMap;
use rayon::prelude::*;

/// Result of GCD-class decomposition.
pub struct GcdDecomposition {
    /// Map from gcd value d → list of index pairs (j,k) with gcd(j,k) = d.
    /// But more usefully: map from d → list of indices j that are multiples of d.
    pub classes: BTreeMap<usize, Vec<usize>>,
    /// For each index j in 1..=N, the set of divisors.
    pub divisors: Vec<Vec<usize>>,
    /// Euler totient values φ(d) for d ≤ N.
    pub totient: Vec<usize>,
    /// Möbius function μ(d) for d ≤ N.
    pub mobius: Vec<i8>,
}

/// Compute gcd using binary GCD (efficient for large integers).

/// Compute Euler totient φ(n) for 1..=n via sieve.
pub fn sieve_totient(n: usize) -> Vec<usize> {
    let mut phi: Vec<usize> = (0..=n).collect();
    for i in 2..=n {
        if phi[i] == i {
            // i is prime
            let mut j = i;
            while j <= n {
                phi[j] -= phi[j] / i;
                j += i;
            }
        }
    }
    phi
}

/// Decompose {1,...,N} by GCD classes.
///
/// Class d contains all pairs (j,k) with gcd(j,k) = d.
/// For the oracle, we focus on "coprimality blocks":
///   Block_d = { j ∈ {1,...,N} : d | j }
/// The Gram submatrix restricted to Block_d has special structure.
pub fn decompose(n: usize) -> GcdDecomposition {
    let mobius = mobius_table(n);
    let totient = sieve_totient(n);

    // Build divisor lists in parallel
    let divisors: Vec<Vec<usize>> = (0..=n)
        .into_par_iter()
        .map(|j| {
            if j == 0 { return vec![]; }
            (1..=j).filter(|d| j % d == 0).collect()
        })
        .collect();

    // Build GCD classes: for each d, indices that are multiples of d
    let mut classes = BTreeMap::new();
    for d in 1..=n {
        let multiples: Vec<usize> = (1..=n).filter(|&j| j % d == 0).collect();
        if !multiples.is_empty() {
            classes.insert(d, multiples);
        }
    }

    GcdDecomposition { classes, divisors, totient, mobius }
}

/// Extract the "coprime core" block: indices j ∈ {1,...,N} with gcd(j, d) = d
/// (i.e., d | j), and then reduce to j/d, keeping only those with gcd(j/d, ...) structure.
pub fn coprime_indices(n: usize, d: usize) -> Vec<usize> {
    (1..=n).filter(|&j| j % d == 0).collect()
}

/// For a GCD class d, extract the reduced indices j/d.
pub fn reduced_indices(n: usize, d: usize) -> Vec<usize> {
    (1..=n)
        .filter(|&j| j % d == 0)
        .map(|j| j / d)
        .collect()
}

/// Count the number of coprime pairs in {1,...,N}.
pub fn coprime_pair_count(n: usize) -> usize {
    (1..=n)
        .into_par_iter()
        .map(|j| {
            (j+1..=n).filter(|&k| gcd(j, k) == 1).count()
        })
        .sum()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_gcd() {
        assert_eq!(gcd(12, 8), 4);
        assert_eq!(gcd(7, 13), 1);
        assert_eq!(gcd(100, 25), 25);
        assert_eq!(gcd(0, 5), 5);
    }

    #[test]
    fn test_mobius() {
        let mu = mobius_table(10);
        assert_eq!(mu[1], 1);
        assert_eq!(mu[2], -1);
        assert_eq!(mu[3], -1);
        assert_eq!(mu[4], 0);  // 4 = 2²
        assert_eq!(mu[5], -1);
        assert_eq!(mu[6], 1);  // 6 = 2·3
    }

    #[test]
    fn test_totient() {
        let phi = sieve_totient(12);
        assert_eq!(phi[1], 1);
        assert_eq!(phi[2], 1);
        assert_eq!(phi[6], 2);
        assert_eq!(phi[12], 4);
    }

    #[test]
    fn test_decompose() {
        let d = decompose(10);
        // Class 1 should contain all 10 indices
        assert_eq!(d.classes[&1].len(), 10);
        // Class 2 should contain 2,4,6,8,10
        assert_eq!(d.classes[&2].len(), 5);
        // Class 5 should contain 5,10
        assert_eq!(d.classes[&5].len(), 2);
    }

    #[test]
    fn test_reduced_indices() {
        let ri = reduced_indices(12, 3);
        assert_eq!(ri, vec![1, 2, 3, 4]); // 3/3, 6/3, 9/3, 12/3
    }
}
