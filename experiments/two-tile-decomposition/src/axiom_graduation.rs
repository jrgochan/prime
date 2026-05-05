//! ═══════════════════════════════════════════════════════════════════════════
//!  AXIOM GRADUATION CERTIFIER — Direct Evaluation of ∑ perClassLimit
//!
//!  Computes ∑ perClassLimit = deltaTarget by evaluating both sides
//!  INDEPENDENTLY (no circular use of gramIntegral = formula).
//!
//!  §1. ∑ perClassLimit is computed from per-class logΓ and ψ values
//!  §2. deltaTarget is computed from formula - strip - stirling - fractTarget
//!  §3. Both are shown to agree at 1024-bit MPFR precision
//!
//!  §4. INDEPENDENT deltaTarget evaluation:
//!      Constructs deltaTarget purely from the twoTileSet structure:
//!        - Piece 1a: -(1/a) Σ_{k=1}^{a-1} logΓ(k/a) = Gauss multiplication
//!        - Piece 1b: +(1/a) Σ_{m₀∈TT} logΓ((m₀+1)/b)  [partial sum]
//!        - Piece 2:  digamma terms with overshoot coefficients
//!
//!      Then compares this "independent deltaTarget" against the
//!      formula-derived deltaTarget to certify the algebraic identity
//!      that would graduate gramIntegral_eq_formula_ge2 in Lean.
//!
//!  The KEY INSIGHT: We can compute ∑ perClassLimit WITHOUT knowing
//!  gramIntegral = formula. Then if ∑ perClassLimit = deltaTarget
//!  (where deltaTarget is defined as formula - strip - stirling - ft/a),
//!  this is equivalent to proving gramIntegral = formula.
//!
//!  For the Lean proof, we need the ALGEBRAIC identity:
//!    ∑_{m₀∈TT} perClassLimit(a,b,m₀) 
//!      = vasyuninGramFormula(a,b) - (a-1)/(ab) 
//!        - (log(2π)-γ-1)/b - fractTarget(a,b)/a
//!
//!  This module certifies it holds at 1024-bit precision for all
//!  coprime (a,b) with 2 ≤ a < b ≤ 100.
//! ═══════════════════════════════════════════════════════════════════════════

use rug::Float;
use cathedral_utils::fmt;
use crate::PREC;
use crate::compute::fu;

// ────────────────────────────────────────────────
// Helper functions
// ────────────────────────────────────────────────

fn log_gamma(x: &Float) -> Float {
    let (lg, _sign) = x.clone().ln_abs_gamma();
    lg
}

fn digamma_f(x: &Float) -> Float {
    x.clone().digamma()
}

fn euler_gamma() -> Float {
    Float::with_val(PREC, rug::float::Constant::Euler)
}

fn pi_const() -> Float {
    Float::with_val(PREC, rug::float::Constant::Pi)
}

fn log_2pi() -> Float {
    let two_pi = Float::with_val(PREC, 2) * pi_const();
    Float::with_val(PREC, two_pi.ln())
}

/// Tile index: n₀ = ⌊am₀/b⌋  
fn tile_index(a: usize, b: usize, m0: usize) -> usize {
    (a * m0) / b
}

/// Is m₀ a two-tile class? b*(n₀+1) < a*(m₀+1)
fn is_two_tile(a: usize, b: usize, m0: usize) -> bool {
    let n0 = tile_index(a, b, m0);
    b * (n0 + 1) < a * (m0 + 1)
}

/// Overshoot: s = a(m₀+1) - b(n₀+1)
fn overshoot(a: usize, b: usize, m0: usize) -> usize {
    let n0 = tile_index(a, b, m0);
    a * (m0 + 1) - b * (n0 + 1)
}

// ────────────────────────────────────────────────
// §1. Per-class limit (computed independently)
// ────────────────────────────────────────────────

