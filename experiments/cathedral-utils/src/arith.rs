//! Number theory primitives.
//!
//! Provides the fundamental arithmetic operations used across all
//! Cathedral experiments: gcd, sieve, Möbius function, Liouville function,
//! integer factorization, b-vector construction, and totient.

/// Greatest common divisor (Euclidean algorithm).
#[inline(always)]
pub fn gcd(mut a: usize, mut b: usize) -> usize {
    while b != 0 {
        let t = b;
        b = a % b;
        a = t;
    }
    a
}

/// Least common multiple.
#[inline(always)]
pub fn lcm(a: usize, b: usize) -> usize {
    if a == 0 || b == 0 {
        0
    } else {
        (a / gcd(a, b)) * b
    }
}

/// Sieve of Eratosthenes. Returns `is_prime[0..=n]`.
pub fn sieve_primes(n: usize) -> Vec<bool> {
    let mut is_prime = vec![true; n + 1];
    if n >= 1 {
        is_prime[0] = false;
    }
    if n >= 1 {
        is_prime[1] = false;
    }
    let mut p = 2;
    while p * p <= n {
        if is_prime[p] {
            let mut m = p * p;
            while m <= n {
                is_prime[m] = false;
                m += p;
            }
        }
        p += 1;
    }
    is_prime
}

/// Möbius function table: μ(n) for n = 0..=max_n.
///
/// μ(1) = 1, μ(n) = 0 if n has a squared factor,
/// μ(n) = (-1)^k if n is a product of k distinct primes.
pub fn mobius_table(max_n: usize) -> Vec<i8> {
    let mut mu = vec![1i8; max_n + 1];
    let mut prime_count = vec![0u8; max_n + 1];
    let mut has_square = vec![false; max_n + 1];

    for p in 2..=max_n {
        if prime_count[p] == 0 && !has_square[p] {
            // p is prime
            for m in (p..=max_n).step_by(p) {
                prime_count[m] += 1;
            }
            let p2 = p * p;
            if p2 <= max_n {
                for m in (p2..=max_n).step_by(p2) {
                    has_square[m] = true;
                }
            }
        }
    }

    mu[0] = 0;
    for n in 2..=max_n {
        if has_square[n] {
            mu[n] = 0;
        } else {
            mu[n] = if prime_count[n] % 2 == 0 { 1 } else { -1 };
        }
    }
    mu
}

/// Liouville function table: λ(n) = (-1)^Ω(n) for n = 0..=max_n.
///
/// Ω(n) = total number of prime factors with multiplicity.
/// Unlike μ(n), λ(n) is never zero — it preserves mass on all integers.
pub fn liouville_table(max_n: usize) -> Vec<i8> {
    let mut omega = vec![0u32; max_n + 1];
    for p in 2..=max_n {
        if omega[p] != 0 {
            continue;
        }
        let mut pk = p;
        while pk <= max_n {
            for m in (pk..=max_n).step_by(pk) {
                omega[m] += 1;
            }
            if pk > max_n / p {
                break;
            }
            pk *= p;
        }
    }
    (0..=max_n)
        .map(|n| if omega[n] % 2 == 0 { 1i8 } else { -1i8 })
        .collect()
}

/// Euler's totient function: φ(n) for n = 0..=max_n.
pub fn euler_totient(max_n: usize) -> Vec<usize> {
    let mut phi: Vec<usize> = (0..=max_n).collect();
    for p in 2..=max_n {
        if phi[p] == p {
            // p is prime
            for m in (p..=max_n).step_by(p) {
                phi[m] = phi[m] / p * (p - 1);
            }
        }
    }
    phi
}

