//! ═══════════════════════════════════════════════════════════════════════════
//!  CPU MODULE — Fallback certification using rayon parallelism
//!
//!  Mirrors the GPU kernel logic using f64 CPU arithmetic.
//!  Uses rayon for pair-level parallelism.
//! ═══════════════════════════════════════════════════════════════════════════

use std::ffi::c_int;
use rayon::prelude::*;

use crate::gpu::PairResult;

fn frac_part(x: f64) -> f64 { x - x.floor() }

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

fn certify_pair_cpu(a: usize, b: usize) -> PairResult {
    let af = a as f64;
    let bf = b as f64;

    let tt_classes: Vec<usize> = (1..b).filter(|&m0| is_two_tile(a, b, m0)).collect();
    let n_tt = tt_classes.len();

    // ═══ STAIRCASE TELESCOPE ═══
    let f_lg = |m: usize| -> f64 { libm::lgamma(((m + 1) as f64) / bf) };
    let f_psi = |m: usize| -> f64 { digamma_cpu(((m + 1) as f64) / bf) };

    let tt_lg: f64 = tt_classes.iter().map(|&m0| f_lg(m0)).sum();
    let tt_psi: f64 = tt_classes.iter().map(|&m0| f_psi(m0)).sum();

    let full_lg: f64 = (0..b).map(|m| f_lg(m)).sum();
    let full_psi: f64 = (0..b).map(|m| f_psi(m)).sum();

    let abel_lg: f64 = (1..b).map(|r| {
        let fv = frac_part(af * r as f64 / bf);
        fv * (f_lg(r) - f_lg(r - 1))
    }).sum();
    let abel_psi: f64 = (1..b).map(|r| {
        let fv = frac_part(af * r as f64 / bf);
        fv * (f_psi(r) - f_psi(r - 1))
    }).sum();

    let rhs_lg = (af / bf) * full_lg + abel_lg - f_lg(b - 1);
    let rhs_psi = (af / bf) * full_psi + abel_psi - f_psi(b - 1);

    let tel_lg_err = (tt_lg - rhs_lg).abs();
    let tel_psi_err = (tt_psi - rhs_psi).abs();

    // ═══ BETA DUALITY ═══
    let beta_lhs: f64 = tt_classes.iter().map(|&m0| {
        let n0 = tile_index(a, b, m0);
        let s = a * (m0 + 1) - b * (n0 + 1);
        let coeff = (s as f64 - af) / (af * af * bf);
        coeff * digamma_cpu((n0 + 1) as f64 / af)
    }).sum();

    let beta_rhs_sum: f64 = (1..a).map(|r| {
        let fv = frac_part(bf * r as f64 / af);
        fv * digamma_cpu(r as f64 / af)
    }).sum();
    let beta_rhs = -(1.0 / (af * bf)) * beta_rhs_sum;

    let beta_pw = tt_classes.iter().all(|&m0| {
        let n0 = tile_index(a, b, m0);
        let s = a * (m0 + 1) - b * (n0 + 1);
        let coeff_l = (s as f64 - af) / (af * af * bf);
        let fv = frac_part(bf * (n0 + 1) as f64 / af);
        let coeff_r = -(1.0 / (af * bf)) * fv;
        (coeff_l - coeff_r).abs() < 1e-10
    });

    // ═══ GRADUATION IDENTITY ═══
    let sum_pcl: f64 = tt_classes.iter().map(|&m0| {
        let n0 = tile_index(a, b, m0);
        let s = a * (m0 + 1) - b * (n0 + 1);
        let alpha = (m0 + 1) as f64 / bf;
        let beta = (n0 + 1) as f64 / af;
        -(1.0 / af) * (libm::lgamma(beta) - libm::lgamma(alpha))
            - ((s as f64 - af) / (af * af * bf)) * digamma_cpu(beta)
            - (1.0 / (af * bf)) * digamma_cpu(alpha)
    }).sum();

    // vasyuninGramFormula
    let gamma_c = 0.57721566490153286_f64;
    let log_2pi = (2.0 * std::f64::consts::PI).ln();

    let vab: f64 = (1..b).map(|m| {
        frac_part(af * m as f64 / bf) * (std::f64::consts::PI * m as f64 / bf).cos()
            / (std::f64::consts::PI * m as f64 / bf).sin()
    }).sum();
    let vba: f64 = (1..a).map(|m| {
        frac_part(bf * m as f64 / af) * (std::f64::consts::PI * m as f64 / af).cos()
            / (std::f64::consts::PI * m as f64 / af).sin()
    }).sum();

    let formula = (log_2pi - gamma_c) / 2.0 * (1.0/af + 1.0/bf)
        + (af - bf) / (2.0*af*bf) * (bf / af).ln()
        - std::f64::consts::PI / (2.0*af*bf) * (vab + vba)
        - 1.0 / (af*bf);

    let ft: f64 = (1..b).map(|r| {
        let fv = frac_part(af * r as f64 / bf);
        let lg_r = libm::lgamma(r as f64 / bf);
        let lg_rp1 = libm::lgamma((r + 1) as f64 / bf);
        let psi_rp1 = digamma_cpu((r + 1) as f64 / bf);
        fv * (lg_r - lg_rp1 + (1.0 / bf) * psi_rp1)
    }).sum();

    let strip = (af - 1.0) / (af * bf);
    let stir = (1.0 / bf) * (log_2pi - gamma_c - 1.0);
    let dt = formula - strip - stir - ft / af;

    let id_err = (sum_pcl - dt).abs();

    let certified = tel_lg_err < 1e-8 && tel_psi_err < 1e-8
        && beta_pw && (beta_lhs - beta_rhs).abs() < 1e-8
        && id_err < 1e-8;

    PairResult {
        a: a as c_int, b: b as c_int,
        n_two_tile: n_tt as c_int,
        beta_bijection: if n_tt == a - 1 { 1 } else { 0 },
        s_permutation: 0,  // skip in f64 mode
        telescope_lg_err: tel_lg_err,
        telescope_psi_err: tel_psi_err,
        beta_duality_pw: if beta_pw { 1 } else { 0 },
        beta_duality_sum_err: (beta_lhs - beta_rhs).abs(),
        sum_pcl, delta_target: dt, identity_err: id_err,
        certified: if certified { 1 } else { 0 },
    }
}

/// CPU certification of all pairs using rayon parallelism.
pub fn cpu_certify(pairs: &[(usize, usize)]) -> Vec<PairResult> {
    pairs.par_iter()
        .map(|&(a, b)| certify_pair_cpu(a, b))
        .collect()
}
