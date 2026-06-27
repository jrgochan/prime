/// Möbius function computation via linear sieve.
///
/// μ(n) = 0  if n has a squared prime factor
/// μ(n) = (-1)^k if n is a product of k distinct primes

/// Compute μ(n) for n = 0..max_n using a sieve.
/// Returns a Vec where result[n] = μ(n).
/// μ(0) = 0 by convention.
pub fn sieve_moebius(max_n: usize) -> Vec<i32> {
    let mut mu = vec![0i32; max_n + 1];
    let mut is_prime = vec![true; max_n + 1];
    let mut smallest_prime = vec![0usize; max_n + 1];

    mu[1] = 1;

    for i in 2..=max_n {
        if is_prime[i] {
            smallest_prime[i] = i;
            mu[i] = -1; // prime => μ = -1
                        // Sieve composites
            let mut j = 2 * i;
            while j <= max_n {
                is_prime[j] = false;
                if smallest_prime[j] == 0 {
                    smallest_prime[j] = i;
                }
                j += i;
            }
        }
    }

    // Now compute μ for composites
    for n in 2..=max_n {
        if is_prime[n] {
            continue; // already set
        }
        let p = smallest_prime[n];
        let m = n / p;

        if m.is_multiple_of(p) {
            // p² divides n => μ(n) = 0
            mu[n] = 0;
        } else {
            // n = p · m where p doesn't divide m
            // μ(n) = -μ(m)
            mu[n] = -mu[m];
        }
    }

    mu
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_moebius_small() {
        let mu = sieve_moebius(20);
        // μ(1)=1, μ(2)=-1, μ(3)=-1, μ(4)=0, μ(5)=-1, μ(6)=1
        assert_eq!(mu[1], 1);
        assert_eq!(mu[2], -1);
        assert_eq!(mu[3], -1);
        assert_eq!(mu[4], 0);
        assert_eq!(mu[5], -1);
        assert_eq!(mu[6], 1);
        assert_eq!(mu[7], -1);
        assert_eq!(mu[8], 0);
        assert_eq!(mu[9], 0);
        assert_eq!(mu[10], 1);
        assert_eq!(mu[12], 0);
        assert_eq!(mu[15], 1);
    }
}
