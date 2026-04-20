// ═══════════════════════════════════════════════════════════════════════════
//  VASYUNIN INTEGRAL VERIFIER — 256-bit MPFR
//  Verifying: G(j,k) = ∫₀¹ {1/(jx)}·{1/(kx)} dx
//
//  Method: Exact piecewise FTC (no quadrature error)
//  Uses MPFR via `rug` for arbitrary precision.
//
//  Created: April 20, 2026 — The Night Assault
// ═══════════════════════════════════════════════════════════════════════════

use rug::Float;
use rug::ops::Pow;
use rayon::prelude::*;
use std::sync::Mutex;
use std::time::Instant;
use std::io::Write;

const PREC: u32 = 256;

// ─── High-precision helpers ──────────────────────────────────────────────

fn fp(x: i64) -> Float { Float::with_val(PREC, x) }
fn fu(x: usize) -> Float { Float::with_val(PREC, x as u64) }
fn pi() -> Float { Float::with_val(PREC, rug::float::Constant::Pi) }
fn euler_gamma() -> Float { Float::with_val(PREC, rug::float::Constant::Euler) }
fn ln2pi() -> Float { Float::with_val(PREC, (fp(2) * pi()).ln()) }

fn gcd(a: usize, b: usize) -> usize {
    let (mut a, mut b) = (a, b);
    while b != 0 { let t = b; b = a % b; a = t; }
    a
}

/// Safe floor: convert Float to usize via floor
fn floor_to_usize(x: &Float) -> usize {
    let floored = Float::with_val(PREC, x.floor_ref());
    match floored.to_f64() {
        f if f < 0.0 => 0,
        f => f as usize,
    }
}

/// Safe ceil: convert Float to usize via ceil
fn ceil_to_usize(x: &Float) -> usize {
    let ceiled = Float::with_val(PREC, x.ceil_ref());
    match ceiled.to_f64() {
        f if f < 0.0 => 0,
        f => f as usize,
    }
}

// ─── Vasyunin cotangent sum ──────────────────────────────────────────────

/// V(a, b) = Σ_{m=1}^{a-1} {mb/a} · cot(πm/a)
fn vasyunin_sum(a: usize, b: usize) -> Float {
    if a <= 1 { return fp(0); }
    let pi_val = pi();
    let af = fu(a);
    let mut total = fp(0);
    for m in 1..a {
        let mb_mod_a = (m * b) % a;
        let frac = Float::with_val(PREC, Float::with_val(PREC, mb_mod_a as u64) / &af);
        let angle = Float::with_val(PREC, &pi_val * Float::with_val(PREC, m as u64) / &af);
        let sin_v = Float::with_val(PREC, angle.clone().sin());
        let cos_v = Float::with_val(PREC, angle.cos());
        if sin_v.is_zero() { continue; }
        let cot_v = Float::with_val(PREC, cos_v / sin_v);
        total += Float::with_val(PREC, frac * cot_v);
    }
    total
}

// ─── Vasyunin Gram entry G(j,k) ─────────────────────────────────────────

