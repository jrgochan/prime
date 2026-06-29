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

/// Fractional part: {x} = x - ⌊x⌋.
///
/// The fundamental building block of the Nyman-Beurling inner product
/// ⟨{j/·}, {k/·}⟩ = ∫₀¹ {j/t}{k/t} dt.
#[inline(always)]
pub fn frac_part(x: f64) -> f64 {
    x - x.floor()
}

/// Liouville function: λ(n) = (-1)^{Ω(n)} for a single n.
///
/// For table-based computation, use [`liouville_table`] instead.
#[inline]
pub fn liouville(n: usize) -> f64 {
    if big_omega(n).is_multiple_of(2) {
        1.0
    } else {
        -1.0
    }
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
            mu[n] = if prime_count[n].is_multiple_of(2) {
                1
            } else {
                -1
            };
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
        .map(|n| {
            if omega[n].is_multiple_of(2) {
                1i8
            } else {
                -1i8
            }
        })
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
        if rem.is_multiple_of(p) {
            let mut exp = 0;
            while rem.is_multiple_of(p) {
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

/// Count of distinct prime factors: ω(n).
///
/// ω(n) = number of distinct primes dividing n.
/// ω(1) = 0, ω(p) = 1, ω(pq) = 2, ω(p²) = 1.
pub fn small_omega(n: usize) -> u32 {
    if n <= 1 {
        return 0;
    }
    let mut count = 0u32;
    let mut rem = n;
    let mut p = 2;
    while p * p <= rem {
        if rem.is_multiple_of(p) {
            count += 1;
            while rem.is_multiple_of(p) {
                rem /= p;
            }
        }
        p += 1;
    }
    if rem > 1 {
        count += 1;
    }
    count
}

/// Table of ω(n) for n = 0..=max_n.
pub fn small_omega_table(max_n: usize) -> Vec<u32> {
    let mut omega = vec![0u32; max_n + 1];
    let is_prime = sieve_primes(max_n);
    for p in 2..=max_n {
        if is_prime[p] {
            for m in (p..=max_n).step_by(p) {
                omega[m] += 1;
            }
        }
    }
    omega
}

/// Von Mangoldt function: Λ(n) = ln(p) if n = p^k, else 0.
pub fn von_mangoldt(n: usize) -> f64 {
    if n <= 1 {
        return 0.0;
    }
    let mut rem = n;
    let mut p = 2;
    while p * p <= rem {
        if rem.is_multiple_of(p) {
            while rem.is_multiple_of(p) {
                rem /= p;
            }
            return if rem == 1 { (p as f64).ln() } else { 0.0 };
        }
        p += 1;
    }
    // n itself is prime
    (n as f64).ln()
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
        while rem.is_multiple_of(p) {
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

/// Euler-Mascheroni constant γ ≈ 0.5772156649...
pub const EULER_GAMMA: f64 = 0.577_215_664_901_532_9;

/// Sum-of-divisors σ₁(n) for a single n.
pub fn sigma1(n: usize) -> usize {
    if n <= 1 {
        return n;
    }
    let mut s = 0usize;
    let mut d = 1;
    while d * d <= n {
        if n.is_multiple_of(d) {
            s += d;
            if d != n / d {
                s += n / d;
            }
        }
        d += 1;
    }
    s
}

/// σ₁(n) table for n = 0..=max_n.
pub fn sigma1_table(max_n: usize) -> Vec<usize> {
    let mut s = vec![0usize; max_n + 1];
    for d in 1..=max_n {
        for m in (d..=max_n).step_by(d) {
            s[m] += d;
        }
    }
    s
}

/// Dirichlet character mod 8. Returns value in {-1, 0, 1}.
/// Matches Cathedral/Rotors/GallagherPartition.lean.
///   ch=0: principal (1 for all odd)
///   ch=1: (1,-1,-1,1) on residues 1,3,5,7
///   ch=2: (1,-1,1,-1) — Kronecker symbol (2/·)
///   ch=3: (1,1,-1,-1) — Kronecker symbol (-1/·)
pub fn chi8(ch: usize, n: usize) -> i64 {
    if n.is_multiple_of(2) {
        return 0;
    }
    match ch {
        0 => 1,
        1 => match n % 8 {
            1 => 1,
            3 => -1,
            5 => -1,
            7 => 1,
            _ => 0,
        },
        2 => match n % 8 {
            1 => 1,
            3 => -1,
            5 => 1,
            7 => -1,
            _ => 0,
        },
        3 => match n % 8 {
            1 => 1,
            3 => 1,
            5 => -1,
            7 => -1,
            _ => 0,
        },
        _ => 0,
    }
}

/// Bartlett-tapered Möbius weights: v_k = -μ(k)(1 - ln k / ln N)
/// for k = 2..=n. Returns vec of length n-1 (index 0 → k=2).
pub fn mobius_weights(n: usize) -> Vec<f64> {
    let mu = mobius_table(n);
    let ln_n = (n as f64).ln();
    (2..=n)
        .map(|k| -(mu[k] as f64) * (1.0 - (k as f64).ln() / ln_n))
        .collect()
}

/// Kahan compensated summation accumulator.
/// Use for long sums where catastrophic cancellation matters.
#[derive(Clone, Copy, Default, Debug)]
pub struct Kahan {
    pub sum: f64,
    pub comp: f64,
}

impl Kahan {
    pub fn new() -> Self {
        Self::default()
    }
    pub fn add(&mut self, val: f64) {
        let y = val - self.comp;
        let t = self.sum + y;
        self.comp = (t - self.sum) - y;
        self.sum = t;
    }
    pub fn value(&self) -> f64 {
        self.sum
    }
}

/// Nyman-Beurling b-vector (analytic formula).
///
/// b_k = ∫₀¹ {1/(kx)} dx = (ln k + 1 - γ) / k
///
/// where {x} = x - ⌊x⌋ is the fractional part function and
/// γ is the Euler-Mascheroni constant.
///
/// NOTE: b_k → 0 as k → ∞ (decays like ln(k)/k).
pub fn b_vector(dim: usize) -> Vec<f64> {
    (0..dim)
        .map(|i| {
            let k = (i + 2) as f64;
            (k.ln() + 1.0 - EULER_GAMMA) / k
        })
        .collect()
}

/// Nyman-Beurling b-vector for k=1..N (Lean-aligned basis).
///
/// b_k = (ln(k) + 1 - γ) / k
///
/// For k=1: b_1 = (0 + 1 - γ) / 1 = 1 - γ ≈ 0.4228
/// This is the missing inner-product contribution when using k=2..N.
pub fn b_vector_full(n: usize) -> Vec<f64> {
    (0..n)
        .map(|i| {
            let k = (i + 1) as f64;
            (k.ln() + 1.0 - EULER_GAMMA) / k
        })
        .collect()
}

/// Nyman-Beurling b-vector (discretization-consistent Vasyunin expansion).
///
/// Uses the same ln(1+1/n) series as the Gram matrix computation,
/// ensuring G and b live in the same discrete Hilbert space:
///
///   b_k = Σ_{n=1}^{T} [ ln(1+1/n)/k - ⌊n/k⌋/(n(n+1)) ] + tail
///
/// When T → ∞, this converges exactly to (ln k + 1 - γ)/k.
///
/// `ln_values`: precomputed ln(1+1/n) table (same one used for Gram entries).
/// `t_max`: truncation point (should match Gram matrix series length).
pub fn b_vector_discrete(dim: usize, ln_values: &[f64], t_max: usize) -> Vec<f64> {
    (0..dim)
        .map(|i| {
            let k = i + 2;
            let kf = k as f64;
            let mut total = 0.0f64;
            let t = t_max.min(ln_values.len() - 1);
            for n in 1..=t {
                let ln_term = ln_values[n]; // ln(1 + 1/n)
                let floor_nk = (n / k) as f64;
                let frac = floor_nk / ((n as f64) * ((n + 1) as f64));
                total += ln_term / kf - frac;
            }
            // Euler-Maclaurin tail correction (matches gram.rs tail)
            let tf = t as f64;
            let inv_t = 1.0 / tf;
            // Leading tail: ~ (1/k) * (1/t) * (1/2 + ...)
            total += (1.0 / kf) * inv_t * 0.5;
            total
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
        assert_eq!(mu[4], 0); // 2²
        assert_eq!(mu[6], 1); // 2·3 (2 distinct primes)
        assert_eq!(mu[8], 0); // 2³
        assert_eq!(mu[10], 1); // 2·5
    }

    #[test]
    fn test_liouville() {
        let lv = liouville_table(10);
        assert_eq!(lv[1], 1); // Ω=0
        assert_eq!(lv[2], -1); // Ω=1
        assert_eq!(lv[4], 1); // Ω=2
        assert_eq!(lv[6], 1); // Ω=2
        assert_eq!(lv[8], -1); // Ω=3
    }

    #[test]
    fn test_factorize() {
        assert_eq!(factorize(12), "2^2·3");
        assert_eq!(factorize(7), "7 (prime)");
        assert_eq!(factorize(1), "1");
        assert_eq!(factorize(360), "2^3·3^2·5");
    }

    #[test]
    fn test_b_vector_decaying() {
        let b = b_vector(20);
        // b_k = (ln k + 1 - γ) / k → 0 as k → ∞
        // b_2 = (ln 2 + 1 - γ) / 2 ≈ (0.6931 + 0.4228) / 2 ≈ 0.5580
        assert!((b[0] - 0.5580).abs() < 0.001, "b[0] = {} ≈ 0.558", b[0]);
        // Must be decreasing for large k (ln(k)/k is eventually decreasing)
        for i in 2..b.len() {
            assert!(b[i] < b[i - 1], "b-vector should be decreasing for k >= 4");
        }
        // Must decay toward zero
        assert!(b[19] < 0.2, "b[19] should be small, got {}", b[19]);
    }

    #[test]
    fn test_euler_totient() {
        let phi = euler_totient(12);
        assert_eq!(phi[1], 1);
        assert_eq!(phi[2], 1);
        assert_eq!(phi[6], 2); // {1, 5}
        assert_eq!(phi[12], 4); // {1, 5, 7, 11}
    }
}
