//! ═══════════════════════════════════════════════════════════════════════════
//!  SERIES COMPONENT EVALUATION — 512-bit MPFR
//!
//!  Computes BOTH the algebraic decomposition (s_combined = Σ rowTerm)
//!  AND the actual row integrals via exact piecewise FTC.
//!
//!  Key discovery: rowTerm ≠ actualRowIntegral for "two-tile" rows
//!  (rows where the b-floor changes within the row). The correction
//!  is summable, so both converge to the same limit.
//! ═══════════════════════════════════════════════════════════════════════════

use rug::Float;

/// MPFR precision in bits. 512 bits ≈ 154 decimal digits.
pub const PREC: u32 = 512;

#[inline]
pub fn fp(x: i64) -> Float { Float::with_val(PREC, x) }
#[inline]
pub fn fu(x: usize) -> Float { Float::with_val(PREC, x as u64) }

/// Tile index n(m) = ⌊am/b⌋
#[inline]
pub fn tile_index(a: usize, b: usize, m: usize) -> usize {
    (a * m) / b
}

// ════════════════════════════════════════════════════════════════
// §1. ALGEBRAIC SERIES (rowTerm-based, from PartialSumConvergence.lean)
// ════════════════════════════════════════════════════════════════

/// rowTerm(a,b,m) = 1/b - (n/a + m/b)·log((m+1)/m) + n/(a(m+1))
pub fn row_term(a: usize, b: usize, m: usize) -> Float {
    let n = tile_index(a, b, m);
    let nf = fu(n);
    let mf = fu(m);
    let m1f = fu(m + 1);
    let af = fu(a);
    let bf = fu(b);
    let ratio = Float::with_val(PREC, &m1f / &mf);
    let log_r = Float::with_val(PREC, ratio.ln());
    // 1/b - (n/a + m/b)·log((m+1)/m) + n/(a(m+1))
    let t1 = Float::with_val(PREC, fp(1) / &bf);
    let coeff = Float::with_val(PREC,
        Float::with_val(PREC, &nf / &af) + Float::with_val(PREC, &mf / &bf));
    let t2 = Float::with_val(PREC, &coeff * &log_r);
    let t3 = Float::with_val(PREC, &nf / Float::with_val(PREC, &af * &m1f));
    let mut r = Float::with_val(PREC, &t1 - &t2);
    r += &t3;
    r
}

/// s_combined(a,b,M) = Σ_{m=1}^{M-1} rowTerm(a,b,m)
pub fn s_combined(a: usize, b: usize, big_m: usize) -> Float {
    let mut sum = Float::with_val(PREC, 0);
    for m in 1..big_m {
        sum += row_term(a, b, m);
    }
    sum
}

// ════════════════════════════════════════════════════════════════
// §2. ACTUAL ROW INTEGRALS (piecewise FTC)
// ════════════════════════════════════════════════════════════════

/// Integral of (1/(ax)-m)(1/(bx)-n) over [lo, hi] via exact FTC.
///
/// ∫ (1/(ax)-m)(1/(bx)-n) dx = [1/(ab)·ln(x) + (am+bn)/(ab)·(1/x)
///                               - mn·x - 1/(2ab)·(1/x²)] evaluated at endpoints
/// Actually, let's compute it directly:
/// f(x) = 1/(abx²) - m/(bx) - n/(ax) + mn
/// Antiderivative: F(x) = -1/(abx) - (m/b)·ln(x) - (n/a)·ln(x) + mn·x
///                       = -1/(abx) - (m/b + n/a)·ln(x) + mn·x
fn cross_piece_ftc(a: usize, b: usize, m: usize, n: usize,
                   lo: &Float, hi: &Float) -> Float {
    let af = fu(a);
    let bf = fu(b);
    let mf = fu(m);
    let nf = fu(n);
    let ab = Float::with_val(PREC, &af * &bf);
    let mn = Float::with_val(PREC, &mf * &nf);
    let log_coeff = Float::with_val(PREC,
        Float::with_val(PREC, &mf / &bf) + Float::with_val(PREC, &nf / &af));

    // F(x) = -1/(ab·x) - log_coeff·ln(x) + mn·x
    let f = |x: &Float| -> Float {
        let inv_abx = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &ab * x));
        let ln_x = Float::with_val(PREC, x.clone().ln());
        let mut val = Float::with_val(PREC, -&inv_abx);
        val -= Float::with_val(PREC, &log_coeff * &ln_x);
        val += Float::with_val(PREC, &mn * x);
        val
    };
    let f_hi = f(hi);
    let f_lo = f(lo);
    Float::with_val(PREC, &f_hi - &f_lo)
}

