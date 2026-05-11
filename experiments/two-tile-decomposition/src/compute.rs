//! ═══════════════════════════════════════════════════════════════════════════
//!  Computational primitives — MPFR row integrals, strip, row terms
//! ═══════════════════════════════════════════════════════════════════════════
use rug::Float;
use crate::PREC;

// ─────────────────────────────────────────────────────────────────────────
// MPFR helpers
// ─────────────────────────────────────────────────────────────────────────

/// Signed integer → MPFR.
#[inline]
pub fn fp(x: i64) -> Float { Float::with_val(PREC, x) }

/// Unsigned → MPFR.
#[inline]
pub fn fu(x: usize) -> Float { Float::with_val(PREC, x as u64) }


// ─────────────────────────────────────────────────────────────────────────
// §1. EXACT ROW INTEGRAL (piecewise FTC)
// ─────────────────────────────────────────────────────────────────────────

/// Compute the exact integral ∫_{1/(a(m+1))}^{1/(am)} {1/(ax)}{1/(bx)} dx
/// using piecewise FTC over tiles.
///
/// On the m-th row, ⌊1/(ax)⌋ = m. The integrand is piecewise-linear in
/// 1/x, so each tile [1/(b(n+1)), 1/(bn)] has a closed-form antiderivative:
///
///   F(x) = -1/(abx) - (n/a + m/b)·log(x) + m·n·x
///
/// The integral is the telescoping sum F(tile_hi) - F(tile_lo) over tiles.
pub fn exact_row_integral(a: usize, b: usize, m: usize) -> Float {
    let af = fu(a);
    let bf = fu(b);
    let ab = Float::with_val(PREC, &af * &bf);
    let mf = fu(m);
    let m1f = fu(m + 1);

    // Row boundaries: x ∈ [1/(a(m+1)), 1/(am)]
    let row_lo = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &af * &m1f));
    let row_hi = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &af * &mf));

    // Range of ⌊1/(bx)⌋ on this row
    let n_hi = (a * m) / b;       // at x = row_hi = 1/(am)
    let n_lo = (a * (m + 1)) / b; // at x = row_lo = 1/(a(m+1))

    // Antiderivative on tile (m, n)
    let eval_f = |x: &Float, n: usize| -> Float {
        let nf = fu(n);
        // -1/(ab·x)
        let t1 = Float::with_val(PREC, fp(-1) / Float::with_val(PREC, &ab * x));
        // -(n/a + m/b)·log(x)
        let na = Float::with_val(PREC, &nf / &af);
        let mb = Float::with_val(PREC, &mf / &bf);
        let coeff = Float::with_val(PREC, &na + &mb);
        let logx = Float::with_val(PREC, x.clone().ln());
        let t2 = Float::with_val(PREC, Float::with_val(PREC, -&coeff) * &logx);
        // m·n·x
        let mn = Float::with_val(PREC, &mf * &nf);
        let t3 = Float::with_val(PREC, &mn * x);
        Float::with_val(PREC, Float::with_val(PREC, &t1 + &t2) + &t3)
    };

    let mut total = Float::with_val(PREC, 0);

    if n_hi == n_lo {
        // Single tile
        let f_hi = eval_f(&row_hi, n_hi);
        let f_lo = eval_f(&row_lo, n_hi);
        total += Float::with_val(PREC, &f_hi - &f_lo);
    } else {
        // Multiple tiles — iterate from n_hi to n_lo
        for n in n_hi..=n_lo {
            let tile_lo = if n == n_lo {
                row_lo.clone()
            } else {
                let bn1 = Float::with_val(PREC, &bf * fu(n + 1));
                Float::with_val(PREC, fp(1) / &bn1)
            };
            let tile_hi = if n == n_hi {
                row_hi.clone()
            } else {
                let bn = Float::with_val(PREC, &bf * fu(n));
                Float::with_val(PREC, fp(1) / &bn)
            };
            if tile_lo >= tile_hi { continue; }
            let f_hi = eval_f(&tile_hi, n);
            let f_lo = eval_f(&tile_lo, n);
            total += Float::with_val(PREC, &f_hi - &f_lo);
        }
    }

    total
}

// ─────────────────────────────────────────────────────────────────────────
// §2. ROW TERM (single-tile approximation from Lean)
// ─────────────────────────────────────────────────────────────────────────

/// rowTerm(a, b, m) = 1/b - (n/a + m/b)·log((m+1)/m) + n/(a·(m+1))
/// where n = tileIndex(a,b,m) = ⌊am/b⌋.
///
/// This is the approximation that treats each row as a single tile
/// with ⌊1/(bx)⌋ = ⌊am/b⌋ everywhere.
pub fn row_term(a: usize, b: usize, m: usize) -> Float {
    let af = fu(a);
    let bf = fu(b);
    let mf = fu(m);
    let m1f = fu(m + 1);
    let n = (a * m) / b;
    let nf = fu(n);

    // 1/b
    let t1 = Float::with_val(PREC, fp(1) / &bf);
    // -(n/a + m/b) · log((m+1)/m)
    let na = Float::with_val(PREC, &nf / &af);
    let mb = Float::with_val(PREC, &mf / &bf);
    let coeff = Float::with_val(PREC, &na + &mb);
    let log_ratio = Float::with_val(PREC, Float::with_val(PREC, &m1f / &mf).ln());
    let t2 = Float::with_val(PREC, Float::with_val(PREC, -&coeff) * &log_ratio);
    // n / (a · (m+1))
    let t3 = Float::with_val(PREC, &nf / Float::with_val(PREC, &af * &m1f));

    Float::with_val(PREC, Float::with_val(PREC, &t1 + &t2) + &t3)
}

// ─────────────────────────────────────────────────────────────────────────
// §3. STRIP INTEGRAL
// ─────────────────────────────────────────────────────────────────────────

/// Strip value: ∫_{1/a}^{1} {1/(ax)}{1/(bx)} dx = (a-1)/(ab)
/// For a=1, the strip is empty (length 0), so strip = 0.
pub fn strip_value(a: usize, b: usize) -> Float {
    if a <= 1 {
        return Float::with_val(PREC, 0);
    }
    let af = fu(a);
    let bf = fu(b);
    let ab = Float::with_val(PREC, &af * &bf);
    Float::with_val(PREC, fu(a - 1) / &ab)
}