/// Factorize n into a human-readable string like "2³·3·7²".
///
/// Returns "(prime)" suffix for primes.
pub fn factorize(n: usize) -> String {
    if n <= 1 {
        return n.to_string();
    }
    let mut factors = Vec::new();
    let mut rem = n;
    let mut p = 2;
    while p * p <= rem {
        if rem % p == 0 {
            let mut exp = 0;
            while rem % p == 0 {
                rem /= p;
                exp += 1;
            }
            if exp == 1 {
                factors.push(format!("{p}"));
            } else {
                factors.push(format!("{p}^{exp}"));
            }
        }
        p += 1;
    }
    if rem > 1 {
        if factors.is_empty() {
            return format!("{n} (prime)");
        }
        factors.push(format!("{rem}"));
    }
    factors.join("·")
}

/// Count of prime factors with multiplicity: Ω(n).
pub fn big_omega(n: usize) -> u32 {
    if n <= 1 {
        return 0;
    }
    let mut count = 0u32;
    let mut rem = n;
    let mut p = 2;
    while p * p <= rem {
        while rem % p == 0 {
            count += 1;
            rem /= p;
        }
        p += 1;
    }
    if rem > 1 {
        count += 1;
    }
    count
}

/// Nyman-Beurling b-vector: b_k = 1 - 1/(2(k+1)) for k = 2, ..., dim+1.
///
/// b_k = ∫₀¹ {1/(kt)} dt where {x} = x - ⌊x⌋.
pub fn b_vector(dim: usize) -> Vec<f64> {
    (0..dim)
        .map(|i| {
            let k = (i + 2) as f64;
            1.0 - 1.0 / (2.0 * k)
        })
        .collect()
}

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_gcd() {
        assert_eq!(gcd(12, 8), 4);
        assert_eq!(gcd(7, 13), 1);
        assert_eq!(gcd(100, 0), 100);
        assert_eq!(gcd(0, 5), 5);
    }

    #[test]
    fn test_lcm() {
        assert_eq!(lcm(4, 6), 12);
        assert_eq!(lcm(7, 13), 91);
        assert_eq!(lcm(0, 5), 0);
    }

    #[test]
    fn test_sieve() {
        let s = sieve_primes(20);
        let primes: Vec<usize> = (0..=20).filter(|&i| s[i]).collect();
        assert_eq!(primes, vec![2, 3, 5, 7, 11, 13, 17, 19]);
    }

    #[test]
    fn test_mobius() {
        let mu = mobius_table(10);
        assert_eq!(mu[1], 1);
        assert_eq!(mu[2], -1); // prime
        assert_eq!(mu[4], 0);  // 2²
        assert_eq!(mu[6], 1);  // 2·3 (2 distinct primes)
        assert_eq!(mu[8], 0);  // 2³
        assert_eq!(mu[10], 1); // 2·5
    }

    #[test]
    fn test_liouville() {
        let lv = liouville_table(10);
        assert_eq!(lv[1], 1);   // Ω=0
        assert_eq!(lv[2], -1);  // Ω=1
        assert_eq!(lv[4], 1);   // Ω=2
        assert_eq!(lv[6], 1);   // Ω=2
        assert_eq!(lv[8], -1);  // Ω=3
    }

    #[test]
    fn test_factorize() {
        assert_eq!(factorize(12), "2^2·3");
        assert_eq!(factorize(7), "7 (prime)");
        assert_eq!(factorize(1), "1");
        assert_eq!(factorize(360), "2^3·3^2·5");
    }

    #[test]
    fn test_b_vector_decreasing() {
        let b = b_vector(20);
        for i in 1..b.len() {
            assert!(b[i] > b[i - 1], "b-vector must be increasing");
        }
        // b_2 = 1 - 1/4 = 0.75
        assert!((b[0] - 0.75).abs() < 1e-10);
    }

    #[test]
    fn test_euler_totient() {
        let phi = euler_totient(12);
        assert_eq!(phi[1], 1);
        assert_eq!(phi[2], 1);
        assert_eq!(phi[6], 2);  // {1, 5}
        assert_eq!(phi[12], 4); // {1, 5, 7, 11}
    }
}
