//! ═══════════════════════════════════════════════════════════════════════════
//!  HONEST ALGEBRA — Three-piece decomposition certification at f64
//!
//!  Certifies ∑ perClassLimit(a,b,m₀) = deltaTarget DIRECTLY,
//!  without using gramIntegral = formula (no circular bootstrap).
//!
//!  The sum splits into three pieces:
//!    P1: -(1/a) Σ logΓ(β)   where β = (n₀+1)/a → Gauss multiplication
//!    P2: +(1/a) Σ logΓ(α)   where α = (m₀+1)/b → two-tile subset
//!    P3: -Σ [(s-a)/(a²b)·ψ(β) + (1/(ab))·ψ(α)] → digamma terms
//! ═══════════════════════════════════════════════════════════════════════════

use rayon::prelude::*;
use cathedral_utils::fmt;
use crate::compute::{self, EULER_GAMMA, LOG_2PI};

#[derive(Debug, Clone)]
pub struct HonestAlgebraResult {
    pub a: usize,
    pub b: usize,
    pub n_two_tile: usize,

    // Structural
    pub beta_covers_full_range: bool,
    pub beta_each_once: bool,
    pub s_is_permutation: bool,

    // Three pieces
    pub piece1_log_gamma_beta: f64,
    pub piece2_log_gamma_alpha: f64,
    pub piece3_digamma: f64,

    // Gauss comparison
    pub piece1_gauss_closed: f64,
    pub piece1_gauss_error: f64,

    // Identity
    pub sum_per_class_limit: f64,
    pub delta_target: f64,
    pub identity_error: f64,
}

pub fn certify_pair(a: usize, b: usize) -> HonestAlgebraResult {
    let af = a as f64;
    let bf = b as f64;

    let tt_classes: Vec<usize> = (1..b)
        .filter(|&m0| compute::is_two_tile(a, b, m0))
        .collect();
    let n_tt = tt_classes.len();

    // ═══ STRUCTURAL CHECKS ═══
    let beta_nums: Vec<usize> = tt_classes.iter()
        .map(|&m0| compute::tile_index(a, b, m0) + 1)
        .collect();
    let mut beta_sorted = beta_nums.clone();
    beta_sorted.sort();
    beta_sorted.dedup();
    let beta_covers = beta_sorted == (1..=a).collect::<Vec<_>>();
    let beta_once = beta_nums.len() == a;

    let s_vals: Vec<usize> = tt_classes.iter()
        .map(|&m0| compute::overshoot(a, b, m0))
        .collect();
    let mut s_sorted = s_vals.clone();
    s_sorted.sort();
    let s_perm = s_sorted == (0..a).collect::<Vec<_>>();

    // ═══ THREE PIECES ═══
    let mut p1 = 0.0_f64;  // -(1/a) Σ logΓ(β)
    let mut p2 = 0.0_f64;  // +(1/a) Σ logΓ(α)
    let mut p3 = 0.0_f64;  // digamma terms
    let mut total = 0.0_f64;

    for &m0 in &tt_classes {
        let n0 = compute::tile_index(a, b, m0);
        let s = compute::overshoot(a, b, m0);
        let alpha = (m0 + 1) as f64 / bf;
        let beta = (n0 + 1) as f64 / af;

        let lg_beta = libm::lgamma(beta);
        let lg_alpha = libm::lgamma(alpha);
        let psi_beta = compute::digamma_f64(beta);
        let psi_alpha = compute::digamma_f64(alpha);

        p1 -= lg_beta / af;
        p2 += lg_alpha / af;
        p3 -= ((s as f64 - af) / (af * af * bf)) * psi_beta;
        p3 -= (1.0 / (af * bf)) * psi_alpha;

        total += -(1.0 / af) * (lg_beta - lg_alpha)
            - ((s as f64 - af) / (af * af * bf)) * psi_beta
            - (1.0 / (af * bf)) * psi_alpha;
    }

    // Gauss closed form: -(1/a)·[(a-1)/2·log(2π) - (1/2)·log(a)]
    let gauss_closed = -((af - 1.0) / (2.0 * af) * LOG_2PI - af.ln() / (2.0 * af));
    let gauss_err = (p1 - gauss_closed).abs();

    let dt = compute::delta_target(a, b);
    let id_err = (total - dt).abs();

    HonestAlgebraResult {
        a, b, n_two_tile: n_tt,
        beta_covers_full_range: beta_covers,
        beta_each_once: beta_once,
        s_is_permutation: s_perm,
        piece1_log_gamma_beta: p1,
        piece2_log_gamma_alpha: p2,
        piece3_digamma: p3,
        piece1_gauss_closed: gauss_closed,
        piece1_gauss_error: gauss_err,
        sum_per_class_limit: total,
        delta_target: dt,
        identity_error: id_err,
    }
}

pub fn certify_all(pairs: &[(usize, usize)]) -> Vec<HonestAlgebraResult> {
    let mut results: Vec<_> = pairs.par_iter()
        .map(|&(a, b)| certify_pair(a, b))
        .collect();
    results.sort_by_key(|r| (r.a, r.b));
    results
}

pub fn print_certification(results: &[HonestAlgebraResult]) {
    fmt::section("§3. HONEST ALGEBRA — ∑ perClassLimit = deltaTarget (DIRECT)");
    println!();
    println!("  Certifying WITHOUT gramIntegral = formula (no circular bootstrap)");
    println!();

    // Structural
    let all_beta = results.iter().all(|r| r.beta_covers_full_range && r.beta_each_once);
    let all_s = results.iter().all(|r| r.s_is_permutation);
    println!("  β covers {{1/a,...,a/a}} exactly : {} ({}/{})",
        if all_beta { fmt::check(true) } else { fmt::check(false) },
        results.iter().filter(|r| r.beta_covers_full_range && r.beta_each_once).count(),
        results.len());
    println!("  s is permutation of {{0,...,a-1}} : {} ({}/{})",
        if all_s { fmt::check(true) } else { fmt::check(false) },
        results.iter().filter(|r| r.s_is_permutation).count(),
        results.len());
    println!();

    // Three pieces
    let max_gauss_err = results.iter().map(|r| r.piece1_gauss_error).fold(0.0_f64, f64::max);
    println!("  Max |Piece1 - Gauss closed form|: {:.4e}", max_gauss_err);
    if max_gauss_err < 1e-8 {
        println!("  {} Piece 1 = Gauss Multiplication Formula", fmt::check(true));
    }
    println!();

    // Identity
    let max_err = results.iter().map(|r| r.identity_error).fold(0.0_f64, f64::max);
    let all_pass = max_err < 1e-8;

    if results.len() <= 200 {
        println!("  {:>5} {:>5}  {:>20}  {:>20}  {:>14}",
            "(a", "b)", "∑ perClassLimit", "deltaTarget", "|error|");
        println!("  {}", "─".repeat(75));
        for r in results {
            let pass = r.identity_error < 1e-8;
            println!("  ({:>2},{:>2})  {:>20.15}  {:>20.15}  {:>14.4e}  {}",
                r.a, r.b, r.sum_per_class_limit, r.delta_target,
                r.identity_error,
                if pass { fmt::check(true) } else { fmt::check(false) });
        }
        println!();
    }

    if all_pass {
        println!("  {} ∑ perClassLimit = deltaTarget — CERTIFIED (DIRECT, NO BOOTSTRAP)",
            fmt::check(true));
    } else {
        println!("  {} IDENTITY CHECK FAILED", fmt::check(false));
    }
    println!("  Max |error|: {:.4e}", max_err);
    println!();
}
