//! ═══════════════════════════════════════════════════════════════════════════
//!  CPU MODULE — Full certification using rayon parallelism
//!
//!  Mirrors the CPU two-tile-decomposition axiom_graduation module
//!  at f64 precision. Includes ALL certification checks:
//!    §1. Structural invariants (beta bijection, s permutation, overshoot)
//!    §2. Gauss formula verification (logΓ and ψ sums vs closed forms)
//!    §3. Staircase telescope (Gemini Key 1)
//!    §4. Beta modulo duality (Gemini Key 2)
//!    §5. Graduation identity (Σ perClassLimit = deltaTarget)
//! ═══════════════════════════════════════════════════════════════════════════

use std::ffi::c_int;
use rayon::prelude::*;

use crate::gpu::PairResult;

// ────────────────────────────────────────────────
// Helper functions
// ────────────────────────────────────────────────

fn frac_part(x: f64) -> f64 { x - x.floor() }

/// Digamma via asymptotic expansion + recurrence (matches CUDA kernel)
fn digamma_cpu(mut x: f64) -> f64 {
    if x <= 0.0 { return f64::NAN; }
    let mut result = 0.0;
    while x < 10.0 {
        result -= 1.0 / x;
        x += 1.0;
    }
    let inv_x = 1.0 / x;
    let inv_x2 = inv_x * inv_x;
    result += x.ln() - 0.5 * inv_x;
    let mut x2k = inv_x2;
    result -= x2k / 12.0;
    x2k *= inv_x2;
    result += x2k / 120.0;
    x2k *= inv_x2;
    result -= x2k / 252.0;
    x2k *= inv_x2;
    result += x2k / 240.0;
    x2k *= inv_x2;
    result -= x2k * 5.0 / 660.0;
    result
}

fn tile_index(a: usize, b: usize, m0: usize) -> usize { (a * m0) / b }

fn is_two_tile(a: usize, b: usize, m0: usize) -> bool {
    let n0 = tile_index(a, b, m0);
    b * (n0 + 1) < a * (m0 + 1)
}

fn overshoot(a: usize, b: usize, m0: usize) -> usize {
    let n0 = tile_index(a, b, m0);
    a * (m0 + 1) - b * (n0 + 1)
}

const EULER_GAMMA: f64 = 0.57721566490153286_f64;

// ────────────────────────────────────────────────
// Full certification per pair
// ────────────────────────────────────────────────

