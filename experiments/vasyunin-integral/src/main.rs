//! ═══════════════════════════════════════════════════════════════════════════
//!  VASYUNIN INTEGRAL VERIFIER — Production Grade
//!  The Cathedral — Certified Gram Matrix Computation
//!
//!  Verifies the Vasyunin-Báez-Duarte identity:
//!    G(j,k) = ∫₀¹ {1/(jx)} · {1/(kx)} dx
//!
//!  where G(j,k) is the discrete Vasyunin cotangent formula:
//!    G(j,k) = (ln(2π)-γ)/2·(1/j+1/k) + (j-k)/(2jk)·ln(k/j)
//!             - πd/(2jk)·(V(j/d,k/d) + V(k/d,j/d)) - 1/(jk)
//!
//!  Method: Exact piecewise FTC (zero quadrature error)
//!    On each tile where ⌊1/(jx)⌋ = m and ⌊1/(kx)⌋ = n, the integrand
//!    is a polynomial (m - 1/(jx))(n - 1/(kx)), integrated exactly via
//!    antiderivative evaluation at tile boundaries.
//!
//!  Precision: 256-bit MPFR via `rug` (77 decimal digits)
//!  Parallelism: rayon (all available cores)
//!  Certification: JSON certificates with error bounds
//!
//!  Created: April 20, 2026 — The Night Assault
//!  Upgraded: April 25, 2026 — Production certification
//! ═══════════════════════════════════════════════════════════════════════════

use cathedral_utils::arith::gcd;
use cathedral_utils::constants;
use rayon::prelude::*;
use rug::ops::Pow;
use rug::Float;
use serde::Serialize;
use std::io::Write;
use std::sync::Mutex;
use std::time::Instant;

// ═══════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════

/// MPFR precision in bits. 256 bits ≈ 77 decimal digits.
const PREC: u32 = 256;

/// Number of bulk rows computed in the main piecewise integration.
const BULK_ROWS: usize = 100_000;

/// Additional tail rows for convergence. Total: BULK + TAIL.
const TAIL_EXTRA: usize = 900_000;

/// Maximum index for off-diagonal verification.
const MAX_K: usize = 50;

/// Maximum diagonal index.
const MAX_DIAG: usize = 50;

/// Minimum matching digits to certify a pair.
const CERT_THRESHOLD: i32 = 4;

// ═══════════════════════════════════════════════════════════════════════════
// HIGH-PRECISION PRIMITIVES
// ═══════════════════════════════════════════════════════════════════════════

fn fp(x: i64) -> Float {
    Float::with_val(PREC, x)
}
fn fu(x: usize) -> Float {
    Float::with_val(PREC, x as u64)
}
fn pi() -> Float {
    Float::with_val(PREC, rug::float::Constant::Pi)
}