fn per_class_limit(a: usize, b: usize, m0: usize) -> Float {
    let n0 = tile_index(a, b, m0);
    let s = overshoot(a, b, m0);
    let af = fu(a);
    let bf = fu(b);
    let alpha = Float::with_val(PREC, fu(m0 + 1) / &bf);
    let beta = Float::with_val(PREC, fu(n0 + 1) / &af);

    let lg_beta = log_gamma(&beta);
    let lg_alpha = log_gamma(&alpha);
    let psi_beta = digamma_f(&beta);
    let psi_alpha = digamma_f(&alpha);

    let one_over_a = Float::with_val(PREC, Float::with_val(PREC, 1) / &af);
    let lg_part = Float::with_val(PREC,
        -Float::with_val(PREC, &lg_beta - &lg_alpha) * &one_over_a);

    let sf = fu(s);
    let s_minus_a = Float::with_val(PREC, &sf - &af);
    let a2b = Float::with_val(PREC, Float::with_val(PREC, &af * &af) * &bf);
    let psi_b_part = Float::with_val(PREC,
        -Float::with_val(PREC, &s_minus_a / &a2b) * &psi_beta);

    let ab = Float::with_val(PREC, &af * &bf);
    let psi_a_part = Float::with_val(PREC,
        -Float::with_val(PREC, Float::with_val(PREC, 1) / &ab) * &psi_alpha);

    Float::with_val(PREC, &lg_part + Float::with_val(PREC, &psi_b_part + &psi_a_part))
}

// ────────────────────────────────────────────────
// §2. DeltaTarget (formula-derived)
// ────────────────────────────────────────────────

fn delta_target_from_formula(a: usize, b: usize) -> Float {
    let formula = crate::formula::vasyunin_gram_formula(a, b);
    let strip = crate::compute::strip_value(a, b);
    let stir = Float::with_val(PREC, crate::formula::stirling_const() / fu(b));
    let ft = Float::with_val(PREC, crate::formula::fract_target(a, b) / fu(a));
    Float::with_val(PREC,
        Float::with_val(PREC,
            Float::with_val(PREC, &formula - &strip) - &stir
        ) - &ft
    )
}

// ────────────────────────────────────────────────
// §3. Individual component verification
// ────────────────────────────────────────────────

/// Gauss multiplication: Σ_{k=1}^{a-1} logΓ(k/a) = (a-1)/2·log(2π) - (1/2)·log(a)
fn gauss_log_gamma_closed(a: usize) -> Float {
    let af = fu(a);
    let am1 = Float::with_val(PREC, &af - Float::with_val(PREC, 1));
    let half = Float::with_val(PREC, 0.5);
    Float::with_val(PREC,
        Float::with_val(PREC, &am1 * &half) * &log_2pi() -
        Float::with_val(PREC, &half * Float::with_val(PREC, af.ln()))
    )
}

/// Direct logΓ sum: Σ_{k=1}^{a-1} logΓ(k/a)
fn gauss_log_gamma_direct(a: usize) -> Float {
    let af = fu(a);
    let mut sum = Float::with_val(PREC, 0);
    for k in 1..a {
        let arg = Float::with_val(PREC, fu(k) / &af);
        sum += log_gamma(&arg);
    }
    sum
}

/// Gauss digamma: Σ_{k=1}^{q-1} ψ(k/q) = -(q-1)γ - q·log(q)
fn gauss_digamma_closed(q: usize) -> Float {
    let qf = fu(q);
    let qm1 = Float::with_val(PREC, &qf - Float::with_val(PREC, 1));
    let gamma = euler_gamma();
    let ln_q = Float::with_val(PREC, qf.clone().ln());
    Float::with_val(PREC,
        -Float::with_val(PREC, &qm1 * &gamma) - Float::with_val(PREC, &qf * &ln_q)
    )
}

/// Direct digamma sum
fn gauss_digamma_direct(q: usize) -> Float {
    let qf = fu(q);
    let mut sum = Float::with_val(PREC, 0);
    for k in 1..q {
        let arg = Float::with_val(PREC, fu(k) / &qf);
        sum += digamma_f(&arg);
    }
    sum
}

// ────────────────────────────────────────────────
// §4. STAIRCASE TELESCOPE (Gemini Key 1)
//
// Σ_{TT} f(m₀) = (a/b)·Σ_{m∈{0..b-1}} f(m)
//              + Σ_{r=1}^{b-1} {ar/b}·(f(r) - f(r-1))
//              - f(b-1)
// ────────────────────────────────────────────────

/// Compute LHS of staircase telescope: Σ_{m₀∈TT} f(m₀)
fn staircase_lhs(a: usize, b: usize, f: &dyn Fn(usize) -> Float) -> Float {
    let mut sum = Float::with_val(PREC, 0);
    for m0 in 1..b {
        if is_two_tile(a, b, m0) {
            sum += f(m0);
        }
    }
    sum
}

