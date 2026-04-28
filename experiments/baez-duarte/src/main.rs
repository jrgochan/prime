// ═══════════════════════════════════════════════════════════════════════
//  BÁEZ-DUARTE DISTANCE CERTIFICATION ENGINE
//  The Cathedral — 512-bit MPFR, Massively Parallel
//
//  Computes the Nyman-Beurling distance d²_N for the basis
//    h_k(x) = {1/(kx)}   with θ = 1/k ≤ 1
//
//  Under u = 1/x:
//    G(j,k) = ∫₁^∞ {u/j}{u/k}/u² du   (Gram matrix)
//    b_k = (ln(k) + 1 - γ) / k          (mean vector)
//    d²_N = 1 - bᵀ G⁻¹ b               (NB distance)
//    X = bᵀ C⁻¹ b,  C = G - bbᵀ        (Sherman-Morrison)
//
//  Expected (RH true): d²_N ~ C/ln(N),  X/ln(N) → 1/C ≈ 21.64
//
//  Usage: cargo run --release [MAX_N]
//         cargo run --release 1000
// ═══════════════════════════════════════════════════════════════════════

mod arithmetic;
mod gram;
mod analysis;
mod certificate;

use std::time::Instant;

fn main() {
    let args: Vec<String> = std::env::args().collect();
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
    println!("  ║  h_k(x) = {{1/(kx)}}  ·  d²_N = 1 - bᵀG⁻¹b                          ║");
    println!(
        "  ║  Cathedral v12 — {}-bit MPFR, {} threads{:>29}║",
        gram::PREC,
        threads,
        format!("N_max = {}", max_n)
    );
    println!("  ╚═══════════════════════════════════════════════════════════════════════╝");

    // Precompute Möbius function
    let _mu = arithmetic::mobius_sieve(max_n + 1);

    // Choose sample sizes up to max_n
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

        // Build mean vector
        let b = gram::build_mean_vector(n);
        println!(
            "  b[1..4] = [{:.10}, {:.10}, {:.10}, {:.10}]",
            b[0].to_f64(),
            b[1].to_f64(),
            b.get(2).map(|x| x.to_f64()).unwrap_or(0.0),
            b.get(3).map(|x| x.to_f64()).unwrap_or(0.0),
        );

        // Build Gram matrix
        let g = gram::build_gram_matrix(n);
        println!("  G(1,1) = {:.14}", g[0][0].to_f64());
        if n > 1 {
            println!("  G(1,2) = {:.14}", g[0][1].to_f64());
        }

        // Full analysis
        let res = analysis::analyze(n, &g, &b);

        // Report
        let sm_dist = 1.0 / (1.0 + res.x_val);

        println!("\n  bᵀ G⁻¹ b   = {:.14}", 1.0 - res.d2_n);
        println!("  d²_N        = {:.14}", res.d2_n);
        println!("  X = bᵀC⁻¹b  = {:.14}", res.x_val);
        println!("  1/(1+X)     = {:.14} (should match d²_N)", sm_dist);
        println!("  SM match    = {:.2e}", (res.d2_n - sm_dist).abs());

        println!("\n  ┌─ SPECTRAL DATA {}┐", "─".repeat(38));
        println!(
            "  │  G: λ_min≈{:.6e}  λ_max≈{:.6e}  κ≈{:.1}  │",
            res.lambda_min_g, res.lambda_max_g, res.cond_g
        );
        println!(
            "  │  C: λ_min≈{:.6e}  κ≈{:.1}  │",
            res.lambda_min_c, res.cond_c
        );
        println!("  └{}┘", "─".repeat(57));

        println!("\n  ┌─ BÁEZ-DUARTE {}┐", "─".repeat(40));
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

    // ═══════════════════════════════════════════════
    // Grand Summary
    // ═══════════════════════════════════════════════
    println!("\n\n{}", "═".repeat(74));
    println!("  GRAND SUMMARY — BÁEZ-DUARTE ({}-bit MPFR, {} threads)", gram::PREC, threads);
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
    println!("  BD theoretical: X/ln(N) → {:.4}", bd_target);

    // Verdicts
    let x_mono = results.windows(2).all(|w| w[1].x_val > w[0].x_val);
    let d2_decay = results.windows(2).all(|w| w[1].d2_n < w[0].d2_n);

    println!("\n  ┌─ VERDICTS {}┐", "─".repeat(44));
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
        println!("\n  ✅ The Riemann Hypothesis is being captured!");
        println!("     d²_N → 0 monotonically, X diverges — consistent with RH.");
    }

    // Write certificate
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
