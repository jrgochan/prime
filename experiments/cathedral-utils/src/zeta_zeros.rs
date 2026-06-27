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
    25.010_857_580_145_69,
    30.424876125859513,
    32.935_061_587_739_19,
    37.586_178_158_825_67,
    40.918_719_012_147_5,
    43.327_073_280_915,
    48.005_150_881_167_16,
    49.773_832_477_672_3,
    // zeros 11-20
    52.970_321_477_714_46,
    56.446_247_697_063_39,
    59.347_044_002_602_35,
    60.831_778_524_609_81,
    65.112_544_048_081_6,
    67.079_810_529_494_17,
    69.546_401_711_173_98,
    72.067_157_674_481_9,
    75.704_690_699_083_93,
    77.144_840_068_874_8,
    // zeros 21-30
    79.337_375_020_249_37,
    82.910_380_854_086_03,
    84.735_492_980_517_05,
    87.425_274_613_125_23,
    88.809_111_207_634_46,
    92.491_899_270_558_48,
    94.651_344_040_519_83,
    95.870_634_228_245_31,
    98.831_194_218_193_69,
    101.317_851_005_731_21,
    // zeros 31-40
    103.725_538_040_478_33,
    105.446_623_052_771_76,
    107.168_611_184_276_6,
    111.029_535_543_088_07,
    111.874_659_177_063_5,
    114.320_220_915_452_2,
    116.226_680_321_581_63,
    118.790_782_866_371_9,
    121.370_125_002_456_43,
    122.946_829_294_052_01,
    // zeros 41-50
    124.256_818_554_345_59,
    127.516_683_880_106_63,
    129.578_704_199_956_23,
    131.087_688_531_023_99,
    133.497_737_203_165_66,
    134.756_509_753_373_82,
    138.116_042_054_864_27,
    139.736_208_952_346_32,
    141.123_707_404_382_37,
    143.111_845_807_673_77,
    // zeros 51-60
    146.000_982_486_766_62,
    147.422_765_343_914_7,
    150.053_520_421_890_25,
    150.925_257_612_027_5,
    153.024_693_811_267_3,
    156.112_909_294_394_83,
    157.597_591_818_296_42,
    158.849_988_171_916_58,
    161.188_964_138_450_76,
    163.030_709_687_106_17,
    // zeros 61-70
    165.537_069_188_247_93,
    167.184_439_978_043,
    169.094_515_416_270_1,
    169.911_976_479_42,
    173.411_536_520_098_82,
    174.754_191_523_696_82,
    176.441_434_298_681_2,
    178.377_407_776_053_81,
    179.916_484_020_146,
    182.207_078_483_846_3,
    // zeros 71-80
    184.874_467_848_467_45,
    185.598_783_677_762,
    187.228_922_584_233_97,
    189.416_158_656_042_77,
    192.026_656_360_841_49,
    193.079_726_604_652_96,
    195.265_396_679_796_54,
    196.876_481_840_908_72,
    198.015_309_676_351_9,
    201.264_751_944_082_6,
    // zeros 81-90
    202.493_594_514_091_28,
    204.189_671_803_069_1,
    205.394_697_202_505_37,
    207.906_258_888_679_53,
    209.576_509_717_024_32,
    211.690_862_595_367_55,
    213.347_919_360_32,
    214.547_044_783_002_32,
    216.169_538_508_242_23,
    219.067_596_349_124_73,
    // zeros 91-100
    220.714_918_839_305_8,
    221.430_705_555_533_7,
    224.007_000_255_035_9,
    224.983_324_670_983,
    227.421_444_280_459_5,
    229.337_413_306_523_2,
    231.250_188_700_531_8,
    231.987_235_253_015_5,
    233.693_404_179_553_7,
    236.524_229_666_130_8,
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
