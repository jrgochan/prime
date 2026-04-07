//! Focused high-N aggregate excess computation with parallelism.
//! Usage: cargo run --release --bin high_n -- <N>

use rayon::prelude::*;

use offdiag_excess::gram_entry;

fn main() {
    let n: usize = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(500);

    eprintln!("Computing aggregate off-diagonal excess for n={} (indices 1..={})", n, n);
    eprintln!("Total entries: {} (parallelized)", n * (n - 1));

    let start = std::time::Instant::now();

    // Compute all off-diagonal entries in parallel
    // Index pairs (i, j) where i != j, both in 0..n
    let pairs: Vec<(usize, usize)> = (0..n)
        .flat_map(|i| (0..n).filter(move |&j| i != j).map(move |j| (i, j)))
        .collect();

    let total_pairs = pairs.len();
    let chunk_size = total_pairs / 100 + 1;
    let progress = std::sync::atomic::AtomicUsize::new(0);

    let results: Vec<(f64, f64)> = pairs
        .par_chunks(chunk_size)
        .map(|chunk| {
            let mut excess = 0.0;
            let mut offdiag = 0.0;
            for &(i, j) in chunk {
                let g = gram_entry(i + 1, j + 1);
                offdiag += g;
                excess += g - 0.25;
            }
            let done = progress.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
            if done % 10 == 0 {
                eprint!("\r  Progress: {}%", (done + 1) * 100 / (total_pairs / chunk_size + 1));
            }
            (excess, offdiag)
        })
        .collect();

    let total_excess: f64 = results.iter().map(|r| r.0).sum();
    let total_offdiag: f64 = results.iter().map(|r| r.1).sum();

    // Compute diagonal sum
    let diag_sum: f64 = (0..n).into_par_iter().map(|i| gram_entry(i + 1, i + 1)).sum();

    let elapsed = start.elapsed();
    let n_pairs = n * (n - 1);
    let avg_offdiag = total_offdiag / n_pairs as f64;

    eprintln!("\n\n═══ Results for n={} ═══", n);
    eprintln!("  Total off-diagonal excess: {:.4}", total_excess);
    eprintln!("  Excess / n:                {:.6}", total_excess / n as f64);
    eprintln!("  Excess / n²:               {:.8}", total_excess / (n as f64 * n as f64));
    eprintln!("  Avg off-diagonal entry:    {:.8}", avg_offdiag);
    eprintln!("  Mean excess per pair:      {:.8}", total_excess / n_pairs as f64);
    eprintln!("  Diagonal sum:              {:.4}", diag_sum);
    eprintln!("  Gram sum:                  {:.4}", diag_sum + total_offdiag);
    eprintln!("  Bound 3n:                  {:.0}", 3.0 * n as f64);
    eprintln!("  Excess > 3n?               {}", if total_excess > 3.0 * n as f64 { "YES ❌" } else { "NO ✅" });
    eprintln!("  Time:                      {:.1}s", elapsed.as_secs_f64());

    // Also output as JSON for analysis
    println!("{{");
    println!("  \"n\": {},", n);
    println!("  \"total_excess\": {:.8},", total_excess);
    println!("  \"excess_per_n\": {:.8},", total_excess / n as f64);
    println!("  \"excess_per_n2\": {:.10},", total_excess / (n as f64 * n as f64));
    println!("  \"avg_offdiag\": {:.10},", avg_offdiag);
    println!("  \"diag_sum\": {:.8},", diag_sum);
    println!("  \"gram_sum\": {:.8},", diag_sum + total_offdiag);
    println!("  \"bound_3n\": {:.0},", 3.0 * n as f64);
    println!("  \"violates\": {}", total_excess > 3.0 * n as f64);
    println!("}}");
}
