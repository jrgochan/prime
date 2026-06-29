//! Benchmark mode — measure prime choir accuracy vs height and prime count.
//!
//! Answers the question: "How many primes do I need for the choir
//! to reliably detect a zero at height t?"
//!
//! Uses Hardy Z zeros as ground truth for comparison.
//! LUDICROUS MODE: uses parallel interference for large banks.

use cathedral_utils::harmonics::PrimeOscillatorBank;
use cathedral_utils::riemann_siegel::hardy_z;
use cathedral_utils::zeta_zeros;
use std::f64::consts::PI;
use std::time::Instant;

/// Run the scaling benchmark.
pub fn run(bank: &PrimeOscillatorBank) {
    println!("🌀 PRIME CHOIR SCALING BENCHMARK — LUDICROUS MODE");
    println!("   \"How does the choir's hearing degrade with height?\"");
    println!();

    // Memory estimate
    let mem_bytes = bank.len() * (8 + 8 + 8); // usize + f64 + f64
    let mem_mb = mem_bytes as f64 / (1024.0 * 1024.0);
    let mem_gb = mem_mb / 1024.0;
    let p_max = bank.primes.last().unwrap_or(&0);
    let use_par = bank.len() > 50_000;

    println!(
        "   Primes: {} (up to {})",
        format_num(bank.len()),
        format_num(*p_max)
    );
    if mem_gb > 1.0 {
        println!("   Bank memory: {:.2} GB", mem_gb);
    } else {
        println!("   Bank memory: {:.1} MB", mem_mb);
    }
    println!(
        "   Parallel: {} (threshold: 50K primes)",
        if use_par { "YES 🚀" } else { "no" }
    );
    println!(
        "   Cores: {} (rayon auto-detected)",
        rayon::current_num_threads()
    );
    println!();

    // §1: Convergence at first zero — vary prime count
    println!("═══ §1. CONVERGENCE AT t₀ = 14.1347 (1st zero) ═════════════");
    println!("    How many primes before the choir cancels?");
    println!();
    println!(
        "    {:>12}  {:>10}  {:>10}  {:>12}",
        "# Primes", "Up to p", "|Σ|", "Relative"
    );
    println!(
        "    {:>12}  {:>10}  {:>10}  {:>12}",
        "────────────", "──────────", "──────────", "────────────"
    );

    let t0 = 14.134725141734693;
    let max_all = if use_par {
        bank.max_interference_par()
    } else {
        bank.max_interference(bank.len())
    };

    let mut checkpoints: Vec<usize> = vec![
        5,
        10,
        25,
        50,
        100,
        250,
        500,
        1_000,
        2_500,
        5_000,
        10_000,
        25_000,
        50_000,
        100_000,
        250_000,
        500_000,
        1_000_000,
        5_000_000,
        10_000_000,
        50_000_000,
        100_000_000,
        500_000_000,
    ];
    checkpoints.push(bank.len());
    checkpoints.sort();
    checkpoints.dedup();

    for &n in &checkpoints {
        if n > bank.len() {
            continue;
        }
        let norm = bank.interference_norm(t0, n);
        let pct = norm / max_all * 100.0;
        let p_at = bank.primes[n - 1];
        println!(
            "    {:>12}  {:>10}  {:>10.6}  {:>10.4}%",
            format_num(n),
            format_num(p_at),
            norm,
            pct
        );
    }
    println!();

    // §2: Accuracy at known zeros with ALL primes (parallel)
    println!("═══ §2. CHOIR ACCURACY VS HEIGHT ════════════════════════════");
    println!(
        "    |Σ| at known zeros using ALL {} primes {}",
        format_num(bank.len()),
        if use_par { "(parallel)" } else { "" }
    );
    println!();
    println!(
        "    {:>6}  {:>12}  {:>10}  {:>10}  {:>10}  {:>8}",
        "Zero#", "Height t", "|Σ| choir", "Z(t) Hardy", "|Σ|/max%", "Quality"
    );
    println!(
        "    {:>6}  {:>12}  {:>10}  {:>10}  {:>10}  {:>8}",
        "──────", "────────────", "──────────", "──────────", "──────────", "────────"
    );

    let known = zeta_zeros::known_zeros(100);
    let test_indices = [0, 1, 2, 4, 9, 19, 29, 49, 69, 99];

    for &idx in &test_indices {
        if idx >= known.len() {
            continue;
        }
        let t = known[idx];
        let start = Instant::now();
        let norm = if use_par {
            bank.interference_norm_par(t)
        } else {
            bank.interference_norm_all(t)
        };
        let eval_time = start.elapsed();
        let z_val = hardy_z(t);
        let pct = norm / max_all * 100.0;
        let quality = if pct < 1.0 {
            "⭐⭐⭐"
        } else if pct < 5.0 {
            "⭐⭐"
        } else if pct < 15.0 {
            "⭐"
        } else {
            "🔇"
        };
        if idx == 0 {
            println!(
                "    {:>6}  {:>12.4}  {:>10.4}  {:>10.6}  {:>8.4}%  {} ({:.1?}/eval)",
                idx + 1,
                t,
                norm,
                z_val,
                pct,
                quality,
                eval_time
            );
        } else {
            println!(
                "    {:>6}  {:>12.4}  {:>10.4}  {:>10.6}  {:>8.4}%  {}",
                idx + 1,
                t,
                norm,
                z_val,
                pct,
                quality
            );
        }
    }
    println!();

    // §3: Beyond the table — extreme heights
    println!("═══ §3. EXPLORING BEYOND THE TABLE ═══════════════════════════");
    println!("    Finding zeros at increasing heights with Hardy Z,");
    println!("    then measuring how well the prime choir detects them.");
    println!();
    println!(
        "    {:>12}  {:>12}  {:>10}  {:>10}  {:>10}  {:>8}  {:>8}",
        "Height t", "True zero", "|Σ| choir", "Z(t±ε)", "|Σ|/max%", "Audible?", "Time"
    );
    println!(
        "    {:>12}  {:>12}  {:>10}  {:>10}  {:>10}  {:>8}  {:>8}",
        "────────────",
        "────────────",
        "──────────",
        "──────────",
        "──────────",
        "────────",
        "────────"
    );

    let test_heights: Vec<f64> = vec![
        500.0,
        1_000.0,
        2_000.0,
        5_000.0,
        10_000.0,
        20_000.0,
        50_000.0,
        100_000.0,
        500_000.0,
        1_000_000.0,
    ];

    for &h in &test_heights {
        // Local search: find first zero near h via Hardy Z sign change
        if let Some(z) = find_zero_near(h) {
            let start = Instant::now();
            let norm = if use_par {
                bank.interference_norm_par(z)
            } else {
                bank.interference_norm_all(z)
            };
            let eval_time = start.elapsed();
            let z_check = hardy_z(z);
            let pct = norm / max_all * 100.0;
            let audible = if pct < 2.0 {
                "✅ Yes"
            } else if pct < 10.0 {
                "🔉 Faint"
            } else if pct < 30.0 {
                "🔈 Weak"
            } else {
                "🔇 No"
            };
            println!(
                "    {:>12.1}  {:>12.4}  {:>10.4}  {:>10.6}  {:>8.4}%  {:>8}  {:>8}",
                h,
                z,
                norm,
                z_check,
                pct,
                audible,
                format_duration(eval_time)
            );
        }
    }
    println!();

    // §4: Hardware-aware scaling guide
    println!("═══ §4. SCALING GUIDE (96 GB M2 Max) ═════════════════════════");
    println!();
    println!(
        "    {:>12}  {:>10}  {:>10}  {:>12}  {:>8}",
        "Prime limit", "π(N)", "Memory", "Eval time*", "Status"
    );
    println!(
        "    {:>12}  {:>10}  {:>10}  {:>12}  {:>8}",
        "────────────", "──────────", "──────────", "────────────", "────────"
    );

    let scales: Vec<(usize, usize, &str, &str, &str)> = vec![
        (10_000, 1_229, "0.03 MB", "~1 µs", "✅"),
        (100_000, 9_592, "0.2 MB", "~10 µs", "✅"),
        (1_000_000, 78_498, "1.8 MB", "~100 µs", "✅"),
        (10_000_000, 664_579, "15 MB", "~1 ms", "✅"),
        (100_000_000, 5_761_455, "132 MB", "~10 ms", "✅"),
        (1_000_000_000, 50_847_534, "1.2 GB", "~100 ms", "✅"),
        (10_000_000_000, 455_052_511, "10.4 GB", "~1 sec", "🚀 96GB"),
    ];

    for (limit, pi_n, mem, eval_t, status) in &scales {
        println!(
            "    {:>12}  {:>10}  {:>10}  {:>12}  {:>8}",
            format_num(*limit),
            format_num(*pi_n),
            mem,
            eval_t,
            status
        );
    }
    println!();
    println!("    * Per evaluation with 12-core parallel. Sweep of 1000 heights = 1000×.");
    println!();

    // Summary
    println!("🌀 ═══════════════════════════════════════════════════════════");
    println!(
        "   SUMMARY: {} primes loaded in {:.1} {}",
        format_num(bank.len()),
        if mem_gb > 1.0 { mem_gb } else { mem_mb },
        if mem_gb > 1.0 { "GB" } else { "MB" }
    );
    println!();
    println!("   The choir reliably hears zeros where |Σ|/max < ~5%.");
    println!("   For higher zeros: --hardy-z (no prime limit needed).");
    println!("   For physics: the choir shows WHY zeros cancel.");
    println!("   For computation: Hardy Z shows WHERE zeros are.");
    println!("═══════════════════════════════════════════════════════════════");
}

