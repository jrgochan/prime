//! ═══════════════════════════════════════════════════════════════════════════
//!  Zeta Zeros — Known Non-Trivial Zeros of ζ(s)
//!
//!  The single source of truth for zeta zero data across all Cathedral
//!  experiments. Provides:
//!
//!  - [`ZETA_ZEROS`] — First 100 zeros hardcoded to f64 precision
//!  - [`known_zeros`] — Access first N zeros from the table
//!  - [`nearest_zero`] — Find the nearest known zero to a height t
//!  - [`zero_gap`] — Gap between consecutive zeros
//!  - [`riemann_n_of_t`] — Expected number of zeros up to height T
//!  - [`compute_zeros`] — Compute zeros on-demand via Riemann-Siegel
//!  - [`load_or_compute_zeros`] — Cached zero computation with disk persistence
//!
//!  ## Data Sources
//!
//!  The hardcoded table comes from Andrew Odlyzko's tables of zeta zeros,
//!  verified against the LMFDB (L-functions and Modular Forms DataBase).
//!  Additional zeros are computed on-demand using the Hardy Z-function
//!  via [`crate::riemann_siegel::find_zeros`].
//! ═══════════════════════════════════════════════════════════════════════════

use std::f64::consts::PI;

// ═══════════════════════════════════════════════════════════════════
// HARDCODED ZERO TABLE — First 100 non-trivial zeros of ζ(s)
//
// These are the imaginary parts of zeros on the critical line Re(s) = ½.
// All 100 zeros verified to ~15 decimal digits (f64 precision).
// Source: Odlyzko's tables, cross-checked against LMFDB.
// ═══════════════════════════════════════════════════════════════════

/// First 100 non-trivial zeros of the Riemann zeta function.
///
/// Each entry is the imaginary part t₀ such that ζ(½ + it₀) = 0.
/// Ordered by increasing magnitude.
pub const ZETA_ZEROS: &[f64] = &[
    // zeros 1-10
    14.134725141734693,
    21.022039638771555,
    25.010857580145688,
    30.424876125859513,
    32.935061587739189,
    37.586178158825671,
    40.918719012147495,
    43.327073280914999,
    48.005150881167159,
    49.773832477672302,
    // zeros 11-20
    52.970321477714460,
    56.446247697063394,
    59.347044002602353,
    60.831778524609809,
    65.112544048081607,
    67.079810529494173,
    69.546401711173979,
    72.067157674481907,
    75.704690699083933,
    77.144840068874805,
    // zeros 21-30
    79.337375020249367,
    82.910380854086030,
    84.735492980517050,
    87.425274613125229,
    88.809111207634465,
    92.491899270558484,
    94.651344040519838,
    95.870634228245309,
    98.831194218193692,
    101.317851005731220,
    // zeros 31-40
    103.725538040478320,
    105.446623052771760,
    107.168611184276600,
    111.029535543088070,
    111.874659177063500,
    114.320220915452200,
    116.226680321581620,
    118.790782866371900,
    121.370125002456430,
    122.946829294052010,
    // zeros 41-50
    124.256818554345580,
    127.516683880106620,
    129.578704199956230,
    131.087688531023990,
    133.497737203165660,
    134.756509753373810,
    138.116042054864260,
    139.736208952346310,
    141.123707404382380,
    143.111845807673770,
    // zeros 51-60
    146.000982486766620,
    147.422765343914710,
    150.053520421890260,
    150.925257612027520,
    153.024693811267310,
    156.112909294394830,
    157.597591818296410,
    158.849988171916590,
    161.188964138450750,
    163.030709687106170,
    // zeros 61-70
    165.537069188247940,
    167.184439978043010,
    169.094515416270100,
    169.911976479419990,
    173.411536520098830,
    174.754191523696810,
    176.441434298681210,
    178.377407776053810,
    179.916484020146000,
    182.207078483846290,
    // zeros 71-80
    184.874467848467450,
    185.598783677761990,
    187.228922584233970,
    189.416158656042780,
    192.026656360841480,
    193.079726604652950,
    195.265396679796530,
    196.876481840908720,
    198.015309676351910,
    201.264751944082600,
    // zeros 81-90
    202.493594514091290,
    204.189671803069110,
    205.394697202505370,
    207.906258888679520,
    209.576509717024310,
    211.690862595367560,
    213.347919360319980,
    214.547044783002320,
    216.169538508242240,
    219.067596349124740,
    // zeros 91-100
    220.714918839305800,
    221.430705555533700,
    224.007000255035900,
    224.983324670983000,
    227.421444280459500,
    229.337413306523200,
    231.250188700531800,
    231.987235253015500,
    233.693404179553700,
    236.524229666130800,
];

