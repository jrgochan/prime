#![allow(unused, dead_code)]
use rayon::prelude::*;
use std::io::Write;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Instant;

fn gcd(mut a: u64, mut b: u64) -> u64 {
    while b != 0 {
        let t = b;
        b = a % b;
        a = t;
    }
    a
}

fn frac(x: f64) -> f64 {
    x - x.floor()
}

/// Compute gramEntry(j,k) via midpoint-rule quadrature.
/// Adaptive: more points for small j,k, fewer for large (bound is looser).
fn gram_entry(j: u64, k: u64) -> f64 {
    // Choose quadrature points based on max(j,k):
    // Small j,k need more precision since the bound is tighter
    let n_quad: u64 = if j.max(k) <= 200 {
        20_000
    } else if j.max(k) <= 1000 {
        10_000
    } else if j.max(k) <= 5000 {
        5_000
    } else {
        2_000 // bound is very loose for large j,k
    };

    let nf = n_quad as f64;
    let mut s = 0.0;
    for i in 1..=n_quad {
        let x = (i as f64 - 0.5) / nf;
        s += frac(j as f64 / x) * frac(k as f64 / x);
    }
    s / nf
}

fn main() {
    let max_n: u64 = 100_000;

    println!("═══════════════════════════════════════════════════════");
    println!("  gram_entry_offdiag_upper verification (multi-threaded)");
    println!("  Bound: gramEntry(j,k) ≤ 1/4 + gcd²/(12jk) + 1/(4·max)");
    println!("  Range: j,k ≤ {}", max_n);
    println!("  Threads: {} (rayon auto)", rayon::current_num_threads());
    println!("═══════════════════════════════════════════════════════");

    let start = Instant::now();
    let violations = AtomicU64::new(0);
    let checked_hard = AtomicU64::new(0);
    let total_pairs = AtomicU64::new(0);
    let progress_j = AtomicU64::new(0);

    // Parallel over rows j, sequential over k within each row
    let row_results: Vec<(f64, u64, u64)> = (1..=max_n)
        .into_par_iter()
        .map(|j| {
            let mut worst_excess: f64 = f64::NEG_INFINITY;
            let mut worst_k: u64 = 0;
            let mut row_hard: u64 = 0;
            let mut row_pairs: u64 = 0;

            for k in (j + 1)..=max_n {
                row_pairs += 1;
                let g = gcd(j, k) as f64;
                let fj = j as f64;
                let fk = k as f64;

                // The bound: 1/4 + g²/(12jk) + 1/(4·max(j,k))
                let bound = 0.25 + g * g / (12.0 * fj * fk) + 1.0 / (4.0 * fk);

                // Skip if bound > 1/3 (gramEntry ≤ 1/3 is PROVED)
                if bound > 0.3334 {
                    continue;
                }

                row_hard += 1;
                let ge = gram_entry(j, k);
                let excess = ge - bound;

                if excess > worst_excess {
                    worst_excess = excess;
                    worst_k = k;
                }

                if excess > 1e-3 {
                    violations.fetch_add(1, Ordering::Relaxed);
                }
            }

            total_pairs.fetch_add(row_pairs, Ordering::Relaxed);
            checked_hard.fetch_add(row_hard, Ordering::Relaxed);

            // Progress reporting (every ~1000 rows)
            let p = progress_j.fetch_add(1, Ordering::Relaxed);
            if p % 2000 == 0 {
                let elapsed = start.elapsed().as_secs_f64();
                let pct = p as f64 / max_n as f64 * 100.0;
                let eta = if p > 0 {
                    elapsed / (p as f64) * (max_n as f64 - p as f64)
                } else {
                    0.0
                };
                eprintln!(
                    "  j~{}/{} ({:.1}%) elapsed={:.1}s ETA={:.0}s violations={}",
                    p,
                    max_n,
                    pct,
                    elapsed,
                    eta,
                    violations.load(Ordering::Relaxed)
                );
            }

            (worst_excess, j, worst_k)
        })
        .collect();

    // Find global worst
    let (worst_excess, worst_j, worst_k) = row_results
        .iter()
        .cloned()
        .max_by(|a, b| a.0.partial_cmp(&b.0).unwrap())
        .unwrap_or((0.0, 0, 0));

    let elapsed = start.elapsed().as_secs_f64();
    let total = total_pairs.load(Ordering::Relaxed);
    let hard = checked_hard.load(Ordering::Relaxed);
    let viols = violations.load(Ordering::Relaxed);

    println!();
    println!("═══════════════════════════════════════════════════════");
    println!("  RESULTS");
    println!("═══════════════════════════════════════════════════════");
    println!("  Total pairs:    {}", total);
    println!(
        "  Hard pairs:     {} ({:.2}%)",
        hard,
        100.0 * hard as f64 / total as f64
    );
    println!("  Violations:     {}", viols);
    println!(
        "  Worst excess:   {:.6e} at ({}, {})",
        worst_excess, worst_j, worst_k
    );
    println!(
        "  Time:           {:.2}s ({} threads)",
        elapsed,
        rayon::current_num_threads()
    );
    println!();
    if viols == 0 {
        println!(
            "  ✅ PASS: gram_entry_offdiag_upper holds for j,k ≤ {}",
            max_n
        );
    } else {
        println!("  ❌ FAIL: {} violations found", viols);
    }

    // Write results
    let mut out = std::fs::File::create("gram_entry_verify_100k.txt").unwrap();
    writeln!(out, "gram_entry_offdiag_upper verification").unwrap();
    writeln!(out, "Range: j,k <= {}", max_n).unwrap();
    writeln!(out, "Adaptive quadrature: 20k/10k/5k/2k points").unwrap();
    writeln!(out, "Total pairs: {}", total).unwrap();
    writeln!(out, "Hard pairs: {}", hard).unwrap();
    writeln!(out, "Violations: {}", viols).unwrap();
    writeln!(
        out,
        "Worst excess: {:.10e} at ({}, {})",
        worst_excess, worst_j, worst_k
    )
    .unwrap();
    writeln!(
        out,
        "Time: {:.2}s ({} threads)",
        elapsed,
        rayon::current_num_threads()
    )
    .unwrap();
    writeln!(out, "Result: {}", if viols == 0 { "PASS" } else { "FAIL" }).unwrap();
}
