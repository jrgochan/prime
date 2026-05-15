//! Number-theoretic arithmetic functions.
//!
//! μ(n)  — Möbius function
//! Λ(n)  — Von Mangoldt function  
//! Li(x) — Logarithmic integral
//! π(x)  — Prime counting (exact, small x)

/// Möbius function μ(n).
/// Returns 0 if n has a squared prime factor,
/// (-1)^k if n is a product of k distinct primes.
pub fn mobius(n: usize) -> i32 {
    if n == 0 { return 0; }
    if n == 1 { return 1; }
    let mut val = n;
    let mut factors = 0i32;
    let mut d = 2usize;
    while d * d <= val {
        if val % d == 0 {
            val /= d;
            if val % d == 0 {
                return 0; // squared factor
            }
            factors += 1;
        }
        d += 1;
    }
    if val > 1 {
        factors += 1;
    }
    if factors % 2 == 0 { 1 } else { -1 }
}

/// Von Mangoldt function Λ(n).
/// Returns ln(p) if n = p^k for some prime p and integer k ≥ 1, else 0.
pub fn von_mangoldt(n: usize) -> f64 {
    if n <= 1 { return 0.0; }
    let mut val = n;
    let mut base = 0usize;
    let mut d = 2usize;
    while d * d <= val {
        if val % d == 0 {
            if base != 0 && base != d {
                return 0.0; // multiple prime factors
            }
            base = d;
            val /= d;
            // don't increment d — check for repeated factors
        } else {
            d += 1;
        }
    }
    if val > 1 {
        if base != 0 && base != val {
            return 0.0;
        }
        base = val;
    }
    if base == 0 { 0.0 } else { (base as f64).ln() }
}

/// Logarithmic integral Li(x) via series approximation.
/// Li(x) = γ + ln(ln(x)) + Σₖ₌₁ (ln(x))^k / (k · k!)
pub fn li(x: f64) -> f64 {
    if x <= 1.0 { return 0.0; }
    let ln_x = x.ln();
    let euler_gamma = 0.5772156649015329;
    let mut sum = euler_gamma + ln_x.ln();
    let mut term = 1.0;
    for k in 1..100 {
        term *= ln_x / k as f64;
        sum += term / k as f64;
        if term.abs() < 1e-15 { break; }
    }
    sum
}

/// Trial-division primality test (small n only).
pub fn is_prime(n: usize) -> bool {
    if n < 2 { return false; }
    if n < 4 { return true; }
    if n % 2 == 0 || n % 3 == 0 { return false; }
    let mut d = 5;
    while d * d <= n {
        if n % d == 0 || n % (d + 2) == 0 { return false; }
        d += 6;
    }
    true
}

/// Generate first `count` primes via sieve.
pub fn primes_up_to_count(count: usize) -> Vec<usize> {
    let mut primes = Vec::with_capacity(count);
    let mut n = 2;
    while primes.len() < count {
        if is_prime(n) {
            primes.push(n);
        }
        n += 1;
    }
    primes
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mobius_values() {
        assert_eq!(mobius(1), 1);
        assert_eq!(mobius(2), -1);
        assert_eq!(mobius(4), 0);   // 2²
        assert_eq!(mobius(6), 1);   // 2·3
        assert_eq!(mobius(30), -1); // 2·3·5
    }

    #[test]
    fn von_mangoldt_values() {
        assert!((von_mangoldt(2) - 2.0_f64.ln()).abs() < 1e-10);
        assert!((von_mangoldt(4) - 2.0_f64.ln()).abs() < 1e-10); // 2²
        assert!((von_mangoldt(8) - 2.0_f64.ln()).abs() < 1e-10); // 2³
        assert_eq!(von_mangoldt(6), 0.0); // 2·3
    }

    #[test]
    fn li_approximation() {
        // Li(2) ≈ 1.0451
        assert!((li(2.0) - 1.0451).abs() < 0.01);
    }

    #[test]
    fn first_primes() {
        let p = primes_up_to_count(5);
        assert_eq!(p, vec![2, 3, 5, 7, 11]);
    }
}