// ═══════════════════════════════════════════════════════════════════
// LOOKUP FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

/// Number of hardcoded zeros available without computation.
pub const NUM_HARDCODED: usize = 100;

/// Return the first `n` known zeros from the hardcoded table.
///
/// Panics if `n > NUM_HARDCODED`.
pub fn known_zeros(n: usize) -> &'static [f64] {
    &ZETA_ZEROS[..n.min(NUM_HARDCODED)]
}

/// Find the nearest known zero to height `t`.
///
/// Returns `Some((index, zero_value))` or `None` if the table is empty.
pub fn nearest_zero(t: f64) -> Option<(usize, f64)> {
    if ZETA_ZEROS.is_empty() {
        return None;
    }

    // Binary search for the closest
    match ZETA_ZEROS.binary_search_by(|z| z.partial_cmp(&t).unwrap()) {
        Ok(i) => Some((i, ZETA_ZEROS[i])),
        Err(i) => {
            if i == 0 {
                Some((0, ZETA_ZEROS[0]))
            } else if i >= ZETA_ZEROS.len() {
                let last = ZETA_ZEROS.len() - 1;
                Some((last, ZETA_ZEROS[last]))
            } else {
                let d_lo = (t - ZETA_ZEROS[i - 1]).abs();
                let d_hi = (t - ZETA_ZEROS[i]).abs();
                if d_lo <= d_hi {
                    Some((i - 1, ZETA_ZEROS[i - 1]))
                } else {
                    Some((i, ZETA_ZEROS[i]))
                }
            }
        }
    }
}

/// Gap between zero `n` and zero `n+1` (0-indexed).
///
/// Returns `None` if `n+1` is beyond the table.
pub fn zero_gap(n: usize) -> Option<f64> {
    if n + 1 < ZETA_ZEROS.len() {
        Some(ZETA_ZEROS[n + 1] - ZETA_ZEROS[n])
    } else {
        None
    }
}

/// Mean zero gap near height `t`: approximately `2π / ln(t/(2π))`.
pub fn expected_zero_gap(t: f64) -> f64 {
    if t <= 2.0 * PI {
        return f64::INFINITY;
    }
    2.0 * PI / (t / (2.0 * PI)).ln()
}

// ═══════════════════════════════════════════════════════════════════
// ZERO-COUNTING FUNCTION
// ═══════════════════════════════════════════════════════════════════

/// Riemann's zero-counting function: N(T) ≈ T/(2π) · ln(T/(2πe)).
///
/// The number of non-trivial zeros with 0 < Im(ρ) < T is approximately N(T).
/// More precisely: N(T) = (T/(2π)) ln(T/(2π)) - T/(2π) + 7/8 + O(1/T).
pub fn riemann_n_of_t(t: f64) -> f64 {
    if t <= 0.0 {
        return 0.0;
    }
    let t_over_2pi = t / (2.0 * PI);
    t_over_2pi * t_over_2pi.ln() - t_over_2pi + 7.0 / 8.0
}

/// Local density of zeros near height `t`: dN/dt ≈ (1/2π) ln(t/(2π)).
pub fn zero_density(t: f64) -> f64 {
    if t <= 2.0 * PI {
        return 0.0;
    }
    (t / (2.0 * PI)).ln() / (2.0 * PI)
}

// ═══════════════════════════════════════════════════════════════════
// ON-DEMAND COMPUTATION
// ═══════════════════════════════════════════════════════════════════