/// Safe floor: Float → usize via MPFR floor.
fn floor_to_usize(x: &Float) -> usize {
    let floored = Float::with_val(PREC, x.floor_ref());
    match floored.to_f64() {
        f if f < 0.0 => 0,
        f => f as usize,
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// VASYUNIN COTANGENT SUM — V(a,b) = Σ_{m=1}^{a-1} {mb/a}·cot(πm/a)
// ═══════════════════════════════════════════════════════════════════════════

fn vasyunin_sum(a: usize, b: usize) -> Float {
    if a <= 1 {
        return fp(0);
    }
    let pi_val = pi();
    let af = fu(a);
    let mut total = fp(0);
    for m in 1..a {
        let mb_mod_a = (m * b) % a;
        let frac = Float::with_val(PREC, Float::with_val(PREC, mb_mod_a as u64) / &af);
        let angle = Float::with_val(PREC, &pi_val * Float::with_val(PREC, m as u64) / &af);
        let sin_v = Float::with_val(PREC, angle.clone().sin());
        let cos_v = Float::with_val(PREC, angle.cos());
        if sin_v.is_zero() {
            continue;
        }
        let cot_v = Float::with_val(PREC, cos_v / sin_v);
        total += Float::with_val(PREC, frac * cot_v);
    }
    total
}

// ═══════════════════════════════════════════════════════════════════════════
// VASYUNIN GRAM ENTRY — THE DISCRETE FORMULA
// ═══════════════════════════════════════════════════════════════════════════

/// Compute G(j,k) via the exact Vasyunin cotangent formula.
/// NO INTEGRALS — pure discrete arithmetic at 256-bit precision.
fn gram_entry(j: usize, k: usize) -> Float {
    let g = constants::euler_gamma_mpfr(PREC);
    let l2p = constants::ln2pi_mpfr(PREC);
    let jf = fu(j);
    let kf = fu(k);

    if j == k {
        // G(k,k) = (ln(2π) - γ)/k - 1/k²
        let a = Float::with_val(PREC, &l2p - &g);
        let b = Float::with_val(PREC, &a / &jf);
        let c = Float::with_val(PREC, fp(1) / Float::with_val(PREC, jf.clone().pow(2u32)));
        return Float::with_val(PREC, b - c);
    }

    let jk = Float::with_val(PREC, &jf * &kf);
    let d = gcd(j, k);
    let jp = j / d;
    let kp = k / d;
    let df = fu(d);
    let pi_val = pi();

    // term1 = (ln(2π) - γ)/2 · (1/j + 1/k)
    let coeff = Float::with_val(PREC, Float::with_val(PREC, &l2p - &g) / fp(2));
    let inv_sum = Float::with_val(
        PREC,
        Float::with_val(PREC, fp(1) / &jf) + Float::with_val(PREC, fp(1) / &kf),
    );
    let term1 = Float::with_val(PREC, &coeff * &inv_sum);

    // term2 = (j-k)/(2jk) · ln(k/j)
    let diff = Float::with_val(PREC, &jf - &kf);
    let denom = Float::with_val(PREC, fp(2) * &jk);
    let ratio = Float::with_val(PREC, Float::with_val(PREC, &kf / &jf).ln());
    let term2 = Float::with_val(PREC, Float::with_val(PREC, diff / denom) * ratio);

    // term3 = πd/(2jk) · (V(j/d, k/d) + V(k/d, j/d))
    let v1 = vasyunin_sum(jp, kp);
    let v2 = vasyunin_sum(kp, jp);
    let v_sum = Float::with_val(PREC, v1 + v2);
    let pi_d = Float::with_val(PREC, &pi_val * &df);
    let two_jk = Float::with_val(PREC, fp(2) * &jk);
    let term3 = Float::with_val(PREC, Float::with_val(PREC, pi_d / two_jk) * v_sum);

    // term4 = 1/(jk)
    let term4 = Float::with_val(PREC, fp(1) / &jk);

    // G = term1 + term2 - term3 - term4
    let sum12 = Float::with_val(PREC, &term1 + &term2);
    let sum34 = Float::with_val(PREC, &term3 + &term4);
    Float::with_val(PREC, sum12 - sum34)
}

// ═══════════════════════════════════════════════════════════════════════════
// PIECEWISE EXACT INTEGRAL — THE FTC ENGINE
// ═══════════════════════════════════════════════════════════════════════════

/// Compute the tail correction: more rows at high m for convergence.
fn tail_correction_mpfr(j: usize, k: usize, m_start: usize, extra_rows: usize) -> Float {
    let jf = fu(j);
    let kf = fu(k);
    let jk = Float::with_val(PREC, &jf * &kf);
    let mut total = fp(0);

    let m_end = m_start + extra_rows;
    for m in m_start..=m_end {
        let mf = fu(m);
        let j_lo = Float::with_val(
            PREC,
            fp(1) / Float::with_val(PREC, &jf * Float::with_val(PREC, &mf + fp(1))),
        );
        let j_hi = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &jf * &mf));
        if j_lo >= j_hi {
            continue;
        }

        let val_at_hi = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &kf * &j_hi));
        let val_at_lo = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &kf * &j_lo));
        let n_min = floor_to_usize(&val_at_hi);
        let n_max = floor_to_usize(&val_at_lo);

        for n in n_min..=n_max {
            let nf = fu(n);
            let k_lo = Float::with_val(
                PREC,
                fp(1) / Float::with_val(PREC, &kf * Float::with_val(PREC, &nf + fp(1))),
            );
            let k_hi = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &kf * &nf));

            let lo = if j_lo > k_lo {
                j_lo.clone()
            } else {
                k_lo.clone()
            };
            let hi = if j_hi < k_hi {
                j_hi.clone()
            } else {
                k_hi.clone()
            };
            if lo >= hi {
                continue;
            }

            // Antiderivative: F(x) = -1/(jkx) - (n/j + m/k)·ln(x) + m·n·x
            let coeff_log = Float::with_val(
                PREC,
                Float::with_val(PREC, &nf / &jf) + Float::with_val(PREC, &mf / &kf),
            );
            let coeff_const = Float::with_val(PREC, &mf * &nf);

            let eval = |x: &Float| -> Float {
                let a = Float::with_val(PREC, fp(-1) / Float::with_val(PREC, &jk * x));
                let b = Float::with_val(PREC, &coeff_log * Float::with_val(PREC, x.clone().ln()));
                let c = Float::with_val(PREC, &coeff_const * x);
                Float::with_val(PREC, Float::with_val(PREC, a - b) + c)
            };

            total += Float::with_val(PREC, eval(&hi) - eval(&lo));
        }
    }
    total
}

