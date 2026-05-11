//! Chebyshev function ψ(y) and Dirichlet convolution verification

/// Chebyshev prime-counting function ψ(y) = Σ_{p^a ≤ y} log(p)
pub fn chebyshev_psi(y: usize, log_primes: &[(usize, f64)]) -> f64 {
    let mut sum = 0.0;
    for &(p, logp) in log_primes {
        let mut pk = p;
        while pk <= y {
            sum += logp;
            // Check for overflow before multiplying
            if pk > y / p + 1 { break; }
            pk *= p;
        }
    }
    sum
}

/// Build a table of (prime, log(prime)) up to n
pub fn prime_log_table(n: usize, _mu: &[i8]) -> Vec<(usize, f64)> {
    // A number p is prime if μ(p) ≠ 0 and p > 1
    // (squarefree with exactly 1 prime factor ⟹ μ = -1)
    // Actually, primes have μ(p) = -1. But for our sieve, let's just check
    let mut primes = Vec::new();
    for p in 2..=n {
        if is_prime(p) {
            primes.push((p, (p as f64).ln()));
        }
    }
    primes
}

fn is_prime(n: usize) -> bool {
    if n < 2 { return false; }
    if n < 4 { return true; }
    if n % 2 == 0 || n % 3 == 0 { return false; }
    let mut i = 5;
    while i * i <= n {
        if n % i == 0 || n % (i + 2) == 0 { return false; }
        i += 6;
    }
    true
}

/// Verify Identity 1: Σ_{k≤y} μ(k)⌊y/k⌋ = 1
pub fn dirichlet_identity_1(y: usize, mu: &[i8]) -> i64 {
    (1..=y).map(|k| mu[k] as i64 * (y / k) as i64).sum()
}

/// Verify Identity 2: Σ_{k≤y} μ(k)·log(k)·⌊y/k⌋ = -ψ(y)
pub fn dirichlet_identity_2(y: usize, mu: &[i8]) -> f64 {
    (1..=y).map(|k| {
        mu[k] as f64 * (k as f64).ln() * (y / k) as f64
    }).sum()
}

/// Compute the Nyman-Beurling residual 1 - f_N(1/y) using Gemini's formula
/// 1 - f_N(1/y) = -y·E_N - (ψ(y) - y)/logN
pub fn residual_gemini(y: f64, e_n: f64, psi_y: f64, log_n: f64) -> f64 {
    -y * e_n - (psi_y - y) / log_n
}

/// Compute E_N = Σ v_k/k + 1/logN
pub fn compute_e_n(mu: &[i8], n: usize) -> f64 {
    let log_n = (n as f64).ln();
    let sum_vk_over_k: f64 = (1..n).map(|k| {
        let vk = -(mu[k] as f64) * (1.0 - (k as f64).ln() / log_n);
        vk / k as f64
    }).sum();
    sum_vk_over_k + 1.0 / log_n
}