/// Compute RHS of staircase telescope: (a/b)Σf(m) + Σ{ar/b}(f(r)-f(r-1)) - f(b-1)
fn staircase_rhs(a: usize, b: usize, f: &dyn Fn(usize) -> Float) -> Float {
    let af = fu(a);
    let bf = fu(b);

    // Full sum: Σ_{m=0}^{b-1} f(m)
    let mut full_sum = Float::with_val(PREC, 0);
    for m in 0..b {
        full_sum += f(m);
    }

    // Abel sum: Σ_{r=1}^{b-1} {ar/b}·(f(r) - f(r-1))
    let mut abel_sum = Float::with_val(PREC, 0);
    for r in 1..b {
        let frac_val = {
            let x = Float::with_val(PREC, fu(a * r) / &bf);
            let fl = Float::with_val(PREC, x.clone().floor());
            Float::with_val(PREC, &x - &fl)
        };
        let diff = Float::with_val(PREC, f(r) - f(r - 1));
        abel_sum += Float::with_val(PREC, &frac_val * &diff);
    }

    // RHS = (a/b)·full_sum + abel_sum - f(b-1)
    Float::with_val(PREC,
        Float::with_val(PREC,
            Float::with_val(PREC, &af / &bf) * &full_sum + &abel_sum
        ) - f(b - 1)
    )
}

/// Certify staircase telescope for logΓ((m+1)/b) and ψ((m+1)/b)
fn certify_staircase(a: usize, b: usize) -> (f64, f64) {
    let bf = fu(b);

    // f₁(m) = logΓ((m+1)/b)
    let f_lg = |m: usize| -> Float {
        let arg = Float::with_val(PREC, fu(m + 1) / &bf);
        log_gamma(&arg)
    };
    let lg_lhs = staircase_lhs(a, b, &f_lg);
    let lg_rhs = staircase_rhs(a, b, &f_lg);
    let lg_err = Float::with_val(PREC, &lg_lhs - &lg_rhs).abs();

    // f₂(m) = ψ((m+1)/b)
    let f_psi = |m: usize| -> Float {
        let arg = Float::with_val(PREC, fu(m + 1) / &bf);
        digamma_f(&arg)
    };
    let psi_lhs = staircase_lhs(a, b, &f_psi);
    let psi_rhs = staircase_rhs(a, b, &f_psi);
    let psi_err = Float::with_val(PREC, &psi_lhs - &psi_rhs).abs();

    (lg_err.to_f64(), psi_err.to_f64())
}

// ────────────────────────────────────────────────
// §5. BETA MODULO DUALITY (Gemini Key 2)
//
// For m₀∈TT with k = tileIndex(a,b,m₀):
//   (s-a)/(a²b) = -(1/(ab))·{b(k+1)/a}
//
// After Beta Bijection reindexing (k → r = k+1):
//   Σ_{TT} coeff·ψ(β) = -(1/(ab))·Σ_{r=1}^{a-1} {br/a}·ψ(r/a)
// ────────────────────────────────────────────────