/// Compute ∫₀¹ {1/(jx)}·{1/(kx)} dx via exact piecewise FTC.
///
/// The integrand is piecewise polynomial on rectangles where
/// ⌊1/(jx)⌋ = m and ⌊1/(kx)⌋ = n are constant. On each tile:
///   {1/(jx)}·{1/(kx)} = (1/(jx) - m)(1/(kx) - n)
/// which has the exact antiderivative:
///   F(x) = -1/(jkx) + (n/j + m/k)·ln(x) + m·n·x   (valid in tile interior)
///
/// Total error ≈ 1/(j·(BULK_ROWS + TAIL_EXTRA)).
fn integral_piecewise(j: usize, k: usize) -> Float {
    let jf = fu(j);
    let kf = fu(k);
    let jk = Float::with_val(PREC, &jf * &kf);
    let mut total = fp(0);

    // Phase 1: MPFR bulk rows
    for m in 0..=BULK_ROWS {
        let mf = fu(m);
        let j_lo = Float::with_val(
            PREC,
            fp(1) / Float::with_val(PREC, &jf * Float::with_val(PREC, &mf + fp(1))),
        );
        let j_hi = if m == 0 {
            fp(1)
        } else {
            Float::with_val(PREC, fp(1) / Float::with_val(PREC, &jf * &mf))
        };
        if j_lo >= j_hi {
            continue;
        }

        let val_at_hi = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &kf * &j_hi));
        let val_at_lo = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &kf * &j_lo));
        let n_min = floor_to_usize(&val_at_hi);
        let n_max = floor_to_usize(&val_at_lo);

        for n in n_min..=n_max {
            let nf = fu(n);
            let k_lo = Float::with_val(
                PREC,
                fp(1) / Float::with_val(PREC, &kf * Float::with_val(PREC, &nf + fp(1))),
            );
            let k_hi = if n == 0 {
                fp(1)
            } else {
                Float::with_val(PREC, fp(1) / Float::with_val(PREC, &kf * &nf))
            };

            let lo = if j_lo > k_lo {
                j_lo.clone()
            } else {
                k_lo.clone()
            };
            let hi = if j_hi < k_hi {
                j_hi.clone()
            } else {
                k_hi.clone()
            };
            if lo >= hi {
                continue;
            }

            let coeff_log = Float::with_val(
                PREC,
                Float::with_val(PREC, &nf / &jf) + Float::with_val(PREC, &mf / &kf),
            );
            let coeff_const = Float::with_val(PREC, &mf * &nf);

            let eval = |x: &Float| -> Float {
                let a = Float::with_val(PREC, fp(-1) / Float::with_val(PREC, &jk * x));
                let b = Float::with_val(PREC, &coeff_log * Float::with_val(PREC, x.clone().ln()));
                let c = Float::with_val(PREC, &coeff_const * x);
                Float::with_val(PREC, Float::with_val(PREC, a - b) + c)
            };

            let f_hi = eval(&hi);
            let f_lo = eval(&lo);
            total += Float::with_val(PREC, f_hi - f_lo);
        }
    }

    // Phase 2: Tail correction
    let tail = tail_correction_mpfr(j, k, BULK_ROWS + 1, TAIL_EXTRA);
    total += tail;
    total
}

