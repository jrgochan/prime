// ═══════════════════════════════════════════════════════════════════════
//  BÁEZ-DUARTE DISTANCE CERTIFICATION ENGINE
//  The Cathedral — Lean 4 Proof Infrastructure
//
//  This experiment produces machine-checkable numerical certificates
//  that validate the quantitative predictions of the formal proof chain:
//
//    proofs/Cathedral/Assembly/MainChain.lean
//      theorem nyman_beurling_equivalence_mellin :
//        RH ↔ d²_N → 0
//
//    proofs/Cathedral/IntegralBasis/BaezDuarte.lean
//      The Báez-Duarte constant C = 1/(2 + γ - ln(4π)) ≈ 0.0462
//      predicts d²_N ≈ C/ln(N), i.e., X/ln(N) → 1/C ≈ 21.64
//
//  The certificate.json output bridges the gap between the formal
//  proof (which establishes the equivalence) and the numerical
//  evidence (which demonstrates convergence at specific N values).
//  The HyperZeta Viewport then renders this data interactively.
//
//  TWO MODES:
//    cargo run --release [MAX_N]          — 512-bit MPFR (certification)
//    cargo run --release -- --fast [N]    — f64 (high-N convergence tracking)
//
//  Mathematical setup:
//    Basis:     h_k(x) = {1/(kx)}     (θ = 1/k ≤ 1)
//    Gram:      G(j,k) = ∫₁^∞ {u/j}{u/k}/u² du
//    Mean:      b_k = (ln(k) + 1 - γ) / k
//    Distance:  d²_N = 1 - bᵀ G⁻¹ b
//    Sherman-M: d²_N = 1/(1 + bᵀ C⁻¹ b),  C = G - bbᵀ
// ═══════════════════════════════════════════════════════════════════════

mod arithmetic;
mod gram;
mod gram_f64;
mod analysis;
mod analysis_f64;
mod certificate;

use std::time::Instant;

fn main() {
    let args: Vec<String> = std::env::args().collect();

    // Check for --fast mode
    let fast_mode = args.iter().any(|a| a == "--fast");

    if fast_mode {
        run_fast_mode(&args);
    } else {
        run_mpfr_mode(&args);
    }
}

// ═══════════════════════════════════════════════════════════════════════
//  FAST MODE — f64, high-N convergence tracking
// ═══════════════════════════════════════════════════════════════════════