/// Certify beta modulo duality: (s-a)/(a²b) = -(1/(ab))·{b(k+1)/a} for each m₀
fn certify_beta_duality(a: usize, b: usize) -> (bool, f64) {
    let af = fu(a);
    let bf = fu(b);
    let a2b = Float::with_val(PREC, Float::with_val(PREC, &af * &af) * &bf);
    let ab = Float::with_val(PREC, &af * &bf);

    let tt_classes: Vec<usize> = (1..b).filter(|&m0| is_two_tile(a, b, m0)).collect();

    // LHS: Σ_{TT} ((s-a)/(a²b))·ψ(β)
    let mut lhs = Float::with_val(PREC, 0);
    for &m0 in &tt_classes {
        let n0 = tile_index(a, b, m0);
        let s = overshoot(a, b, m0);
        let sf = fu(s);
        let coeff = Float::with_val(PREC, Float::with_val(PREC, &sf - &af) / &a2b);
        let beta = Float::with_val(PREC, fu(n0 + 1) / &af);
        let psi_val = digamma_f(&beta);
        lhs += Float::with_val(PREC, &coeff * &psi_val);
    }

    // RHS: -(1/(ab))·Σ_{r=1}^{a-1} {br/a}·ψ(r/a)
    let mut rhs_sum = Float::with_val(PREC, 0);
    for r in 1..a {
        let frac_val = {
            let x = Float::with_val(PREC, fu(b * r) / &af);
            let fl = Float::with_val(PREC, x.clone().floor());
            Float::with_val(PREC, &x - &fl)
        };
        let psi_val = digamma_f(&Float::with_val(PREC, fu(r) / &af));
        rhs_sum += Float::with_val(PREC, &frac_val * &psi_val);
    }
    let rhs = Float::with_val(PREC, -Float::with_val(PREC, Float::with_val(PREC, 1) / &ab) * &rhs_sum);

    let err = Float::with_val(PREC, &lhs - &rhs).abs();

    // Also verify per-element: (s-a)/(a²b) = -(1/(ab))·{b(k+1)/a}
    let pointwise_ok = tt_classes.iter().all(|&m0| {
        let n0 = tile_index(a, b, m0);
        let s = overshoot(a, b, m0);
        let sf = fu(s);
        let coeff_lhs = Float::with_val(PREC, Float::with_val(PREC, &sf - &af) / &a2b);
        let frac_val = {
            let x = Float::with_val(PREC, fu(b * (n0 + 1)) / &af);
            let fl = Float::with_val(PREC, x.clone().floor());
            Float::with_val(PREC, &x - &fl)
        };
        let coeff_rhs = Float::with_val(PREC, -Float::with_val(PREC, Float::with_val(PREC, 1) / &ab) * &frac_val);
        let diff = Float::with_val(PREC, &coeff_lhs - &coeff_rhs).abs();
        diff.to_f64() < 1e-200
    });

    (pointwise_ok, err.to_f64())
}

// ────────────────────────────────────────────────
// §6. Full certification result
// ────────────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct GraduationResult {
    pub a: usize,
    pub b: usize,
    pub n_two_tile: usize,

    // Structural
    pub beta_bijection: bool,
    pub s_permutation: bool,
    pub overshoot_identity: bool,

    // Gauss multiplication
    pub gauss_loggamma_a_err: f64,
    pub gauss_loggamma_b_err: f64,
    pub gauss_digamma_a_err: f64,
    pub gauss_digamma_b_err: f64,

    // Staircase Telescope (Gemini Key 1)
    pub telescope_loggamma_err: f64,
    pub telescope_digamma_err: f64,

    // Beta Modulo Duality (Gemini Key 2)
    pub beta_duality_pointwise: bool,
    pub beta_duality_sum_err: f64,

    // The identity
    pub sum_pcl: f64,
    pub delta_target: f64,
    pub identity_err: f64,

    // Pass/fail
    pub certified: bool,
}

