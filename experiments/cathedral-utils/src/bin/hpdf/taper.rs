//! ═══════════════════════════════════════════════════════════════════════════
//!  HPDF TAPER — Taper Sum Analysis Subcommand
//!
//!  Computes the three taper sums (U, L, Q) from TaperDecomposition.lean,
//!  pointwise Gram bounds, Möbius column sums, and GCD-stratified entry bounds.
//!  All loops are parallelized with rayon for large-N performance.
//!
//!  Produces a certified JSON output with all computed quantities.
//! ═══════════════════════════════════════════════════════════════════════════

use crate::common::*;
use cathedral_utils::arith;
use rayon::prelude::*;
use std::path::Path;
use std::time::Instant;

/// Result of analyzing a single HPDF file for taper sums.
#[derive(Debug, Clone, serde::Serialize)]
pub struct TaperResult {
    pub max_n: usize,
    pub log_n: f64,
    pub untapered_sum: f64,
    pub linear_taper_sum: f64,
    pub quadratic_taper_sum: f64,
    pub q_over_ln_n: f64,
    pub reconstruction: f64,
    pub vtgv: f64,
    pub one_minus_recon_times_ln_n: f64,
    pub max_g: f64,
    pub max_g_pos: (usize, usize),
    pub min_g: f64,
    pub min_g_pos: (usize, usize),
    pub max_jkg_all: f64,
    pub max_jkg_coprime: f64,
    pub gcd_bound_pass: bool,
    pub gcd_pairs_checked: u64,
    pub gcd_violations: u64,
    pub gcd_worst_excess: f64,
    pub runtime_secs: f64,
}

