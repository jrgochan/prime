// siegel-walfisz/src/sieve.rs
//
// Eratosthenes sieve + Möbius function — reused from rotor-spectroscopy

/// Sieve of Eratosthenes: returns `is_prime[0..=n]`
pub fn sieve_primes(n: usize) -> Vec<bool> {
    cathedral_utils::arith::sieve_primes(n)
}

/// Compute μ(k) for k = 0..=n using linear sieve.
/// μ(1) = 1, μ(k) = 0 if k has squared factor, (-1)^r otherwise.
pub fn compute_moebius(n: usize) -> Vec<i8> {
    let mut mu = vec![0i8; n + 1];
    if n >= 1 {
        mu[1] = 1;
    }

    // smallest_prime_factor[k] = smallest prime dividing k
    let mut spf = vec![0usize; n + 1];
    let mut primes = Vec::new();

    for i in 2..=n {
        if spf[i] == 0 {
            // i is prime
            spf[i] = i;
            primes.push(i);
            mu[i] = -1; // prime → one prime factor
        }
        for &p in &primes {
            if p > spf[i] || i * p > n {
                break;
            }
            spf[i * p] = p;
            if i % p == 0 {
                // i*p has p² as factor → μ = 0
                mu[i * p] = 0;
            } else {
                mu[i * p] = -mu[i];
            }
        }
    }
    mu
}