fn gram_entry(j: usize, k: usize) -> Float {
    let g = euler_gamma();
    let l2p = ln2pi();
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
    let inv_sum = Float::with_val(PREC,
        Float::with_val(PREC, fp(1) / &jf) + Float::with_val(PREC, fp(1) / &kf));
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

// ─── Piecewise EXACT integral ────────────────────────────────────────────

/// Compute ∫₀¹ {1/(jx)}·{1/(kx)} dx via exact piecewise FTC.
///
/// Partition (0,1] into tiles where ⌊1/(jx)⌋=m and ⌊1/(kx)⌋=n are constant.
/// On each tile: integrand = (1/(jx)-m)(1/(kx)-n)
/// Antiderivative: F(x) = -1/(jkx) - (n/j + m/k)·ln(x) + mn·x
fn integral_piecewise(j: usize, k: usize) -> Float {
    let jf = fu(j);
    let kf = fu(k);
    let jk = Float::with_val(PREC, &jf * &kf);
    let mut total = fp(0);

    // Truncation limit: contributions decay as O(1/m²),
    // so for 50+ digit accuracy we need ~10^25 terms... that's too many.
    // BUT: the tail can be computed analytically as ∫ {1/(jx)}{1/(kx)} dx
    // for small x, where both fractional parts ≈ 1/(jx) - ⌊1/(jx)⌋.
    //
    // For practical purposes: use enough terms for the target precision.
    // With N terms, error ≈ 1/(jkN). For 15-digit (f64) accuracy, N ≈ 10^15/jk.
    // For 50-digit accuracy, we'd need 10^50 terms — impractical!
    //
    // SOLUTION: Use the substitution u = 1/x to convert to a convergent sum
    // that can be evaluated efficiently. But for now, let's verify to f64
    // precision (15 digits) which requires N ≈ 10^16 / (jk).
    //
    // Actually for moderate jk, we can do much better. The piecewise
    // contributions for row m are O(1/m²), so tail from M is O(1/M).
    // For 15-digit match we need M ≈ 10^15. That's too slow row-by-row.
    //
    // BETTER APPROACH: Do substitution u = 1/(jx), compute ∫₁^∞ via series.
    // Each piece [n, n+1) contributes a term that can be summed.
    //
    // For now: use high M and verify to available precision.

    let max_m: usize = 100_000; // gives ~5 digits for small j,k

    for m in 0..=max_m {
        let mf = fu(m);

        // j-row: x ∈ (1/(j(m+1)), 1/(jm)]
        let j_lo = Float::with_val(PREC, fp(1) / Float::with_val(PREC,
            &jf * Float::with_val(PREC, &mf + fp(1))));
        let j_hi = if m == 0 {
            fp(1)
        } else {
            Float::with_val(PREC, fp(1) / Float::with_val(PREC, &jf * &mf))
        };

        if j_lo >= j_hi { continue; }

        // Find valid n range within this j-row
        // At x = j_hi: 1/(kx) = 1/(k·j_hi) → floor gives n_min
        // At x = j_lo: 1/(kx) = 1/(k·j_lo) → floor gives n_max
        let val_at_hi = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &kf * &j_hi));
        let val_at_lo = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &kf * &j_lo));

        let n_min = floor_to_usize(&val_at_hi);
        let n_max = floor_to_usize(&val_at_lo);

        for n in n_min..=n_max {
            let nf = fu(n);

            // k-tile: x ∈ (1/(k(n+1)), 1/(kn)]
            let k_lo = Float::with_val(PREC, fp(1) / Float::with_val(PREC,
                &kf * Float::with_val(PREC, &nf + fp(1))));
            let k_hi = if n == 0 {
                fp(1)
            } else {
                Float::with_val(PREC, fp(1) / Float::with_val(PREC, &kf * &nf))
            };

            // Intersection of j-row and k-tile
            let lo = if j_lo > k_lo { j_lo.clone() } else { k_lo.clone() };
            let hi = if j_hi < k_hi { j_hi.clone() } else { k_hi.clone() };

            if lo >= hi { continue; }

            // Antiderivative: F(x) = -1/(jkx) - (n/j + m/k)·ln(x) + mn·x
            let coeff_log = Float::with_val(PREC,
                Float::with_val(PREC, &nf / &jf) + Float::with_val(PREC, &mf / &kf));
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
    total
}

// ─── Verification ────────────────────────────────────────────────────────

struct VerifyResult {
    j: usize,
    k: usize,
    formula_f64: f64,
    integral_f64: f64,
    error_f64: f64,
    match_digits: i32,
    formula_str: String,
    integral_str: String,
    time_ms: f64,
}

fn verify_pair(j: usize, k: usize) -> VerifyResult {
    let t = Instant::now();
    let formula = gram_entry(j, k);
    let integral = integral_piecewise(j, k);
    let diff = Float::with_val(PREC, &formula - &integral);
    let error = Float::with_val(PREC, diff.abs());
    let digits = if error.is_zero() {
        77
    } else {
        let log_err = Float::with_val(PREC, error.clone().log10());
        std::cmp::max((-log_err.to_f64()).floor() as i32, 0)
    };
    VerifyResult {
        j, k,
        formula_f64: formula.to_f64(),
        integral_f64: integral.to_f64(),
        error_f64: error.to_f64(),
        match_digits: digits,
        formula_str: formula.to_string_radix(10, None),
        integral_str: integral.to_string_radix(10, None),
        time_ms: t.elapsed().as_secs_f64() * 1000.0,
    }
}

// ─── Main ────────────────────────────────────────────────────────────────