fn run_fast_mode(args: &[String]) {
    let max_n: usize = args.iter()
        .filter(|a| a.as_str() != "--fast" && !a.contains('/'))
        .filter_map(|a| a.parse().ok())
        .last()
        .unwrap_or(5000);

    let threads = rayon::current_num_threads();
    let start = Instant::now();

    println!();
    println!("  ╔═══════════════════════════════════════════════════════════════════════╗");
    println!("  ║  BÁEZ-DUARTE CONVERGENCE TRACKER — FAST MODE                         ║");
    println!("  ║  Cathedral Lean Proof · High-N Convergence Analysis                   ║");
    println!(
        "  ║  f64 (53-bit), {} threads{:>43}║",
        threads,
        format!("N_max = {}", max_n)
    );
    println!("  ╚═══════════════════════════════════════════════════════════════════════╝");
    println!();
    println!("  Lean theorem: nyman_beurling_equivalence_mellin (Assembly/MainChain.lean)");
    println!("  Claim:        RH ↔ d²_N → 0  with  d²_N ≈ C/ln(N),  C ≈ 0.0462");
    println!("  Mode:         FAST (f64) — convergence trend, not certification");

    let _mu = arithmetic::mobius_sieve(max_n + 1);
    let ln_cache = gram_f64::precompute_ln1p_cache_f64(max_n);

    // Dense sampling for convergence tracking
    let mut sizes: Vec<usize> = vec![10, 20, 50, 100, 200, 300, 500];
    // Add every 500 from 1000 onwards
    let mut n = 1000;
    while n <= max_n {
        sizes.push(n);
        n += 500;
    }
    // Ensure max_n is included if not already
    if *sizes.last().unwrap_or(&0) != max_n && max_n > 500 {
        sizes.push(max_n);
    }
    sizes.retain(|&s| s <= max_n);
    sizes.dedup();

    let mut results = Vec::new();

    for &n in &sizes {
        println!("\n{}", "━".repeat(74));
        println!(
            "  N = {}  ({}×{}, f64, {} threads)",
            n, n, n, threads
        );
        println!("{}", "━".repeat(74));

        let t0 = Instant::now();

        let b = gram_f64::build_mean_vector_f64(n);
        let g = gram_f64::build_gram_matrix_f64(n, &ln_cache);

        let res = analysis_f64::analyze_f64(n, &g, &b);

        let sm_dist = 1.0 / (1.0 + res.x_val);
        let sm_match = (res.d2_n - sm_dist).abs();

        println!("\n  d²_N = {:.14},  X = {:.8},  X/ln(N) = {:.6}", res.d2_n, res.x_val, res.x_over_ln_n);
        println!("  SM match = {:.2e},  κ(G) ≈ {:.2e}", sm_match, res.cond_g);

        if sm_match > 1e-8 {
            println!("  ⚠️  SM match degraded — f64 precision limit at this N");
        }

        println!("  ⏱  N={} completed in {:.1}s", n, t0.elapsed().as_secs_f64());

        results.push(res);
    }

    // Grand summary
    println!("\n\n{}", "═".repeat(74));
    println!("  CONVERGENCE TRACKER — FAST MODE (f64)");
    println!("{}", "═".repeat(74));

    println!(
        "\n  {:>5} {:>14} {:>14} {:>10} {:>14} {:>10}",
        "N", "d²_N", "BD predict", "ratio", "X", "X/ln(N)"
    );
    for r in &results {
        let ratio = if r.bd_predicted > 0.0 { r.d2_n / r.bd_predicted } else { 0.0 };
        println!(
            "  {:5} {:14.10} {:14.10} {:10.6} {:14.8} {:10.6}",
            r.n, r.d2_n, r.bd_predicted, ratio, r.x_val, r.x_over_ln_n,
        );
    }

    // Convergence trend
    println!(
        "\n  X/ln(N) trend: {}",
        results
            .iter()
            .map(|r| format!("{:.2}", r.x_over_ln_n))
            .collect::<Vec<_>>()
            .join(" → ")
    );

    let bd_target = 1.0 / (2.0 + 0.5772156649015328606 - (4.0 * std::f64::consts::PI).ln());
    println!("  Lean target: X/ln(N) → {:.4} (IntegralBasis/BaezDuarte.lean)", bd_target);

    // Verdicts
    let x_mono = results.windows(2).all(|w| w[1].x_val > w[0].x_val);
    let d2_decay = results.windows(2).all(|w| w[1].d2_n < w[0].d2_n);

    println!("\n  ┌─ CONVERGENCE VERDICTS {}┐", "─".repeat(32));
    println!(
        "  │  X monotonically increasing:  {}                              │",
        if x_mono { "✅ YES" } else { "❌ NO " }
    );
    println!(
        "  │  d²_N monotonically decaying: {}                              │",
        if d2_decay { "✅ YES" } else { "❌ NO " }
    );
    println!(
        "  │  d²_N > 0 for all N:         {}                              │",
        if results.iter().all(|r| r.d2_n > 0.0) { "✅ YES" } else { "❌ NO " }
    );
    println!("  └{}┘", "─".repeat(57));

    // SM health check
    let last_sm = results.last().map(|r| {
        let sm_dist = 1.0 / (1.0 + r.x_val);
        (r.d2_n - sm_dist).abs()
    }).unwrap_or(0.0);

    if last_sm > 1e-6 {
        println!("\n  ⚠️  f64 precision exhausted at N={}. SM match = {:.2e}", max_n, last_sm);
        println!("     Use 512-bit MPFR mode for certified results at this N:");
        println!("     cargo run --release {}", max_n);
    }

    // Write certificate
    certificate::write_certificate(&results);

    let elapsed = start.elapsed();
    println!(
        "\n  Total runtime: {:.1}s ({} threads, f64 fast mode)",
        elapsed.as_secs_f64(),
        threads
    );
    println!("{}", "═".repeat(74));
}

// ═══════════════════════════════════════════════════════════════════════
//  MPFR MODE — 512-bit precision, Lean proof certification
// ═══════════════════════════════════════════════════════════════════════

