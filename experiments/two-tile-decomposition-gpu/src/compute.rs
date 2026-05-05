//! ═══════════════════════════════════════════════════════════════════════════
//!  COMPUTE MODULE — f64 core math building blocks
//!
//!  Port of the CPU experiment's MPFR compute.rs to f64 precision.
//!  Provides row integrals, strip values, rowTerms, and delta formulas.
//! ═══════════════════════════════════════════════════════════════════════════

use std::f64::consts::PI;

pub const EULER_GAMMA: f64 = 0.57721566490153286;
pub const LOG_2PI: f64 = 1.8378770664093453; // ln(2π)

pub fn gcd(mut a: usize, mut b: usize) -> usize {
    while b != 0 { let t = b; b = a % b; a = t; }
    a
}

// ────────────────────────────────────────────────
// Two-tile geometry
// ────────────────────────────────────────────────

#[inline]
pub fn tile_index(a: usize, b: usize, m0: usize) -> usize { (a * m0) / b }

#[inline]
pub fn is_two_tile(a: usize, b: usize, m0: usize) -> bool {
    let n0 = tile_index(a, b, m0);
    b * (n0 + 1) < a * (m0 + 1)
}

#[inline]
pub fn overshoot(a: usize, b: usize, m0: usize) -> usize {
    let n0 = tile_index(a, b, m0);
    a * (m0 + 1) - b * (n0 + 1)
}

/// Row overshoot: s = (am mod b) + a - b, returns None if single-tile
#[inline]
pub fn row_overshoot(a: usize, b: usize, m: usize) -> Option<usize> {
    let r = (a * m) % b;
    if r > 0 && r + a >= b { Some(r + a - b) } else { None }
}

// ────────────────────────────────────────────────
// Row integral components
// ────────────────────────────────────────────────

/// Strip value: (a-1)/(ab)
pub fn strip_value(a: usize, b: usize) -> f64 {
    (a as f64 - 1.0) / (a as f64 * b as f64)
}

/// Exact row integral: ∫_{1/(a(m+1))}^{1/(am)} {1/(ax)}{1/(bx)} dx
///
/// Uses piecewise evaluation: crossing point at x_c = 1/(b(q+1))
/// where q = ⌊am/b⌋, the integral splits at x_c for two-tile rows.
pub fn exact_row_integral(a: usize, b: usize, m: usize) -> f64 {
    let af = a as f64;
    let bf = b as f64;
    let mf = m as f64;
    let m1 = (m + 1) as f64;

    // Row bounds
    let x_lo = 1.0 / (af * m1);
    let x_hi = 1.0 / (af * mf);

    // Tile indices at endpoints
    let n_hi = (a * m) / b;     // ⌊am/b⌋ — tile index at x_hi
    let n_lo = (a * (m+1)) / b; // ⌊a(m+1)/b⌋ — tile index at x_lo

    if n_hi == n_lo {
        // Single-tile: {1/(bx)} = 1/(bx) - n on entire interval
        single_tile_integral(af, bf, mf, x_lo, x_hi, n_hi)
    } else {
        // Two-tile: split at crossing point x_c = 1/(b(n_hi+1))
        let x_c = 1.0 / (bf * (n_hi + 1) as f64);
        let part_lo = single_tile_integral(af, bf, mf, x_lo, x_c, n_lo);
        let part_hi = single_tile_integral(af, bf, mf, x_c, x_hi, n_hi);
        part_lo + part_hi
    }
}

/// Single-tile integral: ∫_{lo}^{hi} (1/(ax) - m)(1/(bx) - n) dx
/// = ∫ (1/(abx²) - (m/b + n/a)/x + mn) dx
/// = -1/(ab·x) - (m/b + n/a)·ln(x) + mn·x  evaluated at [lo, hi]
fn single_tile_integral(a: f64, b: f64, m: f64, lo: f64, hi: f64, n: usize) -> f64 {
    let nf = n as f64;
    let ab = a * b;

    // Anti-derivative: F(x) = -1/(ab·x) - (m/b + n/a)·ln(x) + mn·x
    let coeff_log = m / b + nf / a;
    let mn = m * nf;

    let f_hi = -1.0 / (ab * hi) - coeff_log * hi.ln() + mn * hi;
    let f_lo = -1.0 / (ab * lo) - coeff_log * lo.ln() + mn * lo;

    f_hi - f_lo
}