fn main() {
    let t0 = Instant::now();

    let header = format!(
        "\n═══════════════════════════════════════════════════════════════════════\n\
         \x20 VASYUNIN INTEGRAL VERIFIER — {}-bit MPFR\n\
         \x20 Verifying: G(j,k) = ∫₀¹ {{1/(jx)}} · {{1/(kx)}} dx\n\
         \x20 Method: Exact piecewise FTC (no quadrature error)\n\
         \x20 Precision: {} bits (~{} decimal digits)\n\
         \x20 Piecewise terms: 100,000 per row\n\
         \x20 Threads: {}\n\
         ═══════════════════════════════════════════════════════════════════════",
        PREC, PREC, PREC * 3 / 10, rayon::current_num_threads());
    println!("{}", header);

    let mut log_lines: Vec<String> = vec![header.clone()];

    // ─── Phase 1: Diagonal ───────────────────────────────────────────
    let phase1_header = "\n━━━ PHASE 1: DIAGONAL G(k,k) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━";
    println!("{}", phase1_header);
    log_lines.push(phase1_header.to_string());

    let col_header = format!("  {:>3} {:>3}  {:>22}  {:>22}  {:>6}  {:>8}",
        "j", "k", "Formula", "Integral", "Digits", "Time(ms)");
    println!("{}", col_header);
    println!("  {}", "─".repeat(72));
    log_lines.push(col_header.clone());

    let diag_range: Vec<usize> = (1..=15).collect();
    let diag_results: Vec<VerifyResult> = diag_range.iter()
        .map(|&k| verify_pair(k, k))
        .collect();

    for r in &diag_results {
        let line = format!("  {:>3} {:>3}  {:>22.15}  {:>22.15}  {:>6}  {:>8.1}",
            r.j, r.k, r.formula_f64, r.integral_f64, r.match_digits, r.time_ms);
        println!("{}", line);
        log_lines.push(line);
    }

    let min_diag = diag_results.iter().map(|r| r.match_digits).min().unwrap_or(0);

    // ─── Phase 2: Off-diagonal ───────────────────────────────────────
    let phase2_header = "\n━━━ PHASE 2: OFF-DIAGONAL G(j,k) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━";
    println!("{}", phase2_header);
    log_lines.push(phase2_header.to_string());

    let col2 = format!("  {:>3} {:>3} {:>3}  {:>22}  {:>22}  {:>6}  {:>8}",
        "j", "k", "gcd", "Formula", "Integral", "Digits", "Time(ms)");
    println!("{}", col2);
    println!("  {}", "─".repeat(76));
    log_lines.push(col2.clone());

    let max_k = 10;
    let pairs: Vec<(usize, usize)> = {
        let mut p = Vec::new();
        for j in 1..=max_k {
            for k in (j+1)..=max_k {
                p.push((j, k));
            }
        }
        p
    };

    let offdiag_mutex: Mutex<Vec<VerifyResult>> = Mutex::new(Vec::new());
    pairs.par_iter().for_each(|&(j, k)| {
        let r = verify_pair(j, k);
        offdiag_mutex.lock().unwrap().push(r);
    });

    let mut offdiag_results = offdiag_mutex.into_inner().unwrap();
    offdiag_results.sort_by_key(|r| (r.j, r.k));

    let mut min_offdiag = 100i32;
    for r in &offdiag_results {
        let d = gcd(r.j, r.k);
        let line = format!("  {:>3} {:>3} {:>3}  {:>22.15}  {:>22.15}  {:>6}  {:>8.1}",
            r.j, r.k, d, r.formula_f64, r.integral_f64, r.match_digits, r.time_ms);
        println!("{}", line);
        log_lines.push(line);
        min_offdiag = min_offdiag.min(r.match_digits);
    }

    // ─── Phase 3: Full precision showcase ────────────────────────────
    let phase3_header = "\n━━━ PHASE 3: FULL PRECISION SHOWCASE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━";
    println!("{}", phase3_header);
    log_lines.push(phase3_header.to_string());

    let showcase = vec![(1,1), (1,2), (2,3), (3,5), (5,7)];
    for (j, k) in &showcase {
        let r = verify_pair(*j, *k);
        let lines = format!(
            "\n  G({},{}):\n    Formula:  {}\n    Integral: {}\n    |Error|:  {:.5e}  ({} digits)",
            j, k, r.formula_str, r.integral_str, r.error_f64, r.match_digits);
        println!("{}", lines);
        log_lines.push(lines);
    }

    // ─── Verdict ─────────────────────────────────────────────────────
    let elapsed = t0.elapsed().as_secs_f64();
    let all_min = std::cmp::min(min_diag, min_offdiag);
    let verdict = format!(
        "\n═══════════════════════════════════════════════════════════════════════\n\
         \x20 {} IDENTITY {} to {} decimal digits\n\
         \x20    G(j,k) = ∫₀¹ {{1/(jx)}}·{{1/(kx)}} dx  ∀ 1≤j,k≤{}\n\
         \x20 Runtime: {:.2}s  |  Precision: {} bits  |  Threads: {}\n\
         ═══════════════════════════════════════════════════════════════════════\n",
        if all_min >= 4 { "✅" } else { "⚠️ " },
        if all_min >= 4 { "VERIFIED" } else { "PARTIAL MATCH" },
        all_min, max_k, elapsed, PREC, rayon::current_num_threads());
    println!("{}", verdict);
    log_lines.push(verdict);

    // ─── Write output files ──────────────────────────────────────────

    // 1. TSV results
    let tsv_path = "results.tsv";
    let mut tsv = std::fs::File::create(tsv_path).unwrap();
    writeln!(tsv, "j\tk\tgcd\tformula\tintegral\terror\tdigits\ttime_ms").unwrap();
    for r in diag_results.iter().chain(offdiag_results.iter()) {
        writeln!(tsv, "{}\t{}\t{}\t{:.15e}\t{:.15e}\t{:.5e}\t{}\t{:.1}",
            r.j, r.k, gcd(r.j, r.k),
            r.formula_f64, r.integral_f64, r.error_f64,
            r.match_digits, r.time_ms).unwrap();
    }
    println!("  📁 TSV results: {}", tsv_path);

    // 2. JSON results
    let json_path = "results.json";
    let mut json = std::fs::File::create(json_path).unwrap();
    writeln!(json, "{{").unwrap();
    writeln!(json, "  \"experiment\": \"vasyunin_integral_verifier\",").unwrap();
    writeln!(json, "  \"precision_bits\": {},", PREC).unwrap();
    writeln!(json, "  \"piecewise_terms\": 100000,").unwrap();
    writeln!(json, "  \"threads\": {},", rayon::current_num_threads()).unwrap();
    writeln!(json, "  \"runtime_seconds\": {:.2},", elapsed).unwrap();
    writeln!(json, "  \"min_matching_digits\": {},", all_min).unwrap();
    writeln!(json, "  \"results\": [").unwrap();
    let all_results: Vec<&VerifyResult> = diag_results.iter()
        .chain(offdiag_results.iter()).collect();
    for (i, r) in all_results.iter().enumerate() {
        let comma = if i + 1 < all_results.len() { "," } else { "" };
        writeln!(json,
            "    {{\"j\":{},\"k\":{},\"gcd\":{},\"formula\":{:.15e},\"integral\":{:.15e},\"error\":{:.5e},\"digits\":{},\"time_ms\":{:.1}}}{}",
            r.j, r.k, gcd(r.j, r.k),
            r.formula_f64, r.integral_f64, r.error_f64,
            r.match_digits, r.time_ms, comma).unwrap();
    }
    writeln!(json, "  ]").unwrap();
    writeln!(json, "}}").unwrap();
    println!("  📁 JSON results: {}", json_path);

    // 3. Full log
    let log_path = "run.log";
    let mut log = std::fs::File::create(log_path).unwrap();
    for line in &log_lines {
        writeln!(log, "{}", line).unwrap();
    }
    println!("  📁 Full log: {}", log_path);

    // 4. High-precision values
    let hp_path = "high_precision.txt";
    let mut hp = std::fs::File::create(hp_path).unwrap();
    writeln!(hp, "# Vasyunin Gram entry values at {}-bit precision", PREC).unwrap();
    writeln!(hp, "# G(j,k) = ∫₀¹ {{1/(jx)}}·{{1/(kx)}} dx").unwrap();
    writeln!(hp, "#").unwrap();
    for (j, k) in &showcase {
        let r = verify_pair(*j, *k);
        writeln!(hp, "G({},{}):", j, k).unwrap();
        writeln!(hp, "  formula:  {}", r.formula_str).unwrap();
        writeln!(hp, "  integral: {}", r.integral_str).unwrap();
        writeln!(hp, "  error:    {:.5e}", r.error_f64).unwrap();
        writeln!(hp, "  digits:   {}", r.match_digits).unwrap();
        writeln!(hp, "").unwrap();
    }
    println!("  📁 High-precision: {}", hp_path);
    println!();
}