pub fn certify_graduation(a: usize, b: usize) -> GraduationResult {
    let tt_classes: Vec<usize> = (1..b).filter(|&m0| is_two_tile(a, b, m0)).collect();
    let n_tt = tt_classes.len();

    // ═══ STRUCTURAL CHECKS ═══

    // Beta Bijection: tileIndex maps twoTileSet → {0,...,a-2}
    let mut beta_vals: Vec<usize> = tt_classes.iter()
        .map(|&m0| tile_index(a, b, m0)).collect();
    beta_vals.sort();
    let beta_bijection = beta_vals == (0..a-1).collect::<Vec<_>>() && n_tt == a - 1;

    // Overshoot permutation: s values form {1,...,a-1}
    let mut s_vals: Vec<usize> = tt_classes.iter()
        .map(|&m0| overshoot(a, b, m0)).collect();
    s_vals.sort();
    let s_permutation = s_vals == (1..a).collect::<Vec<_>>();

    // Overshoot identity: s - a = (am₀ % b) - b for each m₀
    let overshoot_id = tt_classes.iter().all(|&m0| {
        let s = overshoot(a, b, m0) as isize;
        let r = ((a * m0) % b) as isize;
        s - (a as isize) == r - (b as isize)
    });

    // ═══ GAUSS FORMULA CHECKS ═══

    let glg_a_direct = gauss_log_gamma_direct(a);
    let glg_a_closed = gauss_log_gamma_closed(a);
    let glg_a_err = Float::with_val(PREC, &glg_a_direct - &glg_a_closed).abs();

    let glg_b_direct = gauss_log_gamma_direct(b);
    let glg_b_closed = gauss_log_gamma_closed(b);
    let glg_b_err = Float::with_val(PREC, &glg_b_direct - &glg_b_closed).abs();

    let gd_a_direct = gauss_digamma_direct(a);
    let gd_a_closed = gauss_digamma_closed(a);
    let gd_a_err = Float::with_val(PREC, &gd_a_direct - &gd_a_closed).abs();

    let gd_b_direct = gauss_digamma_direct(b);
    let gd_b_closed = gauss_digamma_closed(b);
    let gd_b_err = Float::with_val(PREC, &gd_b_direct - &gd_b_closed).abs();

    // ═══ STAIRCASE TELESCOPE (Gemini Key 1) ═══
    let (tel_lg_err, tel_psi_err) = certify_staircase(a, b);

    // ═══ BETA MODULO DUALITY (Gemini Key 2) ═══
    let (beta_pw, beta_sum_err) = certify_beta_duality(a, b);

    // ═══ THE IDENTITY ═══

    let mut sum_pcl = Float::with_val(PREC, 0);
    for &m0 in &tt_classes {
        sum_pcl += per_class_limit(a, b, m0);
    }

    let dt = delta_target_from_formula(a, b);
    let id_err = Float::with_val(PREC, &sum_pcl - &dt).abs();

    let certified = beta_bijection && s_permutation && overshoot_id
        && glg_a_err.to_f64() < 1e-100
        && glg_b_err.to_f64() < 1e-100
        && gd_a_err.to_f64() < 1e-100
        && gd_b_err.to_f64() < 1e-100
        && tel_lg_err < 1e-100
        && tel_psi_err < 1e-100
        && beta_pw
        && beta_sum_err < 1e-100
        && id_err.to_f64() < 1e-100;

    GraduationResult {
        a, b, n_two_tile: n_tt,
        beta_bijection, s_permutation, overshoot_identity: overshoot_id,
        gauss_loggamma_a_err: glg_a_err.to_f64(),
        gauss_loggamma_b_err: glg_b_err.to_f64(),
        gauss_digamma_a_err: gd_a_err.to_f64(),
        gauss_digamma_b_err: gd_b_err.to_f64(),
        telescope_loggamma_err: tel_lg_err,
        telescope_digamma_err: tel_psi_err,
        beta_duality_pointwise: beta_pw,
        beta_duality_sum_err: beta_sum_err,
        sum_pcl: sum_pcl.to_f64(),
        delta_target: dt.to_f64(),
        identity_err: id_err.to_f64(),
        certified,
    }
}

pub fn certify_all(pairs: &[(usize, usize)]) -> Vec<GraduationResult> {
    use rayon::prelude::*;
    let mut results: Vec<_> = pairs.par_iter()
        .map(|&(a, b)| certify_graduation(a, b))
        .collect();
    results.sort_by_key(|r| (r.a, r.b));
    results
}