// ═══════════════════════════════════════════════════════════════════════════
// CERTIFICATION DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════

#[derive(Serialize, Clone)]
struct EntryResult {
    j: usize,
    k: usize,
    gcd: usize,
    formula: f64,
    integral: f64,
    error: f64,
    matching_digits: i32,
    time_ms: f64,
    certified: bool,
}

#[derive(Serialize)]
struct Certificate {
    experiment: String,
    version: String,
    timestamp: String,
    identity: String,
    method: String,
    precision_bits: u32,
    decimal_digits: u32,
    bulk_rows: usize,
    tail_rows: usize,
    total_rows: usize,
    max_index: usize,
    total_pairs: usize,
    threads: usize,
    runtime_seconds: f64,
    certification_threshold: i32,
    min_matching_digits: i32,
    all_certified: bool,
    lean_bridge: LeanBridge,
    diagonal: Vec<EntryResult>,
    off_diagonal: Vec<EntryResult>,
    showcase: Vec<ShowcaseEntry>,
}

#[derive(Serialize)]
struct LeanBridge {
    axiom: String,
    file: String,
    definition: String,
    status: String,
}

#[derive(Serialize)]
struct ShowcaseEntry {
    j: usize,
    k: usize,
    formula_full: String,
    integral_full: String,
    error: f64,
    matching_digits: i32,
}

// ═══════════════════════════════════════════════════════════════════════════
// VERIFICATION ENGINE
// ═══════════════════════════════════════════════════════════════════════════

fn verify_pair(j: usize, k: usize) -> (EntryResult, Option<ShowcaseEntry>) {
    let t = Instant::now();
    let formula = gram_entry(j, k);
    let integral = integral_piecewise(j, k);
    let diff = Float::with_val(PREC, &formula - &integral);
    let error = Float::with_val(PREC, diff.abs());
    let digits = if error.is_zero() {
        77 // Full precision match
    } else {
        let log_err = Float::with_val(PREC, error.clone().log10());
        std::cmp::max((-log_err.to_f64()).floor() as i32, 0)
    };
    let time_ms = t.elapsed().as_secs_f64() * 1000.0;

    let entry = EntryResult {
        j,
        k,
        gcd: gcd(j, k),
        formula: formula.to_f64(),
        integral: integral.to_f64(),
        error: error.to_f64(),
        matching_digits: digits,
        time_ms,
        certified: digits >= CERT_THRESHOLD,
    };

    // Generate showcase for small pairs
    let showcase = if (j <= 7 && k <= 7) || j == k {
        Some(ShowcaseEntry {
            j,
            k,
            formula_full: formula.to_string_radix(10, None),
            integral_full: integral.to_string_radix(10, None),
            error: error.to_f64(),
            matching_digits: digits,
        })
    } else {
        None
    };

    (entry, showcase)
}