fn certify_pair_cpu(a: usize, b: usize) -> PairResult {
    let af = a as f64;
    let bf = b as f64;
    let pi = std::f64::consts::PI;
    let log_2pi = (2.0 * pi).ln();

    let tt_classes: Vec<usize> = (1..b).filter(|&m0| is_two_tile(a, b, m0)).collect();
    let n_tt = tt_classes.len();

    // ═══════════════════════════════════════════════════
    // §1. STRUCTURAL INVARIANTS
    // ═══════════════════════════════════════════════════

    // Beta Bijection: tileIndex maps twoTileSet → {0,...,a-2} bijectively
    let mut beta_vals: Vec<usize> = tt_classes.iter()
        .map(|&m0| tile_index(a, b, m0)).collect();
    beta_vals.sort();
    let expected_betas: Vec<usize> = (0..a-1).collect();
    let beta_bijection = beta_vals == expected_betas && n_tt == a - 1;

    // S Permutation: overshoot values form {1,...,a-1}
    let mut s_vals: Vec<usize> = tt_classes.iter()
        .map(|&m0| overshoot(a, b, m0)).collect();
    s_vals.sort();
    let expected_s: Vec<usize> = (1..a).collect();
    let s_permutation = s_vals == expected_s;

    // Overshoot identity: s - a ≡ (am₀ mod b) - b for each m₀
    let overshoot_id = tt_classes.iter().all(|&m0| {
        let s = overshoot(a, b, m0) as isize;
        let r = ((a * m0) % b) as isize;
        s - (a as isize) == r - (b as isize)
    });

    // ═══════════════════════════════════════════════════
    // §2. GAUSS FORMULA VERIFICATION
    // ═══════════════════════════════════════════════════

    // logΓ for a-grid: Σ_{k=1}^{a-1} logΓ(k/a) vs (a-1)/2·log(2π) - (1/2)·log(a)
    let gauss_lg_a_direct: f64 = (1..a).map(|k| libm::lgamma(k as f64 / af)).sum();
    let gauss_lg_a_closed = (af - 1.0) / 2.0 * log_2pi - 0.5 * af.ln();
    let gauss_lg_a_err = (gauss_lg_a_direct - gauss_lg_a_closed).abs();

    // logΓ for b-grid
    let gauss_lg_b_direct: f64 = (1..b).map(|k| libm::lgamma(k as f64 / bf)).sum();
    let gauss_lg_b_closed = (bf - 1.0) / 2.0 * log_2pi - 0.5 * bf.ln();
    let gauss_lg_b_err = (gauss_lg_b_direct - gauss_lg_b_closed).abs();

    // Digamma for a-grid: Σ_{k=1}^{a-1} ψ(k/a) vs -(a-1)γ - a·log(a)
    let gauss_d_a_direct: f64 = (1..a).map(|k| digamma_cpu(k as f64 / af)).sum();
    let gauss_d_a_closed = -(af - 1.0) * EULER_GAMMA - af * af.ln();
    let gauss_d_a_err = (gauss_d_a_direct - gauss_d_a_closed).abs();

    // Digamma for b-grid
    let gauss_d_b_direct: f64 = (1..b).map(|k| digamma_cpu(k as f64 / bf)).sum();
    let gauss_d_b_closed = -(bf - 1.0) * EULER_GAMMA - bf * bf.ln();
    let gauss_d_b_err = (gauss_d_b_direct - gauss_d_b_closed).abs();

    // ═══════════════════════════════════════════════════
    // §3. STAIRCASE TELESCOPE (Gemini Key 1)
    // ═══════════════════════════════════════════════════
    let f_lg = |m: usize| -> f64 { libm::lgamma(((m + 1) as f64) / bf) };
    let f_psi = |m: usize| -> f64 { digamma_cpu(((m + 1) as f64) / bf) };

    let tt_lg: f64 = tt_classes.iter().map(|&m0| f_lg(m0)).sum();
    let tt_psi: f64 = tt_classes.iter().map(|&m0| f_psi(m0)).sum();

    let full_lg: f64 = (0..b).map(|m| f_lg(m)).sum();
    let full_psi: f64 = (0..b).map(|m| f_psi(m)).sum();

    let abel_lg: f64 = (1..b).map(|r| {
        frac_part(af * r as f64 / bf) * (f_lg(r) - f_lg(r - 1))
    }).sum();
    let abel_psi: f64 = (1..b).map(|r| {
        frac_part(af * r as f64 / bf) * (f_psi(r) - f_psi(r - 1))
    }).sum();

    let rhs_lg = (af / bf) * full_lg + abel_lg - f_lg(b - 1);
    let rhs_psi = (af / bf) * full_psi + abel_psi - f_psi(b - 1);

    let tel_lg_err = (tt_lg - rhs_lg).abs();
    let tel_psi_err = (tt_psi - rhs_psi).abs();

    // ═══════════════════════════════════════════════════
    // §4. BETA MODULO DUALITY (Gemini Key 2)
    // ═══════════════════════════════════════════════════
    let beta_lhs: f64 = tt_classes.iter().map(|&m0| {
        let n0 = tile_index(a, b, m0);
        let s = overshoot(a, b, m0);
        let coeff = (s as f64 - af) / (af * af * bf);
        coeff * digamma_cpu((n0 + 1) as f64 / af)
    }).sum();

    let beta_rhs_sum: f64 = (1..a).map(|r| {
        frac_part(bf * r as f64 / af) * digamma_cpu(r as f64 / af)
    }).sum();
    let beta_rhs = -(1.0 / (af * bf)) * beta_rhs_sum;

    let beta_pw = tt_classes.iter().all(|&m0| {
        let n0 = tile_index(a, b, m0);
        let s = overshoot(a, b, m0);
        let coeff_l = (s as f64 - af) / (af * af * bf);
        let fv = frac_part(bf * (n0 + 1) as f64 / af);
        let coeff_r = -(1.0 / (af * bf)) * fv;
        (coeff_l - coeff_r).abs() < 1e-10
    });

    // ═══════════════════════════════════════════════════
    // §5. GRADUATION IDENTITY
    // ═══════════════════════════════════════════════════
    let sum_pcl: f64 = tt_classes.iter().map(|&m0| {
        let n0 = tile_index(a, b, m0);
        let s = overshoot(a, b, m0);
        let alpha = (m0 + 1) as f64 / bf;
        let beta = (n0 + 1) as f64 / af;
        -(1.0 / af) * (libm::lgamma(beta) - libm::lgamma(alpha))
            - ((s as f64 - af) / (af * af * bf)) * digamma_cpu(beta)
            - (1.0 / (af * bf)) * digamma_cpu(alpha)
    }).sum();

    // vasyuninGramFormula
    let vab: f64 = (1..b).map(|m| {
        frac_part(af * m as f64 / bf) * (pi * m as f64 / bf).cos()
            / (pi * m as f64 / bf).sin()
    }).sum();
    let vba: f64 = (1..a).map(|m| {
        frac_part(bf * m as f64 / af) * (pi * m as f64 / af).cos()
            / (pi * m as f64 / af).sin()
    }).sum();

    let formula = (log_2pi - EULER_GAMMA) / 2.0 * (1.0/af + 1.0/bf)
        + (af - bf) / (2.0*af*bf) * (bf / af).ln()
        - pi / (2.0*af*bf) * (vab + vba)
        - 1.0 / (af*bf);

    let ft: f64 = (1..b).map(|r| {
        let fv = frac_part(af * r as f64 / bf);
        let lg_r = libm::lgamma(r as f64 / bf);
        let lg_rp1 = libm::lgamma((r + 1) as f64 / bf);
        let psi_rp1 = digamma_cpu((r + 1) as f64 / bf);
        fv * (lg_r - lg_rp1 + (1.0 / bf) * psi_rp1)
    }).sum();

    let strip = (af - 1.0) / (af * bf);
    let stir = (1.0 / bf) * (log_2pi - EULER_GAMMA - 1.0);
    let dt = formula - strip - stir - ft / af;

    let id_err = (sum_pcl - dt).abs();

    // ═══════════════════════════════════════════════════
    // §6. ABEL CANCELLATION (NEW — May 5, 2026)
    // ═══════════════════════════════════════════════════
    // KEY INSIGHT: S₁ + (1/a)·FT = (1/b)·GaussB + (1/(ab))·Σ{ar/b}·ψ((r+1)/b)
    //
    // S₁ = (1/a) · Σ_{TT} logΓ((m₀+1)/b)
    //    = (1/a) · [(a/b)·FullLogΓ + AbelLogΓ - logΓ(1)]
    //    = (1/b)·FullLogΓ + (1/a)·AbelLogΓ    (since logΓ(1)=0)
    //
    // (1/a)·FT = (1/a)·Σ {ar/b}·[logΓ(r/b) - logΓ((r+1)/b) + (1/b)·ψ((r+1)/b)]
    //          = -(1/a)·AbelLogΓ + (1/(ab))·Σ {ar/b}·ψ((r+1)/b)
    //
    // Sum: AbelLogΓ cancels! Leaving:
    //   S₁ + (1/a)·FT = (1/b)·GaussB + (1/(ab))·Σ{ar/b}·ψ((r+1)/b)
    let s1 = (1.0 / af) * tt_lg;  // (1/a) · Σ_{TT} logΓ(α)
    let frac_psi_r1: f64 = (1..b).map(|r| {
        frac_part(af * r as f64 / bf) * digamma_cpu((r + 1) as f64 / bf)
    }).sum();
    let abel_lhs = s1 + ft / af;
    let abel_rhs = gauss_lg_b_closed / bf + frac_psi_r1 / (af * bf);
    let abel_cancel_err = (abel_lhs - abel_rhs).abs();

    // ═══════════════════════════════════════════════════
    // §7. WEIGHTED DIGAMMA REFLECTION (NEW — May 5, 2026)
    // ═══════════════════════════════════════════════════
    // Σ_{r=1}^{b-1} {ar/b}·ψ(r/b) = (1/2)·(Σψ(r/b) - π·V(b,a))
    let wdr_lhs: f64 = (1..b).map(|r| {
        frac_part(af * r as f64 / bf) * digamma_cpu(r as f64 / bf)
    }).sum();
    let sum_psi_icc: f64 = (1..b).map(|r| digamma_cpu(r as f64 / bf)).sum();
    let wdr_rhs = 0.5 * (sum_psi_icc - pi * vab);
    let wdr_err = (wdr_lhs - wdr_rhs).abs();

    // ═══════════════════════════════════════════════════
    // §8. COPRIME COMPLEMENT IDENTITY (NEW — May 5, 2026)
    // ═══════════════════════════════════════════════════
    // {a(b-r)/b} = 1 - {ar/b} for gcd(a,b)=1, 1 ≤ r ≤ b-1
    let coprime_comp = (1..b).all(|r| {
        let lhs = frac_part(af * (b - r) as f64 / bf);
        let rhs = 1.0 - frac_part(af * r as f64 / bf);
        (lhs - rhs).abs() < 1e-12
    });

    // ═══════════════════════════════════════════════════
    // §9. FOUR-WAY ASSEMBLY (NEW — May 5, 2026)
    // ═══════════════════════════════════════════════════
    // Evaluate S₁, S₂, S₃, S₄ through their individual evaluation chains:
    //   S₁: staircase(logΓ) → (a/b)·GaussB + AbelLogΓ
    //   S₂: β-reindex → Gauss_A closed form
    //   S₃: beta duality → (1/(ab))·Σ{br/a}·ψ(r/a)
    //   S₄: staircase(ψ) → (a/b)·ΣψB + AbelΨ + γ
    // Then check: S₁ + S₂ + S₃ + S₄ = dt (deltaTarget)

    // S₁ evaluated via staircase
    let s1_eval = (1.0 / af) * ((af / bf) * full_lg + abel_lg - f_lg(b - 1));

    // S₂ evaluated via β-reindex + Gauss_A
    let s2_eval = -(1.0 / af) * gauss_lg_a_direct;

    // S₃ evaluated via beta duality
    let s3_eval = -beta_lhs;  // beta_lhs = Σ (s-a)/(a²b)·ψ(β) from §4

    // S₄ evaluated via staircase
    let s4_eval = -(1.0 / (af * bf)) * ((af / bf) * full_psi + abel_psi - f_psi(b - 1));

    let fourway_sum = s1_eval + s2_eval + s3_eval + s4_eval;
    let fourway_err = (fourway_sum - dt).abs();

    // ═══ CERTIFICATION ═══
    let certified = beta_bijection && s_permutation && overshoot_id
        && gauss_lg_a_err < 1e-8 && gauss_lg_b_err < 1e-8
        && gauss_d_a_err < 1e-8 && gauss_d_b_err < 1e-8
        && tel_lg_err < 1e-8 && tel_psi_err < 1e-8
        && beta_pw && (beta_lhs - beta_rhs).abs() < 1e-8
        && id_err < 1e-8
        && abel_cancel_err < 1e-8
        && wdr_err < 1e-8
        && coprime_comp
        && fourway_err < 1e-8;

    PairResult {
        a: a as c_int, b: b as c_int,
        n_two_tile: n_tt as c_int,
        beta_bijection: if beta_bijection { 1 } else { 0 },
        s_permutation: if s_permutation { 1 } else { 0 },
        overshoot_identity: if overshoot_id { 1 } else { 0 },
        gauss_loggamma_a_err: gauss_lg_a_err,
        gauss_loggamma_b_err: gauss_lg_b_err,
        gauss_digamma_a_err: gauss_d_a_err,
        gauss_digamma_b_err: gauss_d_b_err,
        telescope_lg_err: tel_lg_err,
        telescope_psi_err: tel_psi_err,
        beta_duality_pw: if beta_pw { 1 } else { 0 },
        beta_duality_sum_err: (beta_lhs - beta_rhs).abs(),
        sum_pcl, delta_target: dt, identity_err: id_err,
        abel_cancel_err,
        wdr_err,
        coprime_complement_ok: if coprime_comp { 1 } else { 0 },
        fourway_err,
        certified: if certified { 1 } else { 0 },
    }
}

/// CPU certification of all pairs using rayon parallelism.
pub fn cpu_certify(pairs: &[(usize, usize)]) -> Vec<PairResult> {
    pairs.par_iter()
        .map(|&(a, b)| certify_pair_cpu(a, b))
        .collect()
}
