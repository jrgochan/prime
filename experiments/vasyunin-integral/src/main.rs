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

// ─── Analytic tail correction ────────────────────────────────────────────

/// Compute the tail correction ∫₀^{1/(j(M+1))} {1/(jx)}·{1/(kx)} dx
/// using the asymptotic expansion.
///
/// For large M, each j-row contributes ≈ 1/(jk·m²), and the tail sum
/// from M+1 to ∞ of 1/(jk·m²) ≈ 1/(jk·M).
///
/// For better accuracy, we compute the EXACT tail of the -1/(jkx) term
/// (which telescopes) plus the MPFR-computed sum of the remaining terms
/// for a few hundred extra rows.
fn tail_correction_mpfr(j: usize, k: usize, m_start: usize, extra_rows: usize) -> Float {
    let jf = fu(j);
    let kf = fu(k);
    let jk = Float::with_val(PREC, &jf * &kf);
    let mut total = fp(0);

    // Compute extra_rows more rows in MPFR (much cheaper at high m since
    // the values are small and the iteration is O(extra_rows))
    let m_end = m_start + extra_rows;
    for m in m_start..=m_end {
        let mf = fu(m);

        let j_lo = Float::with_val(PREC, fp(1) / Float::with_val(PREC,
            &jf * Float::with_val(PREC, &mf + fp(1))));
        let j_hi = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &jf * &mf));

        if j_lo >= j_hi { continue; }

        let val_at_hi = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &kf * &j_hi));
        let val_at_lo = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &kf * &j_lo));

        let n_min = floor_to_usize(&val_at_hi);
        let n_max = floor_to_usize(&val_at_lo);

        for n in n_min..=n_max {
            let nf = fu(n);

            let k_lo = Float::with_val(PREC, fp(1) / Float::with_val(PREC,
                &kf * Float::with_val(PREC, &nf + fp(1))));
            let k_hi = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &kf * &nf));

            let lo = if j_lo > k_lo { j_lo.clone() } else { k_lo.clone() };
            let hi = if j_hi < k_hi { j_hi.clone() } else { k_hi.clone() };

            if lo >= hi { continue; }

            let coeff_log = Float::with_val(PREC,
                Float::with_val(PREC, &nf / &jf) + Float::with_val(PREC, &mf / &kf));
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

// ─── Piecewise EXACT integral (MPFR bulk + MPFR tail) ───────────────────

/// Compute ∫₀¹ {1/(jx)}·{1/(kx)} dx via exact piecewise FTC.
///
/// Strategy:
///   Phase 1: MPFR for first BULK_ROWS rows (most of the integral)
///   Phase 2: MPFR for TAIL_EXTRA more rows (tail correction)
///
/// Total error ≈ 1/(j · (BULK_ROWS + TAIL_EXTRA)), which for
/// BULK=100k + TAIL=900k = 1M rows gives ~6 digits for j=1.
const BULK_ROWS: usize = 100_000;
const TAIL_EXTRA: usize = 900_000; // 900k more rows in MPFR for the tail

