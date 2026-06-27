//! Möbius sieve, Mertens function, and weight computation

use rug::Float;

pub const P: u32 = 256;

/// Sieve of Eratosthenes-style Möbius function computation.
/// Returns μ(n) for 0 ≤ n ≤ limit.
pub fn mobius_sieve(limit: usize) -> Vec<i8> {
    let mut mu = vec![0i8; limit + 1];
    let mut spf = vec![0usize; limit + 1];
    mu[1] = 1;
    for p in 2..=limit {
        if spf[p] != 0 {
            continue;
        }
        spf[p] = p;
        for m in (2 * p..=limit).step_by(p) {
            if spf[m] == 0 {
                spf[m] = p;
            }
        }
    }
    for k in 2..=limit {
        let mut val = k;
        let mut nf = 0u32;
        let mut sq = false;
        while val > 1 {
            let p = spf[val];
            let mut c = 0;
            while val % p == 0 {
                val /= p;
                c += 1;
            }
            if c > 1 {
                sq = true;
                break;
            }
            nf += 1;
        }
        if sq {
            mu[k] = 0;
        } else if nf.is_multiple_of(2) {
            mu[k] = 1;
        } else {
            mu[k] = -1;
        }
    }
    mu
}

/// Mertens function: M(n) = Σ_{k=1}^{n} μ(k)
pub fn mertens_values(mu: &[i8]) -> Vec<i64> {
    let mut m = vec![0i64; mu.len()];
    for i in 1..mu.len() {
        m[i] = m[i - 1] + mu[i] as i64;
    }
    m
}

/// Log-cutoff Möbius weights: w_k = -μ(k) · (1 - ln(k)/ln(N))
/// Matches Lean's `bdMoebiusWeight N i = -μ(i+1) · logWeight(N, i+1)`
pub fn log_cutoff_weights(n: usize, mu: &[i8]) -> Vec<Float> {
    let log_n = Float::with_val(P, n as u64).ln();
    (1..n)
        .map(|k| {
            if mu[k] == 0 {
                return Float::with_val(P, 0);
            }
            let log_k = Float::with_val(P, k as u64).ln();
            let taper = Float::with_val(P, 1u32) - Float::with_val(P, &log_k / &log_n);
            Float::with_val(P, -(mu[k] as f64)) * &taper
        })
        .collect()
}

/// f_N(x) = Σ_{k=1}^{N-1} w_k · {1/(kx)}
/// The Nyman-Beurling approximant.
pub fn f_n_at(x: &Float, w: &[Float]) -> Float {
    let mut sum = Float::with_val(P, 0);
    for (i, wk) in w.iter().enumerate() {
        if wk.is_zero() {
            continue;
        }
        let k = (i + 1) as u64;
        let kx = Float::with_val(P, k) * x;
        let inv = Float::with_val(P, 1u32) / &kx;
        let frac = Float::with_val(P, &inv - inv.clone().floor());
        sum += Float::with_val(P, wk * &frac);
    }
    sum
}
