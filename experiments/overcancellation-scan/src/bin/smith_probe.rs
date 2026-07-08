#![allow(
    dead_code,
    unused_variables,
    unused_imports,
    unused_assignments,
    clippy::needless_range_loop,
    clippy::doc_lazy_continuation,
    non_snake_case,
    clippy::empty_line_after_doc_comments
)]
// overcancellation-scan/src/bin/smith_probe.rs
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║  SMITH COEFFICIENT PROBE — y_d Decay Analysis                   ║
// ║                                                                   ║
// ║  Computes the divisor coefficients y_d from the Smith             ║
// ║  decomposition of vᵀRv, and checks whether                       ║
// ║  |y_d| · d · log(N) is bounded (uniformly in d and N).           ║
// ║                                                                   ║
// ║  If YES: PNT-in-APs (Siegel-Walfisz) may close overcancellation ║
// ║  If NO: need a different approach                                 ║
// ╚═══════════════════════════════════════════════════════════════════╝

use cathedral_utils::arith::mobius_table;

/// Compute the BD log-cutoff weight: w(k, N) = 1 - ln(k)/ln(N)
fn log_weight(k: usize, n: usize) -> f64 {
    if k >= n {
        return 0.0;
    }
    1.0 - (k as f64).ln() / (n as f64).ln()
}

/// Compute the BD witness vector entry: v(k) = -μ(k) · w(k, N)
fn witness_entry(mu_k: i8, k: usize, n: usize) -> f64 {
    -(mu_k as f64) * log_weight(k, n)
}

/// Compute the divisor coefficient y_d = Σ_{d|k, k≤N} v(k)/k
fn divisor_coeff(mu: &[i8], d: usize, n: usize) -> f64 {
    let mut sum = 0.0f64;
    let mut k = d;
    while k <= n {
        let mu_k = mu[k];
        if mu_k != 0 {
            let v_k = witness_entry(mu_k, k, n);
            sum += v_k / (k as f64);
        }
        k += d;
    }
    sum
}

/// Compute J₂(d) = d² · Π_{p|d} (1 - 1/p²)
fn jordan_totient2(d: usize) -> f64 {
    if d == 0 {
        return 0.0;
    }
    let d_f = d as f64;
    let mut result = d_f * d_f;
    let mut n = d;
    let mut p = 2;
    while p * p <= n {
        if n.is_multiple_of(p) {
            result *= 1.0 - 1.0 / (p as f64 * p as f64);
            while n.is_multiple_of(p) {
                n /= p;
            }
        }
        p += 1;
    }
    if n > 1 {
        result *= 1.0 - 1.0 / (n as f64 * n as f64);
    }
    result
}