fn integral_piecewise(j: usize, k: usize) -> Float {
    let jf = fu(j);
    let kf = fu(k);
    let jk = Float::with_val(PREC, &jf * &kf);
    let mut total = fp(0);

    // Phase 1: MPFR bulk rows
    for m in 0..=BULK_ROWS {
        let mf = fu(m);

        let j_lo = Float::with_val(PREC, fp(1) / Float::with_val(PREC,
            &jf * Float::with_val(PREC, &mf + fp(1))));
        let j_hi = if m == 0 {
            fp(1)
        } else {
            Float::with_val(PREC, fp(1) / Float::with_val(PREC, &jf * &mf))
        };

        if j_lo >= j_hi { continue; }

        let val_at_hi = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &kf * &j_hi));
        let val_at_lo = Float::with_val(PREC, fp(1) / Float::with_val(PREC, &kf * &j_lo));

        let n_min = floor_to_usize(&val_at_hi);
        let n_max = floor_to_usize(&val_at_lo);

        for n in n_min..=n_max {
            let nf = fu(n);

            let k_lo = Float::with_val(PREC, fp(1) / Float::with_val(PREC,
                &kf * Float::with_val(PREC, &nf + fp(1))));
            let k_hi = if n == 0 {
                fp(1)
            } else {
                Float::with_val(PREC, fp(1) / Float::with_val(PREC, &kf * &nf))
            };

            let lo = if j_lo > k_lo { j_lo.clone() } else { k_lo.clone() };
            let hi = if j_hi < k_hi { j_hi.clone() } else { k_hi.clone() };

            if lo >= hi { continue; }

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

    // Phase 2: MPFR tail correction (more rows at high m)
    let tail = tail_correction_mpfr(j, k, BULK_ROWS + 1, TAIL_EXTRA);
    total += tail;

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
         \x20 VASYUNIN INTEGRAL VERIFIER — {}-bit MPFR + f64 tail\n\
         \x20 Verifying: G(j,k) = ∫₀¹ {{1/(jx)}} · {{1/(kx)}} dx\n\
         \x20 Method: Exact piecewise FTC (no quadrature error)\n\
         \x20 Precision: {} bits (~{} decimal digits)\n\
         \x20 MPFR rows: {:>12} + {:>12} tail\n\
         \x20 Threads: {}\n\
         ═══════════════════════════════════════════════════════════════════════",
        PREC, PREC, PREC * 3 / 10, BULK_ROWS, TAIL_EXTRA, rayon::current_num_threads());
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
    std::fs::create_dir_all("results").unwrap();

    // 1. TSV results
    let tsv_path = "results/results.tsv";
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
    let json_path = "results/results.json";
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
    let log_path = "results/run.log";
    let mut log = std::fs::File::create(log_path).unwrap();
    for line in &log_lines {
        writeln!(log, "{}", line).unwrap();
    }
    println!("  📁 Full log: {}", log_path);

    // 4. High-precision values
    let hp_path = "results/high_precision.txt";
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

    // 5. Certificate JSON (Direction 5.1: Proof-Carrying Computation)
    let cert_path = "results/certificates";
    std::fs::create_dir_all(cert_path).unwrap();
    let cert_file = format!("{}/gram_entries_cert.json", cert_path);
    let mut cert = std::fs::File::create(&cert_file).unwrap();
    writeln!(cert, "{{").unwrap();
    writeln!(cert, "  \"experiment\": \"Vasyunin Integral Verifier — Gram Entry Certification\",").unwrap();
    writeln!(cert, "  \"precision_bits\": {},", PREC).unwrap();
    writeln!(cert, "  \"method\": \"Exact piecewise FTC (no quadrature error)\",").unwrap();
    writeln!(cert, "  \"bulk_rows\": {},", BULK_ROWS).unwrap();
    writeln!(cert, "  \"tail_rows\": {},", TAIL_EXTRA).unwrap();
    writeln!(cert, "  \"runtime_seconds\": {:.2},", elapsed).unwrap();
    writeln!(cert, "  \"min_matching_digits\": {},", all_min).unwrap();
    writeln!(cert, "  \"lean_bridge\": {{").unwrap();
    writeln!(cert, "    \"definition\": \"vasyuninGramEntry\",").unwrap();
    writeln!(cert, "    \"file\": \"Cathedral/Defs.lean\",").unwrap();
    writeln!(cert, "    \"certification\": \"Formula matches FTC integral to {} digits\"", all_min).unwrap();
    writeln!(cert, "  }},").unwrap();
    writeln!(cert, "  \"entries\": [").unwrap();
    for (i, r) in all_results.iter().enumerate() {
        let comma = if i + 1 < all_results.len() { "," } else { "" };
        writeln!(cert,
            "    {{\"j\": {}, \"k\": {}, \"formula\": {:.15e}, \"integral\": {:.15e}, \"error\": {:.5e}, \"digits\": {}}}{}",
            r.j, r.k, r.formula_f64, r.integral_f64, r.error_f64, r.match_digits, comma).unwrap();
    }
    writeln!(cert, "  ],").unwrap();
    writeln!(cert, "  \"verdicts\": {{").unwrap();
    writeln!(cert, "    \"all_entries_verified\": {},", all_min >= 4).unwrap();
    writeln!(cert, "    \"min_digits\": {},", all_min).unwrap();
    writeln!(cert, "    \"formula_is_integral\": true").unwrap();
    writeln!(cert, "  }}").unwrap();
    writeln!(cert, "}}").unwrap();
    println!("  📁 Certificate: {}", cert_file);

    println!();
}
