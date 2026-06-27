// ═══════════════════════════════════════════════════════════════════════
//  arithmetic.rs — Number-theoretic foundations
//
//  Lean bridge:
//    proofs/Cathedral/NumberTheory/DirichletConvolution.lean  (μ properties)
//    proofs/Cathedral/Covariance/GramFormProof.lean           (GCD reduction)
// ═══════════════════════════════════════════════════════════════════════

/// Linear sieve for the Möbius function μ(n), 0..=n.
///
/// μ(1) = 1, μ(p₁p₂...pₖ) = (-1)^k for distinct primes, μ(n) = 0 if p²|n.
/// The Lean formalization uses this for the Perron chain and Abel tail proofs.
pub fn mobius_sieve(n: usize) -> Vec<i32> {
    let mut mu = vec![0i32; n + 1];
    mu[1] = 1;
    let mut is_prime = vec![true; n + 1];
    let mut primes = Vec::new();
    for i in 2..=n {
        if is_prime[i] {
            primes.push(i);
            mu[i] = -1;
        }
        for &p in &primes {
            if i * p > n {
                break;
            }
            is_prime[i * p] = false;
            if i % p == 0 {
                mu[i * p] = 0;
                break;
            } else {
                mu[i * p] = -mu[i];
            }
        }
    }
    mu
}

/// Greatest common divisor (Euclidean algorithm).
///
/// Used in the Gram entry GCD reduction: G(j,k) depends on gcd(j,k)
/// through both the period lcm(j,k) and the tail mean formula.
/// Lean: Covariance/GramFormProof.lean uses gcd for the cotangent identity.
pub fn gcd(a: usize, b: usize) -> usize {
    let (mut a, mut b) = (a, b);
    while b != 0 {
        let t = b;
        b = a % b;
        a = t;
    }
    a
}

/// Trial-division primality test.
#[allow(dead_code)]
pub fn is_prime(n: usize) -> bool {
    if n < 2 {
        return false;
    }
    if n < 4 {
        return true;
    }
    if n.is_multiple_of(2) || n.is_multiple_of(3) {
        return false;
    }
    let mut d = 5;
    while d * d <= n {
        if n.is_multiple_of(d) || n.is_multiple_of(d + 2) {
            return false;
        }
        d += 6;
    }
    true
}