/// Compute zeros on-demand using the Hardy Z-function.
///
/// This wraps [`crate::riemann_siegel::find_zeros`] with a specified count.
/// For `n <= NUM_HARDCODED`, returns the hardcoded values (faster and more accurate).
/// For `n > NUM_HARDCODED`, computes additional zeros via Riemann-Siegel.
pub fn compute_zeros(n: usize) -> Vec<f64> {
    if n <= NUM_HARDCODED {
        return ZETA_ZEROS[..n].to_vec();
    }

    // Start with hardcoded zeros
    let mut zeros = ZETA_ZEROS.to_vec();

    // Estimate how high we need to go for n zeros: N(T) ≈ n
    // Invert: T ≈ 2π·n / ln(n) (rough)
    let n_f = n as f64;
    let t_estimate = 2.0 * PI * n_f / n_f.ln() * 1.2; // 20% margin

    // Compute additional zeros beyond our table
    let last_known = ZETA_ZEROS[NUM_HARDCODED - 1];
    let additional = crate::riemann_siegel::find_zeros(t_estimate);

    // Merge: keep only zeros beyond our last hardcoded one
    for z in additional {
        if z > last_known + 0.1 {
            zeros.push(z);
        }
    }

    zeros.sort_by(|a, b| a.partial_cmp(b).unwrap());
    zeros.dedup_by(|a, b| (*a - *b).abs() < 0.01);
    zeros.truncate(n);
    zeros
}

/// Load zeros from a cache file, or compute and cache them.
///
/// Cache file format: one f64 per line, ASCII.
/// Default cache path: `./zeta_zeros_cache.txt`
pub fn load_or_compute_zeros(n: usize, cache_path: Option<&str>) -> Vec<f64> {
    let path = cache_path.unwrap_or("zeta_zeros_cache.txt");

    // Try loading from cache
    if let Ok(content) = std::fs::read_to_string(path) {
        let cached: Vec<f64> = content
            .lines()
            .filter_map(|line| line.trim().parse::<f64>().ok())
            .collect();
        if cached.len() >= n {
            return cached[..n].to_vec();
        }
    }

    // Compute
    eprintln!(
        "Computing {} zeta zeros (have {} hardcoded)...",
        n, NUM_HARDCODED
    );
    let zeros = compute_zeros(n);

    // Cache to disk
    if let Ok(mut file) = std::fs::File::create(path) {
        use std::io::Write;
        for z in &zeros {
            writeln!(file, "{:.15}", z).ok();
        }
        eprintln!("Cached {} zeros to {}", zeros.len(), path);
    }

    zeros
}

// ═══════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_zero_count() {
        assert_eq!(ZETA_ZEROS.len(), NUM_HARDCODED);
    }

    #[test]
    fn test_zeros_sorted() {
        for w in ZETA_ZEROS.windows(2) {
            assert!(w[0] < w[1], "Zeros not sorted: {} >= {}", w[0], w[1]);
        }
    }

    #[test]
    fn test_first_zero() {
        assert!((ZETA_ZEROS[0] - 14.134725141734693).abs() < 1e-12);
    }

    #[test]
    fn test_nearest_zero() {
        let (idx, val) = nearest_zero(14.0).unwrap();
        assert_eq!(idx, 0);
        assert!((val - 14.134725).abs() < 0.001);

        let (idx, val) = nearest_zero(21.0).unwrap();
        assert_eq!(idx, 1);
        assert!((val - 21.022040).abs() < 0.001);
    }

    #[test]
    fn test_zero_gap() {
        let gap = zero_gap(0).unwrap();
        // Gap between zero 1 and zero 2: ~6.887
        assert!((gap - 6.887).abs() < 0.01);
    }

    #[test]
    fn test_riemann_n_of_t() {
        // N(100) ≈ 29 (there are 29 zeros below t=100)
        let n = riemann_n_of_t(100.0);
        assert!((n - 29.0).abs() < 2.0, "N(100) = {}, expected ~29", n);
    }

    #[test]
    fn test_known_zeros() {
        let first_10 = known_zeros(10);
        assert_eq!(first_10.len(), 10);
        assert!((first_10[0] - 14.134725).abs() < 0.001);
    }
}
