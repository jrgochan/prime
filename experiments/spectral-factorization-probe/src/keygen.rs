//! Key generation for test semiprimes at various bit widths.

use rand::Rng;

/// A semiprime N = p * q with known factors.
#[derive(Debug, Clone)]
pub struct SemiprimeKey {
    pub n: u64,
    pub p: u64,
    pub q: u64,
    pub bits: u32,
}

impl std::fmt::Display for SemiprimeKey {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(
            f,
            "N={} = {} × {} ({}-bit)",
            self.n, self.p, self.q, self.bits
        )
    }
}

/// A class of test keys at a given bit width.
pub struct KeyClass {
    pub bits: u32,
    pub keys: Vec<SemiprimeKey>,
}

/// Simple trial-division primality test (sufficient for small test keys).
fn is_prime(n: u64) -> bool {
    if n < 2 {
        return false;
    }
    if n < 4 {
        return true;
    }
    if n.is_multiple_of(2) || n.is_multiple_of(3) {
        return false;
    }
    let mut i = 5u64;
    while i * i <= n {
        if n.is_multiple_of(i) || n.is_multiple_of(i + 2) {
            return false;
        }
        i += 6;
    }
    true
}

/// Generate a random prime in [lo, hi).
fn random_prime(lo: u64, hi: u64) -> u64 {
    let mut rng = rand::thread_rng();
    loop {
        let candidate = rng.gen_range(lo..hi) | 1; // force odd
        if is_prime(candidate) {
            return candidate;
        }
    }
}

/// Generate test suite: semiprimes at 16, 24, 32, and 40 bit widths.
/// We keep things small enough for Gram matrix construction at M ≤ 500.
pub fn generate_test_suite() -> Vec<KeyClass> {
    let configs = [
        // (bits, p_range, q_range, count)
        (16u32, (50u64, 180), (180u64, 400), 20usize),
        (24, (500, 2000), (2000, 8000), 15),
        (32, (10000, 40000), (40000, 100000), 10),
        (40, (100000, 500000), (500000, 2000000), 5),
    ];

    let mut classes = Vec::new();

    for &(bits, (p_lo, p_hi), (q_lo, q_hi), count) in &configs {
        println!("  Generating {count} semiprimes at ~{bits} bits...");
        let mut keys = Vec::with_capacity(count);
        for _ in 0..count {
            let p = random_prime(p_lo, p_hi);
            let q = random_prime(q_lo, q_hi);
            let (p, q) = if p < q { (p, q) } else { (q, p) };
            let n = p * q;
            let actual_bits = 64 - n.leading_zeros();
            keys.push(SemiprimeKey {
                n,
                p,
                q,
                bits: actual_bits,
            });
        }
        classes.push(KeyClass { bits, keys });
    }

    classes
}

/// Generate a single semiprime for targeted analysis.
pub fn _generate_single(p: u64, q: u64) -> SemiprimeKey {
    assert!(is_prime(p) && is_prime(q), "Both must be prime");
    let (p, q) = if p < q { (p, q) } else { (q, p) };
    let n = p * q;
    let bits = 64 - n.leading_zeros();
    SemiprimeKey { n, p, q, bits }
}