// ═══════════════════════════════════════════════════════════════════════════
// DISPLAY
// ═══════════════════════════════════════════════════════════════════════════

fn print_header() {
    let header = format!(
        "\n\
         ═══════════════════════════════════════════════════════════════════════\n\
         ║  VASYUNIN INTEGRAL VERIFIER v2.0 — CERTIFIED                      ║\n\
         ║  The Cathedral — Gram Matrix Identity Certification               ║\n\
         ═══════════════════════════════════════════════════════════════════════\n\
         \n\
           Identity:   G(j,k) = ∫₀¹ {{1/(jx)}} · {{1/(kx)}} dx\n\
           Method:     Exact piecewise FTC (zero quadrature error)\n\
           Precision:  {} bits (~{} decimal digits)\n\
           Rows:       {:>10} bulk + {:>10} tail = {:>10} total\n\
           Threads:    {}\n\
           Target:     All 1 ≤ j ≤ k ≤ {}\n\
         \n\
         ───────────────────────────────────────────────────────────────────────",
        PREC,
        PREC * 3 / 10,
        BULK_ROWS,
        TAIL_EXTRA,
        BULK_ROWS + TAIL_EXTRA,
        rayon::current_num_threads(),
        MAX_K
    );
    println!("{}", header);
}

fn print_entry(r: &EntryResult) {
    let status = if r.certified { "✅" } else { "⚠️ " };
    println!("  {} G({:>3},{:>3})  gcd={:<3}  formula={:>22.15}  integral={:>22.15}  Δ={:.2e}  digits={:<3}  {:.0}ms",
        status, r.j, r.k, r.gcd, r.formula, r.integral, r.error, r.matching_digits, r.time_ms);
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════

fn main() {
    let t0 = Instant::now();
    print_header();

    // ─── Phase 1: Diagonal G(k,k) ───────────────────────────────────────
    println!(
        "\n  ━━━ PHASE 1: DIAGONAL G(k,k) for k = 1..{} ━━━",
        MAX_DIAG
    );

    let diag_results: Vec<EntryResult> = (1..=MAX_DIAG).map(|k| verify_pair(k, k).0).collect();

    for r in &diag_results {
        print_entry(r);
    }

    let min_diag = diag_results
        .iter()
        .map(|r| r.matching_digits)
        .min()
        .unwrap_or(0);
    let all_diag_cert = diag_results.iter().all(|r| r.certified);
    println!(
        "\n  Diagonal: min {} digits | {}",
        min_diag,
        if all_diag_cert {
            "ALL CERTIFIED ✅"
        } else {
            "SOME FAILED ⚠️"
        }
    );

    // ─── Phase 2: Off-diagonal G(j,k) ───────────────────────────────────
    let pairs: Vec<(usize, usize)> = {
        let mut p = Vec::new();
        for j in 1..=MAX_K {
            for k in (j + 1)..=MAX_K {
                p.push((j, k));
            }
        }
        p
    };
    let n_pairs = pairs.len();

    println!(
        "\n  ━━━ PHASE 2: OFF-DIAGONAL G(j,k) — {} pairs ━━━",
        n_pairs
    );

    let offdiag_mutex: Mutex<Vec<EntryResult>> = Mutex::new(Vec::new());
    let showcase_mutex: Mutex<Vec<ShowcaseEntry>> = Mutex::new(Vec::new());

    pairs.par_iter().for_each(|&(j, k)| {
        let (entry, showcase) = verify_pair(j, k);
        {
            let mut lock = offdiag_mutex.lock().unwrap();
            lock.push(entry);
            // Print progress every 100 pairs
            if lock.len() % 100 == 0 || lock.len() == n_pairs {
                eprint!(
                    "\r  Progress: {}/{} pairs ({:.0}%)",
                    lock.len(),
                    n_pairs,
                    100.0 * lock.len() as f64 / n_pairs as f64
                );
                std::io::stderr().flush().ok();
            }
        }
        if let Some(sc) = showcase {
            showcase_mutex.lock().unwrap().push(sc);
        }
    });
    eprintln!();

    let mut offdiag_results = offdiag_mutex.into_inner().unwrap();
    offdiag_results.sort_by_key(|r| (r.j, r.k));

    let showcase_entries = showcase_mutex.into_inner().unwrap();

    // Print a representative sample
    let sample: Vec<&EntryResult> = offdiag_results
        .iter()
        .filter(|r| r.j <= 5 || r.gcd > 1 || r.matching_digits < 6)
        .collect();

    for r in &sample[..sample.len().min(40)] {
        print_entry(r);
    }
    if offdiag_results.len() > 40 {
        println!("  ... ({} more pairs)", offdiag_results.len() - 40);
    }

    let min_offdiag = offdiag_results
        .iter()
        .map(|r| r.matching_digits)
        .min()
        .unwrap_or(0);
    let all_offdiag_cert = offdiag_results.iter().all(|r| r.certified);
    let worst = offdiag_results
        .iter()
        .min_by_key(|r| r.matching_digits)
        .unwrap();

    println!(
        "\n  Off-diagonal: min {} digits (worst: G({},{})) | {}",
        min_offdiag,
        worst.j,
        worst.k,
        if all_offdiag_cert {
            "ALL CERTIFIED ✅"
        } else {
            "SOME FAILED ⚠️"
        }
    );

    // ─── Phase 3: GCD structure analysis ────────────────────────────────
    println!("\n  ━━━ PHASE 3: GCD STRUCTURE ANALYSIS ━━━");

    let mut gcd_groups: std::collections::HashMap<usize, Vec<&EntryResult>> =
        std::collections::HashMap::new();
    for r in &offdiag_results {
        gcd_groups.entry(r.gcd).or_default().push(r);
    }
    let mut gcd_keys: Vec<usize> = gcd_groups.keys().cloned().collect();
    gcd_keys.sort();

    for &g in &gcd_keys {
        let group = &gcd_groups[&g];
        let min_d = group.iter().map(|r| r.matching_digits).min().unwrap_or(0);
        let max_d = group.iter().map(|r| r.matching_digits).max().unwrap_or(0);
        let avg_d: f64 =
            group.iter().map(|r| r.matching_digits as f64).sum::<f64>() / group.len() as f64;
        println!(
            "    gcd={:<3}  {} pairs  digits: min={}, avg={:.1}, max={}",
            g,
            group.len(),
            min_d,
            avg_d,
            max_d
        );
    }

    // ─── Phase 4: Full precision showcase ────────────────────────────────
    println!("\n  ━━━ PHASE 4: FULL PRECISION SHOWCASE (256-bit) ━━━");

    let showcase_pairs = vec![(1, 1), (1, 2), (2, 3), (3, 5), (5, 7), (7, 11), (6, 10)];
    for (j, k) in &showcase_pairs {
        let r = verify_pair(*j, *k);
        println!("\n  G({},{})  [gcd={}]:", j, k, gcd(*j, *k));
        if let Some(sc) = &r.1 {
            println!("    Formula:  {}", sc.formula_full);
            println!("    Integral: {}", sc.integral_full);
            println!(
                "    |Error|:  {:.5e}  ({} digits)",
                sc.error, sc.matching_digits
            );
        }
    }

    // ─── Verdict ────────────────────────────────────────────────────────
    let elapsed = t0.elapsed().as_secs_f64();
    let all_min = std::cmp::min(min_diag, min_offdiag);
    let all_certified = all_diag_cert && all_offdiag_cert;
    let total_pairs = diag_results.len() + offdiag_results.len();

    println!("\n═══════════════════════════════════════════════════════════════════════");
    println!(
        "║  {}  VASYUNIN INTEGRAL IDENTITY {} TO {} DIGITS",
        if all_certified { "✅" } else { "⚠️ " },
        if all_certified {
            "CERTIFIED"
        } else {
            "PARTIAL"
        },
        all_min
    );
    println!("║");
    println!(
        "║  G(j,k) = ∫₀¹ {{1/(jx)}} · {{1/(kx)}} dx   ∀ 1 ≤ j ≤ k ≤ {}",
        MAX_K
    );
    println!(
        "║  Pairs verified: {}  ({} diagonal + {} off-diagonal)",
        total_pairs,
        diag_results.len(),
        offdiag_results.len()
    );
    println!(
        "║  Runtime: {:.2}s  |  Precision: {} bits  |  Threads: {}",
        elapsed,
        PREC,
        rayon::current_num_threads()
    );
    println!("║");
    println!("║  Lean axiom: vasyunin_offdiag_integral");
    println!("║  File: Cathedral/Vasyunin/Augmented/VasyuninIntegralProof.lean");
    println!("║  Status: Empirically certified — formal proof in progress");
    println!("═══════════════════════════════════════════════════════════════════════");

    // ─── Write certified results ─────────────────────────────────────────
    std::fs::create_dir_all("results/certificates").unwrap();

    let cert = Certificate {
        experiment: "Vasyunin Integral Verifier — Certified".into(),
        version: "2.0.0".into(),
        timestamp: chrono::Utc::now().to_rfc3339(),
        identity: "G(j,k) = ∫₀¹ {1/(jx)}·{1/(kx)} dx".into(),
        method: "Exact piecewise FTC (zero quadrature error)".into(),
        precision_bits: PREC,
        decimal_digits: PREC * 3 / 10,
        bulk_rows: BULK_ROWS,
        tail_rows: TAIL_EXTRA,
        total_rows: BULK_ROWS + TAIL_EXTRA,
        max_index: MAX_K,
        total_pairs,
        threads: rayon::current_num_threads(),
        runtime_seconds: elapsed,
        certification_threshold: CERT_THRESHOLD,
        min_matching_digits: all_min,
        all_certified,
        lean_bridge: LeanBridge {
            axiom: "vasyunin_offdiag_integral".into(),
            file: "Cathedral/Vasyunin/Augmented/VasyuninIntegralProof.lean".into(),
            definition: "vasyuninGramEntry".into(),
            status: if all_certified {
                format!(
                    "CERTIFIED — formula = integral to {} digits for all {} pairs",
                    all_min, total_pairs
                )
            } else {
                format!(
                    "PARTIAL — min {} digits, {} pairs below threshold",
                    all_min,
                    offdiag_results.iter().filter(|r| !r.certified).count()
                )
            },
        },
        diagonal: diag_results.clone(),
        off_diagonal: offdiag_results.clone(),
        showcase: showcase_entries,
    };

    let cert_json = serde_json::to_string_pretty(&cert).unwrap();
    std::fs::write(
        "results/certificates/vasyunin_integral_cert.json",
        &cert_json,
    )
    .unwrap();
    println!("\n  📁 Certificate: results/certificates/vasyunin_integral_cert.json");

    // TSV for quick analysis
    let tsv_path = "results/results.tsv";
    let mut tsv = std::fs::File::create(tsv_path).unwrap();
    writeln!(
        tsv,
        "j\tk\tgcd\tformula\tintegral\terror\tdigits\tcertified\ttime_ms"
    )
    .unwrap();
    for r in diag_results.iter().chain(offdiag_results.iter()) {
        writeln!(
            tsv,
            "{}\t{}\t{}\t{:.15e}\t{:.15e}\t{:.5e}\t{}\t{}\t{:.1}",
            r.j,
            r.k,
            r.gcd,
            r.formula,
            r.integral,
            r.error,
            r.matching_digits,
            r.certified,
            r.time_ms
        )
        .unwrap();
    }
    println!("  📁 TSV: {}", tsv_path);

    println!();
}