/// Run taper analysis on a single loaded HPDF context.
pub fn analyze(ctx: &HpdfContext) -> TaperResult {
    let t0 = Instant::now();
    let dim = ctx.dim;
    let max_n = ctx.max_n;
    let mu = &ctx.mu;
    let gram = &ctx.gram;
    let log_n = ctx.log_n;

    // ── §1. TAPER SUMS (parallelized by row) ──────────────────────────────

    let t1 = Instant::now();

    // Precompute which indices have nonzero μ
    let mu_nonzero: Vec<(usize, f64, f64)> = (2..=max_n)
        .filter(|&k| mu[k] != 0)
        .map(|k| (k, mu[k] as f64, (k as f64).ln()))
        .collect();

    // j=1 row contribution (not in H5 — only has j,k ≥ 2)
    let mu1 = mu[1] as f64;
    let mut u_j1 = 0.0f64;
    let mut l_j1 = 0.0f64;
    // j=1,k=1
    let g_11 = cathedral_utils::gram::gram_entry_f64(1, 1);
    u_j1 += mu1 * mu1 * g_11;
    // j=1,k>1 and k=1,j>1 (using symmetry)
    for &(k, mu_k, ln_k) in &mu_nonzero {
        let g_1k = cathedral_utils::gram::gram_entry_f64(1, k);
        u_j1 += 2.0 * mu1 * mu_k * g_1k; // j=1,k + k,j=1
        l_j1 += mu1 * mu_k * ln_k * g_1k; // only k→j direction (ln(1)=0 for j=1)
    }

    // Main sum over j,k ∈ {2,...,max_n} from H5 (parallel over rows)
    struct RowResult {
        u: f64,
        l: f64,
        q: f64,
        vtgv: f64,
    }

    let row_results: Vec<RowResult> = (0..dim)
        .into_par_iter()
        .map(|row| {
            let j = row + 2;
            let mu_j = mu[j] as f64;
            if mu_j == 0.0 {
                return RowResult {
                    u: 0.0,
                    l: 0.0,
                    q: 0.0,
                    vtgv: 0.0,
                };
            }
            let ln_j = (j as f64).ln();
            let w_j = -mu_j * (1.0 - ln_j / log_n);
            let (mut u, mut l, mut q, mut v) = (0.0, 0.0, 0.0, 0.0);
            for col in 0..dim {
                let k = col + 2;
                let mu_k = mu[k] as f64;
                if mu_k == 0.0 {
                    continue;
                }
                let ln_k = (k as f64).ln();
                let w_k = -mu_k * (1.0 - ln_k / log_n);
                let g = gram[row * dim + col];
                let mm = mu_j * mu_k;
                u += mm * g;
                l += mm * ln_j * g;
                q += mm * ln_j * ln_k * g;
                v += w_j * w_k * g;
            }
            RowResult {
                u,
                l,
                q,
                vtgv: v,
            }
        })
        .collect();

    let mut untapered = u_j1;
    let mut linear = l_j1;
    let mut quad = 0.0f64;
    let mut vtgv = 0.0f64;
    for r in &row_results {
        untapered += r.u;
        linear += r.l;
        quad += r.q;
        vtgv += r.vtgv;
    }

    let reconstructed = untapered - 2.0 / log_n * linear + quad / (log_n * log_n);

    section_header(1, "TAPER SUMS", t1.elapsed().as_secs_f64());
    println!("  N={max_n}  ln(N)={log_n:.6}");
    println!("  U(N)       = {MAGENTA}{untapered:.10}{RESET}");
    println!("  L(N)       = {MAGENTA}{linear:.10}{RESET}");
    println!("  L+lnN/2    = {YELLOW}{:.10}{RESET}", linear + log_n / 2.0);
    println!("  Q(N)       = {MAGENTA}{quad:.10}{RESET}");
    println!(
        "  |Q|/lnN    = {YELLOW}{:.10}{RESET}",
        quad.abs() / log_n
    );
    println!("  Recon      = {MAGENTA}{reconstructed:.10}{RESET}");
    println!("  vᵀGv       = {MAGENTA}{vtgv:.10}{RESET}");

    // ── §2. POINTWISE BOUNDS (parallel) ───────────────────────────────────

    let t2 = Instant::now();

    struct PwResult {
        max_g: f64,
        max_g_j: usize,
        max_g_k: usize,
        min_g: f64,
        min_g_j: usize,
        min_g_k: usize,
        max_jkg_all: f64,
        max_jkg_all_j: usize,
        max_jkg_all_k: usize,
        max_jkg_cop: f64,
        max_jkg_cop_j: usize,
        max_jkg_cop_k: usize,
    }

    let pw: Vec<PwResult> = (0..dim)
        .into_par_iter()
        .map(|row| {
            let j = row + 2;
            let mut r = PwResult {
                max_g: f64::NEG_INFINITY,
                max_g_j: 0,
                max_g_k: 0,
                min_g: f64::INFINITY,
                min_g_j: 0,
                min_g_k: 0,
                max_jkg_all: 0.0,
                max_jkg_all_j: 0,
                max_jkg_all_k: 0,
                max_jkg_cop: 0.0,
                max_jkg_cop_j: 0,
                max_jkg_cop_k: 0,
            };
            for col in row..dim {
                let k = col + 2;
                let g = gram[row * dim + col];
                let jkg = (j as f64) * (k as f64) * g;
                if g > r.max_g {
                    r.max_g = g;
                    r.max_g_j = j;
                    r.max_g_k = k;
                }
                if g < r.min_g {
                    r.min_g = g;
                    r.min_g_j = j;
                    r.min_g_k = k;
                }
                if jkg > r.max_jkg_all {
                    r.max_jkg_all = jkg;
                    r.max_jkg_all_j = j;
                    r.max_jkg_all_k = k;
                }
                if j != k && arith::gcd(j, k) == 1 && jkg > r.max_jkg_cop {
                    r.max_jkg_cop = jkg;
                    r.max_jkg_cop_j = j;
                    r.max_jkg_cop_k = k;
                }
            }
            r
        })
        .collect();

    let mut best = PwResult {
        max_g: f64::NEG_INFINITY,
        max_g_j: 0,
        max_g_k: 0,
        min_g: f64::INFINITY,
        min_g_j: 0,
        min_g_k: 0,
        max_jkg_all: 0.0,
        max_jkg_all_j: 0,
        max_jkg_all_k: 0,
        max_jkg_cop: 0.0,
        max_jkg_cop_j: 0,
        max_jkg_cop_k: 0,
    };
    for r in &pw {
        if r.max_g > best.max_g {
            best.max_g = r.max_g;
            best.max_g_j = r.max_g_j;
            best.max_g_k = r.max_g_k;
        }
        if r.min_g < best.min_g {
            best.min_g = r.min_g;
            best.min_g_j = r.min_g_j;
            best.min_g_k = r.min_g_k;
        }
        if r.max_jkg_all > best.max_jkg_all {
            best.max_jkg_all = r.max_jkg_all;
            best.max_jkg_all_j = r.max_jkg_all_j;
            best.max_jkg_all_k = r.max_jkg_all_k;
        }
        if r.max_jkg_cop > best.max_jkg_cop {
            best.max_jkg_cop = r.max_jkg_cop;
            best.max_jkg_cop_j = r.max_jkg_cop_j;
            best.max_jkg_cop_k = r.max_jkg_cop_k;
        }
    }

    section_header(2, "POINTWISE BOUNDS", t2.elapsed().as_secs_f64());
    println!(
        "  max G    = {:.10} at ({},{})",
        best.max_g, best.max_g_j, best.max_g_k
    );
    println!(
        "  min G    = {:.10} at ({},{})",
        best.min_g, best.min_g_j, best.min_g_k
    );
    println!(
        "  max jk·G ALL    = {YELLOW}{:.6}{RESET} at ({},{})",
        best.max_jkg_all, best.max_jkg_all_j, best.max_jkg_all_k
    );
    println!(
        "  max jk·G COPRIME= {YELLOW}{:.6}{RESET} at ({},{})",
        best.max_jkg_cop, best.max_jkg_cop_j, best.max_jkg_cop_k
    );

    // Diagonal scaling
    for &k in &[2, 10, 100, 1000, 10000, 50000] {
        if k > max_n {
            break;
        }
        let row = k - 2;
        if row >= dim {
            break;
        }
        let g_kk = gram[row * dim + row];
        println!("  k={:<6} k·G(k,k) = {:.6}", k, (k as f64) * g_kk);
    }

    // ── §3. MÖBIUS COLUMN SUMS (parallel, sampled output) ─────────────────

    let t3 = Instant::now();

    struct ColResult {
        j: usize,
        s: f64,
    }
    let cols: Vec<ColResult> = (0..dim)
        .into_par_iter()
        .map(|row| {
            let j = row + 2;
            let mut s = 0.0f64;
            for col in 0..dim {
                let k = col + 2;
                let mu_k = mu[k] as f64;
                if mu_k == 0.0 {
                    continue;
                }
                s += mu_k * gram[row * dim + col];
            }
            ColResult { j, s }
        })
        .collect();

    let mut max_abs_s = 0.0f64;
    let mut max_abs_j = 0usize;
    let mut max_js = 0.0f64;
    let mut max_js_j = 0usize;
    for c in &cols {
        let a = c.s.abs();
        if a > max_abs_s {
            max_abs_s = a;
            max_abs_j = c.j;
        }
        let ja = (c.j as f64) * a;
        if ja > max_js {
            max_js = ja;
            max_js_j = c.j;
        }
    }

    section_header(3, "MÖBIUS COLUMN SUMS", t3.elapsed().as_secs_f64());
    for &target_j in &[2, 10, 100, 1000, 5000, 10000, 20000, 50000] {
        if target_j > max_n {
            break;
        }
        let idx = target_j - 2;
        if idx >= cols.len() {
            break;
        }
        let c = &cols[idx];
        println!(
            "  j={:<6} S={:>12.8}  j·|S|={:.4}",
            c.j,
            c.s,
            (c.j as f64) * c.s.abs()
        );
    }
    println!("  max|S|   = {:.8} at j={}", max_abs_s, max_abs_j);
    println!("  max j|S| = {:.4} at j={}", max_js, max_js_j);

    // ── §4. GCD BOUND (sampled for large N) ───────────────────────────────

    let t4 = Instant::now();
    let sample_mode = dim > 15000;

    struct BoundResult {
        checked: u64,
        violations: u64,
        worst: f64,
        wj: usize,
        wk: usize,
    }

    let bound_results: Vec<BoundResult> = (0..dim)
        .into_par_iter()
        .map(|row| {
            let j = row + 2;
            // For large matrices, sample every ~10th row
            if sample_mode && row % 10 != 0 {
                return BoundResult {
                    checked: 0,
                    violations: 0,
                    worst: f64::NEG_INFINITY,
                    wj: 0,
                    wk: 0,
                };
            }
            let mut br = BoundResult {
                checked: 0,
                violations: 0,
                worst: f64::NEG_INFINITY,
                wj: 0,
                wk: 0,
            };
            let col_step = if sample_mode { 10 } else { 1 };
            let mut col = row + 1;
            while col < dim {
                let k = col + 2;
                br.checked += 1;
                let g = arith::gcd(j, k) as f64;
                let fj = j as f64;
                let fk = k as f64;
                let bound = 0.25 + g * g / (12.0 * fj * fk) + 1.0 / (4.0 * fk);
                let excess = gram[row * dim + col] - bound;
                if excess > br.worst {
                    br.worst = excess;
                    br.wj = j;
                    br.wk = k;
                }
                if excess > 1e-10 {
                    br.violations += 1;
                }
                col += col_step;
            }
            br
        })
        .collect();

    let mut total_checked = 0u64;
    let mut total_violations = 0u64;
    let mut worst_excess = f64::NEG_INFINITY;
    let mut worst_j = 0;
    let mut worst_k = 0;
    for br in &bound_results {
        total_checked += br.checked;
        total_violations += br.violations;
        if br.worst > worst_excess {
            worst_excess = br.worst;
            worst_j = br.wj;
            worst_k = br.wk;
        }
    }

    let label = if sample_mode { " (sampled)" } else { "" };
    section_header(4, &format!("GCD BOUND{label}"), t4.elapsed().as_secs_f64());
    println!("  Checked:    {total_checked}");
    println!("  Violations: {total_violations}");
    println!(
        "  Worst:      {:.6e} at ({},{})",
        worst_excess, worst_j, worst_k
    );
    if total_violations == 0 {
        println!("  {GREEN}✓ PASS{RESET}");
    } else {
        println!("  {RED}✗ FAIL ({total_violations} violations){RESET}");
    }

    // ── CERTIFICATE ───────────────────────────────────────────────────────

    let total_secs = t0.elapsed().as_secs_f64();
    let recon = reconstructed;
    let one_minus_recon_ln_n = (1.0 - recon) * log_n;

    println!("\n  {BOLD}{CYAN}╔══════════════════════════════════════════════════════╗{RESET}");
    println!(
        "  {BOLD}{CYAN}║{RESET} {BOLD}CERTIFICATE N={max_n}{RESET}  ({total_secs:.1}s total)"
    );
    println!("  {BOLD}{CYAN}╠══════════════════════════════════════════════════════╣{RESET}");
    println!(
        "  {BOLD}{CYAN}║{RESET} U(N)={:.8}  L(N)={:.8}  Q(N)={:.8}",
        untapered, linear, quad
    );
    println!(
        "  {BOLD}{CYAN}║{RESET} |Q|/lnN={YELLOW}{:.6}{RESET}  Recon={MAGENTA}{recon:.8}{RESET}  vᵀGv={vtgv:.8}",
        quad.abs() / log_n
    );
    println!(
        "  {BOLD}{CYAN}║{RESET} (1-R)·lnN={YELLOW}{one_minus_recon_ln_n:.6}{RESET}"
    );
    println!(
        "  {BOLD}{CYAN}║{RESET} GCD bound: {} ({total_checked} pairs)",
        if total_violations == 0 {
            format!("{GREEN}PASS{RESET}")
        } else {
            format!("{RED}FAIL({total_violations}){RESET}")
        }
    );
    println!("  {BOLD}{CYAN}╚══════════════════════════════════════════════════════╝{RESET}");

    TaperResult {
        max_n,
        log_n,
        untapered_sum: untapered,
        linear_taper_sum: linear,
        quadratic_taper_sum: quad,
        q_over_ln_n: quad.abs() / log_n,
        reconstruction: recon,
        vtgv,
        one_minus_recon_times_ln_n: one_minus_recon_ln_n,
        max_g: best.max_g,
        max_g_pos: (best.max_g_j, best.max_g_k),
        min_g: best.min_g,
        min_g_pos: (best.min_g_j, best.min_g_k),
        max_jkg_all: best.max_jkg_all,
        max_jkg_coprime: best.max_jkg_cop,
        gcd_bound_pass: total_violations == 0,
        gcd_pairs_checked: total_checked,
        gcd_violations: total_violations,
        gcd_worst_excess: worst_excess,
        runtime_secs: total_secs,
    }
}