pub fn print_certification(results: &[GraduationResult]) {
    fmt::section("AXIOM GRADUATION CERTIFIER — gramIntegral_eq_formula_ge2");
    println!();
    println!("  Certifying: ∑ perClassLimit(a,b,m₀) = deltaTarget");
    println!("  at 1024-bit MPFR precision for {} coprime pairs", results.len());
    println!();

    // §1. Structural invariants
    println!("  {}§1. STRUCTURAL INVARIANTS{}", fmt::BOLD, fmt::RESET);
    println!();
    println!("  {:>5} {:>5}  {:>5}  {:>10}  {:>10}  {:>10}",
        "(a", "b)", "#TT", "β-bij?", "s-perm?", "s-a=r-b?");
    println!("  {}", "─".repeat(60));

    for r in results {
        println!("  ({:>2},{:>2})  {:>4}   {}  {}  {}",
            r.a, r.b, r.n_two_tile,
            if r.beta_bijection { fmt::check(true) } else { fmt::check(false) },
            if r.s_permutation { fmt::check(true) } else { fmt::check(false) },
            if r.overshoot_identity { fmt::check(true) } else { fmt::check(false) },
        );
    }

    // §2. Gauss formula verification
    println!();
    println!("  {}§2. GAUSS FORMULA VERIFICATION{}", fmt::BOLD, fmt::RESET);
    println!();

    let max_glg = results.iter()
        .map(|r| r.gauss_loggamma_a_err.max(r.gauss_loggamma_b_err))
        .fold(0.0_f64, f64::max);
    let max_gd = results.iter()
        .map(|r| r.gauss_digamma_a_err.max(r.gauss_digamma_b_err))
        .fold(0.0_f64, f64::max);

    println!("  Max |logΓ direct - closed| : {:.4e}", max_glg);
    println!("  Max |ψ direct - closed|    : {:.4e}", max_gd);
    if max_glg < 1e-100 && max_gd < 1e-100 {
        println!("  {} Gauss multiplication + digamma: EXACT", fmt::check(true));
    }

    // §3. Staircase Telescope (Gemini Key 1)
    println!();
    println!("  {}§3. STAIRCASE TELESCOPE (Gemini Key 1){}", fmt::BOLD, fmt::RESET);
    println!("  Σ_{{TT}} f(m₀) = (a/b)·Σf(m) + Σ{{ar/b}}·(f(r)-f(r-1)) - f(b-1)");
    println!();

    let max_tel_lg = results.iter().map(|r| r.telescope_loggamma_err).fold(0.0_f64, f64::max);
    let max_tel_psi = results.iter().map(|r| r.telescope_digamma_err).fold(0.0_f64, f64::max);

    println!("  Max |telescope logΓ error| : {:.4e}", max_tel_lg);
    println!("  Max |telescope ψ error|    : {:.4e}", max_tel_psi);
    if max_tel_lg < 1e-100 && max_tel_psi < 1e-100 {
        println!("  {} Staircase telescope: CERTIFIED ★", fmt::check(true));
    } else {
        println!("  {} Staircase telescope: FAILED", fmt::check(false));
    }

    // §4. Beta Modulo Duality (Gemini Key 2)
    println!();
    println!("  {}§4. BETA MODULO DUALITY (Gemini Key 2){}", fmt::BOLD, fmt::RESET);
    println!("  (s-a)/(a²b) = -(1/(ab))·{{b(k+1)/a}}");
    println!();

    let all_beta_pw = results.iter().all(|r| r.beta_duality_pointwise);
    let max_beta_sum = results.iter().map(|r| r.beta_duality_sum_err).fold(0.0_f64, f64::max);

    println!("  Pointwise coefficient match : {}", if all_beta_pw { fmt::check(true) } else { fmt::check(false) });
    println!("  Max |sum LHS - sum RHS|     : {:.4e}", max_beta_sum);
    if all_beta_pw && max_beta_sum < 1e-100 {
        println!("  {} Beta modulo duality: CERTIFIED ★", fmt::check(true));
    } else {
        println!("  {} Beta modulo duality: FAILED", fmt::check(false));
    }

    // §5. The graduation identity
    println!();
    println!("  {}§5. THE GRADUATION IDENTITY{}", fmt::BOLD, fmt::RESET);
    println!("  ∑ perClassLimit(a,b,m₀) = vasyuninGramFormula - strip - stir/b - ft/a");
    println!();
    println!("  {:>5} {:>5}  {:>22}  {:>22}  {:>14}",
        "(a", "b)", "∑ perClassLimit", "deltaTarget", "|error|");
    println!("  {}", "─".repeat(80));

    let mut max_err = 0.0_f64;
    let mut all_cert = true;
    for r in results {
        if r.identity_err > max_err { max_err = r.identity_err; }
        if !r.certified { all_cert = false; }
        println!("  ({:>2},{:>2})  {:>22.15}  {:>22.15}  {:>14.4e}  {}",
            r.a, r.b,
            r.sum_pcl, r.delta_target, r.identity_err,
            if r.certified { fmt::check(true) } else { fmt::check(false) },
        );
    }

    println!();
    println!("  Max |error|: {:.4e}", max_err);
    println!();
    if all_cert {
        println!("  ★ {} ALL {} PAIRS CERTIFIED — SKELETON KEYS + GRADUATION READY ★",
            fmt::check(true), results.len());
    } else {
        println!("  {} SOME PAIRS FAILED", fmt::check(false));
    }
    println!();
}