/// Is row m a "two-tile" row? (The b-floor value changes within the row.)
/// This happens when a*(m+1) > b*(n+1), i.e., the next a-breakpoint
/// crosses a b-breakpoint.
#[inline]
pub fn is_two_tile(a: usize, b: usize, m: usize) -> bool {
    let n = tile_index(a, b, m);
    a * (m + 1) > b * (n + 1)
}

/// Actual row integral ∫_{1/(a(m+1))}^{1/(am)} {1/(ax)}{1/(bx)} dx
/// via exact piecewise FTC.
pub fn actual_row_integral(a: usize, b: usize, m: usize) -> Float {
    let n = tile_index(a, b, m);
    let af = fu(a);
    let mf = fu(m);
    let m1f = fu(m + 1);
    let bf = fu(b);

    let row_lo = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &af * &m1f));
    let row_hi = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &af * &mf));

    if !is_two_tile(a, b, m) {
        // Single tile: entire row has ⌊1/(bx)⌋ = n
        cross_piece_ftc(a, b, m, n, &row_lo, &row_hi)
    } else {
        // Two-tile row: split at x₀ = 1/(b*(n+1))
        let n1f = fu(n + 1);
        let x0 = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &bf * &n1f));
        // Left piece: [row_lo, x0] with floor = n+1
        let left = cross_piece_ftc(a, b, m, n + 1, &row_lo, &x0);
        // Right piece: [x0, row_hi] with floor = n
        let right = cross_piece_ftc(a, b, m, n, &x0, &row_hi);
        Float::with_val(PREC, &left + &right)
    }
}

/// Σ_{m=1}^{M-1} actualRowIntegral(a,b,m)
pub fn sum_actual_rows(a: usize, b: usize, big_m: usize) -> Float {
    let mut sum = Float::with_val(PREC, 0);
    for m in 1..big_m {
        sum += actual_row_integral(a, b, m);
    }
    sum
}

/// The m=0 strip contribution: ∫_{1/a}^{1} {1/(ax)}{1/(bx)} dx
/// For coprime a < b: on [1/a, 1], {1/(ax)} = 1/(ax) and {1/(bx)} = 1/(bx)
/// (since ax ∈ [1,a] and bx ∈ [b/a,b], both floors are 0).
/// Strip = ∫_{1/a}^1 1/(abx²) dx = [-1/(abx)]_{1/a}^1 = -1/(ab) + a/(ab) = (a-1)/(ab)
pub fn strip(a: usize, b: usize) -> Float {
    if a < 2 {
        return Float::with_val(PREC, 0);
    }
    let a1 = fu(a - 1);
    let ab = Float::with_val(PREC, &fu(a) * &fu(b));
    Float::with_val(PREC, &a1 / &ab)
}

/// Two-tile correction for row m: actual_row_integral - rowTerm.
pub fn two_tile_correction(a: usize, b: usize, m: usize) -> Float {
    if !is_two_tile(a, b, m) {
        return Float::with_val(PREC, 0);
    }
    let actual = actual_row_integral(a, b, m);
    let algebraic = row_term(a, b, m);
    Float::with_val(PREC, &actual - &algebraic)
}