fn format_num(n: usize) -> String {
    if n >= 1_000_000_000 {
        format!("{:.1}B", n as f64 / 1e9)
    } else if n >= 1_000_000 {
        format!("{:.1}M", n as f64 / 1e6)
    } else if n >= 10_000 {
        format!("{:.0}K", n as f64 / 1e3)
    } else {
        format!("{}", n)
    }
}

fn format_duration(d: std::time::Duration) -> String {
    let us = d.as_micros();
    if us < 1_000 {
        format!("{}µs", us)
    } else if us < 1_000_000 {
        format!("{:.1}ms", us as f64 / 1000.0)
    } else {
        format!("{:.2}s", us as f64 / 1_000_000.0)
    }
}

/// Find the first zero of Z(t) near height `h` using local Hardy Z sign-change search.
///
/// Instead of scanning from t=6 (which takes O(N(h)) time), we start at `h`
/// and scan forward with adaptive step size. O(1) in the height.
fn find_zero_near(h: f64) -> Option<f64> {
    let expected_gap = 2.0 * PI / (h / (2.0 * PI)).ln();
    let dt = expected_gap * 0.2; // Step 1/5 of expected gap

    let mut t = h;
    let mut z_prev = hardy_z(t);

    // Scan forward up to 10 gaps
    for _ in 0..(50.0 / dt) as usize {
        let t_next = t + dt;
        let z_next = hardy_z(t_next);

        if z_prev * z_next < 0.0 {
            // Sign change — bisect to machine precision
            let (mut lo, mut hi) = (t, t_next);
            let mut zlo = z_prev;
            for _ in 0..64 {
                let mid = (lo + hi) / 2.0;
                let zm = hardy_z(mid);
                if zlo * zm < 0.0 {
                    hi = mid;
                } else {
                    lo = mid;
                    zlo = zm;
                }
            }
            return Some((lo + hi) / 2.0);
        }

        t = t_next;
        z_prev = z_next;
    }
    None
}