fn main() {
    println!("╔═══════════════════════════════════════════════════════════╗");
    println!("║  SMITH COEFFICIENT PROBE — y_d Decay Analysis            ║");
    println!("║  Does |y_d| · d · log(N) stay bounded?                   ║");
    println!("╚═══════════════════════════════════════════════════════════╝");
    println!();

    // Test points: various N values
    let test_ns: Vec<usize> = vec![1000, 5000, 10000, 50000, 100000, 500000, 1000000];
    let max_n = *test_ns.last().unwrap();

    println!("Sieving Möbius function up to {}...", max_n);
    let mu = mobius_table(max_n);
    println!("Done.\n");

    // ─── SECTION 1: y_d values for small d ───
    println!("═══════════════════════════════════════════════════════════");
    println!("§1. DIVISOR COEFFICIENTS y_d FOR SMALL d");
    println!("═══════════════════════════════════════════════════════════");
    println!();

    let d_values: Vec<usize> = (1..=30).collect();

    // Header
    print!("{:>5} ", "d");
    for &n in &test_ns {
        print!("{:>14} ", format!("N={}", n));
    }
    println!();
    print!("{:>5} ", "-----");
    for _ in &test_ns {
        print!("{:>14} ", "--------------");
    }
    println!();

    for &d in &d_values {
        print!("{:>5} ", d);
        for &n in &test_ns {
            let yd = divisor_coeff(&mu, d, n);
            print!("{:>14.8} ", yd);
        }
        println!();
    }

    // ─── SECTION 2: Scaled coefficients |y_d| · d · log(N) ───
    println!();
    println!("═══════════════════════════════════════════════════════════");
    println!("§2. SCALED COEFFICIENTS: |y_d| · d · log(N)");
    println!("    If PNT-in-APs works, these should be BOUNDED (O(1))");
    println!("═══════════════════════════════════════════════════════════");
    println!();

    print!("{:>5} ", "d");
    for &n in &test_ns {
        print!("{:>14} ", format!("N={}", n));
    }
    println!();
    print!("{:>5} ", "-----");
    for _ in &test_ns {
        print!("{:>14} ", "--------------");
    }
    println!();

    for &d in &d_values {
        print!("{:>5} ", d);
        for &n in &test_ns {
            let yd = divisor_coeff(&mu, d, n);
            let log_n = (n as f64).ln();
            let scaled = yd.abs() * (d as f64) * log_n;
            print!("{:>14.6} ", scaled);
        }
        println!();
    }

    // ─── SECTION 3: Smith sum Σ J₂(d) · y_d² ───
    println!();
    println!("═══════════════════════════════════════════════════════════");
    println!("§3. SMITH SUM: 12·vᵀRv = Σ J₂(d) · y_d²");
    println!("    Target: should be ≈ 12 (giving vᵀRv ≈ 1)");
    println!("    Overcancellation: should be < 12 (giving vᵀGv < 1)");
    println!("═══════════════════════════════════════════════════════════");
    println!();

    print!(
        "{:>10} {:>14} {:>14} {:>14} {:>14} {:>14}",
        "N", "y₁²", "Σ_{d≥2}", "Total", "vᵀRv", "vᵀGv_est"
    );
    println!();
    print!(
        "{:>10} {:>14} {:>14} {:>14} {:>14} {:>14}",
        "----------",
        "--------------",
        "--------------",
        "--------------",
        "--------------",
        "--------------"
    );
    println!();

    for &n in &test_ns {
        let _log_n = (n as f64).ln();

        // Compute y_1
        let y1 = divisor_coeff(&mu, 1, n);
        let y1_sq = y1 * y1;

        // Compute full Smith sum
        let mut smith_sum = 0.0f64;
        let mut tail_sum = 0.0f64;
        for d in 1..=n {
            let yd = divisor_coeff(&mu, d, n);
            let j2d = jordan_totient2(d);
            let term = j2d * yd * yd;
            smith_sum += term;
            if d >= 2 {
                tail_sum += term;
            }
        }

        let v_r_v = smith_sum / 12.0;

        // Estimate (Σv)² = (Σ μ(k)w(k))²
        let mut sum_v = 0.0f64;
        for k in 1..=n {
            if mu[k] != 0 {
                sum_v += witness_entry(mu[k], k, n);
            }
        }
        let rank1 = 0.25 * sum_v * sum_v;
        let v_g_v_est = v_r_v + rank1;

        println!(
            "{:>10} {:>14.8} {:>14.8} {:>14.8} {:>14.8} {:>14.8}",
            n, y1_sq, tail_sum, smith_sum, v_r_v, v_g_v_est
        );
    }

    // ─── SECTION 4: Tail distribution ───
    println!();
    println!("═══════════════════════════════════════════════════════════");
    println!("§4. TAIL DISTRIBUTION: Cumulative sum J2(d)*y_d^2 for d>=2");
    println!("    How fast does the tail converge?");
    println!("═══════════════════════════════════════════════════════════");
    println!();

    let n_for_tail = 100000;
    println!("N = {}", n_for_tail);
    println!();

    let y1 = divisor_coeff(&mu, 1, n_for_tail);
    println!("y₁ = {:.10}  (should be ≈ -1)", y1);
    println!();

    print!(
        "{:>8} {:>14} {:>14} {:>14} {:>14}",
        "D_max", "cumul_tail", "% of budget", "max|y_d|*d", "d*"
    );
    println!();
    print!(
        "{:>8} {:>14} {:>14} {:>14} {:>14}",
        "--------", "--------------", "--------------", "--------------", "--------------"
    );
    println!();

    let budget = 12.0 - y1 * y1; // budget left for d ≥ 2

    let checkpoints = [
        5, 10, 20, 50, 100, 200, 500, 1000, 5000, 10000, 50000, 100000,
    ];
    let mut cumulative = 0.0f64;
    let mut max_yd_d = 0.0f64;
    let mut max_d_star = 1usize;
    let mut prev_checkpoint = 1usize;

    for &checkpoint in &checkpoints {
        if checkpoint > n_for_tail {
            break;
        }
        for d in (prev_checkpoint + 1)..=checkpoint {
            let yd = divisor_coeff(&mu, d, n_for_tail);
            let j2d = jordan_totient2(d);
            cumulative += j2d * yd * yd;
            let scaled = yd.abs() * (d as f64);
            if scaled > max_yd_d {
                max_yd_d = scaled;
                max_d_star = d;
            }
        }
        let pct = if budget > 0.0 {
            100.0 * cumulative / budget
        } else {
            0.0
        };
        println!(
            "{:>8} {:>14.8} {:>13.4}% {:>14.8} {:>14}",
            checkpoint, cumulative, pct, max_yd_d, max_d_star
        );
        prev_checkpoint = checkpoint;
    }

    // ─── SECTION 5: The verdict ───
    println!();
    println!("═══════════════════════════════════════════════════════════");
    println!("§5. VERDICT");
    println!("═══════════════════════════════════════════════════════════");
    println!();

    // Check the N = 100000 case
    let n_check = 100000;
    let _y1_check = divisor_coeff(&mu, 1, n_check);
    let log_n_check = (n_check as f64).ln();

    // Compute scaled coefficients for d = 2..20
    println!("Scaled coefficients |y_d|·d·log(N) at N = {}:", n_check);
    let mut all_bounded = true;
    let mut max_scaled = 0.0f64;
    for d in 1..=20 {
        let yd = divisor_coeff(&mu, d, n_check);
        let scaled = yd.abs() * (d as f64) * log_n_check;
        if d >= 2 && scaled > 5.0 {
            all_bounded = false;
        }
        if d >= 2 && scaled > max_scaled {
            max_scaled = scaled;
        }
        println!(
            "  d={:>3}: y_d = {:>12.8}, |y_d|·d·logN = {:>10.4}",
            d, yd, scaled
        );
    }

    println!();
    if all_bounded {
        println!("✅ RESULT: |y_d|·d·log(N) appears BOUNDED for small d.");
        println!("   The Siegel-Walfisz path looks PROMISING.");
    } else {
        println!("⚠  RESULT: |y_d|·d·log(N) may be GROWING.");
        println!("   Max scaled value: {:.4}", max_scaled);
        println!("   Need to investigate further.");
    }

    // Final vᵀGv estimate
    println!();
    let mut full_smith = 0.0f64;
    for d in 1..=n_check {
        let yd = divisor_coeff(&mu, d, n_check);
        let j2d = jordan_totient2(d);
        full_smith += j2d * yd * yd;
    }
    let v_r_v = full_smith / 12.0;
    let mut sum_v = 0.0f64;
    for k in 1..=n_check {
        if mu[k] != 0 {
            sum_v += witness_entry(mu[k], k, n_check);
        }
    }
    let v_g_v = v_r_v + 0.25 * sum_v * sum_v;

    println!("Final check at N = {}:", n_check);
    println!("  12·vᵀRv = Σ J₂·y² = {:.8}", full_smith);
    println!("  vᵀRv = {:.8}", v_r_v);
    println!("  (Σv)² = {:.8}", sum_v * sum_v);
    println!("  vᵀGv = vᵀRv + ¼(Σv)² = {:.8}", v_g_v);
    println!(
        "  vᵀGv {} 1  →  {}",
        if v_g_v <= 1.0 { "≤" } else { ">" },
        if v_g_v <= 1.0 {
            "OVERCANCELLATION ✅"
        } else {
            "no overcancellation ❌"
        }
    );
}