/// Run the taper subcommand: analyze one or more HPDF files.
pub fn run(paths: &[&Path], emit_json: bool) {
    let mut all_results = Vec::new();

    for path in paths {
        println!(
            "\n  {BOLD}{WHITE}Loading: {RESET}{}",
            path.display()
        );

        match HpdfContext::load(path) {
            Ok(ctx) => {
                let result = analyze(&ctx);

                if emit_json {
                    let mut cert = Certificate::new(&ctx, "taper");
                    cert.results = serde_json::to_value(&result).unwrap();
                    cert.runtime_secs = result.runtime_secs;
                    let out = cert.write("taper", ctx.max_n);
                    println!(
                        "\n  {GREEN}✓{RESET} Certificate: {}",
                        out.display()
                    );
                }

                all_results.push(result);
            }
            Err(e) => {
                eprintln!("  {RED}✗ Error: {e}{RESET}");
            }
        }
    }

    // Summary table when processing multiple files
    if all_results.len() > 1 {
        println!("\n  {BOLD}{CYAN}═══ SUMMARY ═══{RESET}");
        println!(
            "  {:>6} {:>8} {:>10} {:>10} {:>10} {:>8} {:>10} {:>8}",
            "N", "ln(N)", "U(N)", "L(N)", "Q(N)", "|Q|/lnN", "Recon", "(1-R)ln"
        );
        for r in &all_results {
            println!(
                "  {:>6} {:>8.3} {:>10.6} {:>10.6} {:>10.4} {:>8.4} {:>10.6} {:>8.4}",
                r.max_n,
                r.log_n,
                r.untapered_sum,
                r.linear_taper_sum,
                r.quadratic_taper_sum,
                r.q_over_ln_n,
                r.reconstruction,
                r.one_minus_recon_times_ln_n
            );
        }
    }
}
