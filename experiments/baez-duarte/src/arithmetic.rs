// ═══════════════════════════════════════════════════════════════════════
//  arithmetic.rs — Number-theoretic foundations
//  Möbius sieve, GCD, primality
// ═══════════════════════════════════════════════════════════════════════

/// Linear sieve for the Möbius function μ(n), 0..=n.
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

/// Greatest common divisor (binary GCD).
pub fn gcd(a: usize, b: usize) -> usize {
    let (mut a, mut b) = (a, b);
    while b != 0 {
        let t = b;
        b = a % b;
        a = t;
    }
    a
}

/// Trial-division primality.
pub fn is_prime(n: usize) -> bool {
    if n < 2 {
        return false;
    }
    if n < 4 {
        return true;
    }
    if n % 2 == 0 || n % 3 == 0 {
        return false;
    }
    let mut d = 5;
    while d * d <= n {
        if n % d == 0 || n % (d + 2) == 0 {
            return false;
        }
        d += 6;
    }
    true
}