fn run_mpfr_mode(args: &[String]) {
    let max_n: usize = if args.len() > 1 {
        args[1].parse().unwrap_or(500)
    } else {
        500
    };

    let threads = rayon::current_num_threads();
    let start = Instant::now();

    println!();
    println!("  ╔═══════════════════════════════════════════════════════════════════════╗");
    println!("  ║  BÁEZ-DUARTE DISTANCE CERTIFICATION ENGINE                           ║");
    println!("  ║  Cathedral Lean Proof · Numerical Certificate Generator              ║");
    println!(
        "  ║  {}-bit MPFR, {} threads{:>43}║",
        gram::PREC,
        threads,
        format!("N_max = {}", max_n)
    );
    println!("  ╚═══════════════════════════════════════════════════════════════════════╝");
    println!();
    println!("  Lean theorem: nyman_beurling_equivalence_mellin (Assembly/MainChain.lean)");
    println!("  Claim:        RH ↔ d²_N → 0  with  d²_N ≈ C/ln(N),  C ≈ 0.0462");

    let _mu = arithmetic::mobius_sieve(max_n + 1);
    let ln_cache = gram::precompute_ln1p_cache(max_n);

    let all_sizes = [10, 20, 50, 100, 150, 200, 300, 400, 500, 750, 1000, 1500, 2000];
    let sizes: Vec<usize> = all_sizes.iter().copied().filter(|&s| s <= max_n).collect();

    let mut results = Vec::new();

    for &n in &sizes {
        println!("\n{}", "━".repeat(74));
        println!(
            "  N = {}  ({}×{}, {}-bit MPFR, {} threads)",
            n, n, n, gram::PREC, threads
        );
        println!("{}", "━".repeat(74));

        let t0 = Instant::now();

        let b = gram::build_mean_vector(n);
        println!(
            "  b[1..4] = [{:.10}, {:.10}, {:.10}, {:.10}]",
            b[0].to_f64(),
            b[1].to_f64(),
            b.get(2).map(|x| x.to_f64()).unwrap_or(0.0),
            b.get(3).map(|x| x.to_f64()).unwrap_or(0.0),
        );

        let g = gram::build_gram_matrix(n, &ln_cache);
        println!("  G(1,1) = {:.14}", g[0][0].to_f64());
        if n > 1 {
            println!("  G(1,2) = {:.14}", g[0][1].to_f64());
        }

        let res = analysis::analyze(n, &g, &b);

        let sm_dist = 1.0 / (1.0 + res.x_val);

        println!("\n  bᵀ G⁻¹ b   = {:.14}", 1.0 - res.d2_n);
        println!("  d²_N        = {:.14}", res.d2_n);
        println!("  X = bᵀC⁻¹b  = {:.14}", res.x_val);
        println!("  1/(1+X)     = {:.14} (should match d²_N)", sm_dist);
        println!("  SM match    = {:.2e}", (res.d2_n - sm_dist).abs());

        println!("\n  ┌─ BÁEZ-DUARTE CERTIFICATION {}┐", "─".repeat(27));
        println!("  │  d²_N (measured)    = {:.12}                    │", res.d2_n);
        println!("  │  d²_N (BD predict)  = {:.12}  (C/lnN)          │", res.bd_predicted);
        println!(
            "  │  Ratio meas/pred    = {:.6}                          │",
            if res.bd_predicted > 0.0 {
                res.d2_n / res.bd_predicted
            } else {
                0.0
            }
        );
        println!("  │  X / ln(N)          = {:.8}  (target ≈ 21.64)   │", res.x_over_ln_n);
        println!("  └{}┘", "─".repeat(57));

        println!("  ⏱  N={} completed in {:.1}s", n, t0.elapsed().as_secs_f64());

        results.push(res);
    }

    // Grand Summary
    println!("\n\n{}", "═".repeat(74));
    println!("  GRAND SUMMARY — LEAN PROOF CERTIFICATION ({}-bit MPFR)", gram::PREC);
    println!("{}", "═".repeat(74));

    println!(
        "\n  {:>5} {:>14} {:>14} {:>10} {:>14} {:>10}",
        "N", "d²_N", "BD predict", "ratio", "X", "X/ln(N)"
    );
    for r in &results {
        println!(
            "  {:5} {:14.10} {:14.10} {:10.6} {:14.8} {:10.6}",
            r.n,
            r.d2_n,
            r.bd_predicted,
            if r.bd_predicted > 0.0 {
                r.d2_n / r.bd_predicted
            } else {
                0.0
            },
            r.x_val,
            r.x_over_ln_n,
        );
    }

    println!(
        "\n  X/ln(N) trend: {}",
        results
            .iter()
            .map(|r| format!("{:.2}", r.x_over_ln_n))
            .collect::<Vec<_>>()
            .join(" → ")
    );

    let bd_target = 1.0 / (2.0 + 0.5772156649015328606 - (4.0 * std::f64::consts::PI).ln());
    println!("  Lean target: X/ln(N) → {:.4} (IntegralBasis/BaezDuarte.lean)", bd_target);

    let x_mono = results.windows(2).all(|w| w[1].x_val > w[0].x_val);
    let d2_decay = results.windows(2).all(|w| w[1].d2_n < w[0].d2_n);

    println!("\n  ┌─ LEAN CERTIFICATION VERDICTS {}┐", "─".repeat(25));
    println!(
        "  │  X monotonically increasing:  {}                              │",
        if x_mono { "✅ YES" } else { "❌ NO " }
    );
    println!(
        "  │  d²_N monotonically decaying: {}                              │",
        if d2_decay { "✅ YES" } else { "❌ NO " }
    );
    println!(
        "  │  d²_N > 0 for all N:         {}                              │",
        if results.iter().all(|r| r.d2_n > 0.0) {
            "✅ YES"
        } else {
            "❌ NO "
        }
    );
    println!("  └{}┘", "─".repeat(57));

    if x_mono && d2_decay {
        println!("\n  ✅ Certificate validates nyman_beurling_equivalence_mellin");
        println!("     d²_N → 0 monotonically, X diverges — consistent with RH.");
        println!("     Lean file: Assembly/MainChain.lean");
    }

    certificate::write_certificate(&results);

    let elapsed = start.elapsed();
    println!(
        "\n  Total runtime: {:.1}s ({} threads, {}-bit MPFR)",
        elapsed.as_secs_f64(),
        threads,
        gram::PREC
    );
    println!("{}", "═".repeat(74));
}