/// rowTerm(a,b,m): single-tile approximation using n₀ = ⌊am/b⌋
pub fn row_term(a: usize, b: usize, m: usize) -> f64 {
    let n0 = (a * m) / b;
    single_tile_integral(a as f64, b as f64, m as f64,
        1.0 / (a as f64 * (m + 1) as f64),
        1.0 / (a as f64 * m as f64),
        n0)
}

/// Delta formula: Δ(m) = -(1/a)·ln(a(m+1)/(a(m+1)-s)) + m·s/(a(m+1)·(a(m+1)-s))
pub fn delta_exact(a: usize, b: usize, m: usize) -> f64 {
    let s = match row_overshoot(a, b, m) {
        Some(s) => s,
        None => return 0.0,
    };
    let af = a as f64;
    let sf = s as f64;
    let mf = m as f64;
    let am1 = af * (mf + 1.0);
    let am1_s = am1 - sf;

    // log term: -(1/a)·ln(am1/am1_s)
    let log_term = -(1.0 / af) * (am1 / am1_s).ln();
    // linear term: m·s / (am1 · am1_s)
    let lin_term = mf * sf / (am1 * am1_s);

    log_term + lin_term
}

// ────────────────────────────────────────────────
// Formula components
// ────────────────────────────────────────────────

/// Vasyunin gram formula: the closed-form for gramIntegral(a,b)
pub fn vasyunin_gram_formula(a: usize, b: usize) -> f64 {
    let af = a as f64;
    let bf = b as f64;

    // Cotangent sums
    let vab: f64 = (1..b).map(|m| {
        let mf = m as f64;
        frac(af * mf / bf) * (PI * mf / bf).cos() / (PI * mf / bf).sin()
    }).sum();
    let vba: f64 = (1..a).map(|m| {
        let mf = m as f64;
        frac(bf * mf / af) * (PI * mf / af).cos() / (PI * mf / af).sin()
    }).sum();

    (LOG_2PI - EULER_GAMMA) / 2.0 * (1.0/af + 1.0/bf)
        + (af - bf) / (2.0*af*bf) * (bf / af).ln()
        - PI / (2.0*af*bf) * (vab + vba)
        - 1.0 / (af*bf)
}

/// Stirling constant: log(2π) - γ - 1
pub fn stirling_const() -> f64 { LOG_2PI - EULER_GAMMA - 1.0 }

/// Fractional target: Σ_{r=1}^{b-1} {ar/b}·(logΓ(r/b) - logΓ((r+1)/b) + (1/b)·ψ((r+1)/b))
pub fn fract_target(a: usize, b: usize) -> f64 {
    let af = a as f64;
    let bf = b as f64;
    (1..b).map(|r| {
        let rf = r as f64;
        let fv = frac(af * rf / bf);
        let lg_r = libm::lgamma(rf / bf);
        let lg_rp1 = libm::lgamma((rf + 1.0) / bf);
        let psi_rp1 = digamma_f64((rf + 1.0) / bf);
        fv * (lg_r - lg_rp1 + (1.0 / bf) * psi_rp1)
    }).sum()
}

/// deltaTarget = formula - strip - stir/b - ft/a
pub fn delta_target(a: usize, b: usize) -> f64 {
    let formula = vasyunin_gram_formula(a, b);
    let strip = strip_value(a, b);
    let stir = stirling_const() / b as f64;
    let ft = fract_target(a, b) / a as f64;
    formula - strip - stir - ft
}

// ────────────────────────────────────────────────
// Special function helpers
// ────────────────────────────────────────────────

#[inline]
pub fn frac(x: f64) -> f64 { x - x.floor() }

/// Digamma via asymptotic expansion + recurrence
pub fn digamma_f64(mut x: f64) -> f64 {
    if x <= 0.0 { return f64::NAN; }
    let mut result = 0.0;
    while x < 10.0 { result -= 1.0 / x; x += 1.0; }
    let inv_x = 1.0 / x;
    let inv_x2 = inv_x * inv_x;
    result += x.ln() - 0.5 * inv_x;
    let mut x2k = inv_x2;
    result -= x2k / 12.0;  x2k *= inv_x2;
    result += x2k / 120.0; x2k *= inv_x2;
    result -= x2k / 252.0; x2k *= inv_x2;
    result += x2k / 240.0; x2k *= inv_x2;
    result -= x2k * 5.0 / 660.0;
    result
}
