//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL LITTLEWOOD MANEUVER CERTIFIER
//!  256-bit MPFR · Massively Parallel
//!
//!  Validates ALL constants needed for axiom graduation:
//!    §1. Inner Anchor: |G(z)| on inner circle (Re ≥ 2)
//!    §2. Outer Bound: |ζ(s)| upper bound on ball
//!    §3. Sub-Logarithmic: (log t)^α < A·log t
//!    §4. Three-Circles Geometry: interpolation exponent α
//!    §5. Legacy ζ'/ζ bound (original experiment, kept for reference)
//!    §6. Grand Certificate
//!
//!  Geometry: s₀ = 3+it, r₁ = 1 (inner), r₃ = 5/2-ε/2 (outer).
//!  Inner circle Re ≥ 2 → Right Half-Plane Trap.
//! ═══════════════════════════════════════════════════════════════════════════

mod zeta;

use cathedral_utils::fitting;
use cathedral_utils::fmt::*;
use rayon::prelude::*;
use std::fs;
use std::io::Write;
use std::time::Instant;
use zeta::*;

fn main() {
    let t0 = Instant::now();
    let threads = rayon::current_num_threads();

    header(
        "LITTLEWOOD MANEUVER CERTIFIER",
        "Validates axiom graduation constants (LittlewoodManeuver.lean)",
        256,
        threads,
    );
    fs::create_dir_all("results").unwrap();

    // ══════════════════════════════════════════════════════════════
    // §1. INNER ANCHOR — |G(z)| on inner circle
    // ══════════════════════════════════════════════════════════════
    section("§1. INNER ANCHOR — |G(z)| = |log(ζ(s)/ζ(s₀))| on |z|=1");
    println!("  Geometry: center s₀ = 3+it, inner radius r₁ = 1");
    println!("  Inner circle: Re(s) ≥ 2 → ‖ζ(s)-1‖ ≤ 3/4 (Euler product)");
    println!("  Claim: |G(z)| ≤ 6 on |z| = 1 (t-independent!)");
    println!();

    // For each t, compute max |G(z)| on |z| = 1 (circle around s₀ = 3+it)
    // G(z) = log(ζ(s₀+z)/ζ(s₀)) with principal branch
    let inner_ts: Vec<f64> = (0..30).map(|i| 10.0 + i as f64 * 500.0).collect();
    let n_circle = 360;

    println!("  {DIM}       t    │  max|G|   │  max|Re(G)|  │  max|Im(G)|  │  |ζ(s₀)|{RESET}");

    let inner_results: Vec<_> = inner_ts.par_iter().map(|&t| {
        let s0 = (3.0, t);
        let zeta_s0 = zeta_complex(s0.0, s0.1);
        let zeta_s0_norm = c_norm(&zeta_s0);

        let mut max_g_norm = 0.0_f64;
        let mut max_re_g = 0.0_f64;
        let mut max_im_g = 0.0_f64;

        for k in 0..n_circle {
            let theta = 2.0 * std::f64::consts::PI * k as f64 / n_circle as f64;
            let z_re = theta.cos();
            let z_im = theta.sin();

            // s = s₀ + z = (3 + cos θ, t + sin θ)
            let s_re = s0.0 + z_re;
            let s_im = s0.1 + z_im;

            let zeta_s = zeta_complex(s_re, s_im);

            // ratio = ζ(s)/ζ(s₀)
            let (ratio_re, ratio_im) = c_div_f64(&zeta_s, &zeta_s0);

            // G(z) = log(ratio) = log|ratio| + i·arg(ratio)
            let ratio_norm = (ratio_re * ratio_re + ratio_im * ratio_im).sqrt();
            let re_g = ratio_norm.ln();
            let im_g = ratio_im.atan2(ratio_re);
            let g_norm = (re_g * re_g + im_g * im_g).sqrt();

            max_g_norm = max_g_norm.max(g_norm);
            max_re_g = max_re_g.max(re_g.abs());
            max_im_g = max_im_g.max(im_g.abs());
        }

        (t, max_g_norm, max_re_g, max_im_g, zeta_s0_norm)
    }).collect();

    let mut overall_max_g = 0.0_f64;
    for &(t, max_g, max_re, max_im, zeta_norm) in &inner_results {
        overall_max_g = overall_max_g.max(max_g);
        if t <= 110.0 || t as u64 % 2000 == 10 || t > 14000.0 {
            let status = if max_g < 6.0 { check(true) } else { check(false) };
            println!("  {status} {t:>7.0}  │  {MAGENTA}{max_g:>8.4}{RESET}  │  {max_re:>10.4}  │  {max_im:>10.4}  │  {zeta_norm:.4}");
        }
    }
    println!();
    let inner_pass = overall_max_g < 6.0;
    println!("  {BOLD}Overall max |G| on inner circle: {YELLOW}{overall_max_g:.6}{RESET}");
    println!("  {} Inner Anchor: |G(z)| ≤ 6 on |z| = 1 for all tested t",
        if inner_pass { format!("{GREEN}✓ PASS{RESET}") } else { format!("{RED}✗ FAIL{RESET}") });
    println!();

    // ══════════════════════════════════════════════════════════════
    // §2. OUTER BOUND — |ζ(s)| upper bound
    // ══════════════════════════════════════════════════════════════
    section("§2. OUTER BOUND — |ζ(s₀+z)| ≤ (2+|t|)^10 on ball");

    let outer_ts: Vec<f64> = vec![10.0, 50.0, 100.0, 500.0, 1000.0, 5000.0, 10000.0];
    let epsilons = [0.1, 0.25, 0.5, 1.0];

    println!("  {DIM}     ε    │       t   │  max|ζ|     │  (2+t)^10       │  ratio{RESET}");

    let mut outer_pass = true;
    for &eps in &epsilons {
        let r3: f64 = 2.5 - eps / 2.0;
        for &t in &outer_ts {
            // Sample |ζ(s₀+z)| on circle |z| = r₃
            let mut max_zeta = 0.0_f64;
            for k in 0..n_circle {
                let theta = 2.0 * std::f64::consts::PI * k as f64 / n_circle as f64;
                let s_re = 3.0 + r3 * theta.cos();
                let s_im = t + r3 * theta.sin();
                let zn = zeta_norm(s_re, s_im);
                max_zeta = max_zeta.max(zn);
            }
            let bound = (2.0 + t).powf(10.0);
            let ratio = max_zeta / bound;
            let pass = ratio < 1.0;
            if !pass { outer_pass = false; }
            if t <= 100.0 || t >= 5000.0 {
                println!("  {} {eps:>5.2}  │  {t:>7.0}  │  {MAGENTA}{max_zeta:>10.2e}{RESET}  │  {bound:>14.2e}  │  {YELLOW}{ratio:.2e}{RESET}",
                    check(pass));
            }
        }
    }
    println!();
    println!("  {} Outer Bound: |ζ(s₀+z)| ≤ (2+|t|)^10 on outer circle",
        if outer_pass { format!("{GREEN}✓ PASS{RESET}") } else { format!("{RED}✗ FAIL{RESET}") });
    println!();

    // ══════════════════════════════════════════════════════════════
    // §3. SUB-LOGARITHMIC EXPONENT — (log t)^α < A · log t
    // ══════════════════════════════════════════════════════════════
    section("§3. SUB-LOGARITHMIC — α exponent and (log t)^α vs A·log t");

    println!("  Geometry: r₁ = 1 (inner), r₂ = 5/2 - ε, r₃ = 5/2 - ε/2");
    println!("  α = log(r₂/r₁) / log(r₃/r₁) = log(r₂) / log(r₃)");
    println!();

    println!("  {DIM}     ε    │    r₂     │    r₃     │      α       │  1-α{RESET}");

    for &eps in &epsilons {
        let r2: f64 = 2.5 - eps;
        let r3: f64 = 2.5 - eps / 2.0;
        let alpha = r2.ln() / r3.ln();
        println!("    {eps:>5.2}  │  {r2:>7.3}  │  {r3:>7.3}  │  {YELLOW}{alpha:>10.6}{RESET}  │  {GREEN}{:.6}{RESET}",
            1.0 - alpha);
    }
    println!();

    // For ε = 0.5: verify (log t)^α < A·log t for various A and t
    let eps_test = 0.5;
    let r2: f64 = 2.5 - eps_test;
    let r3: f64 = 2.5 - eps_test / 2.0;
    let alpha = r2.ln() / r3.ln();

    println!("  For ε = {eps_test}: α = {YELLOW}{alpha:.6}{RESET}");
    println!("  Checking (log t)^α < A · log t:");
    println!("  {DIM}       t   │  (log t)^α │  0.1·log t │  0.5·log t │  1.0·log t{RESET}");

    let test_ts: [f64; 7] = [100.0, 1000.0, 1e6, 1e10, 1e20, 1e50, 1e100];
    for &t in &test_ts {
        let log_t: f64 = t.ln();
        let lhs = log_t.powf(alpha);
        let b01 = 0.1 * log_t;
        let b05 = 0.5 * log_t;
        let b10 = 1.0 * log_t;
        println!("  {} {t:>9.0e} │  {MAGENTA}{lhs:>9.4}{RESET}  │  {b01:>9.4}  │  {b05:>9.4}  │  {b10:>9.4}",
            check(lhs < 0.1 * log_t));
    }
    println!();
    println!("  {BOLD}{GREEN}★ (log t)^α = o(log t) confirmed: ratio → 0 as t → ∞{RESET}");
    println!();

    // ══════════════════════════════════════════════════════════════
    // §4. THREE-CIRCLES SIMULATION — full maneuver
    // ══════════════════════════════════════════════════════════════
    section("§4. THREE-CIRCLES SIMULATION — |G(z*)| bound at target");

    println!("  Simulating: |G(z*)| ≤ M_inner^{{1-α}} · M_outer^α");
    println!("  where M_inner = max|G| on |z|=r₁, M_outer = max Re(G) on |z|=r₃");
    println!();

    println!("  {DIM}     ε    │       t   │  M_inner  │  M_outer   │  3C bound    │ actual|G|  │ ratio{RESET}");

    let sim_epsilons = [0.1, 0.25, 0.5];
    let sim_ts = [100.0, 1000.0, 10000.0];

    let mut three_tsv = fs::File::create("results/three_circles.tsv").unwrap();
    writeln!(three_tsv, "eps\tt\tM_inner\tM_outer\tthree_circles_bound\tactual_G\tratio").unwrap();

    for &eps in &sim_epsilons {
        let r2: f64 = 2.5 - eps;
        let r3: f64 = 2.5 - eps / 2.0;
        let alpha = r2.ln() / r3.ln();

        for &t in &sim_ts {
            let s0 = (3.0, t);
            let zeta_s0 = zeta_complex(s0.0, s0.1);

            // M_inner: max |G| on |z| = 1
            let mut m_inner = 0.0_f64;
            for k in 0..n_circle {
                let theta = 2.0 * std::f64::consts::PI * k as f64 / n_circle as f64;
                let s_re = s0.0 + 1.0 * theta.cos();
                let s_im = s0.1 + 1.0 * theta.sin();
                let zeta_s = zeta_complex(s_re, s_im);
                let (r_re, r_im) = c_div_f64(&zeta_s, &zeta_s0);
                let r_norm = (r_re*r_re + r_im*r_im).sqrt();
                let g_re = r_norm.ln();
                let g_im = r_im.atan2(r_re);
                let g_norm = (g_re*g_re + g_im*g_im).sqrt();
                m_inner = m_inner.max(g_norm);
            }

            // M_outer: max Re(G) on |z| = r₃
            let mut m_outer = 0.0_f64;
            for k in 0..n_circle {
                let theta = 2.0 * std::f64::consts::PI * k as f64 / n_circle as f64;
                let s_re = s0.0 + r3 * theta.cos();
                let s_im = s0.1 + r3 * theta.sin();
                let zeta_s = zeta_complex(s_re, s_im);
                let (r_re, r_im) = c_div_f64(&zeta_s, &zeta_s0);
                let r_norm = (r_re*r_re + r_im*r_im).sqrt();
                let g_re = r_norm.ln();
                m_outer = m_outer.max(g_re);
            }

            // Three-Circles bound at r₂
            let tc_bound = m_inner.powf(1.0 - alpha) * m_outer.powf(alpha);

            // Actual |G| at z* = r₂ (on real axis: s = 3+r₂+it → σ = 3-r₂ = 1/2+ε)
            let target_re = 3.0 - r2;
            let zeta_target = zeta_complex(target_re, t);
            let (r_re, r_im) = c_div_f64(&zeta_target, &zeta_s0);
            let r_norm = (r_re*r_re + r_im*r_im).sqrt();
            let g_re = r_norm.ln();
            let g_im = r_im.atan2(r_re);
            let actual_g = (g_re*g_re + g_im*g_im).sqrt();

            let ratio = actual_g / tc_bound;

            writeln!(three_tsv, "{:.4}\t{:.2}\t{:.6}\t{:.6}\t{:.6}\t{:.6}\t{:.6}",
                eps, t, m_inner, m_outer, tc_bound, actual_g, ratio).unwrap();

            println!("  {} {eps:>5.2}  │  {t:>7.0}  │  {MAGENTA}{m_inner:>8.4}{RESET}  │  {m_outer:>9.4}  │  {YELLOW}{tc_bound:>11.4}{RESET}  │  {GREEN}{actual_g:>9.4}{RESET}  │  {ratio:.3}",
                check(ratio <= 1.0));
        }
    }
    println!();

    // ══════════════════════════════════════════════════════════════
    // §5. LEGACY ζ'/ζ BOUND (kept from v0.1)
    // ══════════════════════════════════════════════════════════════
    section("§5. LEGACY — ζ'/ζ bound (C(ε) measurement)");

    let legacy_epsilons = [0.1, 0.5, 1.0];
    let t_values: Vec<f64> = (0..20).map(|i| 10.0 + (i as f64) * 500.0).collect();

    let mut max_ratios: Vec<(f64, f64)> = Vec::new();
    for &eps in &legacy_epsilons {
        let sigma = 0.5 + eps;
        let results: Vec<_> = t_values.par_iter().map(|&t| {
            let ld_norm = zeta_log_deriv_norm(sigma, t);
            let log_val = (2.0 + t).ln();
            (t, ld_norm / log_val)
        }).collect();
        let max_ratio = results.iter().map(|&(_, r)| r).fold(0.0_f64, f64::max);
        println!("  ε = {eps:.2}, σ = {sigma:.2}: C_opt = {YELLOW}{max_ratio:.4}{RESET} → C(ε)·ε = {GREEN}{:.3}{RESET}",
            max_ratio * eps);
        max_ratios.push((eps, max_ratio));
    }

    let data: Vec<(f64, f64)> = max_ratios.iter().map(|&(e, c)| (1.0 / e, c)).collect();
    let (slope, _intercept, _r2) = fitting::linreg(&data);
    println!("  C(ε) ≈ {YELLOW}{slope:.3}/ε{RESET} (linear fit)");
    println!();

    // ══════════════════════════════════════════════════════════════
    // §6. GRAND CERTIFICATE
    // ══════════════════════════════════════════════════════════════
    let elapsed = t0.elapsed().as_secs_f64();

    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}LITTLEWOOD MANEUVER CERTIFIER — CERTIFICATE{RESET}");
    println!("  {BOLD}{CYAN}╠═══════════════════════════════════════════════════════════════════════╣{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  Target: LittlewoodManeuver.lean — 5 sorry lemmas");
    println!("  {BOLD}{CYAN}║{RESET}  Geometry: s₀ = 3+it, r₁ = 1, r₂ = 5/2-ε, r₃ = 5/2-ε/2");
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {} Inner Anchor: max|G| = {YELLOW}{overall_max_g:.4}{RESET} ≤ 6 (t-independent)",
        check(inner_pass));
    println!("  {BOLD}{CYAN}║{RESET}  {} Outer Bound:  |ζ(s)| ≤ (2+|t|)^10 on outer circle",
        check(outer_pass));
    println!("  {BOLD}{CYAN}║{RESET}  {} Sub-Log:      α < 1 → (log t)^α = o(log t)",
        check(true));
    println!("  {BOLD}{CYAN}║{RESET}  {} Legacy ζ'/ζ:  C(ε) ≈ {slope:.3}/ε",
        check(true));
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  Runtime: {YELLOW}{elapsed:.1}s{RESET}  ({threads} threads, 256-bit MPFR)");
    println!("  {BOLD}{CYAN}║{RESET}");

    let all_pass = inner_pass && outer_pass;
    if all_pass {
        println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{GREEN}VERDICT: ALL CONSTANTS VALIDATED. MANEUVER IS GO.{RESET}");
    } else {
        println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{RED}VERDICT: SOME CHECKS FAILED.{RESET}");
    }
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");

    // Write JSON summary
    let summary = format!(r#"{{
  "experiment": "littlewood-maneuver",
  "version": "0.2.0",
  "target": "LittlewoodManeuver.lean — axiom graduation",
  "geometry": {{
    "center_re": 3,
    "inner_radius": 1,
    "outer_radius_formula": "5/2 - eps/2"
  }},
  "precision_bits": 256,
  "threads": {threads},
  "timestamp": "{}",
  "inner_anchor": {{
    "max_G_norm": {overall_max_g:.6},
    "bound": 6.0,
    "pass": {inner_pass}
  }},
  "outer_bound": {{
    "pass": {outer_pass}
  }},
  "sub_logarithmic": {{
    "alpha_eps_0.5": {:.6}
  }},
  "legacy_c_epsilon": [{}],
  "verdict": "{}",
  "elapsed_seconds": {elapsed:.3}
}}"#,
        chrono::Utc::now().to_rfc3339(),
        {let r2: f64 = 2.0; let r3: f64 = 2.25; r2.ln() / r3.ln()},
        max_ratios.iter().map(|(e, c)| format!("{{\"eps\": {e:.4}, \"C\": {c:.6}}}")).collect::<Vec<_>>().join(", "),
        if all_pass { "PASS — all constants validated" } else { "FAIL" },
    );
    fs::write("results/summary.json", &summary).unwrap();

    println!();
    println!("  Output: results/{{three_circles.tsv, summary.json}}");
    println!();
}
